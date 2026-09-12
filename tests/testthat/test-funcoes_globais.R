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

test_that("comparar_series alinha os anos dos dois municípios", {
  series <- comparar_series(preparado_teste, 110002, 350001, "indice_final")
  expect_equal(names(series), c("ano", "valor_a", "valor_b"))
  expect_equal(nrow(series), 2)
  expect_equal(series$valor_a[series$ano == 2020], 90)
  expect_equal(series$valor_b[series$ano == 2020], 30)
})

test_that("comparar_ano calcula as diferenças por medida", {
  comparacao <- comparar_ano(preparado_teste, 110002, 350001, 2020)
  expect_equal(nrow(comparacao), 7)
  expect_equal(comparacao$nome[1], "IBISMA")
  expect_equal(comparacao$delta[1], 30 - 90)
})

test_that("formatadores usam a convenção brasileira", {
  expect_equal(formatar_numero(12.345), "12,3")
  expect_equal(formatar_numero(c(1.5, NA)), c("1,5", "Sem dados"))
  expect_equal(formatar_inteiro(5570), "5.570")
  expect_equal(rotulo_posicao(1234, 5570), "1.234º de 5.570")
})

test_that("frase_percentil limita o texto a 99%", {
  expect_match(frase_percentil(99.96), "99%")
  expect_match(frase_percentil(50), "50%")
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

  medianas <- stats::setNames(rep(50, 6), BLOCOS$nome)
  html_mediana <- as.character(grafico_petalas(blocos, medianas = medianas))
  expect_equal(
    lengths(regmatches(html_mediana, gregexpr("ponto-mediana", html_mediana))),
    6
  )
  expect_true(grepl("Mediana Brasil", html_mediana))
})
