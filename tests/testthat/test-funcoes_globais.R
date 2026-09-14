# Testes das funções globais do painel (dados, categorias, rankings e cores)

# Criando uma base pequena e previsível para os testes de cálculo
base_teste <- data.frame(
  ano = c(2020, 2020, 2020, 2020, 2021, 2021, 2021, 2021),
  codmunres = c(110001, 110002, 350001, 350002, 110001, 110002, 350001, 350002),
  bloco1 = c(0.10, 0.80, 0.40, 0.90, 0.20, 0.70, 0.50, 0.95),
  bloco2 = c(0.20, 0.70, 0.50, 0.60, 0.25, 0.65, 0.55, 0.85),
  bloco3 = c(0.30, 0.60, 0.55, 0.50, 0.35, 0.55, 0.60, 0.75),
  bloco4 = c(0.40, 0.50, 0.60, 0.40, 0.45, 0.45, 0.65, 0.65),
  bloco5 = c(0.50, 0.40, 0.65, 0.30, 0.55, 0.35, 0.70, 0.55),
  bloco6 = c(0.60, 0.30, 0.70, 0.20, 0.65, 0.25, 0.75, 0.45),
  indice_final = c(0.70, 0.90, 0.30, 0.10, 0.75, 0.85, 0.35, 0.15),
  municipio = c("Um", "Dois", "Tres", "Quatro", "Um", "Dois", "Tres", "Quatro"),
  uf = c("Rondonia", "Rondonia", "Sao Paulo", "Sao Paulo",
         "Rondonia", "Rondonia", "Sao Paulo", "Sao Paulo"),
  sigla_uf = c("RO", "RO", "SP", "SP", "RO", "RO", "SP", "SP"),
  regiao = c("Norte", "Norte", "Sudeste", "Sudeste",
             "Norte", "Norte", "Sudeste", "Sudeste"),
  cod_r_saude = 1:4,
  r_saude = c("A", "B", "C", "D"),
  cod_macro_r_saude = 1:4,
  macro_r_saude = c("M1", "M2", "M3", "M4"),
  stringsAsFactors = FALSE
)

preparado_teste <- preparar_dados(base_teste)

test_that("preparar_dados monta o formato longo com as sete medidas", {
  # Conferindo a quantidade de linhas e a escala dos valores
  expect_equal(nrow(preparado_teste$longo), 8 * 7)
  expect_setequal(unique(preparado_teste$longo$medida), c("indice_final", BLOCOS$medida))
  expect_true(all(preparado_teste$longo$valor >= 0 & preparado_teste$longo$valor <= 100))
  expect_equal(preparado_teste$anos, c(2020, 2021))
  expect_equal(nrow(preparado_teste$municipios), 4)
})

test_that("categorizar usa os quintis e preserva valores ausentes", {
  cortes <- c(20, 40, 60, 80)
  categorias <- categorizar(c(10, 30, 50, 70, 90, NA), cortes)
  expect_equal(
    as.character(categorias),
    c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto", NA)
  )
  expect_true(is.ordered(categorias))
})

test_that("cortes_categorias devolve os quatro quintis", {
  cortes <- cortes_categorias(1:100)
  expect_length(cortes, 4)
  expect_equal(unname(cortes), unname(stats::quantile(1:100, PROBS_CORTES)))
})

test_that("valores_ano classifica e ranqueia corretamente", {
  valores <- valores_ano(preparado_teste, 2020, "indice_final")
  expect_equal(nrow(valores), 4)

  # A posição 1 deve ser o município mais vulnerável
  mais_vulneravel <- valores[valores$pos_nac == 1, ]
  expect_equal(mais_vulneravel$municipio, "Dois")
  expect_equal(mais_vulneravel$total_nac, 4)

  # O ranking dentro da UF deve ser calculado por grupo
  ro <- valores[valores$sigla_uf == "RO", ]
  expect_equal(ro$municipio[ro$pos_uf == 1], "Dois")
  expect_equal(ro$total_uf, c(2, 2))
})

test_that("resumo_municipio reúne índice, categoria, rankings e blocos", {
  resumo <- resumo_municipio(preparado_teste, 110002, 2020)
  expect_equal(resumo$municipio, "Dois")
  expect_equal(resumo$valor, 90)
  expect_equal(resumo$categoria, "Muito alto")
  expect_equal(resumo$pos_nac, 1)
  expect_equal(resumo$pos_uf, 1)
  expect_equal(nrow(resumo$blocos), 6)
  expect_equal(resumo$blocos$nome, BLOCOS$nome)
  expect_type(resumo$blocos$cor, "character")
})

