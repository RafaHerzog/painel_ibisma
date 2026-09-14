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
- `waiter` cobria o primeiro carregamento (removido na Sessão 2 — ver adiante).
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
2. **Seletores grandes:** a sincronização do perfil usava
   `session$sendInputMessage()`. Na Sessão 2 foi corrigida para a função oficial
   `shinyWidgets::updateSlimSelect()` (que existe no pacote).
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

---

# Sessão 2 — Correções e refinamentos (12/09/2026)

- **Pacote:** `painel_ibisma_v4` (a v4 seguiu como base; a v3 foi consultada
  apenas como referência visual dos componentes corrigidos).
- **Objetivo:** corrigir problemas específicos e aproximar navbar, mapa e
  gráfico de pétalas do que já havia sido melhor resolvido na v3, sem regredir
  o restante.

## 1. SlimSelect

- `updateSlimSelect()` **existe** no shinyWidgets 0.9.1 — a limitação registrada
  na Sessão 1 estava incorreta. `atualizar_seletor()` passou a usá-la no lugar
  do `session$sendInputMessage()`.
- A largura das opções passou a ser tratada apenas no dropdown aberto
  (`width: max-content` com teto de `min(92vw, 30rem)`), sem alterar o input
  fechado; um observador no JS reposiciona a lista quando ela ultrapassaria a
  borda da janela.
- O roxo foi removido dos seletores: valor exibido, foco e opção destacada usam
  o azul médio `#1E5AA0` (hover continua no azul claro `#32A0FF`).

## 2. Navbar

- **Causa de desaparecer no scroll:** o `page_fillable()` criava
  `.bslib-page-fill { height:100% }`, o que limitava o `position: sticky` à
  viewport. O CSS libera a altura natural do documento (`height: auto` +
  `min-height: 100vh`).
- Visual: fundo `#0A1E3C`, IBISMA + descrição do índice (visível a partir de
  `lg`), itens brancos. O indicador inferior da v4 foi mantido (sublinhado azul
  claro) e, no menu colapsado, acompanha a largura do texto.

## 3. Mapa

- O zoom-out parou de encolher o mapa indefinidamente: `setMaxBounds` +
  `maxBoundsViscosity = 1` (como na v3) e zoom mínimo calculado dinamicamente
  para o enquadramento do Brasil conforme o contêiner (4 no desktop, 3 no
  mobile), recalculado em resize.
- A entrada "Sem dados" saiu da legenda (`com_sem_dados = FALSE`); cores e
  tooltip de municípios sem dado seguem iguais.

## 4. Busca do ranking

- **Causa:** o `searchMethod` do reactable recebe objetos de linha e os valores
  ficam em `linha.values`; o código lia `linha.municipio`, então nada casava.
- Corrigido para `linha.values.municipio` / `linha.values.sigla_uf`, mantendo a
  normalização de acentos e maiúsculas.

## 5. Gráfico de pétalas

- A flor polar do echarts4r foi substituída pelo leque SVG da v3
  (`R/fct_petalas.R`), com guias, marcas de 25/50/75, círculo de valor e ponto
  da mediana do Brasil.
- Tooltip própria (Bootstrap 5, inicializada no JS) no padrão do painel, com
  bloco, valor, ranking e selo de categoria; é reinicializada por
  `MutationObserver` a cada redesenho.
- `grafico_flor()` (echarts) removido e corrigido o `estilo_echarts()`, que
  quebrava a legenda com duas séries por causa do casamento parcial
  `icon` → `icons` do echarts4r.

## 6. Remoção do waiter

- `waiter` foi removido do app e das dependências por não funcionar bem.

## 7. Testes e validação

- `devtools::test()`: 74 asserções verdes (novos testes de limites do mapa,
  legenda e pétalas).
- O smoke headless foi ampliado (`--mouse`, `--click`, promises e captura por
  viewport) e validou: navbar sticky/scrollspy, zoom mínimo em desktop e mobile,
  busca (termo exato, parcial, com acento, troca de ano/indicador e ordenação),
  tooltip real nas seis pétalas, dropdowns em 1600/720/390 px, cenário sem
  dados (Borá/2023) e comparação entre municípios.
- Evidências em `dev/smoke/sessao_correcoes/` (ignorado pelo git).

> Observação de ambiente: o `rlang` 1.1.4 instalado ficou abaixo do exigido
> pelo `testthat` 3.3.2; a suíte foi rodada com `rlang` 1.2.0 vindo de uma
> biblioteca temporária. Recomenda-se atualizar o pacote com o R fechado.

---

# Sessão 3 — UI/UX, cores e hierarquia (12/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** corrigir cinco problemas de UI/UX e comportamento, centralizar
  a lógica de cores por dimensão e validar tudo com smoke tests headless.

## 1. Posicionamento das seções ao clicar na navbar

- **Causa raiz:** `html { scroll-padding-top: ... }` **e** `section[id] {
  scroll-margin-top: ... }` eram aplicados juntos; o navegador soma os dois,
  parando a seção ~176 px abaixo do topo (navbar + sobra da seção anterior).
  A altura ainda era um chute fixo (`--altura-navbar: 4.75rem`) e não
  acompanhava breakpoints.
- **Correção estrutural:** o CSS passou a compensar só com `scroll-margin-top:
  var(--altura-navbar)`; o JavaScript mede a altura real da navbar
  (`ResizeObserver` + `resize`) e grava em `--altura-navbar`. Os cliques nas
  âncoras são interceptados: o menu móvel fecha primeiro, a altura é remedida
  e a rolagem usa `section.top - altura_navbar` (com respeito a
  `prefers-reduced-motion`). Deep link com hash na URL também é reposicionado
  no `load`.
- **Validação:** offset seção↔navbar de 0,0–0,4 px em desktop, após `resize`
  e no mobile (menu abrindo e fechando), com o item ativo do scrollspy correto.

## 2. Paleta central por medida (uma fonte de verdade)

- `fct_cores.R` ganhou `paleta_bloco()` e `paleta_medida(medida)`; `paleta_mapa`
  e `paleta_categorias` passaram a delegar para ela.
- `cor_categoria(categoria, medida = "indice_final")` e
  `montar_selos(categorias, medida)` agora aceitam a medida.
- Tooltip do mapa (`tooltip_municipio`) recebe a paleta da medida: a chip da
  categoria deixa de ser sempre roxa e passa a usar a rampa do IBISMA ou do
  bloco exibido, com cor de texto por contraste.
- Tooltip das pétalas ganhou marcador ao lado do título e selo de categoria na
  rampa do bloco (`--cor-medida` + `cor_categoria(categoria, medida)`).
- **Descoberta:** o Bootstrap sanitiza o HTML do tooltip e remove `style` em
  linha; as cores dinâmicas eram descartadas. As tooltips das pétalas passaram
  a ser inicializadas com `sanitize: false` (o conteúdo é gerado pelo servidor).
- Ranking, legenda do mapa, evolução temporal e pétalas consomem as mesmas
  funções; o tema do reactable deriva os tons de destaque de `COR_IBISMA` com
  `misturar_cores()` em vez de hexadecimais soltos.
- O campo de busca dos `slimSelectInput` passou a exibir "Buscar..." no lugar
  do "Search" padrão do plugin.

## 3. Rebalanceamento das cinco categorias

- IBISMA: `#D5C2E8`, `#B592D6`, `#915EC4`, `#6B35A3`, `#4B1D73`.
- Blocos: rampa derivada com pesos 0,62 e 0,30 para o branco e 0,32 e 0,62 para
  o azul escuro (antes 0,88/0,55 no branco), mantendo a cor do bloco na
  categoria central. "Muito baixo" deixou de se confundir com o fundo do mapa e
  com as bordas brancas, e as cinco categorias seguem progressivas e distintas.
- `grafico_petalas()` ganhou uma legenda de nomes (sem valores, que continuam
  só nas pétalas) para identificar os blocos sem hover.

## 4. Ranking com 12 linhas fixas

- Removidos `pageSizeOptions` e `showPageSizeOptions`; a tabela continua
  paginada, com `defaultPageSize = 12` e a última página com o resto.

