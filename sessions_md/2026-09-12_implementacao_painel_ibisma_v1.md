# Sessão — Implementação da primeira versão do painel IBISMA (v4)

- **Data:** 12/09/2026
- **Pacote:** `painel_ibisma_v4`
- **Objetivo:** construir a primeira versão do painel do IBISMA — Índice Brasileiro de
  Insegurança em Saúde Materna — em R/Shiny + golem + bslib, de forma modular,
  responsiva e validada com smoke tests visuais/headless.

---

## 1. Reconhecimento inicial

### 1.1 Documentação do projeto

`AGENTS.md` foi lido integralmente. Pontos que guiaram a implementação:

- Cores do OOBr (azul escuro `#0A1E3C`, azul claro `#32A0FF`, amarelo, verde etc.).
- Tamanhos de fonte apenas via classes/variáveis de
  `inst/app/www/global/custom.css`.
- Inputs de seleção devem usar `shinyWidgets::slimSelectInput` sempre que possível.
- Comentários em português, em gerúndio, de preferência uma linha por comentário.
- Código simples, sem over-engineering, comentado de forma extensiva.
- `devtools::test()` para testes; `dev/headless_smoke.R` para smoke visual/headless.

### 1.2 Estrutura existente

O projeto continha apenas o esqueleto golem:

```
R/            app_config.R, app_server.R, app_ui.R, run_app.R
inst/app/www/ global/custom.css (só variáveis de fonte), funcoes_javascript.js (vazio), logos/
data/         df_ibisma.rda
data-raw/     cria_rda.R, databases/base_exemplo_ibisma.csv, tabela_aux_municipios.csv
dev/          01_start.R, 02_dev.R, 03_deploy.R, run_dev.R
```

Descobertas que exigiram cuidado:

- `inst/app/www/logos/global/` guardava cópias antigas e gigantes de CSS/JS
  (~311 KB + ~659 KB) que o `golem::bundle_resources()` carregaria automaticamente,
  quebrando o layout. **Solução:** deixar de usar `bundle_resources()` e carregar
  explicitamente apenas `www/global/custom.css` e `www/global/funcoes_javascript.js`.
  Os arquivos antigos não foram apagados.

### 1.3 Dados (`data/df_ibisma.rda`)

| Característica | Valor |
| --- | --- |
| Linhas | 55.699 |
| Municípios | 5.570 |
| Anos | 2015 a 2024 |
| Colunas | `ano`, `codmunres` (6 dígitos — padrão DATASUS), `bloco1..bloco6`, `indice_final`, `municipio`, `uf`, `sigla_uf`, `regiao`, `cod_r_saude`, `r_saude`, `cod_macro_r_saude`, `macro_r_saude` |
| Valores | Percentis em 0–1 (uniformes por ano); exibidos em 0–100 |
| Ausências | Nenhum `NA`; apenas **Borá/SP não tem 2023** (5569 municípios no ano) |
| Extras | Colunas para níveis futuros já disponíveis: `regiao`, `r_saude`, `macro_r_saude` |

O código municipal tem 6 dígitos (equivalente ao código IBGE de 7 dígitos sem o
dígito verificador). A malha do `geobr` foi ligada por
`substr(code_muni, 1, 6)` — cobertura de **100%**.

### 1.4 Ambiente

R 4.4.3 (Windows). Pacotes relevantes disponíveis: `shiny` 1.13, `golem` 0.5.1,
`bslib` 0.10, `shinyWidgets` 0.9.1, `leaflet` 2.2.2, `sf` 1.0.20, `geobr` 2.0.1,
`echarts4r` 0.4.5, `reactable` 0.4.4, `highcharter` 0.12.2, `waiter` 0.2.5,
`fontawesome` 0.5.3, `chromote` 0.5.1, `callr` 3.7.6, `devtools` 2.4.5,
`roxygen2` 7.3.2, `testthat` 3.2.3.

### 1.5 Referências de UX estudadas

- **US MVI (Surgo)** — mapa com filtro por tema em "pills", legenda de 5 classes
  ("Very High" a "Very Low"), dica de hover, comparação por clique e rodapé com
  fontes. Inspirou o Panorama.
