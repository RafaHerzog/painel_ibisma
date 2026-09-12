# =============================================================================
#   FUNÇÕES AUXILIARES DE GRÁFICOS
#   Monta os gráficos do painel com echarts4r (licença Apache 2.0):
#   evolução temporal, flor dos blocos e diferenças entre municípios.
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
#' @param legendar Exibir a legenda na parte superior.
#' @return Objeto echarts4r com o estilo aplicado.
#' @noRd
estilo_echarts <- function(grafico, legendar = TRUE) {
  grafico |>
    echarts4r::e_text_style(
      fontFamily = "Source Sans Pro, system-ui, sans-serif",
      color = COR_AZUL_ESCURO
    ) |>
    echarts4r::e_legend(
      show = legendar,
      top = 0,
      left = 0,
      icon = "roundRect",
      itemWidth = 14,
      itemHeight = 8,
      textStyle = list(color = COR_AZUL_ESCURO, fontSize = 12),
      inactiveColor = "#B9C0CB"
    )
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

#' Montando o gráfico de evolução temporal de uma medida
#'
#' @param series Data frame retornado por comparar_series().
#' @param nome_a Nome do município principal.
#' @param nome_b Nome do município de comparação (opcional).
#' @param cor Cor da série principal.
#' @param ano_destaque Ano a marcar com uma linha vertical (opcional).
#' @param descricao Texto de acessibilidade do gráfico.
#' @return Objeto echarts4r pronto para renderização.
#' @noRd
grafico_evolucao <- function(series, nome_a, nome_b = NULL, cor = COR_IBISMA,
                             ano_destaque = NULL, descricao = NULL) {
  # Formatando os valores anuais para uso no tooltip em JavaScript
  tooltip <- eh_tooltip_series(series)

  # Criando o gráfico com a série do município principal
  grafico <- series |>
    echarts4r::e_charts(ano) |>
    echarts4r::e_line(
      serie = valor_a,
      name = nome_a,
      smooth = TRUE,
      symbol = "circle",
      symbolSize = 7,
      connectNulls = FALSE,
      lineStyle = list(width = 3),
      itemStyle = list(color = cor, borderColor = "#FFFFFF", borderWidth = 1.5)
    )

  # Acrescentando a série do município comparado, quando houver
  if (!is.null(nome_b) && "valor_b" %in% names(series)) {
    grafico <- grafico |>
      echarts4r::e_line(
        serie = valor_b,
        name = nome_b,
        smooth = TRUE,
        symbol = "circle",
        symbolSize = 7,
        connectNulls = FALSE,
        lineStyle = list(width = 2, type = "dashed"),
        itemStyle = list(color = COR_AZUL_ESCURO, borderColor = "#FFFFFF", borderWidth = 1.5)
      )
  }

  # Marcando o ano selecionado no perfil com uma linha discreta
  if (!is.null(ano_destaque)) {
    grafico <- grafico |>
      echarts4r::e_mark_line(
        data = list(xAxis = as.numeric(ano_destaque)),
        symbol = "none",
        silent = TRUE,
        lineStyle = list(color = "#C7CCD4", type = "dotted", width = 1),
        label = list(show = FALSE)
      )
  }

  # Finalizando eixos, tooltip e estilo geral do gráfico
  grafico |>
    echarts4r::e_x_axis(
      type = "value",
      min = min(series$ano),
      max = max(series$ano),
      interval = 1,
      name = NULL,
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
      formatter = tooltip,
      extras = list(
        axisPointer = list(type = "line", lineStyle = list(color = "#C7CCD4"))
      )
    ) |>
    estilo_echarts(legendar = !is.null(nome_b)) |>
    echarts4r::e_grid(left = 40, right = 20, top = if (is.null(nome_b)) 20 else 40, bottom = 30) |>
    echarts4r::e_animation(duration = 350)
}

#' Montando o JavaScript do tooltip das séries temporais
#'
#' @param series Data frame retornado por comparar_series().
#' @return Texto de função JavaScript para o echarts.
#' @noRd
eh_tooltip_series <- function(series) {
  # Montando uma tabela de valores numéricos por ano para o tooltip
  linhas <- lapply(seq_len(nrow(series)), function(i) {
    list(
      a = if (is.na(series$valor_a[i])) NULL else unname(series$valor_a[i]),
      b = if (is.null(series$valor_b) || is.na(series$valor_b[i])) NULL else unname(series$valor_b[i])
    )
  })
  names(linhas) <- as.character(series$ano)

  paste0(
    "function (params) {
       var dados = ", jsonlite::toJSON(linhas, auto_unbox = TRUE, null = "null"), ";
       if (!params || !params.length) return '';
       var ano = String(params[0].axisValue);
       var d = dados[ano] || {};
       var f = function (v) { return Number(v).toFixed(1).replace('.', ','); };
       var s = '<b>' + ano + '</b>';
       params.forEach(function (p) {
         var valor = (p.seriesIndex === 0) ? d.a : d.b;
         if (valor === null || valor === undefined) return;
         s += '<br/>' + p.marker + ' ' + p.seriesName + ': <b>' + f(valor) + '</b>';
       });
       if (d.a !== null && d.a !== undefined && d.b !== null && d.b !== undefined) {
         var diferenca = d.b - d.a;
         s += '<br/><span style=\"color:#5A6472\">Diferen\\u00e7a: </span><b>' +
              (diferenca > 0 ? '+' : '') + f(diferenca) + '</b>';
       }
       return s;
     }"
  )
}