## 5. Perfil dos municípios — palco único

- A tabela de valores dos blocos foi removida.
- A primeira versão da sessão empilhou o resumo e as pétalas em coluna única,
  mas o resultado desperdiçava a largura. O perfil foi refeito como um palco
  único inspirado no IMAPI: nome do município e métricas territoriais no topo,
  leque de pétalas grande e centralizado e, na base, um placar com o ranking
  Brasil à esquerda, o valor do IBISMA nomeado ao centro ("IBISMA em \<ano\>",
  "de 100", selo e frase de percentil) e o ranking estadual à direita.
- No mobile o placar empilha com o valor primeiro e os rankings abaixo.
- O leque ganhou `viewBox` recortado (`45 60 410 236`) e limite de altura
  `min(56vh, 520px)`, crescendo dentro do palco sem esticar o desenho.
- Ajustes finais pedidos a partir da referência: nome e UF em um único
  destaque (`Jutaí, AM`, sem elemento separado para a sigla); a descrição das
  pétalas passou para logo abaixo das métricas, antes do leque; a lembrança
  textual "Mediana Brasil" saiu da legenda (os pontos escuros continuam no
  desenho, explicados pelo texto).
- O ranking estadual passou a ser rotulado "Ranking na UF (Amazonas)".
- Todos os valores exibidos no painel usam uma casa decimal, incluindo o
  número dentro de cada pétala e o valor em destaque do IBISMA.
- A frase de percentil passou a usar uma casa decimal e teto de 99,9% (antes
  99%), para não subestimar o município mais vulnerável do ranking.
- Ordem da seção: identificação (controles + palco) → evolução → comparação.

## 6. Testes e validação

- `devtools::test()`: 115 asserções verdes (novos testes de `paleta_medida`,
  `cor_categoria`/`montar_selos` por medida, chip do tooltip do mapa e da
  pétala, arredondamento em uma casa e frase de percentil em 99,9%).
- Smoke headless: navbar (cliques, resize, hash, mobile), mapa com as 7 medidas
  (preenchimentos e legenda idênticos às paletas), tooltips com chip correta,
  ranking (12 linhas, sem seletor, chips por medida, busca), perfil (palco
  ocupando a largura útil, valor centralizado entre os rankings, ausência da
  tabela antiga, pétalas com tooltip, evolução com comparação, tabela de
  diferenças), cenário sem dados (Borá/2023, com o placar desaparecendo e
  voltando ao trocar o ano) e responsivo em 1600/1024/390 px sem estouro
  horizontal.
- `dev/headless_smoke.R` ganhou `--pre-eval`/`--pre-eval-file` para preparar um
  estado (trocar medida, abrir tooltip) antes do screenshot.

## 7. Limitações remanescentes

- O eixo de anos da evolução ainda mostra separador de milhar ("2.015").
- O `sanitize: false` das tooltips das pétalas é seguro porque o HTML é gerado
  pelo servidor a partir da base; não usar essa opção para conteúdo de usuário.
- Os rótulos numéricos das barras de comparação não aparecem no gráfico (os
  valores seguem na tooltip e na tabela); comportamento pré-existente.

---

# Sessão 4 — Evolução temporal e comparação lado a lado (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** corrigir dois problemas do gráfico de evolução temporal
  (formatação do eixo X e sete séries simultâneas) e reformular completamente a
  comparação entre municípios, que passou a acontecer nos próprios elementos do
  perfil (palcos e gráficos lado a lado), sem seção independente.

## 1. Eixo X do gráfico temporal

- **Causa:** o eixo de valor do ECharts formata números com quatro dígitos com
  separador de milhar por padrão (`2.015`). Não era problema de dado: os anos
  sempre foram inteiros.
- **Correção:** `grafico_evolucao()` passou a definir o formatter do eixo
  (`e_x_axis(formatter = JS("Math.round(...)"))`), mantendo `min`, `max` e
  `interval = 1`. Funciona em qualquer município e com a comparação ativa
  (o formatter é reaplicado a cada re-render).
- **Teste:** o objeto do gráfico é inspecionado quanto ao formatter
  (`JS_EVAL` com `Math.round`) na suíte.

## 2. Sete séries no gráfico de evolução

- `series_municipio()` (em `fct_dados.R`) monta um data frame com `ano` e uma
  coluna por medida, preenchendo anos ausentes com `NA`; `series_tem_valor()`
  decide quando há algo para desenhar.
- O gráfico desenha **IBISMA + seis blocos** de uma vez, com os nomes e as cores
  reais de `MEDIDAS`; o IBISMA é a linha mais espessa e todas as séries mostram
  o ponto de cada ano como círculo (`symbolSize = 6`, borda branca).
- O seletor "Evolução do" foi removido — a leitura é sempre conjunta.
- As cores continuam representando **dimensões**, nunca municípios.

## 3. Legenda nativa compartilhada (reformulada em duas etapas)

- A legenda HTML foi descartada. A pedido, passou a ser a legenda **nativa do
  ECharts**, primeiro embutida no gráfico principal; na revisão final, foi
  movida para **um widget ECharts próprio, abaixo dos gráficos e centralizado
  entre os dois**, com os eixos e a grade escondidos (`grafico_legenda()`).
- `estilo_echarts()` centraliza a legenda (`left = "center"`), usa os ícones
  padrão das séries, `itemGap = 16` e altura responsiva por media query.
- O widget de legenda entra no **mesmo grupo** dos dois gráficos
  (`e_group` + `e_connect_group`): clicar em um item oculta/mostra a série nos
  **dois** gráficos. A sincronização também faz as **tooltips** aparecerem no
  mesmo ano nos dois gráficos — leitura comparativa direta.
- **Persistência da seleção:** a echarts4r publica a seleção da legenda em
  `input$legenda_evolucao_legend_selected`; os gráficos a reaplicam com
  `shiny::isolate()`, de modo que esconder uma série sobrevive à troca de ano,
  à troca do município principal e à troca/remoção da comparação, sem
  re-renderizar os gráficos a cada clique na legenda.

## 4. Comparação reformulada, sem seção própria

- A seção "Comparação entre municípios" foi removida por completo (interface,
  gráfico de diferenças, tabela e linha pontilhada), junto das funções
  `comparar_series()`, `comparar_ano()`, `grafico_diferencas()`,
  `eh_tooltip_diferencas()` e `grafico_vazio()`, e `jsonlite` saiu das
  dependências.
- **Palcos reutilizáveis:** `perfil_palco()` (novo `R/fct_perfil.R`) monta
  identificação, métricas territoriais, pétalas e placar para qualquer
  município; `perfil_placar()` concentra o placar. O mesmo componente serve
  principal e comparado, mudando apenas os argumentos.
- **Evolução reutilizável:** o mesmo `grafico_evolucao()` desenha cada
  município; cada um tem seu próprio gráfico (não compartilham o mesmo canvas).
- **Estados controlados:** sem comparação há um palco e um gráfico; com
  comparação, dois de cada; ao remover, a coluna comparada é suspensa (`req`)
  e o layout volta suavemente. Trocar o principal mantém a comparação ativa e
  atualiza apenas o lado esquerdo.
- **Hierarquia:** rótulos "Município principal"/"Município comparado" e títulos
  com o nome de cada município acima dos gráficos.

## 5. Transições e espaçamento

- **Causa da animação invisível:** a transição usava
  `grid-template-columns` (não interpola em engines mais antigas) e era
  desligada por `prefers-reduced-motion: reduce` — que é o padrão do Chrome
  headless e pode estar ativo no sistema do usuário.
- **Correção:** a `.dupla` passou a ser um **flex** com transição em
  `flex-basis`/`max-width`/`margin-left`/`opacity` (interpola em qualquer
  navegador) e o desligamento por `prefers-reduced-motion` foi removido para
  essa transição.
- **Verificação de verdade:** o smoke ganhou `--motion` e `--reduce`, que emulam
  a preferência via CDP, e a largura das colunas passou a ser amostrada a cada
  80 ms. Resultado real: `1376x0 → 1340x35 → 1112x256 → 890x470 → 763x592 →
  664x688` (com `no-preference` e com `reduce`).
