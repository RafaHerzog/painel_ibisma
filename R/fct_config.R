# =============================================================================
#   DEFINIÇÕES DO IBISMA E SUAS CORES
#   Reúne o dicionário do índice (blocos, medidas e categorias), as rampas de
#   cinco tons de cada medida e as funções de cor e contraste do painel.
#   Manter tudo aqui evita valores espalhados pelo código e facilita a evolução.
# =============================================================================

# -----------------------------------------------------------------------------
#   CORES INSTITUCIONAIS E DE IDENTIFICAÇÃO
# -----------------------------------------------------------------------------

# Definindo as cores institucionais reaproveitadas no painel
COR_AZUL_ESCURO <- "#0A1E3C"
COR_AZUL_CLARO  <- "#32A0FF"
COR_AZUL_MEDIO  <- "#1E5AA0"
COR_AMARELO     <- "#FAC80F"
COR_VERDE       <- "#41BE3C"
COR_CORAL       <- "#E4572E"
COR_TEAL        <- "#00A6A6"

# Definindo a cor de identificação do índice
COR_IBISMA <- "#4B1D73"

# Definindo a cor usada para municípios e anos sem dado disponível
COR_SEM_DADOS <- "#D8DCE3"

# -----------------------------------------------------------------------------
#   CATEGORIAS E RAMPAS DE COR
# -----------------------------------------------------------------------------

# Definindo os rótulos ordenados das cinco categorias de vulnerabilidade
CATEGORIAS <- c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto")

# Definindo as rampas de cinco tons de cada medida, na ordem das categorias
# A cor de identificação fica no tom central dos blocos e no tom mais alto do índice
PALETAS <- list(
  indice_final = stats::setNames(
    c("#D5C2E8", "#B592D6", "#915EC4", "#6B35A3", COR_IBISMA),
    CATEGORIAS
  ),
  bloco1 = stats::setNames(
    c("#FDEAA4", "#FCD857", COR_AMARELO, "#AD921D", "#655F2B"),
    CATEGORIAS
  ),
  bloco2 = stats::setNames(
    c("#B7E6B5", "#7AD276", COR_VERDE, "#2F8B3C", "#1F5B3C"),
    CATEGORIAS
  ),
  bloco3 = stats::setNames(
    c("#B1DBFF", "#70BCFF", COR_AZUL_CLARO, "#2576C1", "#194F86"),
    CATEGORIAS
  ),
  bloco4 = stats::setNames(
    c("#F5BFB0", "#EC896D", COR_CORAL, "#9E4532", "#5D3437"),
    CATEGORIAS
  ),
  bloco5 = stats::setNames(
    c("#AAC0DB", "#628CBC", COR_AZUL_MEDIO, "#184780", "#123562"),
    CATEGORIAS
  ),
  bloco6 = stats::setNames(
    c("#9EDDDD", "#4CC1C1", COR_TEAL, "#037A84", "#065264"),
    CATEGORIAS
  )
)

# -----------------------------------------------------------------------------
#   DICIONÁRIO DAS MEDIDAS
# -----------------------------------------------------------------------------

# Definindo as sete medidas na ordem canônica do painel
# A ordem manda nas colunas das séries, nos sete gráficos e nos seletores
MEDIDAS <- data.frame(
  medida = c(
    "indice_final",
    "bloco1",
    "bloco2",
    "bloco3",
    "bloco4",
    "bloco5",
    "bloco6"
  ),
  nome = c(
    "IBISMA",
    "Social",
    "Planejamento Reprodutivo",
    "Pré-natal",
    "Parto",
    "Sistema de saúde",
    "Clima"
  ),
  rotulo = c(
    "IBISMA",
    "Bloco Social",
    "Bloco Planejamento Reprodutivo",
    "Bloco Pré-natal",
    "Bloco Parto",
    "Bloco Sistema de saúde",
    "Bloco Clima"
  ),
  stringsAsFactors = FALSE
)

# Derivando a cor de identificação do tom central dos blocos e do topo do índice
MEDIDAS$cor <- vapply(MEDIDAS$medida, function(medida) {
  tom <- if (identical(medida, "indice_final")) "Muito alto" else "Médio"
  unname(PALETAS[[medida]][tom])
}, character(1))

