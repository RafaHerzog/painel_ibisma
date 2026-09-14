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

# Definindo as alturas dos gráficos de evolução do índice e dos blocos
ALTURA_GRAFICO_IBISMA <- 270L
ALTURA_GRAFICO_BLOCO <- 160L

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

#' Calculando o piso do eixo Y de um conjunto de séries
#'
#' @param series Data frame retornado por series_municipio().
#' @param medidas Medidas consideradas no cálculo (o índice ou os seis blocos).
#' @return Piso em dezena para o eixo começar perto dos dados (0 a 90).
#' @noRd
piso_eixo_y <- function(series, medidas = MEDIDAS$medida) {
  # Reunindo os valores das medidas pedidas em um único vetor
  colunas <- intersect(medidas, names(series))
  valores <- unlist(series[, colunas, drop = FALSE], use.names = FALSE)
  if (all(is.na(valores))) {
    return(0)
  }

  # Arredondando o menor valor para baixo na dezena e evitando eixo degenerado
  piso <- floor(min(valores, na.rm = TRUE) / 10) * 10
  max(0, min(piso, 90))
}

#' Calculando o teto do eixo Y de um conjunto de séries
#'
#' @param series Data frame retornado por series_municipio().
#' @param medidas Medidas consideradas no cálculo (o índice ou os seis blocos).
#' @return Teto em dezena para o eixo terminar perto dos dados (10 a 100).
#' @noRd
teto_eixo_y <- function(series, medidas = MEDIDAS$medida) {
  # Reunindo os valores das medidas pedidas em um único vetor
  colunas <- intersect(medidas, names(series))
  valores <- unlist(series[, colunas, drop = FALSE], use.names = FALSE)
  if (all(is.na(valores))) {
    return(100)
  }

  # Arredondando o maior valor para cima na dezena e respeitando o limite do índice
  teto <- ceiling(max(valores, na.rm = TRUE) / 10) * 10
  min(100, max(10, teto))
}

#' Obtendo o último valor válido de uma série
#'
#' @param valores Vetor numérico de uma série.
#' @return Último valor não ausente ou NA quando não houver nenhum.
#' @noRd
ultimo_valor <- function(valores) {
  validos <- valores[!is.na(valores)]
  if (length(validos) == 0) {
    return(NA_real_)
  }
  validos[length(validos)]
}

