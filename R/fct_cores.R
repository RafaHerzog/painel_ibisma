# =============================================================================
#   FUNÇÕES AUXILIARES DE CORES
#   Converte as configurações de fct_config.R em vetores e funções de cor
#   usados por mapas, gráficos, legendas e selos do painel.
# =============================================================================

#' Obtendo a cor de uma ou mais medidas
#'
#' @param medida Vetor de identificadores de medida ("indice_final", "bloco1"...).
#' @return Vetor de cores em hexadecimal, na mesma ordem da entrada.
#' @noRd
cor_medida <- function(medida) {
  # Casando cada medida com sua cor configurada
  cores <- MEDIDAS$cor[match(medida, MEDIDAS$medida)]
  # Usando a cor do IBISMA como padrão para medidas desconhecidas
  ifelse(is.na(cores), COR_IBISMA, cores)
}

#' Obtendo o nome de exibição de uma ou mais medidas
#'
#' @param medida Vetor de identificadores de medida.
#' @return Vetor de nomes legíveis, na mesma ordem da entrada.
#' @noRd
nome_medida <- function(medida) {
  # Casando cada medida com seu nome configurado
  nomes <- MEDIDAS$nome[match(medida, MEDIDAS$medida)]
  # Usando o próprio identificador como padrão para medidas desconhecidas
  ifelse(is.na(nomes), medida, nomes)
}

#' Montando a paleta nomeada das cinco categorias
#'
#' @return Vetor nomeado de cores, em que os nomes são as categorias.
#' @noRd
paleta_categorias <- function() {
  stats::setNames(unname(PALETA_IBISMA), CATEGORIAS)
}

#' Obtendo a cor de uma categoria de vulnerabilidade
#'
#' @param categoria Vetor de categorias ("Muito baixo" ... "Muito alto").
#' @return Vetor de cores em hexadecimal, com cinza para valores ausentes.
#' @noRd
cor_categoria <- function(categoria) {
  # Buscando cada categoria na paleta e tratando valores sem dado
  cores <- unname(PALETA_IBISMA[categoria])
  ifelse(is.na(cores), COR_SEM_DADOS, cores)
}

#' Misturando duas cores em hexadecimal
#'
#' @param cor1 Cor de partida em hexadecimal.
#' @param cor2 Cor de chegada em hexadecimal.
#' @param peso Peso da segunda cor na mistura (0 a 1).
#' @return Cor resultante em hexadecimal.
#' @noRd
misturar_cores <- function(cor1, cor2, peso) {
  # Convertendo as cores para canais RGB e aplicando a mistura ponderada
  rgb1 <- grDevices::col2rgb(cor1)
  rgb2 <- grDevices::col2rgb(cor2)
  misto <- round((1 - peso) * rgb1 + peso * rgb2)
  grDevices::rgb(misto[1], misto[2], misto[3], maxColorValue = 255)
}

#' Montando a paleta de cinco tons usada no mapa para uma medida
#'
#' @param medida Identificador da medida exibida no mapa.
#' @return Vetor de cinco cores, da categoria mais baixa para a mais alta.
#' @noRd
paleta_mapa <- function(medida) {
  # Usando a paleta roxa do IBISMA quando a medida é o índice final
  if (identical(medida, "indice_final")) {
    return(unname(PALETA_IBISMA))
  }
  # Derivando uma rampa a partir da cor do bloco selecionado
  base <- cor_medida(medida)[1]
  rampa <- grDevices::colorRampPalette(
    c(
      misturar_cores(base, "#FFFFFF", 0.88),
      misturar_cores(base, "#FFFFFF", 0.55),
      base,
      misturar_cores(base, COR_AZUL_ESCURO, 0.35)
    ),
    bias = 1
  )
  rampa(5)
}

#' Escolhendo a cor de texto com melhor contraste sobre um fundo
#'
#' @param cor Cor de fundo em hexadecimal.
#' @return "#FFFFFF" para fundos escuros e a cor azul escura para fundos claros.
#' @noRd
cor_texto_sobre <- function(cor) {
  # Calculando a luminância relativa do fundo informado
  rgb <- grDevices::col2rgb(cor) / 255
  luminancia <- 0.2126 * rgb[1, ] + 0.7152 * rgb[2, ] + 0.0722 * rgb[3, ]
  unname(ifelse(luminancia > 0.55, COR_AZUL_ESCURO, "#FFFFFF"))
}