- **Índice de Transparência Covid-19 (OKBR)** — mapa à esquerda e ranking à
  direita, alternância Estados/Capitais, medalhas de nível e trilha de leitura.
  Inspirou a integração mapa + ranking.
- **IMAPI** — perfil do município com nome em destaque, métricas de contexto,
  flor de domínios e rankings Brasil/estadual. Inspirou o Perfil.

Nenhum painel anterior do IBISMA foi consultado — a construção partiu das
instruções e das referências acima, por decisão explícita do usuário.

---

## 2. Avaliação e decisões tomadas

1. **Visão geral + Ranking integrados** na seção "Panorama". Motivos: controles
   únicos (nível, ano, medida), menos sincronização de estado, mapa e ranking se
   destacam mutuamente, página mais curta. No desktop ficam lado a lado (6/6); no
   mobile empilham.
2. **Navbar com 2 âncoras** (`Panorama`, `Perfil dos municípios`), scroll suave,
   item ativo via JS (scrollspy) e menu colapsável no mobile.
3. **Cores:** IBISMA em 5 tons de roxo; cada bloco com cor própria; "Sem dados"
   em cinza. Medidas de bloco usam rampa própria no mapa (clareia → escurece a
   partir da cor do bloco); o IBISMA usa a rampa roxa.
4. **Flor do perfil:** pétalas proporcionais (0–100) com os nomes reais dos
   blocos e pontos da **mediana Brasil** como referência (em vez de réplica
   decorativa sem escala).
5. **Comparação entre municípios:** barras de diferença (cor por direção) +
   tabela com valores e Δ, em vez de duas flores sobrepostas (ilegível).
6. **Bibliotecas por componente:** `leaflet` (mapa, canvas e sem tiles externos),
   `reactable` (ranking), `echarts4r` (flor, evolução e diferenças).
7. **`highcharter` foi descartado** durante a sessão: o Highcharts não é gratuito
   para uso governamental (Fiocruz se enquadra) e o aviso aparece no carregamento
   do pacote. Toda a visualização foi unificada em ECharts (Apache-2.0).
8. **Nível de análise** implementado como configuração (`NIVEIS_ANALISE`) com
   apenas "Município" habilitado; UF/região entram depois acrescentando linhas.

---

## 3. Malha geográfica (data-raw/prepara_malha.R)

- `geobr::read_municipality(year = 2020)` e `read_state(year = 2020)`; a malha
  do geobr já vem simplificada (`simplified = TRUE`).
- **Descoberta importante:** o CRS é EPSG:4674 (geodésico), então
  `sf::st_simplify(dTolerance = ...)` interpreta a tolerância em **metros**.
- Simplificação com tolerância **2.000 m** e recuperação dos 3 municípios que
  desapareceriam usando a malha de 1.000 m.
- Conversão para **EPSG:4326** (exigência do leaflet).
- Chave `codmunres` de 6 dígitos criada a partir de `substr(code_muni, 1, 6)`.
- Saídas salvas em `inst/app/data/`:
  - `malha_municipios.rds` — 1,0 MB (5.570 municípios)
  - `malha_ufs.rds` — 0,09 MB (27 UFs)
- Validação de cobertura: 100% dos códigos da base encontrados na malha.

Arquivos gerados (não versionados como data de pacote, servidos como recurso do app).

---

## 4. Arquitetura entregue

```
R/
├── app_config.R              (existente) caminhos e config golem
├── app_ui.R                  shell: tema bslib, navbar por âncoras, seções, recursos com cache-busting
├── app_server.R              cache da base, estado compartilhado do município, waiter, módulos
├── run_app.R                 (existente)
├── fct_config.R              BLOCOS, MEDIDAS, PALETA_IBISMA, CATEGORIAS, NIVEIS_ANALISE, textos
├── fct_cores.R               cor_medida, paleta_categorias, cor_categoria, paleta_mapa, contraste
├── fct_dados.R               preparar_dados, tabela_ano, valores_ano, resumo_municipio, séries,
│                             comparações, opções de seletores, formatadores pt-BR
├── fct_mapa.R                malha em cache, dados_mapa, malha_do_ano, tooltip, leaflet base,
│                             desenho de municípios/UF e mensagem customizada de atualização
├── fct_graficos.R            estilo e tooltips ECharts, flor polar, evolução, diferenças, gráfico vazio
├── utils_ui.R                tema_ibisma, navbar, título de seção, controle em frase, selos,
│                             legenda, métrica, estado vazio, rodapé, atualizar_seletor
├── mod_panorama.R            controles, mapa, legenda, ranking reactable e sincronizações
├── mod_perfil_municipio.R    hero, flor, índice, evolução, comparação e estados sem dado
└── painel_ibisma_v4-package.R doc do pacote (import shiny, sf)

inst/app/www/global/
├── custom.css               identidade visual completa (~25 KB)
└── funcoes_javascript.js    handler do mapa + scrollspy/menu (~3,5 KB)

tests/testthat/
├── test-funcoes_globais.R   61 testes das funções globais
└── (tests/testthat.R)

dev/headless_smoke.R         smoke test visual/headless parametrizável
```