#' Formatando o JavaScript do tooltip do gráfico de diferenças
#'
#' @param comparacao Data frame retornado por comparar_ano().
#' @param nome_a Nome do município principal.
#' @param nome_b Nome do município de comparação.
#' @return Texto de função JavaScript para o echarts.
#' @noRd
eh_tooltip_diferencas <- function(comparacao, nome_a, nome_b) {
  # Montando uma tabela de apoio com os valores de cada medida
  info <- stats::setNames(
    lapply(seq_len(nrow(comparacao)), function(i) {
      list(
        a = formatar_numero(comparacao$valor_a[i]),
        b = formatar_numero(comparacao$valor_b[i]),
        d = formatar_numero(comparacao$delta[i])
      )
    }),
    comparacao$nome
  )

  paste0(
    "function (p) {
       var info = ", jsonlite::toJSON(info, auto_unbox = TRUE), ";
       var d = info[p.name] || {};
       var sinal = (p.value > 0) ? '+' : '';
       return '<b>' + p.name + '</b>' +
              '<br/>", nome_a, ": <b>' + d.a + '</b>' +
              '<br/>", nome_b, ": <b>' + d.b + '</b>' +
              '<br/>Diferen\\u00e7a: <b>' + sinal + d.d + '</b>';
     }"
  )
}

#' Montando o gráfico de diferenças entre dois municípios
#'
#' @param comparacao Data frame retornado por comparar_ano().
#' @param nome_a Nome do município principal.
#' @param nome_b Nome do município de comparação.
#' @return Objeto echarts4r pronto para renderização.
#' @noRd
grafico_diferencas <- function(comparacao, nome_a, nome_b) {
  # Definindo a cor de cada barra conforme a direção da diferença
  comparacao$color <- ifelse(comparacao$delta >= 0, COR_CORAL, COR_VERDE)

  # Criando um gráfico de barras horizontal centrado no zero
  comparacao |>
    echarts4r::e_charts(nome, reorder = FALSE) |>
    echarts4r::e_bar(
      serie = delta,
      name = "Diferen\u00e7a",
      barWidth = "55%",
      itemStyle = list(borderRadius = 4)
    ) |>
    echarts4r::e_add_nested("itemStyle", color) |>
    echarts4r::e_flip_coords() |>
    echarts4r::e_labels(
      show = TRUE,
      position = "right",
      distance = 6,
      formatter = htmlwidgets::JS(
        "function (p) {
           var v = p.value;
           if (v === null || v === undefined || isNaN(v)) return '';
           return (v > 0 ? '+' : '') + Number(v).toFixed(1).replace('.', ',');
         }"
      ),
      color = COR_AZUL_ESCURO,
      fontSize = 11,
      fontWeight = "bold"
    ) |>
    echarts4r::e_x_axis(
      min = -100,
      max = 100,
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(lineStyle = list(color = "#EEF0F4"))
    ) |>
    echarts4r::e_y_axis(
      type = "category",
      axisLabel = list(color = COR_AZUL_ESCURO, fontSize = 11),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE)
    ) |>
    tooltip_echarts(
      trigger = "item",
      formatter = eh_tooltip_diferencas(comparacao, nome_a, nome_b)
    ) |>
    estilo_echarts(legendar = FALSE) |>
    echarts4r::e_grid(left = 150, right = 50, top = 10, bottom = 30)
}