- **Espaçamento palco ↔ evolução:** o card do palco tem `height: 100%`; dentro
  da coluna com `overflow: hidden`, a `margin-bottom` era clipada e a evolução
  encostava no palco. A margem dos cards dentro da `.dupla` foi zerada e o
  respiro (`1.5rem`) passou a vir da `.dupla--palcos` — medido em 24 px.

## 6. Tooltip da evolução

- Mostra `Município (UF) — ano` e as sete linhas, com marcadores nas cores das
  dimensões e valores ausentes omitidos; nomes com apóstrofo são escapados
  (`encodeString`) antes de entrar no JavaScript.
- Com a comparação ativa, as tooltips dos dois gráficos aparecem sincronizadas
  no mesmo ano.

## 7. Testes e validação

- `devtools::test()`: **146 asserções verdes**, cobrindo `series_municipio` /
  `series_tem_valor`, o formato do gráfico de evolução (séries, cores, símbolos,
  eixo, tooltip), `grafico_legenda` (itens, eixos ocultos, grupo, `itemGap`) e
  `perfil_palco` (identificação, pétalas, placar e estado vazio).
- Smoke headless (evidências em `dev/smoke/sessao_comparacao_v3`, `v4` e `v5`):
  estados A/B/C/D, troca de comparação, troca de ano, Borá/2023, animação
  amostrada, legenda compartilhada (clique sincroniza e sobrevive a re-render),
  ausência da seção antiga e da linha pontilhada, legenda abaixo/centralizada e
  responsivo em 1600/1024/390 px sem estouro horizontal.

## 8. Decisões e limitações remanescentes

- A legenda compartilhada é um widget ECharts dedicado; o custo é um canvas
  vazio de ~64 px (96 px no mobile) abaixo dos gráficos.
- O sincronismo via grupo do ECharts também sincroniza tooltips — avaliado como
  positivo para a comparação, mas pode ser desligado trocando o mecanismo por
  um espelho só da legenda, se o uso indicar.
- No empilhamento (≤1100 px) a entrada do comparado é animada; a saída é
  instantânea (o `display: none` da coluna vazia).
- Em telas muito estreitas a legenda quebra em até três linhas; a altura do
  canvas acompanha por media query.

---

# Sessão 5 — Métricas territoriais, tooltips de corte e placar (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** refinar o cabeçalho territorial do perfil (ordem, cortes e
  tooltips condicionais), estabilizar o placar e igualar as colunas do modo
  comparação.

## 1. Métricas territoriais em grid

- `.perfil-metricas` deixou de ser um `flex` com quebra e virou um grid de
  quatro colunas `minmax(3rem/7rem, max-content)`, com `justify-content: start`
  e respiro de 2,5 rem entre colunas.
- Cada coluna tem limite máximo próprio (8/10/18/22 rem; 7,5/8/15/19 rem até
  1280 px) e os campos ficam sempre em uma linha, com reticências quando o
  texto passa do limite — sem quebrar a linha nem mudar a altura.
- Até 768 px as informações passam a duas colunas por linha.
- **Ordem corrigida:** Região, UF, Macrorregião de saúde e Região de saúde
  (antes macrorregião e região de saúde estavam trocadas). O rótulo "Unidade
  da federação" foi encurtado para "UF".
- Os limites acompanham o conteúdo: "Região de saúde" (nomes de até ~50
  caracteres na base) ficou com o maior limite e "Macrorregião de saúde" com o
  menor, na base e na media query.
- **Modo comparação:** `justify-content: space-between` distribui as quatro
  colunas pela largura do palco quando a comparação está ativa; sem comparação
  o alinhamento segue à esquerda.

## 2. Tooltip condicional dos campos territoriais

- `metrica_hero()` ganhou o argumento `tooltip`; quando ligado, rótulo e valor
  expõem o texto completo em `data-tooltip-texto` e recebem a classe
  `metrica-tooltip`.
- No JavaScript a inicialização foi refatorada em `criarTooltip()` (rica, para
  as pétalas, e simples, para os campos). A tooltip do campo territorial só é
  criada quando o texto está de fato cortado (`scrollWidth > clientWidth`),
  com `tabindex` para leitura por teclado; quando deixa de estar cortado, a
  instância é destruída (`dispose`) e o `tabindex` removido.
- A avaliação de corte é refeita em `resize` (agendada por
  `requestAnimationFrame`), quando as fontes terminam de carregar
  (`document.fonts.ready`) e a cada novo elemento inserido pelo Shiny
  (`MutationObserver`).
- O CSS do cartão da tooltip foi simplificado: fundo branco via
  `--bs-tooltip-bg` (a seta herda a cor), opacidade 1 no `.show` e
  `font-size` na medida padrão do painel; as regras manuais de seta por
  posição foram removidas. O foco por teclado ganhou contorno visível.

## 3. Placar do IBISMA

- As laterais do placar usam `minmax(7.5rem, 1fr)`, reservando o mesmo espaço
  para os rankings nacional e estadual mesmo quando posições e totais têm
  quantidades de dígitos diferentes — o valor central não se desloca.
- Rótulo e valor de cada ranking ficam em uma única linha, com reticências.
- O ranking estadual deixou de repetir a UF no título: "Ranking na UF", sem
  "(Amazonas)".

## 4. Igualdade das colunas na comparação

- Principal e comparado usam `flex-basis: calc(50% - 0.75rem)`, descontando
  metade do respiro de 1,5 rem; antes a coluna comparada ficava com 50% e a
  principal absorvia a diferença, deixando as duas com larguras diferentes.

## 5. Testes e validação

- `devtools::test()`: **150 asserções verdes** (novas: "Ranking na UF" sem a
  UF e campos territoriais com `metrica-tooltip` / `data-tooltip-texto`).
- Smoke headless com a comparação ativa (1600×950): nos dois palcos o
  `justify-content` computado foi `space-between`, a ordem dos rótulos foi
  `Região > UF > Macrorregião de saúde > Região de saúde` e as colunas
  ocuparam a largura total (folga 0/0 nas bordas).
- Nota de ambiente: a suíte rodou com `rlang` 1.2.0 de uma biblioteca
  temporária, porque o `rlang` 1.1.4 instalado está abaixo do exigido pelo
  `testthat` 3.3.2.

---

# Sessão 6 — Pétalas com disco fixo, escala alinhada à guia (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** redesenhar o gráfico de pétalas (disco de valor no topo, sem
  ticks e sem mediana, escala alinhada à guia), trocar o texto do percentil e
  refinar espaçamentos do perfil.

## 1. Disco de valor e limpeza do desenho

- O disco com o valor passou a ficar sempre no fim da guia, na posição que
  indica 100, independentemente do valor do bloco; guia, disco e texto usam a
  mesma ponta (`ponta_x`/`ponta_y`).
- Removidos os ticks de 25/50/75 e o ponto da mediana do Brasil.
- Removida a infraestrutura de suporte: `distancia_petala()` (ficou sem uso),
  o argumento `medianas` de `petala_svg()`, `grafico_petalas()` e
  `perfil_palco()`, o reativo `medianas_blocos` no módulo e a função
  `mediana_referencia()` em `fct_dados.R`, que ficou sem chamadas.
- A legenda textual (`TEXTO_PETALAS`) perdeu a menção à mediana.

## 2. Escala da pétala

- Removidos os pisos de tamanho: antes o comprimento era `0,22 + 0,78v` e a
  largura `0,65 + 0,35v`; a pétala passou a escalar apenas com o valor.
- **Desalinhamento corrigido:** o caminho base da pétala tem 170 unidades de
  comprimento e a guia vai até 185; com isso, uma pétala de 49,1 terminava em
  45,1% da guia e o meio não representava 50%.
- Criada a constante `PETALAS_COMPRIMENTO <- 170`, usada no próprio `d` do
  caminho, e a escala passou a `(valor / 100) × (PETALAS_RAIO /
  PETALAS_COMPRIMENTO)`, com uma escala única para comprimento e largura: o
  meio da guia é 50% e a ponta em 100% encosta no disco.
