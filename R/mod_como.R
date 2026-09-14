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
          esqueleto_slot(
            shiny::uiOutput(ns("palco_principal")),
            esqueleto_palco(),
            classe = "esqueleto-slot--palco esqueleto-slot--principal"
          )
        ),
        htmltools::tags$div(
          class = "dupla__item dupla__item--comparado",
          esqueleto_slot(
            shiny::uiOutput(ns("palco_comparado")),
            esqueleto_palco(),
            classe = "esqueleto-slot--palco esqueleto-slot--comparado"
          )
        )
      ),
      # Evolução temporal com o IBISMA em destaque e os blocos em pequenos múltiplos
      htmltools::tags$div(
        class = "painel-bloco painel-bloco--evolucao",
        htmltools::tags$div(
          class = "bloco-cabecalho",
          htmltools::tags$h3(class = "bloco-titulo", "Evolu\u00e7\u00e3o ao longo do tempo"),
          htmltools::tags$p(
            class = "bloco-descricao",
            paste(
              "Acompanhe a evolução do IBISMA e de seus seis blocos entre 2015 e 2024."
            )
          ),
          # Identificando os municípios e o período exibidos nos gráficos
          esqueleto_slot(
            shiny::uiOutput(ns("evolucao_identificacao")),
            esqueleto_identificacao(),
            classe = "esqueleto-slot--identificacao"
          )
        ),
        # Grade com sete cartões, preenchida apenas quando houver série para desenhar
        esqueleto_slot(
          shiny::uiOutput(ns("evolucoes")),
          esqueleto_grade_evolucao(),
          classe = "esqueleto-slot--evolucao"
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

    # Avisando o navegador para animar a transição dos palcos
    shiny::observeEvent(tem_comparacao(), {
      session$sendCustomMessage("ibisma_comparacao", list(
        palcos = ns("palcos"),
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

    # Verificando se o comparado tem alguma série para desenhar
    comparacao_tem_serie <- shiny::reactive({
      tem_comparacao() && series_tem_valor(series_comparacao())
    })

    # Calculando os limites do eixo Y de um grupo de medidas nos dois municípios
    limites_do_grupo <- function(medidas) {
      # Reunindo os limites apenas dos gráficos que têm dado para desenhar
      pisos <- numeric(0)
      tetos <- numeric(0)
      if (series_tem_valor(series_principal())) {
        pisos <- c(pisos, piso_eixo_y(series_principal(), medidas))
        tetos <- c(tetos, teto_eixo_y(series_principal(), medidas))
      }
      if (comparacao_tem_serie()) {
        pisos <- c(pisos, piso_eixo_y(series_comparacao(), medidas))
        tetos <- c(tetos, teto_eixo_y(series_comparacao(), medidas))
      }
      if (length(pisos) == 0) {
        return(list(min = 0, max = 100))
      }
      # Abrindo a faixa ao máximo para nenhuma das duas séries ser cortada
      list(min = min(pisos), max = max(tetos))
    }

    # Dando ao IBISMA uma escala própria, mais estreita que a dos blocos
    limites_ibisma <- shiny::reactive(limites_do_grupo("indice_final"))
    # Compartilhando a escala dos seis blocos para os cartões serem comparáveis
    limites_blocos <- shiny::reactive(limites_do_grupo(BLOCOS$medida))

    # Montando o gráfico de evolução de uma medida
    grafico_da_medida <- function(medida) {
      # Desenhando a linha comparada apenas quando ela tem algum valor
      comparacao <- if (comparacao_tem_serie()) series_comparacao() else NULL
      # Usando a escala compartilhada do grupo de medidas do gráfico
      limites <- if (identical(medida, "indice_final")) limites_ibisma() else limites_blocos()
      grafico_evolucao(
        series_principal(),
        medida = medida,
        nome = nome_municipio(dados, municipio()),
        comparacao = comparacao,
        nome_comparacao = if (is.null(comparacao)) NULL else {
          nome_municipio(dados, cod_comparacao())
        },
        minimo_y = limites$min,
        maximo_y = limites$max
      )
    }

    # Renderizando um gráfico para cada medida em um laço para evitar repetição
    for (i in seq_len(nrow(MEDIDAS))) {
      local({
        medida <- MEDIDAS$medida[i]
        output[[paste0("grafico_", medida)]] <- echarts4r::renderEcharts4r({
          shiny::req(series_tem_valor(series_principal()))
          grafico_da_medida(medida)
        })
      })
    }

    # Montando a identificação dos municípios e do período exibidos na grade
    output$evolucao_identificacao <- shiny::renderUI({
      # Escondendo a identificação quando o município não tem série temporal
      shiny::req(series_tem_valor(series_principal()))
      # Reunindo o principal e, quando houver série, o comparado
      nomes <- nome_municipio(dados, municipio())
      if (comparacao_tem_serie()) {
        nomes <- paste0(nomes, " e ", nome_municipio(dados, cod_comparacao()))
      }
      periodos <- range(dados$anos)
      htmltools::tags$p(
        class = "evolucao-identificacao",
        htmltools::tags$span(class = "evolucao-identificacao__nomes", nomes),
        htmltools::tags$span(class = "evolucao-identificacao__separador", "|"),
        htmltools::tags$span(
          class = "evolucao-identificacao__periodo",
          paste0(periodos[1], " \u2013 ", periodos[2])
        )
      )
    })

    # Inserindo a grade de cartões apenas quando existir algum valor
    output$evolucoes <- shiny::renderUI({
      if (!series_tem_valor(series_principal())) {
        return(estado_vazio(
          "Sem dados de s\u00e9rie temporal para este munic\u00edpio.",
          icone = "circle-info"
        ))
      }
      grade_evolucao_ui(ns)
    })
  })
}
