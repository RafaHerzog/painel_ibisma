# AGENTS.md — painel_ibisma

Repositório voltado à construção de um painel de visualização para o IBISMA - Índice Brasileiro
de Insegurança em Saúde Materna. O índice é composto por seis blocos/dimensões: Social; Planejamento
Reprodutivo; Pré-natal; Parto; Sistema de saúde; Clima. Cada bloco é composto por um conjunto de indicadores.
Para o cálculo do índice final, foram definidos pesos tanto para os blocos quanto para os indicadores utilizando
Análise Fatorial. O índice varia entre 0 e 100, e seu valor representa o percentual de municípios com vulnerabilidade
menor ou igual, i.e., o percentil de vulnerabilidade. Quando maior a vulnerabilidade, maior o valor do índice.

## Cores do projeto (Observatório Obstétrico Brasileiro)

- Cores principais:
    - Azul escuro: #0A1E3C; rgb(10, 30, 60).
    - Azul claro: #32A0FF; rgb(50, 160, 255).

- Cores secundárias:
    - Branco: #FFFFFF; rgb(255, 255, 255).
    - Azul médio: #1E5AA0; rgb(30, 90, 160).
    - Amarelo: #FAC80F; rgb(250, 200, 15).
    - Verde: #41BE3C; rgb(65, 190, 60).

## Convenções

- Qualquer tamanho de fonte utilizado em elementos do painel deve deve usar uma das classes ou variáveis
de tamanho de fonte definidas em [inst/app/www/global/custom.css](inst/app/www/global/custom.css).
- Inputs de seleção devem usar o slimSelectInput, do pacote shinyWidgets. Quanto a outros inputs, prefira sempre
inputs do pacote shinyWidgets. Customize-os extensivamente para garantir que eles tenham a identidade visual do projeto
e para que sigam os princípios mais modernos de design e experiência do usuário.
- Comentários devem ser feitos em português, buscando evitar neologismos e prezando por compreensão. Cada comentário deve ter
no máximo uma linha e devem em geral iniciar com um verbo em gerúndio, referente à ação que aquele código faz. Ex: "Criando uma
função que...". O código deve ser comentado extensivamente, para que pessoas que não estejam habituadas com a codebase consigam
entender facilmente o que está sendo feito.
- Deve-se prezar por códigos simples, sem over-engeneering, que sejam fáceis de entender mesmo para pessoas que não estejam
habituadas com a codebase.

## Comandos essenciais

- Rodar o app em desenvolvimento: `devtools::run_dev()` (ou
  `pkgload::load_all()` + `run_app()`).
- Rodar todos os testes: `devtools::test()`.
- Rodar um grupo de testes: `devtools::test(filter = "funcoes_globais")`
  (ex.: `"cascata"`, `"app"`, `"parquet_io"`).
- Regenerar os dados do painel (depois de mudar a base bruta):
  `data-raw/cria_rda.R` é um script linear, rodável passo a passo (botão Source
  do RStudio ou `Rscript`), que lê os CSVs de `data-raw/databases/` e gera os
  arquivos prontos (`inst/app/data/dados_ibisma.rds` e `tabela_ano_*.rds`) e a
  malha (chave `gerar_malha`, desligada por padrão). O script não carrega o
  pacote, o app apenas lê `inst/app/data/` e o pacote não tem dado próprio.

> IMPORTANTE: SEMPRE use `devtools::test()` (faz `pkgload::load_all()`).
> `testthat::test_file(...)` direto NÃO carrega as funções internas do pacote e
> falha com "could not find function" mesmo para testes válidos.

## Smoke test visual/headless (chromote, fora da suíte)

- Quando usar: checagem visual de CSS/layout que a suíte não cobre. Complementa o E2E de
  `test-app.R` para verificações ad hoc — NÃO substitui `devtools::test()`.
- Script reutilizável: `Rscript dev/headless_smoke.R [--port=4848]
  [--outdir=<dir>] [--wait-for=<seletor CSS>] [--shot=<nome.png>]
  [--eval="<JS>"] [--pre-eval="<JS>"] [--eval-file=arq.js]
  [--pre-eval-file=arq.js] [--width=1600] [--height=900] [--scroll=<px>]
  [--mouse=x,y] [--click=x,y]` — sobe o app em background, abre no Chrome
  headless, espera o seletor, salva o screenshot, avalia o JS (deve retornar
  STRING; o resultado vai ao console) e derruba o servidor. O `--eval` aceita
  promises (ex.: IIFE assíncrona com `await`), `--mouse`/`--click` disparam
  mouse real para validar hover e clique, e a captura sem `--full` registra
  apenas a área visível (funciona em qualquer rolagem). O `--pre-eval` roda
  antes do screenshot para preparar um estado (ex.: trocar a medida e abrir
  uma tooltip) e então capturá-lo.
  Rodar com working directory na raiz do pacote.
- Armadilhas (custo de uma sessão de debug cada):
  - `run_app()` NÃO aceita `port=` direto — a porta vai em
    `options = list(port = ..., launch.browser = FALSE)` (senão o app sobe na
    3838 e o poller nunca acha).
  - No `callr::r_bg`, `run_app()` sozinho morre em silêncio: é o
    `print.shiny.appobj` que sobe o servidor → usar `print(run_app(...))`
    explícito (sem ele o processo só serializa o objeto e sai limpo, sem erro).
  - `ChromoteSession$Runtime$evaluate` retorna `$result$value`; NUNCA usar `NA`
    do R dentro do código JS (vira ReferenceError e o resultado chega como
    `undefined`) — retornar string delimitada (`'a|b|c'`) e parsear no R.