- Valor ausente (`NA`) continua virando 0; sem mínimo, a pétala deixa de ser
  desenhada e apenas o disco aparece.

## 3. Texto do percentil

- `frase_percentil()` deixou "acima de x% dos municípios brasileiros em
  insegurança" e passou a "acima de x% dos municípios em insegurança em saúde
  materna".

## 4. Ajustes visuais do perfil (CSS)

- Placar sem a borda superior e com espaçamentos internos reduzidos de
  1,25 rem para 1 rem.
- Título "Evolução ao longo do tempo" passou a usar
  `--fonte-muito-grande-size`.

## 5. Testes e validação

- `devtools::test()`: **152 asserções verdes** — o teste das pétalas confere os
  seis discos à distância de 185 do centro, a ausência de `ponto-mediana` no
  HTML e a escala de cada pétala igual a `valor/100 × 185/170`.
- Smoke headless com Abadia de Goiás/2024: pétala Clima com razão 0,491 da
  guia (49,1%) e 2,5 px de distância do meio — coerente com a leitura
  "meio = 50%".

---

# Sessão 7 — Seções e módulos "Onde?" e "Como?" (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** renomear as duas seções do painel e seus módulos para
  "Onde?" (antigo Panorama/Visão geral) e "Como?" (antigo Perfil dos
  municípios), mantendo a coerência entre rótulos, âncoras e código.

## 1. Rótulos das seções

- Na navbar e no eyebrow de cada seção: "Panorama" e "Visão geral" passaram a
  "Onde?"; "Perfil dos municípios" passou a "Como?".

## 2. Módulos e âncoras

- Arquivos renomeados com `git mv` (histórico preservado):
  `R/mod_panorama.R` → `R/mod_onde.R` e `R/mod_perfil_municipio.R` →
  `R/mod_como.R`.
- Funções renomeadas: `mod_panorama_ui/server` → `mod_onde_ui/server` e
  `mod_perfil_municipio_ui/server` → `mod_como_ui/server`, com os chamados
  atualizados em `app_ui.R` e `app_server.R`.
- Ids dos módulos e âncoras das seções: `"panorama"` → `"onde"` e
  `"perfil"` → `"como"`; os outputs com namespace passam a ser `#onde-mapa` e
  `#como-palcos`.
- Classe da seção de perfil: `secao-perfil` → `secao-como`, com as duas
  regras correspondentes do CSS atualizadas.
- Mantido o termo "perfil" nos componentes de conteúdo (`fct_perfil.R`,
  `perfil_palco()`, `perfil_placar()` e classes `perfil-*`), que descrevem o
  perfil do município e não o módulo.

## 3. Testes e validação

- `devtools::test()`: **152 asserções verdes** — a suíte não referencia ids
  ou rótulos das seções.
- Smoke headless: navbar com `Onde?->#onde` e `Como?->#como`, seções `#onde`
  e `#como` presentes e módulos `#onde-mapa` e `#como-palcos` renderizando,
  sem erros de JavaScript ou de servidor.

---

# Sessão 8 — Esqueletos de carregamento (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** adicionar esqueletos de carregamento a todos os outputs,
  preservando o espaço do conteúdo, com o visual do painel hospitalar e sem
  mudanças bruscas de layout.

## 1. Arquitetura em slots empilhados

- `R/fct_esqueleto.R` passou a montar os esqueletos e o helper
  `esqueleto_slot(output, esqueleto)`, que cria `div.esqueleto-slot` com
  `display: grid` e os dois na mesma célula (`grid-area: stack`).
- O CSS exibe o esqueleto apenas enquanto o output está `:empty`
  (``.esqueleto-slot > :not(.esqueleto):empty + .esqueleto``) e o esconde
  assim que o conteúdo renderiza; como os dois ocupam a mesma célula, a
  altura é sempre `max(esqueleto, conteúdo)`.
- Os wrappers de `uiOutput` (que o Shiny deixa `display: contents`) viram
  blocos dentro dos slots para permitir a sobreposição.
- A primeira versão usava templates clonados por JavaScript; a versão final
  adotou a arquitetura de slot do painel hospitalar e **removeu o controlador
  JavaScript** (o arquivo `funcoes_javascript.js` só recebeu o marcador de
  carga inicial).

## 2. Cores e animação iguais às do painel hospitalar

- Gradiente e animação copiados literalmente do
  `painel_hospitalar_copilot`: `linear-gradient(90deg, rgb(224 233 242 / 68%)
  24%, rgb(246 249 252 / 82%) 50%, rgb(224 233 242 / 68%) 76%)`,
  `background-size: 210% 100%` e `animation: loading-shimmer 1.7s infinite
  ease` (`background-position: 200% → -200%`).
- O hospitalar não tem guarda de `prefers-reduced-motion` para o shimmer; a
  primeira versão do painel desligava a animação nesse caso e o brilho
  parecia parado (o Windows do usuário está com os efeitos de animação
  desligados). A guarda foi removida para manter a paridade.
- Mapas, pétalas e curvas (SVG) não aceitam `background` animado; receberam
  uma camada `::after` com as mesmas cores e o mesmo `loading-shimmer` sobre
  o desenho.

## 3. Esqueleto do mapa

- Saíram as formas circulares abstratas; entrou a **silhueta do Brasil**
  gerada a partir da malha real: `st_union` das UFs, `st_simplify` de 20 km
  (184 pontos) e normalização para um viewBox `0 0 100 100`.
- O caminho foi embutido como constante `ESQUELETO_MAPA_BRASIL` e o SVG usa
  `preserveAspectRatio="xMidYMid meet"`, com o controle de zoom reservado.

## 4. Esqueletos apenas no carregamento inicial

- `funcoes_javascript.js`: no primeiro `shiny:idle` (que fecha a primeira
  fila de recálculos), espera 700 ms, confirma que não há `.recalculating` e
  adiciona `pagina-carregada` ao `<html>`; se houver recálculo atrasado,
  tenta de novo a cada 250 ms.
- O CSS `html.pagina-carregada .esqueleto-slot > .esqueleto` esconde os
  esqueletos definitivamente, inclusive em elementos recriados (gráficos de
  evolução na troca de município) e no palco comparado.

## 5. Diagnóstico do flash de rodapé

- Um gravador por `requestAnimationFrame` mediu a altura da página durante a
  carga: ela caía de **2819 px para 1777 px por ~150 ms** quando os
  esqueletos eram removidos (o controlador JavaScript os removia no início
  do flush, antes de os valores renderizarem).
- Com os slots empilhados, a janela vazia deixou de existir: a altura fica
  estável (`quedas: []`) e a troca de filtro com a página rolada não gera
  quedas nem saltos de scroll (`min = max = 2819`).

## 6. Ajustes do esqueleto da tabela do ranking

- Busca alinhada à direita (`margin-left: auto`), na mesma posição do
  `.rt-search` real (`x1287 w170`).
- Cabeçalho com uma barra por coluna, na largura e no alinhamento dos
  rótulos reais (Pos. e Valor à direita), com 7 px de altura.
- Paginação com a sequência real: Anterior, botões de página unificados,
  reticências, última página e Próxima — quebrando linha no mobile como o
  reactable (o "Próxima" desce para a segunda linha, à esquerda).
- Barra do resumo (`onde-ranking_resumo`) passou de `0.65em` para `0.85em`.

## 7. Testes e validação

- `devtools::test()`: **172 asserções verdes**, incluindo a estrutura dos
  esqueletos e do slot.
- Geometria real × esqueleto com delta 0 em 1600×900 (com e sem comparação)
  e em 390×844: mapa 540/490, ranking 476/506, palco 610/609, evolução
  357/354; altura da página idêntica antes/durante/depois da carga.
- Ciclo CSS verificado nas trocas de ano, medida, escopo e comparação:
  nenhum esqueleto aparece depois de `pagina-carregada` (`maxEsq = 0`) e
  nenhum fica preso.
- `prefers-reduced-motion`: o shimmer permanece ativo, como no hospitalar.

## 8. Limitações