# Definindo os seis blocos como o recorte das medidas sem o índice
BLOCOS <- MEDIDAS[MEDIDAS$medida != "indice_final", ]
row.names(BLOCOS) <- NULL

# -----------------------------------------------------------------------------
#   FUNÇÕES DE COR
# -----------------------------------------------------------------------------

#' Definindo uma função que obtém a cor de identificação de uma ou mais medidas
#'
#' @param medida Vetor de identificadores de medida ("indice_final", "bloco1"...).
#' @return Vetor de cores em hexadecimal, na mesma ordem da entrada.
#' Usada em: fct_dados.R (resumo do município), fct_graficos.R, fct_petalas.R e mod_onde.R (tema do ranking).
#' @noRd
cor_medida <- function(medida) {
  # Buscando a cor de cada medida no dicionário
  MEDIDAS$cor[match(medida, MEDIDAS$medida)]
}

#' Definindo uma função que obtém o nome de exibição de uma ou mais medidas
#'
#' @param medida Vetor de identificadores de medida ("indice_final", "bloco1"...).
#' @param prefixo_bloco Se TRUE, usa o rótulo com o prefixo "Bloco".
#' @return Vetor de nomes legíveis, na mesma ordem da entrada.
#' Usada em: fct_dados.R (resumo do município), fct_graficos.R, fct_mapa.R (tooltip do mapa) e mod_onde.R (resumo do ranking).
#' @noRd
nome_medida <- function(medida, prefixo_bloco = FALSE) {
  # Devolvendo o rótulo com o prefixo quando pedido
  if (prefixo_bloco) {
    return(MEDIDAS$rotulo[match(medida, MEDIDAS$medida)])
  }
  # Devolvendo o nome curto da medida
  MEDIDAS$nome[match(medida, MEDIDAS$medida)]
}

#' Definindo uma função que mistura duas cores em hexadecimal
#'
#' @param cor1 Cor de partida em hexadecimal.
#' @param cor2 Cor de chegada em hexadecimal.
#' @param peso Peso da segunda cor na mistura (0 a 1).
#' @return Cor resultante em hexadecimal.
#' Usada em: mod_onde.R (tema do ranking).
#' @noRd
misturar_cores <- function(cor1, cor2, peso) {
  # Convertendo as duas cores para canais RGB e aplicando a mistura ponderada
  rgb1 <- grDevices::col2rgb(cor1)
  rgb2 <- grDevices::col2rgb(cor2)
  misto <- round((1 - peso) * rgb1 + peso * rgb2)
  grDevices::rgb(misto[1], misto[2], misto[3], maxColorValue = 255)
}

#' Definindo uma função que obtém a cor de uma categoria de vulnerabilidade
#'
#' @param categoria Vetor de categorias ("Muito baixo" ... "Muito alto").
#' @param medida Identificador da medida que define a rampa de cores.
#' @return Vetor de cores em hexadecimal, com cinza para valores ausentes.
#' Usada em: fct_mapa.R (cores e tooltip do mapa), fct_petalas.R (tooltip da pétala) e utils_ui.R (selos de categoria).
#' @noRd
cor_categoria <- function(categoria, medida = "indice_final") {
  # Buscando cada categoria na rampa da medida e tratando valores sem dado
  paleta <- PALETAS[[medida]]
  cores <- unname(paleta[categoria])
  ifelse(is.na(cores), COR_SEM_DADOS, cores)
}

#' Definindo uma função que escolhe a cor de texto com melhor contraste sobre um fundo
#'
#' @param cor Cor de fundo em hexadecimal.
#' @return "#FFFFFF" para fundos escuros e a cor azul escura para fundos claros.
#' Usada em: fct_mapa.R (tooltip do mapa), fct_petalas.R (disco da pétala), mod_onde.R (tema do ranking) e utils_ui.R (selos de categoria).
#' @noRd
cor_texto_sobre <- function(cor) {
  # Calculando a luminância relativa do fundo informado
  rgb <- grDevices::col2rgb(cor) / 255
  luminancia <- 0.2126 * rgb[1, ] + 0.7152 * rgb[2, ] + 0.0722 * rgb[3, ]
  unname(ifelse(luminancia > 0.55, COR_AZUL_ESCURO, "#FFFFFF"))
}
