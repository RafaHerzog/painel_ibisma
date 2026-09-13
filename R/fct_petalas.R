# =============================================================================
#   GRÁFICO DE PÉTALAS DOS SEIS BLOCOS
#   Constrói o leque de pétalas em SVG a partir da implementação da v3,
#   mantendo os valores e a mediana do Brasil como referências no desenho.
# =============================================================================

# Definindo os ângulos do leque simétrico em que as seis pétalas são distribuídas
ANGULOS_PETALAS <- c(-65, -39, -13, 13, 39, 65)

# Definindo o centro e o raio máximo do leque no sistema do viewBox
PETALAS_CX <- 250
PETALAS_CY <- 275
PETALAS_RAIO <- 185

# Definindo a área visível do desenho, cortando as sobras de topo e laterais
PETALAS_VIEWBOX <- "45 60 410 236"

#' Calculando a distância de um ponto ao longo da guia da pétala
#'
#' @param percentual Valor de 0 a 100 que define a posição na guia.
#' @return Distância em unidades do viewBox a partir do centro do leque.
#' @noRd
distancia_petala <- function(percentual) {
  # Reservando um trecho inicial da guia para afastar o desenho do centro
  30 + (percentual / 100) * (PETALAS_RAIO - 30)
}

#' Montando o conteúdo HTML do tooltip de uma pétala
#'
#' @param nome Nome do bloco.
#' @param valor Valor do bloco na escala 0 a 100.
#' @param categoria Categoria de vulnerabilidade do bloco.
#' @param pos_nac Posição do município no ranking nacional.
#' @param total_nac Total de municípios ranqueados.
#' @param medida Identificador do bloco que define a cor da dimensão.
#' @return Texto HTML pronto para o tooltip do Bootstrap.
#' @noRd
tooltip_petala <- function(nome, valor, categoria, pos_nac, total_nac, medida) {
  # Montando o cartão com nome, valor, ranking e selo de categoria
  # O marcador ao lado do nome e o selo usam a rampa de cor da dimensão
  paste0(
    '<div class="tooltip-petala" style="--cor-medida:', cor_medida(medida), ';">',
    '<div class="tooltip-petala__titulo">',
    '<span class="tooltip-petala__marca"></span>', nome,
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Valor</span>',
    '<span class="tooltip-petala__valor">', formatar_numero(valor), "</span>",
    "</div>",
    '<div class="tooltip-petala__linha">',
    '<span class="tooltip-petala__rotulo">Ranking</span>',
    '<span class="tooltip-petala__valor">',
    rotulo_posicao(pos_nac, total_nac),
    "</span></div>",
    badge_categoria(categoria, cor = cor_categoria(categoria, medida)),
    "</div>"
  )
}