- O esqueleto da tabela reserva sempre as 12 linhas da página padrão, mesmo
  quando o escopo tem menos municípios (só o DF tem 1 linha).
- Elementos recriados depois da carga (gráfico de evolução na troca de
  município) ficam com o espaço reservado vazio por ~80 ms, sem esqueleto,
  por decisão de exibi-los apenas no carregamento inicial.
- O esqueleto do palco reserva a altura cheia; em anos sem dado (Borá/2023)
  o palco vira estado vazio depois da carga inicial, como antes.

---

# Sessão 9 — Rodapé institucional com logos negativos (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** refazer o rodapé de realizadores e financiadores, que estava
  com "cara de adesivos" (cada logo dentro de uma caixa branca), aproximando-o
  da referência institucional: logos negativos direto no fundo azul, títulos
  sem linha e nota final com separador de largura total.

## 1. Da plaquinha branca ao logo negativo

- A primeira tentativa manteve os logos coloridos em caixas brancas de
  tamanho fixo (`7rem × 2,875rem`, `object-fit: contain`): o ritmo melhorou,
  mas o efeito de adesivos colados permaneceu e não correspondia à
  referência.
- Com as versões negativas enviadas pelo usuário, o rodapé passou a exibir
  os logos brancos direto sobre o `#0A1E3C`, sem fundo, borda ou padding.
- Ficaram de fora, por enquanto, os logos do Ministério da Saúde e da
  Medicina USP (sem versão negativa); os arquivos continuam na pasta.
- Os blocos ganharam a divisória vertical de referência (borda esquerda no
  segundo bloco), removida quando eles empilham (≤ 992 px).

## 2. Títulos, separador e nota

- As linhas sob "Realização" e "Financiamento" foram removidas; os títulos
  ficaram apenas com o texto em caixa-alta espaçada.
- A linha acima da nota deixou de pertencer ao parágrafo: o contêiner
  `rodape-base` cobre toda a largura útil do `painel-container` (a mesma das
  logos), com o texto limitado a `70rem` dentro dele.
- A primeira frase da nota passou a "Este painel está em desenvolvimento.",
  mantendo o aviso de que o IBISMA é um índice relativo.
- Os `img` do rodapé ganharam `loading="lazy"` e `decoding="async"`.

## 3. Otimização dos arquivos de logo

- Novo `data-raw/otimiza_logos.R`, executável na raiz do pacote: recorta a
  moldura transparente, aplica margem uniforme de 8 px e reduz cada PNG das
  pastas de realização e financiadores para no máximo 480×200 px.
- O script detecta logos negativos que vierem com o desenho escuro e os
  converte para branco (`image_colorize`), preservando o recorte — foi o
  caso do primeiro arquivo da Fiocruz, depois substituído pela versão
  vertical correta.
- O rodapé caiu de ~1,4 MB para ~170 KB de PNG no total, sem perda visível
  nas alturas exibidas (36 px no desktop e 28 px no mobile).
- Os recursos legados de `inst/app/www/logos/global/` (CSS e JS antigos, já
  fora do carregamento desde a primeira sessão) foram removidos.

## 4. Testes e validação

- `devtools::test()`: **172 asserções verdes**.
- Smoke headless em 1600×900 e 390×844: rodapé sem estouro horizontal, com a
  divisória sumindo no empilhamento, títulos sem borda inferior e a linha da
  nota com a largura do container (1376 px e 358 px).
- Evidências em `dev/smoke/rodape/` (ignorado pelo git).

---

# Sessão 10 — Seletores refinados e fendas da malha do mapa (13/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** refinar o comportamento e o visual dos seletores slimSelect e
  eliminar os espaços em branco do mapa, causados por fendas internas da malha
  municipal.

## 1. Seletores slimSelect

- `seletor_inline()` ganhou o argumento `busca`: medida e nível (poucas opções)
  passam a abrir sem campo de busca; ano e escopo continuam com busca. Os
  textos do plugin foram traduzidos (`searchText = "Nenhum resultado"`) e o
  realce do trecho encontrado foi ligado (`searchHighlight = TRUE`).
- `atualizar_seletor()` remove nomes do valor com `unname()`, evitando que o
  vetor nomeado viaje na mensagem JSON.
- O dropdown virou um cartão próprio: raio de 14 px, duas camadas de sombra,
  entrada animada com `opacity` + `visibility` + `pointer-events` (sem caixa
  invisível clicável), busca integrada com lupa desenhada por máscara SVG e
  botão de limpar no mesmo traço, lista com opções arredondadas, seleção em
  azul médio cheio, realce do trecho buscado em amarelo suave e fichas em
  pílula para a seleção múltipla.
- O posicionamento do dropdown foi reescrito no JavaScript: a posição do
  plugin não é mais sobrescrita (o `translate` faz o ajuste), com margem de
  10 px e respiro de 6 px (invertido quando abre acima), centralização quando
  o cartão é maior que a janela e reavaliação em `resize`, após digitar na
  busca e a cada mutação relevante (agendada por `requestAnimationFrame`).

## 2. Mensagem de atualização do mapa

- `atualizar_municipios()` passou a enviar `cores` e `labels` como **listas
  nomeadas** (`as.list(setNames(...))`), no lugar de vetores nomeados — o
  `jsonlite` emitia aviso ao serializar. Um teste captura a mensagem em uma
  sessão simulada e confirma que o `toJSON` do Shiny não gera aviso.

## 3. Diagnóstico das fendas

- O mapa abria "buracos" brancos entre municípios porque a malha era
  simplificada **polígono a polígono** (`st_simplify(dTolerance = 2000)`, em
  metros por causa do CRS geodésico). A mesma divisa era simplificada de
  formas diferentes dos dois lados: onde ambos recuavam abria fenda; onde
  ambos avançavam, sobreposição.
- Medições na malha antiga: **15.901 fendas**, **144.494 km² (1,70% do
  território)**, maior fenda de 713 km², além de 67.482 km² de sobreposições.
- Concentração por UF (% da área do estado em fendas): PB 5,41%, SP 4,77%,
  SC 4,57%, PR 3,80%, SE 3,61%, AL 3,43%, RS 3,34%, RN 3,22%, MG 3,03%,
  RJ 2,89% — contra 0,37% no AM: onde os municípios são pequenos, a tolerância
  de 2 km consome uma fração muito maior da área.
- `st_simplify(preserveTopology = TRUE)` foi testado e **não resolveu**: ele
  preserva a topologia dentro de cada polígono, não entre vizinhos
  (resultado idêntico).
- No zoom afastado, dois fatores agravavam o esbranquiçado: o traço branco de
  0,25 px sobre 5.570 polígonos minúsculos e o `fillOpacity = 0.88`, que
  deixava o fundo claro atravessar as cores.

## 4. Malha regenerada com topologia compartilhada

- `data-raw/prepara_malha.R` passou a usar `rmapshaper::ms_simplify(keep =
  0.01, keep_shapes = TRUE)`: cada divisa é simplificada **uma única vez** e
  reaproveitada pelos dois municípios vizinhos, sem abrir fendas. As colunas
  (`codmunres`, `sigla_uf`, `geometry`) e a conversão para EPSG:4326 foram
  mantidas; a malha de UFs (apenas contornos) não mudou.
- Resultado: 5.570 municípios, cobertura de 100% dos códigos da base,
  **8.283 fendas / 8.201 km² (0,10% do território)** e maior fenda de
  60,5 km² — melhora de ~18× na área total. Custo: 383 mil pontos e RDS de
  1,50 MB (antes: 190 mil pontos e 1,04 MB), com primeiro carregamento um
  pouco maior.
- O script exige o `rmapshaper` (V8; a instalação pode atualizar o `Rcpp`
  para >= 1.1.0). A geração foi feita com o V8 já instalado.

## 5. Estilo dos municípios

- Primeiro o traço passou a usar a **própria cor do município**
  (`color = ~cor`, `weight = 0.5`), para fechar as fendas residuais sem o
  esbranquiçado do traço branco. Na revisão, a preferência foi por manter as
  divisas municipais visíveis: o **traço branco fino voltou**, bem leve
  (`color = "#FFFFFF"`, `weight = 0.25`, `opacity = 0.65`), agora sem as fendas
  que causavam os espaços brancos originais.
