# =============================================================================
#   FUNÇÕES AUXILIARES DE GRÁFICOS
#   Monta os gráficos do painel com echarts4r (licença Apache 2.0), entre eles
#   a evolução temporal do IBISMA e dos seis blocos. O leque de pétalas fica
#   em fct_petalas.R, em SVG.
# =============================================================================

# Definindo a família de fontes usada em todos os gráficos
FONTE_GRAFICOS <- "'Source Sans Pro', system-ui, -apple-system, sans-serif"

# Definindo o estilo compartilhado dos tooltips do echarts
CSS_TOOLTIP <- paste0(
  "border-radius:10px;",
  "box-shadow:0 6px 20px rgba(10,30,60,.14);",
  "padding:10px 12px;"
)

#' Aplicando o estilo base do IBISMA a um gráfico echarts4r
#'
#' @param grafico Objeto echarts4r.
#' @param legendar Exibir a legenda nativa.
#' @param selecao Lista com as séries visíveis na legenda (opcional).
#' @param topo Posição vertical da legenda no gráfico.
#' @return Objeto echarts4r com o estilo aplicado.
#' @noRd
estilo_echarts <- function(grafico, legendar = TRUE, selecao = NULL, topo = 0) {
  # Montando as opções da legenda nativa do echarts
  opcoes_legenda <- list(
    show = legendar,
    top = topo,
    left = "center",
    itemWidth = 16,
    itemHeight = 9,
    # Dando um respiro maior entre os itens da legenda
    itemGap = 16,
    textStyle = list(color = COR_AZUL_ESCURO, fontSize = 12),
    inactiveColor = "#B9C0CB"
  )
  # Reaplicando a seleção do usuário para ela sobreviver a re-renderizações
  if (!is.null(selecao)) {
    opcoes_legenda$selected <- selecao
  }

  grafico <- grafico |>
    echarts4r::e_text_style(
      fontFamily = "Source Sans Pro, system-ui, sans-serif",
      color = COR_AZUL_ESCURO
    )
  do.call(echarts4r::e_legend, c(list(grafico), opcoes_legenda))
}

#' Aplicando o tooltip padrão do IBISMA a um gráfico echarts4r
#'
#' @param grafico Objeto echarts4r.
#' @param trigger Modo de acionamento do tooltip ("item" ou "axis").
#' @param formatter Função JavaScript com o conteúdo do tooltip (opcional).
#' @param extras Lista com opções adicionais do tooltip (opcional).
#' @return Objeto echarts4r com o tooltip configurado.
#' @noRd
tooltip_echarts <- function(grafico, trigger = "item", formatter = NULL, extras = list()) {
  # Reunindo o estilo padrão com as opções específicas de cada gráfico
  opcoes <- c(
    list(
      trigger = trigger,
      backgroundColor = "#FFFFFF",
      borderColor = "#E3E6EB",
      borderWidth = 1,
      textStyle = list(
        color = COR_AZUL_ESCURO,
        fontFamily = "Source Sans Pro",
        fontSize = 12
      ),
      extraCssText = CSS_TOOLTIP,
      confine = TRUE
    ),
    extras
  )
  if (!is.null(formatter)) {
    opcoes$formatter <- htmlwidgets::JS(formatter)
  }
  do.call(echarts4r::e_tooltip, c(list(grafico), opcoes))
}