#' Decidindo em que lado do último ponto cada nome de localidade é desenhado
#'
#' Os rótulos ficam acima do fim das linhas, exceto quando a série termina
#' perto do topo do gráfico. Com comparação ativa, os dois nomes nunca dividem
#' o mesmo espaço: eles vão para lados opostos ou recebem afastamentos
#' diferentes quando não há espaço livre de um dos lados.
#'
#' @param dados Data frame com as colunas principal e comparacao (opcional).
#' @param minimo_y Piso do eixo Y.
#' @param maximo_y Teto do eixo Y.
#' @return Lista com lado e afastamento vertical do rótulo de cada série.
#' @noRd
lados_rotulos <- function(dados, minimo_y, maximo_y) {
  # Calculando a posição relativa do fim de cada série dentro do eixo
  faixa <- maximo_y - minimo_y
  posicao <- function(valores) {
    valor <- ultimo_valor(valores)
    if (is.na(valor) || faixa <= 0) {
      return(0.5)
    }
    (valor - minimo_y) / faixa
  }

  # Guardando o afastamento padrão do rótulo em relação ao último ponto
  afastamento <- 12
  # Guardando um afastamento maior para dois nomes que dividem o mesmo lado
  afastamento_longo <- 30
  # Existe espaço seguro acima até 80% da faixa; abaixo, a partir de 20%
  cabe_acima <- function(fracao) fracao <= 0.8
  cabe_abaixo <- function(fracao) fracao >= 0.2
  # Montando o rótulo com um lado e um afastamento opcional
  rotulo <- function(lado, distancia = afastamento) {
    list(lado = lado, afastamento = distancia)
  }

  # Resolvendo o caso sem comparação, em que existe apenas um rótulo
  fracao_principal <- posicao(dados$principal)
  if (is.null(dados$comparacao)) {
    return(list(principal = rotulo(
      if (cabe_acima(fracao_principal)) "acima" else "abaixo"
    )))
  }

  # Mantendo o lado natural quando os dois fins estão bem separados no eixo
  fracao_comparacao <- posicao(dados$comparacao)
  if (abs(fracao_principal - fracao_comparacao) > 0.15) {
    lado_natural <- function(fracao) if (cabe_acima(fracao)) "acima" else "abaixo"
    return(list(
      principal = rotulo(lado_natural(fracao_principal)),
      comparacao = rotulo(lado_natural(fracao_comparacao))
    ))
  }

  # Resolvendo os fins próximos, em que os dois nomes precisam de espaço
  principal_maior <- fracao_principal >= fracao_comparacao
  fracao_maior <- max(fracao_principal, fracao_comparacao)
  fracao_menor <- min(fracao_principal, fracao_comparacao)

  # Perto do topo, descendo os dois nomes com afastamentos diferentes
  if (!cabe_acima(fracao_maior)) {
    rotulos <- list(
      maior = rotulo("abaixo"),
      menor = rotulo("abaixo", afastamento_longo)
    )
  } else if (cabe_abaixo(fracao_menor)) {
    # Com espaço abaixo, o menor valor desce e o maior fica acima
    rotulos <- list(maior = rotulo("acima"), menor = rotulo("abaixo"))
  } else {
    # Colado no piso, o menor valor sobe mais para não encostar no maior
    rotulos <- list(
      maior = rotulo("acima"),
      menor = rotulo("acima", afastamento_longo)
    )
  }
  list(
    principal = if (principal_maior) rotulos$maior else rotulos$menor,
    comparacao = if (principal_maior) rotulos$menor else rotulos$maior
  )
}

#' Montando as opções do rótulo exibido no fim de uma linha
#'
#' @param rotulo Lado e afastamento calculados por lados_rotulos().
#' @param cor Cor do texto, igual à cor da série.
#' @param opacidade Opacidade do texto (menor na série comparada).
#' @return Lista com as opções do endLabel do echarts.
#' @noRd
opcoes_rotulo_serie <- function(rotulo, cor, opacidade = 1) {
  acima <- identical(rotulo$lado, "acima")
  list(
    show = TRUE,
    # Usando o próprio nome da série como texto do rótulo
    formatter = "{a}",
    color = cor,
    opacity = opacidade,
    fontSize = 11,
    fontWeight = 600,
    # Ancorando o texto à direita do ponto para ele não sair pela borda
    align = "right",
    verticalAlign = if (acima) "bottom" else "top",
    offset = c(0, if (acima) -rotulo$afastamento else rotulo$afastamento),
    # Criando um halo branco para o nome ficar legível sobre a linha
    textBorderColor = "#FFFFFF",
    textBorderWidth = 4
  )
}

