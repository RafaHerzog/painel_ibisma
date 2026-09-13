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