### 4.1 Configuração central (`fct_config.R`)

- `BLOCOS`: bloco1=Social, bloco2=Planejamento Reprodutivo, bloco3=Pré-natal,
  bloco4=Parto, bloco5=Sistema de saúde, bloco6=Clima — **ordem confirmada pelo
  usuário** (o arquivo de dados não traz dicionário).
- Cores dos blocos: Social `#FAC80F`, Planejamento `#41BE3C`, Pré-natal
  `#32A0FF`, Parto `#E4572E`, Sistema `#1E5AA0`, Clima `#00A6A6`.
- `PALETA_IBISMA` (5 classes): `#EFE6F7`, `#C9A8E4`, `#9F6FD0`, `#7239A8`, `#4B1D73`.
- `PROBS_CORTES = c(.2, .4, .6, .8)` — categorias por quintis da distribuição de
  cada ano e medida.

### 4.2 Dados (`fct_dados.R`)

- `dados_ibisma()` prepara a base **uma vez por processo** (cache em ambiente).
- Formato longo com as 7 medidas, valores em 0–100.
- `tabela_ano()` (com cache por ano) calcula, para cada medida: cortes, categoria,
  rank nacional e rank na UF (posição 1 = mais vulnerável).
- `resumo_municipio()`, `serie_municipio()`, `comparar_series()`, `comparar_ano()`.
- `municipio_padrao()`: abre o painel no município mais vulnerável do último ano
  (Jutaí/AM em 2024).
- `frase_percentil()` limita o texto a "acima de 99%" para não dizer 100%.
- Formatadores pt-BR (`12,3`, `5.570`, `1.234º de 5.570`).

### 4.3 Mapa (`fct_mapa.R`)

- Malha carregada em cache de processo.
- `malha_do_ano()` junta geometria + cor + tooltip e cria `codmunres_txt`
  (o leaflet só indexa `layerId` do tipo string).
- Tooltip em HTML próprio (município/UF, medida, valor e selo de categoria),
  incluindo "Sem dados" em cinza.
- Sem tiles externos (estética editorial), `preferCanvas = TRUE`, contornos de UF
  por cima e reenquadramento do Brasil após `invalidateSize()`.

### 4.4 Gráficos (`fct_graficos.R`)

- Tema ECharts com fonte Source Sans Pro e tooltips padronizados.
- **Flor polar** (`grafico_flor`): `e_polar` + barras com `coord_system = "polar"`,
  `e_angle_axis(serie = nome)` para os rótulos dos blocos, pontos da mediana
  Brasil e legenda própria.
- **Evolução** (`grafico_evolucao`): até 2 séries (linha cheia e tracejada),
  eixo X de anos como eixo de valor (2015–2024) e marcador do ano selecionado.
- **Diferenças** (`grafico_diferencas`): barras horizontais centradas no zero,
  cor coral (mais insegurança) / verde (menos insegurança) e tooltip com valores.
- `grafico_vazio()` sempre com título (ver seção de correções).

### 4.5 UI/UX