test_that("resumo_municipio devolve NULL quando não há dado no ano", {
  resumo <- resumo_municipio(preparado_teste, 999999, 2020)
  expect_null(resumo)
})

test_that("series_municipio monta as sete medidas em colunas", {
  series <- series_municipio(preparado_teste, 110002)
  expect_equal(names(series), c("ano", MEDIDAS$medida))
  expect_equal(nrow(series), 2)
  expect_equal(series$indice_final[series$ano == 2020], 90)
  expect_equal(series$bloco1[series$ano == 2021], 70)
  expect_true(series_tem_valor(series))

  # Município sem dado no ano deve continuar com os anos e colunas esperados
  vazio <- series_municipio(preparado_teste, 999999)
  expect_equal(names(vazio), c("ano", MEDIDAS$medida))
  expect_false(series_tem_valor(vazio))
})

test_that("grafico_evolucao desenha uma medida com o nome no fim da linha", {
  series <- series_municipio(preparado_teste, 110002)

  # Sem comparação existe apenas a série principal, com a cor da medida
  grafico <- grafico_evolucao(series, "indice_final", nome = "Dois (RO)")
  expect_length(grafico$x$opts$series, 1)
  serie <- grafico$x$opts$series[[1]]
  expect_equal(serie$name, "Dois (RO)")
  expect_equal(serie$itemStyle$color, cor_medida("indice_final"))
  expect_equal(serie$lineStyle$type, "solid")
  expect_true(serie$showSymbol)

  # O nome da localidade é o rótulo do fim da linha, sem legenda no gráfico
  expect_true(serie$endLabel$show)
  expect_equal(serie$endLabel$formatter, "{a}")
  expect_equal(serie$endLabel$align, "right")
  expect_false(isTRUE(grafico$x$opts$legend$show))

  # O eixo X precisa formatar os anos como inteiros, sem separador de milhar
  formatter <- grafico$x$opts$xAxis[[1]]$axisLabel$formatter
  expect_s3_class(formatter, "JS_EVAL")
  expect_true(grepl("Math.round", as.character(formatter)))

  # O eixo Y começa no piso da medida e pode ser fixado pelo módulo
  expect_equal(grafico$x$opts$yAxis[[1]]$min, 80)
  expect_equal(grafico$x$opts$yAxis[[1]]$max, 100)
  compartilhado <- grafico_evolucao(series, "indice_final", minimo_y = 90)
  expect_equal(compartilhado$x$opts$yAxis[[1]]$min, 90)

  # O desenho em SVG evita o borrão do canvas sob zoom ou escala fracionária
  expect_equal(grafico$x$renderer, "svg")

  # O tooltip mostra apenas o ano e cada localidade com a marca da série
  tooltip <- as.character(grafico$x$opts$tooltip$formatter)
  expect_true(grepl("Math.round", tooltip))
  expect_true(grepl("repeating-linear-gradient", tooltip, fixed = TRUE))
  expect_true(grepl("seriesIndex", tooltip, fixed = TRUE))
  expect_true(grepl("space-between", tooltip, fixed = TRUE))
  # A marca da comparação usa a mesma cor clareada em direção ao branco
  expect_true(grepl("clarear", tooltip, fixed = TRUE))
  expect_true(grepl("0.55", tooltip, fixed = TRUE))
  expect_false(grepl("rgba(", tooltip, fixed = TRUE))
  expect_false(grepl("IBISMA", tooltip, fixed = TRUE))
})