- `fillOpacity` subiu de 0,88 para 0,95 e o `smoothFactor` caiu de 1 para 0
  (a malha já chega simplificada; o cliente não simplifica de novo).
- O handler JavaScript da mensagem repinta apenas `fillColor` e
  `fillOpacity`, já que a divisa branca é fixa.
- Os contornos brancos das UFs continuam por cima, suavizados para
  `weight = 0.8` e `opacity = 0.85`, garantindo a leitura política do mapa.
- O realce de hover e o contorno de seleção (ambos em azul escuro) também
  ficaram mais leves: `weight = 1.6 → 1.2` no hover (`fct_mapa.R:192`) e
  `weight = 2.4 → 1.8` no selecionado (`mod_onde.R:184`), preservando a
  hierarquia base < hover < selecionado.

## 6. Testes e validação

- `devtools::test()`: **182 asserções verdes** (incluindo os testes novos de
  `seletor_inline` e da serialização da mensagem do mapa). A suíte rodou com
  `rlang` 1.2.0 de uma biblioteca temporária, porque o `rlang` 1.1.4 instalado
  está abaixo do exigido pelo testthat.
- Smoke headless em 1600×950: zoom-out inicial com as cores saturadas e sem o
  pontilhado branco no NE/SE/S; zoom-in no Nordeste (zoom 8) sem fendas
  internas — os contornos visíveis são os das UFs.
- Evidências em `dev/smoke/` (ignorado pelo git).

## 7. Limitações

- Restam 8.283 fendas de 8.201 km² no total (0,10% do território); a maior
  (60,5 km²) só aparece em zoom muito aproximado.
- O RDS da malha cresceu ~45% (1,04 MB → 1,50 MB), o que deixa o primeiro
  carregamento do mapa um pouco mais lento.

---

# Sessão 11 — Evolução temporal: hierarquia, eixo Y e nitidez (14/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** fazer o IBISMA se destacar no gráfico de evolução temporal,
  adaptar o eixo Y à faixa dos dados (compartilhado na comparação) e corrigir
  o borrão dos gráficos ECharts em telas com escala fracionária ou sob zoom.

## 1. Hierarquia visual do IBISMA

- O IBISMA passou a ser desenhado **por cima** dos blocos (`z = 10`) — antes
  era a primeira série e os blocos ficavam sobre ele —, com linha de 3,5 px e
  bolinha de 8. Os blocos ficaram com 1,8 px, símbolo 5 e opacidade 0,7.
- Ao passar o mouse, a série focada volta à opacidade 1 (`emphasis` com
  `lineStyle`/`itemStyle`), preservando o `focus = "series"` que apaga as
  demais linhas.
- `grafico_legenda()` alinhou as larguras ao gráfico (3,5 no IBISMA, 1,5 nos
  blocos).

## 2. Bolinha apenas no IBISMA

- A série do índice mantém o ponto de cada ano sempre visível; nos blocos o
  ponto só aparece no hover (`showSymbol` condicional em `grafico_evolucao()`),
  o que limpa o desenho sem perder a leitura da tooltip.
- A legenda nativa continua exibindo o ícone com bolinha em todos os itens: o
  ECharts desenha o ícone da legenda por conta própria e ignora
  `symbol`/`showSymbol` da série (tentativa com `symbol = "none"` revertida).
  Alinhar a legenda exigiria `legend.data` com `icon` por item.

## 3. Eixo Y adaptativo

- Nova `piso_eixo_y()`: arredonda o menor valor das sete séries para **baixo
  na dezena** (limite entre 0 e 90, para não degenerar quando tudo é 100).
- `grafico_evolucao()` ganhou o argumento `minimo_y`; sem ele, o piso vem das
  próprias séries. Jutaí/AM, por exemplo, passou a exibir o eixo 70–100 em vez
  de 0–100, aproveitando a área do gráfico.

## 4. Eixo Y compartilhado na comparação

- O reativo `piso_y` do módulo Como? calcula o **menor piso entre principal e
  comparado** e o repassa aos dois gráficos; séries sem dado são ignoradas
  (com o principal vazio, o eixo segue apenas o comparado; sem valor algum,
  volta a 0).
- Validação: Jutaí × Inhapi/AL resultou em `50|50` nos dois gráficos; ao
  remover a comparação, o eixo volta ao piso do principal.

## 5. Nitidez dos gráficos (renderizador SVG)

- **Causa:** no ECharts 6.0.0 embutido, `painter.dpr` é definido apenas na
  construção do gráfico e nunca recalculado — nem no `resize()` — de modo que
  qualquer mudança de DPR (zoom do navegador, janela movida para um monitor com
  escala diferente) deixa o canvas na resolução antiga. O htmlwidgets 1.6.4
  também não observa mudanças de tamanho do contêiner (sem `ResizeObserver`).
  Além disso, o canvas é naturalmente mais macio em escalas fracionárias
  (125%/150%), comuns no Windows.
- **Correção:** os três widgets ECharts (gráficos principal/comparado e legenda
  compartilhada) passaram a usar `renderer = "svg"`, que independe de
  `devicePixelRatio` e permanece nítido sob zoom ou escala fracionária.
- A legenda compartilhada continua sincronizando os dois gráficos com SVG
  (clique em "Social" esconde a série em ambos).

## 6. Smoke test

- `dev/headless_smoke.R` ganhou `--dpr=<número>`, que emula a escala de tela
  via `Emulation.setDeviceMetricsOverride` para checagens de nitidez.
- Evidências: `dev/smoke/evolucao_eixo/` (hierarquia e eixos iguais),
  `dev/smoke/dpr/` (SVG nítido em 1,25 e 1,5) e `dev/smoke/simbolos/`
  (bolinha apenas no IBISMA), todas ignoradas pelo git.

## 7. Testes

- `devtools::test()`: **203 asserções verdes**, cobrindo `piso_eixo_y`, o eixo
  compartilhado entre os dois gráficos (via `testServer`, com o JSON do widget
  decodificado por `jsonlite`), a hierarquia das séries, o símbolo condicional
  e o renderizador SVG.
- `jsonlite` entrou em `Suggests` apenas para os testes; a suíte rodou com
  `rlang` 1.2.0 de uma biblioteca temporária (o 1.1.4 instalado está abaixo do
  exigido pelo testthat).

## 8. Limitações

- Os ícones da legenda seguem com bolinha em todos os itens (ver seção 2).
- O piso do eixo é calculado com as sete séries; esconder uma série pela
  legenda não recalcula o eixo (por desenho, para não re-renderizar a cada
  clique).
- O eixo adaptativo não começa em 0; o recorte fica visível apenas nos rótulos
  do próprio eixo (a frase que explicava o ajuste foi retirada da descrição).

---

# Sessão 12 — Evolução temporal em pequenos múltiplos (14/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** reformular a visualização "Evolução ao longo do tempo" — que
  concentrava IBISMA e seis blocos em um único gráfico por município — em uma
  grade com um gráfico para o índice e seis para os blocos, com identificação
  direta das localidades e comparação dentro de cada gráfico.

## 1. Estrutura

- A seção passou a ter um cartão de largura total para o **IBISMA** e o título
  intermediário **"Blocos do IBISMA"** (mantendo a linguagem de "blocos" usada
  pelas pétalas e pelos seletores) sobre seis cartões em pequenos múltiplos.
- A grade usa CSS Grid: 3 colunas em telas largas (3 × 2), 2 colunas até
  1100 px (alinhado ao breakpoint da comparação de palcos) e 1 coluna até
  768 px. O cartão do IBISMA ocupa a largura toda em qualquer largura.
- Alturas fixas: 270 px para o IBISMA e 160 px para os blocos, evitando que os
  cartões fiquem estreitos demais sem depender de recálculo de tamanho.
- `grade_evolucao_ui()` (em `fct_graficos.R`) monta os sete cartões; o servidor
  registra os sete outputs em um laço sobre `MEDIDAS`, sem repetição de código.
