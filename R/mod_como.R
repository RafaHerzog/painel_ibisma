# =============================================================================
#   MÓDULO COMO?
#   Permite explorar um município em detalhe: situação no ano escolhido,
#   flor dos seis blocos e evolução temporal do IBISMA e dos blocos.
#   Quando há comparação ativa, palcos e gráficos aparecem lado a lado.
# =============================================================================

#' Interface do módulo Como?
#'
#' @param id Identificador do módulo.
#' @return Elemento HTML da seção Como?.
#' @noRd
mod_como_ui <- function(id) {
  ns <- shiny::NS(id)

  # Montando as opções de municípios e de anos usadas nos controles
  municipios <- opcoes_municipios(dados_ibisma())
  anos_ordem <- rev(anos_disponiveis())
  anos <- stats::setNames(anos_ordem, anos_ordem)
  # Incluindo a opção de não comparar com nenhum município
  opcoes_comparacao <- c("Nenhum" = "nenhum", municipios)

  htmltools::tags$section(
    id = "como",
    class = "secao-painel secao-como",
    htmltools::tags$div(
      class = "painel-container",
      # Cabeçalho editorial da seção
      titulo_secao(
        eyebrow = "Como?",
        titulo = "Como a inseguran\u00e7a se apresenta no munic\u00edpio?",
        descricao = paste(
          "Escolha um munic\u00edpio para ver a situa\u00e7\u00e3o no ano selecionado",
          "e a evolu\u00e7\u00e3o ao longo do tempo, comparando com outro munic\u00edpio",
          "quando quiser."
        )
      ),
      # Controles principais escritos como uma frase
      frase_controles(
        htmltools::tags$span(class = "controle-texto", "Ver"),
        seletor_inline(ns("municipio"), municipios, selected = municipio_padrao(), largura = "320px"),
        htmltools::tags$span(class = "controle-texto", "em"),
        seletor_inline(ns("ano"), anos, selected = max(anos_disponiveis())),
        htmltools::tags$span(class = "controle-texto", "e comparar com"),
        seletor_inline(ns("comparar"), opcoes_comparacao, selected = "nenhum", largura = "320px")
      ),
      # Explicando as pétalas uma única vez, acima dos palcos
      htmltools::tags$p(class = "petalas-caption", TEXTO_PETALAS),
      # Palcos do município principal e do comparado, exibidos lado a lado
      htmltools::tags$div(
        class = "dupla dupla--palcos",
        id = ns("palcos"),
        htmltools::tags$div(
          class = "dupla__item dupla__item--principal",
          shiny::uiOutput(ns("palco_principal"))
        ),
        htmltools::tags$div(
          class = "dupla__item dupla__item--comparado",
          shiny::uiOutput(ns("palco_comparado"))
        )
      ),
      # Evolução temporal do IBISMA e dos seis blocos
      htmltools::tags$div(
        class = "painel-bloco painel-bloco--evolucao",
        htmltools::tags$div(
          class = "bloco-cabecalho",
          htmltools::tags$h3(class = "bloco-titulo", "Evolu\u00e7\u00e3o ao longo do tempo"),
          htmltools::tags$p(
            class = "bloco-descricao",
            paste(
              "Cada linha acompanha o IBISMA ou um dos seis blocos ao longo dos anos;",
              "clique na legenda para ocultar ou mostrar uma s\u00e9rie."
            )
          )
        ),
        htmltools::tags$div(
          class = "dupla dupla--evolucao",
          id = ns("evolucoes"),
          htmltools::tags$div(
            class = "dupla__item dupla__item--principal",
            shiny::uiOutput(ns("evolucao_principal"))
          ),
          htmltools::tags$div(
            class = "dupla__item dupla__item--comparado",
            shiny::uiOutput(ns("evolucao_comparada"))
          )
        ),
        # Legenda nativa compartilhada, centralizada abaixo dos gráficos
        htmltools::tags$div(
          class = "evolucao-legenda",
          echarts4r::echarts4rOutput(ns("legenda_evolucao"), height = "64px")
        )
      )
    )
  )
}