#' Montando o gráfico de evolução temporal de um município
#'
#' @param series Data frame retornado por series_municipio().
#' @param nome Nome do município exibido no tooltip (opcional).
#' @param legenda Exibir a legenda nativa do echarts no topo (opcional).
#' @param grupo Nome do grupo que sincroniza a legenda entre dois gráficos.
#' @param selecao Lista com as séries visíveis na legenda (opcional).
#' @return Objeto echarts4r pronto para renderização.
#' @noRd
grafico_evolucao <- function(series, nome = NULL, legenda = TRUE, grupo = NULL,
                             selecao = NULL) {
  # Criando o gráfico e acrescentando uma linha para cada uma das sete medidas
  grafico <- echarts4r::e_charts(series, ano)
  for (i in seq_len(nrow(MEDIDAS))) {
    medida <- MEDIDAS$medida[i]
    # Destacando o IBISMA com a linha mais espessa do gráfico
    largura <- if (identical(medida, "indice_final")) 3 else 2
    grafico <- grafico |>
      echarts4r::e_line_(
        serie = medida,
        name = MEDIDAS$nome[i],
        symbol = "circle",
        symbolSize = 6,
        connectNulls = FALSE,
        # Apagando as demais linhas ao passar o mouse para facilitar a leitura
        emphasis = list(focus = "series"),
        lineStyle = list(width = largura, color = MEDIDAS$cor[i]),
        itemStyle = list(
          color = MEDIDAS$cor[i],
          borderColor = "#FFFFFF",
          borderWidth = 1.2
        )
      )
  }

  # Finalizando eixos, tooltip e estilo geral do gráfico
  grafico <- grafico |>
    echarts4r::e_x_axis(
      type = "value",
      min = min(series$ano),
      max = max(series$ano),
      interval = 1,
      # Formando os anos como inteiros, sem o separador de milhar do echarts
      formatter = htmlwidgets::JS(
        "function (valor) { return String(Math.round(valor)); }"
      ),
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(lineStyle = list(color = "#E3E6EB")),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ) |>
    echarts4r::e_y_axis(
      min = 0,
      max = 100,
      name = NULL,
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(lineStyle = list(color = "#EEF0F4"))
    ) |>
    tooltip_echarts(
      trigger = "axis",
      formatter = tooltip_series_js(nome),
      extras = list(
        axisPointer = list(type = "line", lineStyle = list(color = "#C7CCD4"))
      )
    ) |>
    estilo_echarts(legendar = legenda, selecao = selecao) |>
    echarts4r::e_grid(left = 40, right = 16, top = 16, bottom = 28) |>
    echarts4r::e_animation(duration = 350)

  # Colocando os gráficos no mesmo grupo para a legenda valer para os dois
  if (!is.null(grupo)) {
    grafico <- grafico |>
      echarts4r::e_group(grupo) |>
      echarts4r::e_connect_group(grupo)
  }
  grafico
}

#' Montando um gráfico com apenas a legenda nativa das sete séries
#'
#' @param grupo Nome do grupo que sincroniza a legenda com os gráficos.
#' @return Objeto echarts4r com a legenda centralizada e sem eixos visíveis.
#' @noRd
grafico_legenda <- function(grupo = NULL) {
  # Criando uma linha vazia por medida apenas para a legenda existir
  vazio <- data.frame(ano = 2015)
  for (medida in MEDIDAS$medida) {
    vazio[[medida]] <- NA_real_
  }

  # Montando as sete séries invisíveis que dão nome e cor a cada item
  grafico <- echarts4r::e_charts(vazio, ano)
  for (i in seq_len(nrow(MEDIDAS))) {
    largura <- if (identical(MEDIDAS$medida[i], "indice_final")) 3 else 2
    grafico <- grafico |>
      echarts4r::e_line_(
        serie = MEDIDAS$medida[i],
        name = MEDIDAS$nome[i],
        symbol = "circle",
        symbolSize = 6,
        lineStyle = list(width = largura, color = MEDIDAS$cor[i]),
        itemStyle = list(color = MEDIDAS$cor[i])
      )
  }

  # Escondendo eixos e grade para sobrar apenas a legenda centralizada
  grafico <- grafico |>
    echarts4r::e_x_axis(show = FALSE) |>
    echarts4r::e_y_axis(show = FALSE) |>
    echarts4r::e_grid(left = 0, right = 0, top = 0, bottom = 0) |>
    estilo_echarts(legendar = TRUE, topo = "middle") |>
    echarts4r::e_animation(show = FALSE)

  # Entrando no mesmo grupo para os cliques valerem nos dois gráficos
  if (!is.null(grupo)) {
    grafico <- grafico |>
      echarts4r::e_group(grupo) |>
      echarts4r::e_connect_group(grupo)
  }
  grafico
}

#' Montando o JavaScript do tooltip das séries temporais
#'
#' @param nome Nome do município exibido no topo do tooltip (opcional).
#' @return Texto de função JavaScript para o echarts.
#' @noRd
tooltip_series_js <- function(nome = NULL) {
  # Montando o título com a localidade e escapando aspas para o JavaScript
  titulo <- if (is.null(nome)) "" else paste0(nome, " \u2014 ")
  titulo_js <- encodeString(titulo, quote = "'")

  paste0(
    "function (params) {
       if (!params || !params.length) return '';
       var f = function (v) { return Number(v).toFixed(1).replace('.', ','); };
       var ano = String(Math.round(params[0].axisValue));
       var s = '<b>' + ", titulo_js, " + ano + '</b>';
       params.forEach(function (p) {
         var v = p.value;
         if (Array.isArray(v)) { v = v[v.length - 1]; }
         if (v === null || v === undefined || isNaN(v)) return;
         s += '<br/>' + p.marker + ' ' + p.seriesName + ': <b>' + f(v) + '</b>';
       });
       return s;
     }"
  )
}