- O grid do ECharts usa `left = 28` (sem `containLabel`), de modo que os
  números do eixo Y começam junto da borda esquerda do cartão, alinhados ao
  título (medido em 3,6 px de folga).
- O esqueleto da seção (`esqueleto_grade_evolucao()`) reproduz a mesma grade e
  as mesmas alturas, com a coluna de 28 px dos números do eixo Y
  (`.esqueleto__grafico` em grid): `esqueleto_grafico_margem()` desenha barras
  claras e de tamanho único (16 × 4 px, início em 4 px, como o "100" real em
  3,6 px) na posição exata em que os números aparecem, e
  `esqueleto_grafico_svg(altura)` traça a grade e os
  traços nas margens do ECharts (topo 16 px, base `altura - 28 px`), sem a
  linha vertical de eixo Y que o gráfico real não tem.

## 2. Uma medida por gráfico, até duas localidades

- `grafico_evolucao()` passou a desenhar **uma única medida** ("indice_final"
  ou um bloco) com uma ou duas séries: principal (linha cheia) e comparada
  (linha **pontilhada**, mesma cor e opacidade 0,55, desenhada abaixo).
- Os pisos do eixo Y passaram a ser calculados por grupo com
  `piso_eixo_y(series, medidas)`: o IBISMA usa o piso da própria série e os
  seis blocos **compartilham** o piso da menor série de bloco entre os dois
  municípios, para os cartões serem comparáveis entre si. O topo segue em 100.
- A legenda foi eliminada: cada série leva o nome da localidade no fim da
  linha (`endLabel` nativo do ECharts, formatter `{a}`), com `align: "right"` e
  halo branco (`textBorderColor`) para leitura sobre as linhas.
- `lados_rotulos()` decide o lado e o afastamento de cada nome: acima por
  padrão, abaixo perto do topo do eixo, e em lados opostos (ou com
  afastamentos diferentes) quando os dois fins estão próximos — evitando
  rótulos sobrepostos sem truncar nomes, inclusive nos mais longos da base
  ("Vila Bela da Santíssima Trindade (MT)", 178 px).
- A legenda nativa não é mais usada em lugar nenhum da seção: saíram o widget
  compartilhado (`grafico_legenda()`), o `estilo_echarts()` e o sincronismo de
  grupo do ECharts; o `e_legend(show = FALSE)` é explícito porque o echarts4r
  cria uma legenda padrão quando as séries têm nome.
- O hover não apaga a série vizinha: nenhuma das linhas usa `focus` no
  `emphasis`, então as duas permanecem visíveis enquanto o mouse está sobre o
  gráfico; a comparação mantém o traço pontilhado mais claro mesmo sob o
  cursor. O retorno visual do hover fica com o realce padrão do ECharts e com
  a tooltip.
- Hierarquia dos títulos dentro dos cartões: "IBISMA" em
  `--fonte-muito-grande-size` e os seis blocos em `--fonte-grande-size`
  (`.evolucao-card--ibisma .evolucao-card__titulo`).

## 3. Tooltip

- Trigger por eixo, uma tooltip por gráfico (a sincronização entre gráficos
  deixou de existir porque as duas localidades convivem no mesmo gráfico).
- Cabeçalho apenas com o ano (`2024`); cada linha traz o nome da localidade à
  esquerda e o valor à direita (`display:flex; align-items:center;
  justify-content:space-between`) e uma marca própria no lugar do `p.marker`:
  um traço curto na cor do bloco com um ponto pequeno no centro, contínuo na
  série principal e pontilhado na comparação; na comparação a cor é clareada em
  direção ao branco (mistura opaca de 55%, e não rgba) para o pontilhado não
  aparecer dentro da bolinha. A cor identifica a dimensão e o tipo de traço
  identifica a localidade.

## 4. Módulo e JavaScript

- `mod_como.R` perdeu a dupla de colunas da evolução e a legenda inferior; a
  seção virou um único slot (`uiOutput(ns("evolucoes"))`) que mostra a grade ou
  um estado vazio quando não há série temporal.
- O piso compartilhado `piso_y` foi substituído por `piso_ibisma` e
  `piso_blocos`; a comparação é desenhada apenas quando o comparado tem série.
- O handler `ibisma_comparacao` deixou de tratar a antiga coluna de evolução e
  de disparar `resize` (os gráficos da grade não mudam de largura com a
  comparação); continua aplicando `dupla--comparando` nos palcos.

## 5. Testes e validação

- `devtools::test()`: **222 asserções verdes** — testes reescritos de
  `grafico_evolucao` (uma medida, cores, traço pontilhado, rótulos, tooltip e
  ausência de `focus` no hover), `lados_rotulos` (separação dos rótulos e
  bordas do eixo), `piso_eixo_y` por grupo, pisos por grupo no `testServer` e
  esqueleto da grade com sete cartões, coluna de margem e 28 barras de número.
- Smoke headless em 1600, 1024 e 390 px, com e sem comparação, hover real
  (tooltip `Social — 2019 / Jutaí (AM) 99,7`), alternância liga/desliga da
  comparação (2 → 1 séries), cenário Borá/2023 (lacuna no ano ausente), nome
  longo (rótulos dentro dos cartões), palcos ainda lado a lado na comparação e
  esqueleto da grade com a mesma geometria final (936 px). Sem erros de
  JavaScript e sem estouro horizontal.
- Alinhamento e esqueleto conferidos por medição: número real em 3,6 px e
  grade em 28/16/`altura - 28`; esqueleto com barras de 16 × 4 px em 4,0 px,
  grade idêntica e sem a linha vertical que o gráfico não tem.
- Evidências em `dev/smoke/evolucao_v2/`, `evolucao_v3/` e `evolucao_v4/`
  (ignorados pelo git): a v3 registra as alturas menores e o novo tooltip; a
  v4, o alinhamento do eixo e as barras uniformes do esqueleto.

---

# Sessão 13 — Ranking por medida e identificação da evolução (14/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** adaptar o ranking à medida exibida (cores, buscas, seleção e
  cabeçalho) e identificar os municípios e o período no card de evolução,
  com esqueleto e bolinhas de dimensão nos títulos.

## 1. Cores do ranking por medida e prefixo "Bloco"

- `tema_reactable(medida)` deriva hover, linha selecionada, barra lateral e
  botões de página da cor da medida (`cor_medida()`); o botão ativo usa
  `cor_texto_sobre()` para contraste (ex.: amarelo do Social pede texto
  azul escuro). Para o IBISMA, os valores são idênticos aos anteriores.
- `nome_medida(medida, prefixo_bloco = TRUE)` prefixa os blocos: o resumo do
  ranking virou "5.570 municípios do Brasil em 2024 · Bloco Planejamento
  Reprodutivo", mantendo "· IBISMA" para o índice.
- **Achado:** como a coluna Pos. é `sticky`, as linhas usam a classe
  `rt-tr-highlight-sticky` e o `highlightColor` do tema nunca casava (o
  hover ficava no cinza padrão). O tema agora expõe `--cor-hover-ranking` e
  `--cor-selecao-ranking`, consumidas por duas regras em `custom.css`
  (hover e seleção sob o mouse).

## 2. Buscas insensíveis a acentos e sinais

- A busca do ranking (`busca_sem_acento`) normaliza em NFD, remove
  diacríticos e sinais não alfanuméricos e ignora caixa: "olho d agua"
  encontra os sete municípios "Olho d'Água".
- As buscas dos slimSelect (que só ignoravam caixa) ganharam o mesmo
  filtro via `funcoes_javascript.js` (`events.searchFilter` normalizado),
  com nova tentativa por até 5 s até o Shiny criar as instâncias e reforço
  no `load`. Validado com "sao" → "São Paulo (SP)" e "olho d agua" →
  resultados "Olho-d'Água"/"Olho D'Água".

## 3. Visual da busca da tabela

- `searchInputStyle` saiu do tema; o campo `.rt-search` passou a repetir a
  busca dos dropdowns (fundo suave, borda transparente e raio 10 px, altura
  2.4 rem, lupa por SVG com cor própria no foco, anel azul no foco).