#' Server do módulo Como?
#'
#' @param id Identificador do módulo.
#' @param dados Lista retornada por preparar_dados().
#' @param municipio Reativo compartilhado com o município selecionado.
#' @return Nada; registra os outputs e observadores do módulo.
#' @noRd
mod_como_server <- function(id, dados, municipio) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Mantendo o seletor do perfil sincronizado com o restante do painel
    shiny::observeEvent(municipio(), {
      selecionado <- municipio()
      if (!is.null(selecionado) && !is.na(selecionado)) {
        atualizar_seletor(session, "municipio", selecionado)
      }
    }, ignoreInit = FALSE)

    # Registrando a troca de município feita no próprio seletor
    shiny::observeEvent(input$municipio, {
      novo <- suppressWarnings(as.integer(input$municipio))
      if (!is.na(novo) && !identical(novo, municipio())) {
        municipio(novo)
      }
    })

    # Convertendo o ano escolhido no controle para número
    ano <- shiny::reactive(as.integer(input$ano))

    # Obtendo os dados territoriais do município selecionado
    info <- shiny::reactive({
      dados$municipios[dados$municipios$codmunres == municipio(), ][1, ]
    })

    # Montando o resumo do município no ano escolhido
    resumo <- shiny::reactive({
      resumo_municipio(dados, municipio(), ano())
    })

    # ----- Município de comparação -----

    # Descobrindo o município de comparação escolhido, se houver
    cod_comparacao <- shiny::reactive({
      valor <- input$comparar
      if (is.null(valor) || identical(valor, "nenhum")) {
        return(NULL)
      }
      suppressWarnings(as.integer(valor))
    })

    # Verificando se existe um município de comparação escolhido
    tem_comparacao <- shiny::reactive({
      !is.null(cod_comparacao())
    })

    # Obtendo os dados territoriais do município comparado
    info_comparacao <- shiny::reactive({
      cod <- cod_comparacao()
      if (is.null(cod)) return(NULL)
      dados$municipios[dados$municipios$codmunres == cod, ][1, ]
    })

    # Montando o resumo do município comparado no mesmo ano
    resumo_comparacao <- shiny::reactive({
      cod <- cod_comparacao()
      if (is.null(cod)) return(NULL)
      resumo_municipio(dados, cod, ano())
    })

    # ----- Palcos -----

    # Montando o palco do município principal, com rótulo apenas na comparação
    output$palco_principal <- shiny::renderUI({
      perfil_palco(
        municipio = info(),
        resumo = resumo(),
        ano = ano(),
        rotulo = if (tem_comparacao()) "Munic\u00edpio principal" else NULL
      )
    })

    # Montando o palco do município comparado; fica suspenso sem comparação
    output$palco_comparado <- shiny::renderUI({
      shiny::req(cod_comparacao())
      perfil_palco(
        municipio = info_comparacao(),
        resumo = resumo_comparacao(),
        ano = ano(),
        comparado = TRUE,
        rotulo = "Munic\u00edpio comparado"
      )
    })

    # Avisando o navegador para animar a transição; tem_comparacao nunca é NULL
    shiny::observeEvent(tem_comparacao(), {
      session$sendCustomMessage("ibisma_comparacao", list(
        palcos = ns("palcos"),
        evolucoes = ns("evolucoes"),
        ativa = tem_comparacao()
      ))
    }, ignoreInit = TRUE)

    # ----- Evolução temporal -----

    # Montando as séries das sete medidas de cada município
    series_principal <- shiny::reactive(series_municipio(dados, municipio()))
    series_comparacao <- shiny::reactive({
      shiny::req(cod_comparacao())
      series_municipio(dados, cod_comparacao())
    })

    # Montando a legenda compartilhada, conectada aos dois gráficos
    output$legenda_evolucao <- echarts4r::renderEcharts4r({
      grafico_legenda(grupo = ns("evolucao"))
    })

    # Inserindo o gráfico do principal apenas quando existir algum valor
    output$evolucao_principal <- shiny::renderUI({
      series <- series_principal()
      if (!series_tem_valor(series)) {
        return(estado_vazio(
          "Sem dados de s\u00e9rie temporal para este munic\u00edpio.",
          icone = "circle-info"
        ))
      }
      htmltools::tagList(
        htmltools::tags$h4(
          class = "evolucao-titulo",
          nome_municipio(dados, municipio())
        ),
        echarts4r::echarts4rOutput(ns("grafico_principal"), height = "330px")
      )
    })

    # Desenhando as sete linhas do município principal sem legenda interna
    output$grafico_principal <- echarts4r::renderEcharts4r({
      series <- series_principal()
      shiny::req(series_tem_valor(series))
      grafico_evolucao(
        series,
        nome = nome_municipio(dados, municipio()),
        legenda = FALSE,
        grupo = ns("evolucao"),
        # Lendo a seleção da legenda sem criar dependência reativa
        selecao = shiny::isolate(input$legenda_evolucao_legend_selected)
      )
    })

    # Inserindo o gráfico do comparado apenas quando houver par e algum valor
    output$evolucao_comparada <- shiny::renderUI({
      cod <- cod_comparacao()
      shiny::req(cod)
      series <- series_comparacao()
      if (!series_tem_valor(series)) {
        return(estado_vazio(
          "Sem dados de s\u00e9rie temporal para o munic\u00edpio comparado.",
          icone = "circle-info"
        ))
      }
      htmltools::tagList(
        htmltools::tags$h4(
          class = "evolucao-titulo",
          nome_municipio(dados, cod)
        ),
        echarts4r::echarts4rOutput(ns("grafico_comparado"), height = "330px")
      )
    })

    # Desenhando as sete linhas do município comparado sem repetir a legenda
    output$grafico_comparado <- echarts4r::renderEcharts4r({
      cod <- cod_comparacao()
      shiny::req(cod)
      series <- series_comparacao()
      shiny::req(series_tem_valor(series))
      grafico_evolucao(
        series,
        nome = nome_municipio(dados, cod),
        legenda = FALSE,
        grupo = ns("evolucao"),
        selecao = shiny::isolate(input$legenda_evolucao_legend_selected)
      )
    })
  })
}