#' Montando o gráfico de evolução temporal de uma medida
#'
#' @param series Data frame retornado por series_municipio().
#' @param medida Medida desenhada ("indice_final" ou um "bloco1"..."bloco6").
#' @param nome Nome da localidade principal exibido no rótulo e no tooltip.
#' @param comparacao Data frame do município comparado (opcional).
#' @param nome_comparacao Nome do município comparado (opcional).
#' @param minimo_y Piso do eixo Y; quando NULL, calculado das próprias séries.
#' @param maximo_y Teto do eixo Y; quando NULL, calculado das próprias séries.
#' @return Objeto echarts4r pronto para renderização.
#' @noRd
grafico_evolucao <- function(series, medida, nome = NULL,
                             comparacao = NULL, nome_comparacao = NULL,
                             minimo_y = NULL, maximo_y = NULL) {
  # Identificando a cor e o destaque da medida desenhada
  cor <- cor_medida(medida)
  eh_indice <- identical(medida, "indice_final")

  # Calculando o piso do eixo quando o módulo não impõe um valor compartilhado
  if (is.null(minimo_y)) {
    minimo_y <- piso_eixo_y(series, medida)
  }
  # Calculando o teto do eixo quando o módulo não impõe um valor compartilhado
  if (is.null(maximo_y)) {
    maximo_y <- teto_eixo_y(series, medida)
  }
  # Evitando um eixo degenerado quando piso e teto caem na mesma dezena
  if (maximo_y <= minimo_y) {
    maximo_y <- min(100, minimo_y + 10)
  }

  # Montando a tabela do gráfico com uma coluna por localidade
  dados <- data.frame(ano = series$ano, principal = series[[medida]])
  if (!is.null(comparacao)) {
    dados$comparacao <- comparacao[[medida]]
  }

  # Descobrindo em que lado cada nome de localidade aparece no fim da linha
  lados <- lados_rotulos(dados, minimo_y, maximo_y)

  # Reservando ao IBISMA a linha mais espessa e o símbolo maior
  largura <- if (eh_indice) 3 else 2
  tamanho <- if (eh_indice) 6 else 4.5

  # Criando o gráfico e desenhando a série da localidade principal
  grafico <- echarts4r::e_charts(dados, ano, renderer = "svg") |>
    echarts4r::e_line_(
      serie = "principal",
      name = if (is.null(nome)) "Munic\u00edpio" else nome,
      symbol = "circle",
      symbolSize = tamanho,
      showSymbol = TRUE,
      z = 3,
      connectNulls = FALSE,
      # Sem foco de série no hover: a outra linha nunca é apagada
      lineStyle = list(width = largura, color = cor, type = "solid"),
      itemStyle = list(
        color = cor,
        borderColor = "#FFFFFF",
        borderWidth = 1.2
      ),
      endLabel = opcoes_rotulo_serie(lados$principal, cor)
    )

  # Acrescentando a linha pontilhada do município comparado, quando houver
  if (!is.null(dados$comparacao)) {
    grafico <- grafico |>
      echarts4r::e_line_(
        serie = "comparacao",
        name = if (is.null(nome_comparacao)) "Compara\u00e7\u00e3o" else nome_comparacao,
        symbol = "circle",
        symbolSize = tamanho - 1,
        showSymbol = TRUE,
        # Desenhando abaixo da linha principal, que fica em evidência
        z = 2,
        connectNulls = FALSE,
        # Mantendo a mesma cor, com traço pontilhado e opacidade menor
        lineStyle = list(
          width = largura,
          color = cor,
          type = "dotted",
          opacity = 0.55
        ),
        itemStyle = list(
          color = cor,
          borderColor = "#FFFFFF",
          borderWidth = 1,
          opacity = 0.55
        ),
        endLabel = opcoes_rotulo_serie(lados$comparacao, cor, opacidade = 0.75)
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
      min = minimo_y,
      max = maximo_y,
      name = NULL,
      axisLabel = list(color = "#5A6472", fontSize = 11),
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      splitLine = list(lineStyle = list(color = "#EEF0F4"))
    ) |>
    tooltip_echarts(
      trigger = "axis",
      formatter = tooltip_evolucao_js(),
      extras = list(
        axisPointer = list(type = "line", lineStyle = list(color = "#C7CCD4"))
      )
    ) |>
    echarts4r::e_text_style(
      fontFamily = FONTE_GRAFICOS,
      color = COR_AZUL_ESCURO
    ) |>
    # Desligando a legenda, já que o nome de cada localidade fica no fim da linha
    echarts4r::e_legend(show = FALSE) |>
    # Reservando só a coluna dos números do eixo Y, alinhada ao título do cartão
    echarts4r::e_grid(left = 28, right = 12, top = 16, bottom = 28) |>
    echarts4r::e_animation(duration = 350)

  grafico
}

#' Montando o JavaScript do tooltip da evolução temporal
#'
#' @return Texto de função JavaScript para o echarts.
#' @noRd
tooltip_evolucao_js <- function() {
  paste0(
    "function (params) {
       if (!params || !params.length) return '';
       var f = function (v) { return Number(v).toFixed(1).replace('.', ','); };
       /* Clareando a cor em direção ao branco, como a opacidade reduzida do traço */
       /* A cor fica opaca para o traço pontilhado não aparecer dentro da bolinha */
       var clarear = function (cor, alfa) {
         var hex = String(cor).replace('#', '');
         if (hex.length === 3) {
           hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
         }
         var n = parseInt(hex, 16);
         if (isNaN(n)) return cor;
         var misturar = function (canal) {
           return Math.round(canal * alfa + 255 * (1 - alfa));
         };
         return 'rgb(' + misturar((n >> 16) & 255) + ',' +
                misturar((n >> 8) & 255) + ',' + misturar(n & 255) + ')';
       };
       /* Montando a marca da série com a cor e o tipo de traço do gráfico */
       var marca = function (p) {
         var cor = typeof p.color === 'string' ? p.color : '#4B1D73';
         /* A comparação mantém a mesma cor com a opacidade reduzida do traço */
         var corMarca = p.seriesIndex === 0 ? cor : clarear(cor, 0.55);
         var traco = p.seriesIndex === 0
           ? 'background:' + corMarca
           : 'background-image:repeating-linear-gradient(90deg,' +
             corMarca + ' 0 2px,transparent 2px 5px)';
         return '<span style=\"position:relative;display:inline-block;width:18px;height:9px;margin-right:6px;vertical-align:middle;flex:0 0 auto\">' +
                '<span style=\"position:absolute;left:0;right:0;top:3px;height:3px;border-radius:2px;' + traco + '\"></span>' +
                '<span style=\"position:absolute;left:50%;top:1px;width:7px;height:7px;margin-left:-3.5px;border-radius:50%;background:' + corMarca + ';box-shadow:0 0 0 1.5px #FFFFFF\"></span>' +
                '</span>';
       };
       var ano = String(Math.round(params[0].axisValue));
       var s = '<b>' + ano + '</b>';
       params.forEach(function (p) {
         var v = p.value;
         if (Array.isArray(v)) { v = v[v.length - 1]; }
         if (v === null || v === undefined || isNaN(v)) return;
         s += '<div style=\"display:flex;align-items:center;justify-content:space-between;gap:1.5rem\">' +
              '<span>' + marca(p) + p.seriesName + '</span><b>' + f(v) + '</b></div>';
       });
       return s;
     }"
  )
}