- Esqueleto da busca ajustado à nova geometria (196 × 38 no desktop,
  173 × 38 até 768 px), sem estouro horizontal no mobile (390/390).
- Medição: campo da tabela e campo do dropdown com 196×38, mesmo raio,
  fonte, padding e estado de foco; digitação continua filtrando.

## 4. Seleção e página do ranking sincronizadas

- A tabela já nasce com o município padrão selecionado: `defaultSelected`
  no `renderReactable` marca a linha na própria montagem.
- Na troca de dimensão/escopo, o foco é mantido se o município segue no
  ranking e reseta para o 1º colocado quando sai dele
  (`observeEvent(list(input$medida, input$escopo))`). Trocas de fora da
  tabela (mapa, seletor do perfil) usam `updateReactable(selected=...)`.
- O salto de página reage ao eco da seleção publicado pelo cliente
  (`updateReactable(page=...)` apenas), que chega depois da montagem do
  widget — elimina a corrida em que um índice de outro contexto era
  aplicado à tabela recém-renderizada (observada como seleção errada em
  trocas rápidas medida→escopo).
- Ao limpar a busca, o servidor reposiciona a tabela na página do
  município em foco (o reset nativo do reactable voltava à página 1).

## 5. Cabeçalho do ranking

- Havia um `<p></p>` vazio abaixo do resumo por HTML inválido (o `div` do
  slot do esqueleto dentro do `<p>` faz o navegador fechar o parágrafo).
  O resumo ficou no próprio slot e a dica virou parágrafo próprio.
- A pedido, a dica saiu do cabeçalho para logo acima da tabela, com a
  classe `bloco-descricao` e margem própria
  (`.bloco-descricao--tabela { margin-bottom: 0.6rem }`, folga medida de
  10 px). O resumo segue sem a classe.

## 6. Identificação da evolução, esqueleto e bolinhas

- Novo `uiOutput("evolucao_identificacao")` no cabeçalho do card:
  `Jutaí (AM) | 2015 – 2024`, e na comparação
  `Jutaí (AM) e Inhapi (AL) | 2015 – 2024` (só quando o comparado tem
  série; some quando o principal não tem série, como o restante da grade).
  Nomes em `--fonte-muito-grande-size`/700 e separador em
  `var(--cor-texto-suave)`.
- Esqueleto dedicado (`esqueleto_identificacao()` + slot): a primeira
  versão centralizava a barra e ela ficava ~4 px acima do texto; a correção
  alinha com a margem do parágrafo (topo 9 px nos dois estados).
- Títulos dos sete cartões ganharam bolinha (`evolucao-card__ponto`,
  0.5 em) na cor da dimensão via `cor_medida()`.

## 7. Testes e validação

- `devtools::test()`: **263 asserções verdes** — `nome_medida` com
  prefixo, tema por medida e variáveis CSS, seleção inicial/`defaultSelected`,
  manter/resetar foco, salto de página, dica do cabeçalho, identificação da
  evolução, esqueleto e bolinhas. (A suíte rodou com `rlang` 1.3.0 de
  biblioteca temporária, pois o 1.1.4 instalado fica abaixo do exigido pelo
  testthat.)
- Smoke headless (evidências nos temporários, fora do git): resumo com
  "Bloco", hover/seleção/página nas cores do bloco (bloco2 verde, Social
  amarelo, IBISMA roxo inalterado), manter Jutaí (rank 22/página 2 →
  rank 6/página 1 no AM), reset para Campos Novos Paulista em SP,
  clique na linha sincronizando o perfil, buscas sem acento/sinais e
  geometria de esqueletos/desktop/mobile.

## 8. Commits da sessão

- `9af4b33` Refina o ranking: cores por medida, buscas, seleção e cabeçalho
- `882fcb6` Identifica os municípios e o período na evolução
- `c149286` Marca os títulos da evolução com a cor da dimensão

---

# Sessão 14 — Teto adaptativo do eixo Y, rótulos de ano no mobile e placar (14/09/2026)

- **Pacote:** `painel_ibisma_v4`.
- **Objetivo:** tornar o teto do eixo Y adaptativo (espelhando o piso), dar
  respiro aos anos do eixo X no mobile com rótulos inclinados e colocar os
  rankings do placar lado a lado em telas pequenas.

## 1. Teto adaptativo do eixo Y

- Nova `teto_eixo_y(series, medidas)`: arredonda o maior valor das séries para
  **cima na dezena** e limita a faixa em `[10, 100]` (o 10 evita eixo degenerado
  quando tudo é zero; 100 é o teto do índice). Série sem valor algum devolve 100.
- `grafico_evolucao()` ganhou `maximo_y` e o repassa ao `e_y_axis`; quando NULL,
  o teto vem das próprias séries. Se piso e teto caírem na mesma dezena, o teto
  sobe 10 (até 100) para o eixo não degenerar.
- `lados_rotulos()` passou a receber piso e teto e calcula a posição relativa dos
  nomes no fim das linhas com a faixa real (`maximo_y - minimo_y`), o que também
  ajusta o corte de "perto do topo" quando o teto encolhe.
- `mod_como.R`: `piso_do_grupo()` virou `limites_do_grupo()` e devolve
  `list(min, max)`. Na comparação a faixa é **aberta ao máximo** (menor piso e
  maior teto entre principal e comparado) para nenhuma das séries ser cortada.
  O IBISMA mantém escala própria e os seis blocos seguem compartilhando uma
  única escala, agora com piso e teto iguais.
- Efeito nos testes: Dois (RO) passou a ter eixo 80–90 no índice (antes 80–100)
  e, na comparação com Quatro (SP), 10–90 no índice e 20–100 nos blocos.
- O piso máximo foi avaliado (90 → 95), mas ficou **mantido em 90**: a mudança
  literal só afetaria o caso de menor valor igual a 100 (um município em 2022).

## 2. Rótulos de ano no mobile

- A primeira tentativa foi mostrar os anos de dois em dois (`interval = 2`) via
  hook no cliente; a preferência passou a ser manter todos os anos visíveis com
  inclinação de 45°.
- Novo `rotulos_anos_js()`, aplicado com `htmlwidgets::onRender()` no fim de
  `grafico_evolucao()`: em cartões com largura < 340 px
  (`LARGURA_ROTULOS_ANOS`), inclina os rótulos em 45° e sobe a margem inferior
  do ECharts de 28 para 40 px; acima disso, tudo segue horizontal. O ajuste roda
  no cliente, reage a `resize` com um listener único por elemento
  (`data-rotulos-anos`) e não passa pelo servidor.
- Medições: cartões de bloco com 395 px no desktop e 276–310 px no mobile, o
  que separa bem o limiar; a 1024 px os cartões seguem horizontais.
- Limitação: o esqueleto da grade reserva a margem inferior de 28 px, então no
  mobile há um ajuste de ~12 px na troca esqueleto → gráfico, visível só no
  carregamento inicial.

## 3. Placar em duas colunas no mobile

- No `@media (max-width: 768px)`, o `.perfil-placar` passou de três linhas
  empilhadas para duas colunas: o índice ocupa a primeira linha inteira e
  "Ranking Brasil" e "Ranking na UF" ficam lado a lado abaixo, mantendo o
  alinhamento do desktop (Brasil à esquerda, UF à direita). A regra que forçava
  os dois rankings à esquerda no empilhamento foi removida.

## 4. Testes e validação

- `devtools::test()`: **281 asserções verdes** — novos testes de `teto_eixo_y`
  (arredondamento para cima, limites, série vazia), dos limites por grupo no
  `testServer` (min e max), do caso degenerado e do hook de rotação.
- Smoke headless: mobile 390 px com os 10 anos rotacionados e sem corte;
  desktop 1600 px e 1024 px horizontais; placar mobile com os rankings lado a
  lado; sem erros de JavaScript.
- Evidências em `dev/smoke/` e em temporários fora do git.

## 5. Commits da sessão

- `fa7bfb0` Torna o teto do eixo Y adaptativo na evolucao temporal
- `53df2dd` Rotaciona os rotulos de ano no mobile
- `b74bba9` Coloca os rankings do placar lado a lado no mobile