test_that("grafico_evolucao destaca a comparação com traço pontilhado", {
  principal <- series_municipio(preparado_teste, 110002)
  comparacao <- series_municipio(preparado_teste, 350002)
  grafico <- grafico_evolucao(
    principal, "bloco1",
    nome = "Dois (RO)",
    comparacao = comparacao,
    nome_comparacao = "Quatro (SP)"
  )

  # As duas localidades usam a mesma cor, diferenciadas pelo traço
  expect_length(grafico$x$opts$series, 2)
  linha_principal <- grafico$x$opts$series[[1]]
  linha_comparada <- grafico$x$opts$series[[2]]
  expect_equal(linha_comparada$name, "Quatro (SP)")
  expect_equal(linha_principal$lineStyle$color, cor_medida("bloco1"))
  expect_equal(linha_comparada$lineStyle$color, cor_medida("bloco1"))
  expect_equal(linha_comparada$lineStyle$type, "dotted")
  expect_true(linha_comparada$lineStyle$opacity < 1)
  expect_true(linha_comparada$z < linha_principal$z)

  # Os dois nomes vão para o fim das linhas, respeitando o lado calculado
  expect_equal(linha_principal$endLabel$formatter, "{a}")
  expect_equal(linha_comparada$endLabel$formatter, "{a}")

  # Nenhuma série apaga a outra no hover (sem foco de série no destaque)
  expect_null(linha_principal$emphasis)
  expect_null(linha_comparada$emphasis)
})

test_that("lados_rotulos separa rótulos próximos e respeita as bordas do eixo", {
  # Fins bem separados mantêm cada rótulo no lado natural do próprio ponto
  lados <- lados_rotulos(data.frame(principal = c(1, 95), comparacao = c(1, 60)), 50)
  expect_equal(lados$principal$lado, "abaixo")
  expect_equal(lados$comparacao$lado, "acima")

  # Fins próximos e longe do topo ficam em lados opostos
  lados <- lados_rotulos(data.frame(principal = c(60, 70), comparacao = c(60, 68)), 50)
  expect_equal(lados$principal$lado, "acima")
  expect_equal(lados$comparacao$lado, "abaixo")

  # Fins próximos e perto do topo descem juntos, com afastamentos diferentes
  lados <- lados_rotulos(data.frame(principal = c(60, 99), comparacao = c(60, 98.5)), 90)
  expect_equal(lados$principal$lado, "abaixo")
  expect_equal(lados$comparacao$lado, "abaixo")
  expect_true(lados$principal$afastamento != lados$comparacao$afastamento)

  # Fins próximos e no piso do eixo sobem juntos, com afastamentos diferentes
  lados <- lados_rotulos(data.frame(principal = c(95, 91), comparacao = c(1, 90.5)), 90)
  expect_equal(lados$principal$lado, "acima")
  expect_equal(lados$comparacao$lado, "acima")
  expect_true(lados$principal$afastamento != lados$comparacao$afastamento)

  # Sem comparação o rótulo sobe, a menos que a série termine no topo
  expect_equal(lados_rotulos(data.frame(principal = c(60, 70)), 50)$principal$lado, "acima")
  expect_equal(lados_rotulos(data.frame(principal = c(60, 95)), 50)$principal$lado, "abaixo")
})

test_that("piso_eixo_y arredonda o menor valor para baixo na dezena", {
  series <- series_municipio(preparado_teste, 110002)
  # O menor valor do município fica em 25, então o eixo começa em 20
  expect_equal(piso_eixo_y(series), 20)

  # O piso pode ser calculado apenas com um grupo de medidas
  expect_equal(piso_eixo_y(series, "indice_final"), 80)
  expect_equal(piso_eixo_y(series, BLOCOS$medida), 20)

  # Valores altos aproximam o piso de 100, sem criar um eixo degenerado
  alto <- series
  alto[, MEDIDAS$medida] <- 95
  alto$indice_final[alto$ano == 2021] <- 91
  expect_equal(piso_eixo_y(alto), 90)

  cem <- series
  cem[, MEDIDAS$medida] <- 100
  expect_equal(piso_eixo_y(cem), 90)

  # Série sem valor algum mantém o eixo na escala completa
  vazio <- series
  vazio[, MEDIDAS$medida] <- NA_real_
  expect_equal(piso_eixo_y(vazio), 0)
})