#' Montando uma pétala individual do gráfico
#'
#' @param i Índice do bloco.
#' @param blocos Data frame com nome, valor, categoria, cor e ranking dos blocos.
#' @param mediana Mediana do Brasil do bloco (opcional).
#' @return Elemento HTML com o grupo SVG da pétala.
#' @noRd
petala_svg <- function(i, blocos, mediana = NULL) {
  # Extraindo os dados e calculando os fatores de escala da pétala
  nome <- as.character(blocos$nome[i])
  valor <- blocos$valor[i]
  if (is.na(valor)) valor <- 0
  cor <- blocos$cor[i]
  angulo <- ANGULOS_PETALAS[i]
  escala_comp <- 0.22 + (valor / 100) * 0.78
  escala_larg <- 0.65 + (valor / 100) * 0.35

  # Convertendo o ângulo do leque em radianos para posicionar os elementos
  rad <- (angulo - 90) * (pi / 180)
  fim_x <- round(PETALAS_CX + PETALAS_RAIO * cos(rad), 1)
  fim_y <- round(PETALAS_CY + PETALAS_RAIO * sin(rad), 1)
  marca <- distancia_petala(valor)
  marca_x <- round(PETALAS_CX + marca * cos(rad), 1)
  marca_y <- round(PETALAS_CY + marca * sin(rad), 1)

  # Desenhando os três pontos de referência de 25%, 50% e 75% na guia
  ticks <- lapply(c(25, 50, 75), function(pct) {
    dist <- distancia_petala(pct)
    htmltools::tags$circle(
      cx = round(PETALAS_CX + dist * cos(rad), 1),
      cy = round(PETALAS_CY + dist * sin(rad), 1),
      r = 1.8,
      fill = "#C4C9D2",
      opacity = 0.8
    )
  })

  # Desenhando o ponto da mediana do Brasil quando ela for informada
  mediana_ponto <- NULL
  if (!is.null(mediana) && !is.na(mediana)) {
    dist_mediana <- distancia_petala(mediana)
    mediana_ponto <- htmltools::tags$circle(
      cx = round(PETALAS_CX + dist_mediana * cos(rad), 1),
      cy = round(PETALAS_CY + dist_mediana * sin(rad), 1),
      r = 3.6,
      fill = "#0A1E3C",
      stroke = "#FFFFFF",
      `stroke-width` = 1.5,
      class = "ponto-mediana"
    )
  }

  # Montando o grupo com guia, pétala, valor, mediana e tooltip
  htmltools::tags$g(
    class = "grupo-petala",
    `data-bs-toggle` = "tooltip",
    `data-bs-placement` = "top",
    tabindex = "0",
    title = tooltip_petala(
      nome, blocos$valor[i], blocos$categoria[i],
      blocos$pos_nac[i], blocos$total_nac[i], blocos$medida[i]
    ),
    # Linha guia pontilhada que sustenta a escala da pétala
    htmltools::tags$line(
      x1 = PETALAS_CX,
      y1 = PETALAS_CY,
      x2 = fim_x,
      y2 = fim_y,
      stroke = "#E2E5EA",
      `stroke-width` = 1.5,
      `stroke-dasharray` = "2,3"
    ),
    ticks,
    mediana_ponto,
    # Forma da pétala rotacionada e escalada pelo valor do bloco
    htmltools::tags$path(
      d = "M 0 0 C -26 -40, -28 -120, 0 -170 C 28 -120, 26 -40, 0 0 Z",
      fill = cor,
      `fill-opacity` = 0.82,
      stroke = cor,
      `stroke-width` = 1.2,
      transform = sprintf(
        "translate(%s, %s) rotate(%s) scale(%s, %s)",
        PETALAS_CX, PETALAS_CY, angulo,
        round(escala_larg, 3), round(escala_comp, 3)
      ),
      class = "forma-petala"
    ),
    # Círculo com o valor em uma casa decimal no ápice da pétala
    htmltools::tags$circle(
      cx = marca_x,
      cy = marca_y,
      r = 16,
      fill = cor,
      stroke = "#FFFFFF",
      `stroke-width` = 2,
      class = "circulo-nota"
    ),
    htmltools::tags$text(
      x = marca_x,
      y = marca_y + 3.4,
      `text-anchor` = "middle",
      fill = cor_texto_sobre(cor),
      `font-size` = "9.5px",
      `font-weight` = "700",
      `font-family` = "Source Sans Pro, system-ui, sans-serif",
      formatar_numero(valor)
    )
  )
}

#' Montando o gráfico de pétalas dos seis blocos do IBISMA
#'
#' @param blocos Data frame com nome, valor, categoria, cor e ranking dos blocos.
#' @param medianas Vetor com a mediana do Brasil por bloco (opcional).
#' @return Elemento HTML com o leque de pétalas e as legendas de apoio.
#' @noRd
grafico_petalas <- function(blocos, medianas = NULL) {
  # Garantindo que os nomes cheguem como texto
  blocos$nome <- as.character(blocos$nome)
  # Descobrindo a medida de cada pétala quando ela não vier pronta
  if (is.null(blocos$medida)) {
    blocos$medida <- MEDIDAS$medida[match(blocos$nome, MEDIDAS$nome)]
  }
  # Preenchendo a cor de identificação a partir da medida quando necessário
  if (is.null(blocos$cor)) {
    blocos$cor <- cor_medida(blocos$medida)
  }

  # Montando cada pétala na ordem dos seis blocos do painel
  petalas <- lapply(seq_len(nrow(blocos)), function(i) {
    mediana <- if (!is.null(medianas)) {
      unname(medianas[as.character(blocos$nome[i])])
    } else {
      NULL
    }
    petala_svg(i, blocos, mediana)
  })

  # Montando o disco central que sustenta o leque
  centro <- htmltools::tags$circle(
    cx = PETALAS_CX,
    cy = PETALAS_CY,
    r = 8,
    fill = "#0A1E3C",
    stroke = "#FFFFFF",
    `stroke-width` = 2
  )

  # Nomeando cada bloco na legenda para identificar as pétalas sem hover
  itens_legenda <- lapply(seq_len(nrow(blocos)), function(i) {
    htmltools::tags$span(
      class = "petalas-legenda__item",
      htmltools::tags$span(
        class = "petalas-legenda__cor",
        style = paste0("background:", blocos$cor[i], ";")
      ),
      as.character(blocos$nome[i])
    )
  })

  # Montando o contêiner final com o SVG responsivo
  htmltools::tags$div(
    class = "petalas",
    htmltools::tags$svg(
      viewBox = PETALAS_VIEWBOX,
      class = "svg-petalas",
      xmlns = "http://www.w3.org/2000/svg",
      `role` = "img",
      `aria-label` = "Leque com os seis blocos do IBISMA",
      centro,
      petalas
    ),
    htmltools::tags$div(class = "petalas-legenda", itens_legenda)
  )
}