- Controles em frase natural com `slimSelectInput` sublinhado ("Mostrar IBISMA
  dos municípios em 2024"; "Ver Jutaí (AM) em 2024 e comparar com Nenhum").
- Blocos com fundo claro, sem "cara de dashboard"; muito espaço em branco.
- Ranking com busca sem acentos (`normalize('NFD')`), paginação, seleção única e
  selos de categoria pré-renderizados em HTML vetorizado.
- Estados vazios ilustrados (ícone + texto) para município sem dado no ano.
- `waiter` cobre o primeiro carregamento e some quando o mapa fica pronto.
- Acessibilidade: foco visível, `aria-*` na navbar/mapa, descrições nos gráficos
  (quando suportado) e contraste calculado para selos (`cor_texto_sobre`).

### 4.6 Navegação e responsividade

- Navbar sticky com blur, âncoras e item ativo por JS; menu hambúrguer no mobile.
- Tipografia com breakpoints adicionais em 768 px; controles empilham; mapa com
  altura por `clamp()`/`vh`; rodapé reorganizado.
- `prefers-reduced-motion` respeitado no scroll suave.

---

## 5. Problemas encontrados e correções (aprendizados)

1. **`bundle_resources()` carregava CSS/JS legados** de `www/logos/global/`.
   Solução: carregamento explícito dos dois arquivos do painel.
2. **Cache do navegador servia JS antigo** durante o desenvolvimento.
   Solução: versão por `mtime` do arquivo nas URLs (`?v=AAAAMMDDHHMMSS`).
3. **`reactable::searchMethod`** recebe `(rows, columnIds, searchValue)` e deve
   **retornar o array filtrado**, não um booleano. Corrigido para busca sem acento.
4. **Funções `cell` em R no reactable são aplicadas linha a linha** — 4,3 s para
   5.570 linhas. Solução: selos pré-computados vetorizados e formatadores em JS
   (`cellInfo.value.toFixed(1)`); montagem caiu para milissegundos.
5. **`echarts4r` usa `coord_system`, não `coordinateSystem`** — o argumento
   inválido criava uma chave duplicada e quebrava o gráfico polar.
6. **Gráfico ECharts sem título e sem série derruba o render**
   (`Cannot read properties of undefined (reading 'coordinateSystem')`).
   Solução: `grafico_vazio()` sempre com título.
7. **Trocar a estrutura de opções do mesmo ECharts** (flor → gráfico vazio)
   reusa a instância e quebra. Solução: o gráfico só é inserido dinamicamente
   via `renderUI` quando há dados; caso contrário, aparece um estado vazio.
8. **Um widget com erro JS interrompe a fila de renderização do cliente**: o
   `values` do Shiny é processado em sequência e um erro em um output impede os
   seguintes. Isso explicou telas parcialmente vazias e títulos "presos".
9. **`leaflet` só indexa `layerId` string**; e `layerManager._byLayerId` guarda a
   própria camada (não um objeto com `.layer`), com chave `"categoria\nid"` —
   o handler JS foi escrito a partir dessa estrutura.
10. **`HTMLWidgets.getInstance(el)` pode estar indefinido** dependendo do ciclo
    de vida; `HTMLWidgets.find("#id")` se mostrou confiável no handler.
11. **`fontawesome::fa()` não aceita `class`** e não passa por
    `tagAppendAttributes`; a classe foi aplicada em um `<span>` externo.
12. **`st_simplify` em CRS geodésico usa metros** — a primeira tentativa com
    tolerâncias em graus não simplificava nada.
13. **Licença do Highcharts** — pacote `highcharter` removido das dependências.

---

## 6. Testes e validação

### 6.1 Testes unitários — `tests/testthat/test-funcoes_globais.R`

- 61 asserções, todas passando, cobrindo:
  - preparação da base (formato longo, escala 0–100, anos);
  - cortes por quintis e categorização (incluindo `NA` e cortes repetidos);
  - rankings nacional e por UF (posição 1 = mais vulnerável);
  - `resumo_municipio`, séries e comparações;
  - formatadores pt-BR e frase de percentil;
  - paletas/cores e contraste;
  - opções de medida, ano e escopo;
  - selos, cores de mapa e `municipio_padrao`.

Comando: `devtools::test()` (ou `devtools::test(filter = "funcoes_globais")`).

### 6.2 Smoke test visual/headless — `dev/headless_smoke.R`

Interface conforme AGENTS.md (porta, outdir, wait-for, shot, eval, width, height)
e extensões: `--full` (página inteira), `--scroll`, `--mobile`, `--espera`,
`--eval-file`. Registra erros de JS e erros do servidor no fim da execução.

Fluxos verificados por headless (chromote):

- carregamento inicial (mapa, ranking, flor, evolução sem erros);
- hover no mapa com tooltip ("Primavera do Leste (MT) — IBISMA 44,0 — Médio");
- clique no mapa seleciona o município e atualiza o perfil;
- clique em linha do ranking atualiza o perfil e destaca no mapa;
- troca de medida (mapa recolorido na rampa do bloco e legenda atualizada);
- ranking por UF (645 municípios de SP) e busca sem acento ("sao paulo", "iporanga");
- comparação entre municípios (barras coloridas + tabela com Δ);
- cenário sem dados (Borá/2023) com estados vazios e retorno correto;
- navbar: âncora rola para a seção e o item ativo acompanha;
- desktop (1600×950) e mobile (390×844).

Evidências salvas em `dev/smoke/` (`final_completo.png`, `final_mobile.png`,
`mapa_tooltip.png`, `interacao_comparacao.png`, `sem_dados.png` etc.).

---

## 7. Estado final do repositório

- `R/` com 2.701 linhas distribuídas em 13 arquivos (fatores, módulos e utilitários).
- `tests/testthat/test-funcoes_globais.R` com 142 linhas e 61 testes verdes.
- `inst/app/data/` com as duas malhas (~1,1 MB no total).
- `inst/app/www/global/` com o CSS do painel (~25 KB) e o JS (~3,5 KB).
- `DESCRIPTION` com as dependências reais (`bslib`, `shinyWidgets`, `leaflet`,
  `sf`, `tidyr`, `reactable`, `echarts4r`, `waiter`, `fontawesome`, `htmltools`,
  `htmlwidgets`, `jsonlite` etc.), `Suggests` com `testthat`, `chromote` e
  `callr`, e `Config/testthat/edition: 3`.
- `.gitignore` com `.Rproj.user`, `.Rhistory` e `dev/smoke/`.
- `NAMESPACE` gerado por `devtools::document()`.

---

## 8. Como rodar e validar

```r
# carregar e rodar
pkgload::load_all()
run_app()                    # ou dev/run_dev.R

# testes
devtools::test()
devtools::test(filter = "funcoes_globais")

# smoke visual (na raiz do pacote)
Rscript dev/headless_smoke.R --wait-for="#panorama-mapa" --full --shot=painel.png
Rscript dev/headless_smoke.R --mobile --width=390 --height=844 --shot=mobile.png \
  --eval="document.querySelectorAll('.leaflet-container').length"
```

---

## 9. Limitações conhecidas e próximos passos

1. **Níveis de análise:** apenas município habilitado. UF e região já existem nos
   dados; basta acrescentar linhas em `NIVEIS_ANALISE` e tratar agregação.
2. **Seletores grandes:** `slimSelectInput` não possui `update*` no shinyWidgets;
   a sincronização do perfil usa `session$sendInputMessage()` (funciona, mas é um
   ponto a acompanhar em atualizações futuras do pacote).
3. **Primeiro carregamento do mapa** leva ~3–5 s por causa da serialização da
   geometria. Alternativas: TopoJSON, mais simplificação ou clustering.
4. **Sem exportação** de dados/figuras e sem compartilhamento por URL.
5. **Tooltips comparativos dentro do mapa** (ex.: diferença entre municípios)
   ficaram fora do escopo desta primeira versão.
6. **Descrições de acessibilidade** existem no código, mas o módulo de
   acessibilidade do ECharts não está disponível na versão atual do pacote.
7. **Base de exemplo:** o rodapé deixa claro que os dados são um exemplo de
   desenvolvimento e que o IBISMA é um índice relativo (percentil).

---

## 10. Decisões pendentes de confirmação

- O mapeamento `bloco1..6` → nomes foi feito na ordem do AGENTS.md
  (Social → Clima). Se a ordem real for outra, basta ajustar `BLOCOS` em
  `R/fct_config.R`.
- A seção única "Panorama" substitui as entradas separadas "Visão geral" e
  "Ranking" do pedido original, por decisão de UX documentada na seção 2.