#' Montando a flor dos seis blocos do IBISMA
#'
#' @param blocos Data frame com nome, valor, categoria, cor e posição de cada bloco.
#' @param medianas Vetor com a mediana do Brasil por bloco (opcional).
#' @return Objeto echarts4r pronto para renderização.
#' @noRd
grafico_flor <- function(blocos, medianas = NULL) {
  # Mantendo os nomes como texto para que o echarts receba os rótulos corretos
  blocos$nome <- as.character(blocos$nome)

  # Acrescentando a mediana de referência quando ela for informada
  if (!is.null(medianas)) {
    blocos$mediana <- unname(medianas[as.character(blocos$nome)])
  }

  # Montando a tabela de apoio usada pelo tooltip em JavaScript
  info <- stats::setNames(
    lapply(seq_len(nrow(blocos)), function(i) {
      list(
        valor = formatar_numero(blocos$valor[i]),
        categoria = as.character(blocos$categoria[i]),
        posicao = rotulo_posicao(blocos$pos_nac[i], blocos$total_nac[i])
      )
    }),
    as.character(blocos$nome)
  )

  # Criando o gráfico polar com uma pétala por bloco
  flor <- blocos |>
    echarts4r::e_charts(nome, reorder = FALSE) |>
    echarts4r::e_polar() |>
    echarts4r::e_angle_axis(
      serie = nome,
      startAngle = 90,
      axisLabel = list(
        color = COR_AZUL_ESCURO,
        fontSize = 11,
        fontFamily = "Source Sans Pro"
      ),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ) |>
    echarts4r::e_radius_axis(
      min = 0,
      max = 100,
      axisLabel = list(show = FALSE),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(show = FALSE)
    ) |>
    echarts4r::e_bar(
      serie = valor,
      name = "Valor",
      legend = FALSE,
      coord_system = "polar",
      barWidth = "60%",
      colorBy = "data",
      itemStyle = list(borderRadius = 4),
      label = list(show = FALSE)
    ) |>
    echarts4r::e_color(blocos$cor) |>
    echarts4r::e_legend(
      show = !is.null(medianas),
      top = 0,
      left = "center",
      icon = "circle",
      itemWidth = 8,
      itemHeight = 8,
      textStyle = list(color = COR_AZUL_ESCURO, fontSize = 11),
      data = list("Mediana Brasil")
    ) |>
    tooltip_echarts(
      trigger = "item",
      formatter = paste0(
        "function (p) {
           var info = ", jsonlite::toJSON(info, auto_unbox = TRUE), ";
           var d = info[p.name];
           if (!d) return p.name;
           return '<b>' + p.name + '</b><br/>' +
                  'Valor: <b>' + d.valor + '</b><br/>' +
                  'Categoria: ' + d.categoria + '<br/>' +
                  'Ranking nacional: ' + d.posicao;
         }"
      )
    )

  # Sobrepondo os pontos com a mediana do Brasil em cada bloco
  if (!is.null(medianas)) {
    flor <- flor |>
      echarts4r::e_scatter(
        serie = mediana,
        name = "Mediana Brasil",
        coord_system = "polar",
        symbolSize = 7,
        silent = TRUE,
        tooltip = list(show = FALSE),
        itemStyle = list(
          color = COR_AZUL_ESCURO,
          borderColor = "#FFFFFF",
          borderWidth = 1.5
        )
      )
  }
  flor
}

#' Montando um gráfico vazio com uma mensagem central
#'
#' @param mensagem Texto exibido no centro do gráfico.
#' @return Objeto echarts4r vazio com a mensagem.
#' @noRd
grafico_vazio <- function(mensagem) {
  # Garantindo um texto padrão para que o gráfico nunca fique sem título
  if (!nzchar(mensagem)) {
    mensagem <- "Sem dados para exibir."
  }

  # Criando um gráfico sem eixos apenas com a mensagem ao centro
  echarts4r::e_charts() |>
    echarts4r::e_animation(show = FALSE) |>
    echarts4r::e_title(
      text = mensagem,
      left = "center",
      top = "middle",
      textStyle = list(
        color = "#5A6472",
        fontWeight = "normal",
        fontSize = 13,
        fontFamily = "Source Sans Pro"
      )
    )
}