test_that("a evolução usa pisos de eixo por grupo de medidas", {
  municipio <- shiny::reactiveVal(110002)
  shiny::testServer(
    mod_como_server,
    args = list(dados = preparado_teste, municipio = municipio),
    {
      session$setInputs(municipio = "110002", ano = "2020", comparar = "350002")

      # Lendo as opções diretamente do JSON do widget renderizado
      opcoes_do_grafico <- function(saida) {
        jsonlite::fromJSON(saida, simplifyVector = FALSE)$x$opts
      }

      # O IBISMA tem escala própria, partindo do menor índice entre os dois
      expect_equal(opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$min, 10)
      # Os seis blocos compartilham o piso da menor série de bloco
      expect_equal(opcoes_do_grafico(output$grafico_bloco1)$yAxis[[1]]$min, 20)

      # Cada gráfico desenha a localidade principal e a comparação
      series_bloco <- opcoes_do_grafico(output$grafico_bloco1)$series
      expect_length(series_bloco, 2)
      expect_equal(series_bloco[[2]]$lineStyle$type, "dotted")

      # Sem comparação o eixo do IBISMA segue apenas o município principal
      session$setInputs(comparar = "nenhum")
      expect_equal(opcoes_do_grafico(output$grafico_indice_final)$yAxis[[1]]$min, 80)
      expect_length(opcoes_do_grafico(output$grafico_bloco1)$series, 1)

      # Com o principal sem dado, os gráficos ficam suspensos na grade
      session$setInputs(comparar = "350002", municipio = "999999")
      expect_error(output$grafico_indice_final, class = "shiny.silent.error")
    }
  )
})

test_that("formatadores usam a convenção brasileira", {
  expect_equal(formatar_numero(12.345), "12,3")
  expect_equal(formatar_numero(c(1.5, NA)), c("1,5", "Sem dados"))
  expect_equal(formatar_inteiro(5570), "5.570")
  expect_equal(rotulo_posicao(1234, 5570), "1.234º de 5.570")
  # Todos os valores do painel são exibidos com uma casa decimal
  expect_equal(formatar_numero(99.96), "100,0")
  expect_equal(formatar_numero(0.04), "0,0")
})

test_that("frase_percentil limita o texto a 99,9% com uma casa decimal", {
  expect_match(frase_percentil(99.96), "99,9%")
  expect_match(frase_percentil(100), "99,9%")
  expect_match(frase_percentil(50), "50,0%")
  expect_match(frase_percentil(NA), "Sem dado")
})

test_that("paletas e cores seguem a configuração do projeto", {
  expect_equal(unname(paleta_mapa("indice_final")), unname(PALETA_IBISMA))
  expect_equal(cor_medida("bloco1"), BLOCOS$cor[1])
  expect_equal(cor_medida("indice_final"), COR_IBISMA)
  expect_equal(cor_categoria(NA_character_), COR_SEM_DADOS)
  expect_equal(cor_texto_sobre("#FFFFFF"), COR_AZUL_ESCURO)
  expect_equal(cor_texto_sobre("#0A1E3C"), "#FFFFFF")

  # A rampa de um bloco deve ter cinco tons distintos
  rampa <- paleta_mapa("bloco3")
  expect_length(rampa, 5)
  expect_equal(length(unique(rampa)), 5)
})

test_that("opções de medida, ano e escopo do ranking estão completas", {
  medidas <- opcoes_medidas()
  expect_equal(unname(medidas), MEDIDAS$medida)
  expect_true(all(grepl("^Bloco", names(medidas)[-1])))
  expect_equal(anos_disponiveis(), sort(unique(df_ibisma$ano)))
  escopos <- opcoes_escopo_ranking()
  expect_equal(escopos[[1]], "nacional")
  expect_equal(length(escopos), 28)
})

test_that("seletor_inline controla a busca e traduz os textos", {
  # O seletor padrão liga a busca e usa os textos em português
  com_busca <- as.character(seletor_inline("teste", c("A" = "a", "B" = "b")))
  expect_true(grepl('"showSearch":true', com_busca, fixed = TRUE))
  expect_true(grepl("Buscar...", com_busca, fixed = TRUE))
  expect_true(grepl("Nenhum resultado", com_busca, fixed = TRUE))
  expect_true(grepl('"searchHighlight":true', com_busca, fixed = TRUE))

  # O seletor sem busca esconde o campo, mantendo as opções intactas
  sem_busca <- as.character(seletor_inline("teste2", c("A" = "a"), busca = FALSE))
  expect_true(grepl('"showSearch":false', sem_busca, fixed = TRUE))
})