#' Montando a grade de gráficos da evolução temporal
#'
#' @param ns Função de namespace do módulo.
#' @return Elemento HTML com o cartão do IBISMA e os seis cartões dos blocos.
#' @noRd
grade_evolucao_ui <- function(ns) {
  # Montando um cartão com o título e o gráfico de uma medida
  cartao <- function(medida, altura, classe = NULL) {
    htmltools::tags$div(
      class = paste(c("evolucao-card", classe), collapse = " "),
      htmltools::tags$h4(
        class = "evolucao-card__titulo",
        # Marcando o título com a bolinha na cor da dimensão do gráfico
        htmltools::tags$span(
          class = "evolucao-card__ponto",
          style = paste0("--cor-medida:", cor_medida(medida), ";")
        ),
        nome_medida(medida)
      ),
      echarts4r::echarts4rOutput(
        ns(paste0("grafico_", medida)),
        height = paste0(altura, "px")
      )
    )
  }

  htmltools::tags$div(
    class = "evolucao-grade",
    # Destacando o IBISMA em um cartão de largura total
    cartao("indice_final", ALTURA_GRAFICO_IBISMA, "evolucao-card--ibisma"),
    # Organizando os seis blocos em pequenos múltiplos
    htmltools::tags$h4(class = "evolucao-grade__titulo", "Blocos do IBISMA"),
    lapply(seq_len(nrow(BLOCOS)), function(i) {
      cartao(BLOCOS$medida[i], ALTURA_GRAFICO_BLOCO)
    })
  )
}