test_that("atualizar_municipios envia listas nomeadas que serializam sem aviso", {
  # Capturando a mensagem enviada por uma sessão simulada
  capturada <- new.env(parent = emptyenv())
  sessao <- list(sendCustomMessage = function(tipo, mensagem) {
    capturada$tipo <- tipo
    capturada$mensagem <- mensagem
  })
  base <- dados_mapa(preparado_teste, 2020, "indice_final")
  atualizar_municipios(sessao, "mapa", base)

  expect_equal(capturada$tipo, "ibisma_mapa_atualiza")
  mensagem <- capturada$mensagem
  # As cores e os tooltips precisam ser listas nomeadas, e não vetores nomeados
  expect_type(mensagem$cores, "list")
  expect_type(mensagem$labels, "list")
  expect_equal(names(mensagem$cores), as.character(base$codmunres))

  # O toJSON usado pelo Shiny não deve emitir o aviso de vetor nomeado
  aviso <- NULL
  withCallingHandlers(
    shiny:::toJSON(mensagem),
    warning = function(w) {
      aviso <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  expect_null(aviso)
})

test_that("montar_selos gera o HTML dos selos de categoria", {
  selos <- montar_selos(c("Muito baixo", "Muito alto"))
  expect_length(selos, 2)
  expect_true(all(grepl("badge-categoria", selos)))
  expect_true(grepl(PALETA_IBISMA[["Muito alto"]], selos[2]))
})

test_that("dados_mapa monta cores e tooltips para o ano", {
  base <- dados_mapa(preparado_teste, 2020, "indice_final")
  expect_equal(nrow(base), 4)
  expect_true(all(nzchar(base$tooltip)))
  expect_true(all(base$cor %in% unname(PALETA_IBISMA)))
  expect_true(all(grepl("tooltip-mapa", base$tooltip)))

  base_bloco <- dados_mapa(preparado_teste, 2020, "bloco3")
  expect_false(identical(unique(base_bloco$cor), unname(PALETA_IBISMA)))
})

test_that("municipio_padrao escolhe o mais vulnerável do último ano", {
  padrao <- municipio_padrao(preparado_teste)
  expect_true(padrao %in% preparado_teste$municipios$codmunres)
})

test_that("nome_municipio devolve nome e sigla", {
  expect_equal(nome_municipio(preparado_teste, 110002), "Dois (RO)")
  expect_equal(nome_municipio(preparado_teste, 999999), "Município")
})

test_that("mapa_base limita o zoom e o arrasto ao enquadramento do Brasil", {
  mapa <- mapa_base()
  opcoes <- mapa$x$options
  expect_equal(opcoes$minZoom, 4)
  expect_equal(opcoes$maxZoom, 10)
  expect_equal(opcoes$maxBoundsViscosity, 1)
  metodos <- vapply(
    mapa$x$calls,
    function(chamada) chamada$method,
    character(1)
  )
  expect_true("setMaxBounds" %in% metodos)
})

test_that("legenda_categorias omite Sem dados por padrão", {
  padrao <- as.character(legenda_categorias())
  expect_false(grepl("Sem dados", padrao))
  expect_true(grepl("Muito alto", padrao))

  completo <- as.character(legenda_categorias(com_sem_dados = TRUE))
  expect_true(grepl("Sem dados", completo))
})

test_that("paleta_medida concentra a rampa usada por mapa, selos e tooltips", {
  # O IBISMA mantém a paleta roxa e cada bloco usa a própria rampa
  expect_equal(paleta_medida("indice_final"), PALETA_IBISMA)
  for (m in BLOCOS$medida) {
    rampa <- paleta_medida(m)
    expect_length(rampa, 5)
    expect_equal(names(rampa), CATEGORIAS)
    expect_equal(length(unique(rampa)), 5)
    # A categoria central deve ser a cor de identificação do bloco
    expect_equal(unname(rampa[3]), cor_medida(m))
  }
  # A cor mais clara não pode se confundir com o cinza de "Sem dados"
  expect_false(any(paleta_medida("bloco1") == COR_SEM_DADOS))
})

test_that("cor_categoria e montar_selos respeitam a medida informada", {
  cor_bloco <- cor_categoria("Muito alto", "bloco3")
  expect_equal(cor_bloco, unname(paleta_medida("bloco3")["Muito alto"]))
  expect_false(identical(cor_bloco, cor_categoria("Muito alto")))
  selos <- montar_selos(c("Muito baixo", "Muito alto"), "bloco3")
  expect_true(grepl(cor_bloco, selos[2], fixed = TRUE))
})

test_that("tooltip do mapa usa a cor da medida exibida", {
  # A chip do IBISMA usa a paleta roxa
  base_indice <- dados_mapa(preparado_teste, 2020, "indice_final")
  cor_indice <- cor_categoria("Muito alto")
  expect_true(any(grepl(paste0("--cor-cat:", cor_indice), base_indice$tooltip, fixed = TRUE)))

  # A chip de um bloco usa a rampa daquele bloco
  base_bloco <- dados_mapa(preparado_teste, 2020, "bloco3")
  cor_bloco <- cor_categoria("Muito alto", "bloco3")
  expect_true(any(grepl(paste0("--cor-cat:", cor_bloco), base_bloco$tooltip, fixed = TRUE)))
  expect_false(any(grepl(paste0("--cor-cat:", cor_indice), base_bloco$tooltip, fixed = TRUE)))
})

test_that("tooltip da pétala carrega a cor da dimensão", {
  blocos <- data.frame(
    medida = BLOCOS$medida,
    nome = BLOCOS$nome,
    valor = c(10, 30, 50, 70, 90, 100),
    categoria = c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto", "Muito alto"),
    cor = BLOCOS$cor,
    pos_nac = 1:6,
    total_nac = rep(100, 6),
    stringsAsFactors = FALSE
  )
  html <- as.character(grafico_petalas(blocos))
  expect_true(grepl("tooltip-petala__marca", html, fixed = TRUE))
  expect_true(grepl(paste0("--cor-medida:", cor_medida("bloco3")), html, fixed = TRUE))
  expect_true(grepl(paste0("--cor-fundo:", cor_categoria("Médio", "bloco3")), html, fixed = TRUE))
  expect_true(grepl("petalas-legenda", html, fixed = TRUE))
})

test_that("grafico_petalas monta as seis pétalas com tooltip", {
  blocos <- data.frame(
    nome = BLOCOS$nome,
    valor = c(10, 30, 50, 70, 90, 100),
    categoria = c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto", "Muito alto"),
    cor = BLOCOS$cor,
    pos_nac = 1:6,
    total_nac = rep(100, 6),
    stringsAsFactors = FALSE
  )
  html <- as.character(grafico_petalas(blocos))
  expect_true(grepl("svg-petalas", html))
  expect_equal(
    lengths(regmatches(html, gregexpr("grupo-petala", html))),
    6
  )
  expect_true(grepl("tooltip-petala", html))
  expect_true(grepl("Planejamento Reprodutivo", html))
  # Os valores dentro das pétalas usam sempre uma casa decimal
  expect_true(grepl(">100,0</text>", html, fixed = TRUE))
  expect_true(grepl(">10,0</text>", html, fixed = TRUE))

  # Os discos de valor ficam sempre no fim da guia, e não na ponta da pétala
  expect_false(grepl("ponto-mediana", html))
  discos <- regmatches(
    html,
    gregexpr('cx="[0-9.]+" cy="[0-9.]+" r="16"', html)
  )[[1]]
  expect_length(discos, 6)
  coordenadas <- do.call(rbind, lapply(discos, function(disco) {
    as.numeric(regmatches(disco, gregexpr("[0-9.]+", disco))[[1]])[1:2]
  }))
  distancias <- sqrt((coordenadas[, 1] - 250)^2 + (coordenadas[, 2] - 275)^2)
  expect_true(all(round(distancias) == 185))

  # A ponta da pétala percorre a guia na mesma escala do disco
  escalas <- as.numeric(sub(
    ".*scale\\(([0-9.]+)\\)", "\\1",
    regmatches(html, gregexpr("scale\\([0-9.]+\\)", html))[[1]]
  ))
  esperadas <- round((blocos$valor / 100) * (185 / 170), 3)
  expect_equal(round(escalas, 3), esperadas)
})

test_that("perfil_palco monta identificação, pétalas e placar", {
  resumo <- resumo_municipio(preparado_teste, 110002, 2020)
  municipio <- preparado_teste$municipios[preparado_teste$municipios$codmunres == 110002, ]
  html <- as.character(perfil_palco(
    municipio, resumo, ano = 2020,
    rotulo = "Município principal"
  ))
  expect_true(grepl("Dois, RO", html, fixed = TRUE))
  expect_true(grepl("Município principal", html, fixed = TRUE))
  expect_true(grepl("svg-petalas", html, fixed = TRUE))
  expect_true(grepl("IBISMA em 2020", html, fixed = TRUE))
  expect_true(grepl("perfil-placar", html, fixed = TRUE))
  # O ranking estadual não repete o nome da UF no título
  expect_true(grepl("Ranking na UF", html, fixed = TRUE))
  expect_false(grepl("Ranking na UF (", html, fixed = TRUE))
  # Os valores territoriais guardam o texto completo para o tooltip condicional
  expect_true(grepl("metrica-tooltip", html, fixed = TRUE))
  expect_true(grepl("data-tooltip-texto", html, fixed = TRUE))

  # O palco do comparado usa a classe própria, sem o rótulo do principal
  html_b <- as.character(perfil_palco(
    municipio, resumo, ano = 2020,
    comparado = TRUE, rotulo = "Município comparado"
  ))
  expect_true(grepl("painel-bloco--comparado", html_b, fixed = TRUE))
  expect_true(grepl("Município comparado", html_b, fixed = TRUE))
})

test_that("perfil_palco mostra estado vazio quando não há dado no ano", {
  municipio <- preparado_teste$municipios[preparado_teste$municipios$codmunres == 110002, ]
  html <- as.character(perfil_palco(municipio, NULL, ano = 2020))
  expect_true(grepl("não possui dados no ano selecionado", html, fixed = TRUE))
  expect_false(grepl("perfil-placar", html, fixed = TRUE))
})

test_that("esqueletos preservam a estrutura de cada output", {
  # O ranking replica a busca, o cabeçalho, as 12 linhas e a paginação
  ranking <- as.character(esqueleto_ranking())
  expect_equal(
    lengths(regmatches(ranking, gregexpr("esqueleto__linha", ranking))),
    12
  )
  expect_true(grepl("esqueleto__busca", ranking))
  expect_true(grepl("esqueleto__paginacao", ranking))
  # O cabeçalho alinha números à direita e a paginação reproduz os botões
  expect_true(grepl("esqueleto__celula--direita", ranking))
  expect_true(grepl("esqueleto__paginacao-nav", ranking))
  expect_true(grepl("esqueleto__barra--reticencias", ranking))

  # O mapa desenha a silhueta do Brasil junto do controle de zoom
  mapa <- as.character(esqueleto_mapa())
  expect_true(grepl("esqueleto__desenho", mapa))
  expect_true(grepl("esqueleto__forma", mapa))
  expect_true(grepl("esqueleto__controle", mapa))

  # O palco mantém identificação, pétalas e placar na mesma composição
  palco <- as.character(esqueleto_palco())
  expect_true(grepl("perfil-nome", palco))
  expect_true(grepl("perfil-metricas", palco))
  expect_true(grepl("svg-petalas", palco))
  expect_true(grepl("perfil-placar", palco))
  expect_equal(
    lengths(regmatches(palco, gregexpr("esqueleto__disco", palco))),
    6
  )
  # O esqueleto não deve repetir nenhum valor do conteúdo real
  expect_false(grepl("IBISMA em", palco))

  # A evolução reserva os sete cartões com eixos e traços abstratos
  evolucao <- as.character(esqueleto_grade_evolucao())
  expect_true(grepl("evolucao-grade", evolucao))
  expect_true(grepl("esqueleto__traco", evolucao))
  expect_equal(
    lengths(regmatches(evolucao, gregexpr('class="esqueleto__grafico"', evolucao))),
    7
  )
  # Cada gráfico reserva a coluna dos números do eixo Y, como o gráfico real
  expect_equal(
    lengths(regmatches(evolucao, gregexpr("esqueleto__grafico-margem", evolucao))),
    7
  )
  expect_equal(
    lengths(regmatches(evolucao, gregexpr("esqueleto__barra--rotulo", evolucao))),
    28
  )

  # O slot empilha o output e o esqueleto para o CSS exibir durante a carga
  slot <- as.character(esqueleto_slot(
    htmltools::tags$div(id = "saida"),
    esqueleto_texto(),
    classe = "esqueleto-slot--texto"
  ))
  expect_true(grepl("esqueleto-slot", slot, fixed = TRUE))
  expect_true(grepl('id="saida"', slot, fixed = TRUE))
  expect_true(grepl("esqueleto--texto", slot, fixed = TRUE))
})
