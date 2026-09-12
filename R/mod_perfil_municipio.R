# =============================================================================
#   MÓDULO PERFIL DOS MUNICÍPIOS
#   Permite explorar um município em detalhe: situação no ano escolhido,
#   flor dos seis blocos, evolução temporal e comparação com outro município.
# =============================================================================

#' Interface do módulo Perfil dos municípios
#'
#' @param id Identificador do módulo.
#' @return Elemento HTML da seção de perfil.
#' @noRd
mod_perfil_municipio_ui <- function(id) {
  ns <- shiny::NS(id)

  # Montando as opções de municípios e de anos usadas nos controles
  municipios <- opcoes_municipios(dados_ibisma())
  anos_ordem <- rev(anos_disponiveis())
  anos <- stats::setNames(anos_ordem, anos_ordem)
  # Incluindo a opção de não comparar com nenhum município
  opcoes_comparacao <- c("Nenhum" = "nenhum", municipios)

  htmltools::tags$section(
    id = "perfil",
    class = "secao-painel secao-perfil",
    htmltools::tags$div(
      class = "painel-container",
      # Cabeçalho editorial da seção
      titulo_secao(
        eyebrow = "Perfil dos munic\u00edpios",
        titulo = "Como a inseguran\u00e7a se apresenta no munic\u00edpio?",
        descricao = paste(
          "Escolha um munic\u00edpio para ver a situa\u00e7\u00e3o no ano selecionado,",
          "a evolu\u00e7\u00e3o ao longo do tempo e a compara\u00e7\u00e3o com outro munic\u00edpio."
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
      # Cabeçalho com o nome do município e suas informações territoriais
      shiny::uiOutput(ns("hero"), class = "perfil-hero"),
      # Situação no ano: flor dos blocos e resumo do índice
      bslib::layout_columns(
        col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(6, 6)),
        gap = "1.5rem",
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--flor",
          # O conteúdo é criado conforme houver dado para o ano escolhido
          shiny::uiOutput(ns("flor_area"))
        ),
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--indice",
          shiny::uiOutput(ns("indice"))
        )
      ),
      # Evolução temporal da medida escolhida
      htmltools::tags$div(
        class = "painel-bloco",
        htmltools::tags$div(
          class = "bloco-cabecalho bloco-cabecalho--linha",
          htmltools::tags$div(
            htmltools::tags$h3(class = "bloco-titulo", "Evolu\u00e7\u00e3o ao longo do tempo"),
            htmltools::tags$p(
              class = "bloco-descricao",
              "Use o seletor para alternar entre o IBISMA e cada bloco. A linha pontilhada aparece quando h\u00e1 compara\u00e7\u00e3o ativa."
            )
          ),
          frase_controles(
            htmltools::tags$span(class = "controle-texto", "Evolu\u00e7\u00e3o do"),
            seletor_inline(ns("medida_serie"), opcoes_medidas(), selected = "indice_final", largura = "280px")
          )
        ),
        # O gráfico ou o aviso de ausência de dados é criado dinamicamente
        shiny::uiOutput(ns("evolucao_area"))
      ),
      # Comparação entre municípios no ano escolhido
      htmltools::tags$div(
        class = "painel-bloco painel-bloco--comparacao",
        # O conteúdo é criado apenas quando houver um município de comparação
        shiny::uiOutput(ns("comparacao_area"))
      )
    )
  )
}

#' Server do módulo Perfil dos municípios
#'
#' @param id Identificador do módulo.
#' @param dados Lista retornada por preparar_dados().
#' @param municipio Reativo compartilhado com o município selecionado.
#' @return Nada; registra os outputs e observadores do módulo.
#' @noRd
mod_perfil_municipio_server <- function(id, dados, municipio) {
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

    # Obtendo os dados territoriais do município selecionado
    info <- shiny::reactive({
      dados$municipios[dados$municipios$codmunres == municipio(), ][1, ]
    })

    # Montando o resumo do município no ano escolhido
    resumo <- shiny::reactive({
      resumo_municipio(dados, municipio(), as.integer(input$ano))
    })

    # Calculando a mediana nacional de cada bloco como referência da flor
    medianas_blocos <- shiny::reactive({
      valores <- vapply(
        BLOCOS$medida,
        function(m) mediana_referencia(dados, m, as.integer(input$ano))[["brasil"]],
        numeric(1)
      )
      names(valores) <- BLOCOS$nome
      valores
    })

    # ----- Cabeçalho e situação no ano -----

    # Desenhando o cabeçalho com nome e informações territoriais
    output$hero <- shiny::renderUI({
      mun <- info()
      if (is.na(mun$codmunres)) {
        return(estado_vazio("Selecione um munic\u00edpio para ver o perfil."))
      }
      htmltools::tagList(
        htmltools::tags$h3(
          class = "perfil-nome",
          mun$municipio,
          htmltools::tags$span(class = "perfil-uf", mun$sigla_uf)
        ),
        htmltools::tags$div(
          class = "perfil-metricas",
          metrica_hero("Regi\u00e3o", mun$regiao),
          metrica_hero("Unidade da federa\u00e7\u00e3o", mun$uf),
          metrica_hero("Regi\u00e3o de sa\u00fade", mun$r_saude),
          metrica_hero("Macrorregi\u00e3o de sa\u00fade", mun$macro_r_saude)
        )
      )
    })

    # Montando o cabeçalho do bloco da flor, usado também no estado vazio
    cabecalho_flor <- shiny::reactive({
      htmltools::tags$div(
        class = "bloco-cabecalho",
        htmltools::tags$h3(
          class = "bloco-titulo",
          paste0("Situa\u00e7\u00e3o em ", input$ano)
        ),
        htmltools::tags$p(
          class = "bloco-descricao",
          paste0(
            "Cada p\u00e9tala representa um bloco do IBISMA: quanto maior a p\u00e9tala, ",
            "maior a inseguran\u00e7a naquele bloco. O ponto escuro marca a mediana do Brasil."
          )
        )
      )
    })

    # Inserindo a flor apenas quando houver dado para o ano selecionado
    output$flor_area <- shiny::renderUI({
      if (is.null(resumo())) {
        return(htmltools::tagList(
          cabecalho_flor(),
          estado_vazio(
            "Este munic\u00edpio n\u00e3o possui dados no ano selecionado.",
            icone = "circle-info"
          )
        ))
      }
      htmltools::tagList(
        cabecalho_flor(),
        echarts4r::echarts4rOutput(ns("flor"), height = "380px")
      )
    })

    # Montando a flor dos seis blocos do município
    output$flor <- echarts4r::renderEcharts4r({
      # Interrompendo quando o município não tem dado no ano escolhido
      shiny::req(resumo())
      grafico_flor(resumo()$blocos, medianas = medianas_blocos())
    })

    # Montando o resumo numérico ao lado da flor
    output$indice <- shiny::renderUI({
      r <- resumo()
      if (is.null(r)) {
        return(estado_vazio(
          paste(
            "Sem dados de IBISMA e dos blocos para",
            info()$municipio, "em", input$ano, ".",
            "Veja a evolu\u00e7\u00e3o ao longo do tempo abaixo."
          ),
          icone = "circle-info"
        ))
      }

      # Montando uma linha para cada bloco com cor, nome, valor e categoria
      linhas_blocos <- lapply(seq_len(nrow(r$blocos)), function(i) {
        bloco <- r$blocos[i, ]
        htmltools::tags$div(
          class = "perfil-bloco-linha",
          htmltools::tags$span(
            class = "perfil-bloco-dot",
            style = paste0("background:", bloco$cor, ";")
          ),
          htmltools::tags$span(class = "perfil-bloco-nome", bloco$nome),
          htmltools::tags$span(class = "perfil-bloco-valor", formatar_numero(bloco$valor)),
          htmltools::tags$span(class = "perfil-bloco-cat", as.character(bloco$categoria))
        )
      })

      htmltools::tagList(
        htmltools::tags$div(
          class = "perfil-indice",
          htmltools::tags$div(
            class = "perfil-indice__linha",
            htmltools::tags$span(
              class = "perfil-indice__valor",
              formatar_numero(r$valor, decimais = 2)
            ),
            badge_categoria(r$categoria)
          ),
          htmltools::tags$p(class = "perfil-indice__frase", frase_percentil(r$valor))
        ),
        htmltools::tags$div(
          class = "perfil-ranks",
          metrica_hero(
            "Ranking nacional",
            rotulo_posicao(r$pos_nac, r$total_nac)
          ),
          metrica_hero(
            paste0("Ranking em ", r$sigla_uf),
            rotulo_posicao(r$pos_uf, r$total_uf)
          )
        ),
        htmltools::tags$div(class = "perfil-blocos", linhas_blocos)
      )
    })

    # ----- Evolução temporal -----

    # Descobrindo o município de comparação escolhido, se houver
    cod_comparacao <- shiny::reactive({
      valor <- input$comparar
      if (is.null(valor) || identical(valor, "nenhum")) {
        return(NULL)
      }
      suppressWarnings(as.integer(valor))
    })

    # Montando a série temporal do município e, se houver, do comparado
    series_evolucao <- shiny::reactive({
      comparar_series(dados, municipio(), cod_comparacao(), input$medida_serie)
    })

    # Verificando se existe algum valor na série para desenhar o gráfico
    tem_serie <- shiny::reactive({
      series <- series_evolucao()
      cod_b <- cod_comparacao()
      !(all(is.na(series$valor_a)) && (is.null(cod_b) || all(is.na(series$valor_b))))
    })

    # Inserindo o gráfico da série apenas quando existir algum valor
    output$evolucao_area <- shiny::renderUI({
      if (!tem_serie()) {
        return(estado_vazio(
          "Sem dados de s\u00e9rie temporal para este munic\u00edpio.",
          icone = "circle-info"
        ))
      }
      echarts4r::echarts4rOutput(ns("evolucao"), height = "360px")
    })

    # Desenhando a série temporal do município e, se houver, do comparado
    output$evolucao <- echarts4r::renderEcharts4r({
      # Interrompendo quando não existir nenhum valor na série
      shiny::req(tem_serie())
      series <- series_evolucao()
      cod_b <- cod_comparacao()

      grafico_evolucao(
        series = series,
        nome_a = nome_municipio(dados, municipio()),
        nome_b = if (!is.null(cod_b)) nome_municipio(dados, cod_b),
        cor = cor_medida(input$medida_serie),
        ano_destaque = input$ano,
        descricao = paste(
          "Evolu\u00e7\u00e3o de", nome_medida(input$medida_serie),
          "entre", min(series$ano), "e", max(series$ano)
        )
      )
    })

    # ----- Comparação entre municípios -----

    # Calculando as diferenças entre os dois municípios no ano escolhido
    comparacao <- shiny::reactive({
      cod_b <- cod_comparacao()
      if (is.null(cod_b) || is.na(cod_b)) {
        return(NULL)
      }
      comparar_ano(dados, municipio(), cod_b, as.integer(input$ano))
    })

    # Verificando se existe um município de comparação escolhido
    tem_comparacao <- shiny::reactive({
      !is.null(cod_comparacao())
    })

    # Montando o conteúdo da comparação, incluindo o gráfico apenas quando houver par
    output$comparacao_area <- shiny::renderUI({
      if (!tem_comparacao()) {
        return(htmltools::tagList(
          htmltools::tags$h3(class = "bloco-titulo", "Compara\u00e7\u00e3o entre munic\u00edpios"),
          estado_vazio(
            "Escolha um munic\u00edpio no controle \u201ccomparar com\u201d para ver as diferen\u00e7as por bloco.",
            icone = "code-compare"
          )
        ))
      }

      # Montando o cabeçalho com o nome dos dois municípios comparados
      cabecalho <- htmltools::tagList(
        htmltools::tags$h3(
          class = "bloco-titulo",
          paste0("Compara\u00e7\u00e3o em ", input$ano)
        ),
        htmltools::tags$p(
          class = "bloco-descricao",
          paste0(
            "Barras \u00e0 direita indicam maior inseguran\u00e7a de ",
            nome_municipio(dados, cod_comparacao()),
            "; \u00e0 esquerda, menor inseguran\u00e7a em rela\u00e7\u00e3o a ",
            nome_municipio(dados, municipio()), "."
          )
        )
      )

      # Verificando se há dados para os dois municípios no ano escolhido
      if (is.null(comparacao())) {
        return(htmltools::tagList(
          cabecalho,
          estado_vazio("Sem dados para comparar no ano selecionado.", icone = "circle-info")
        ))
      }

      # Inserindo o gráfico e a tabela somente quando a comparação é possível
      htmltools::tagList(
        cabecalho,
        echarts4r::echarts4rOutput(ns("comparacao_grafico"), height = "320px"),
        shiny::uiOutput(ns("comparacao_tabela"))
      )
    })

    # Desenhando o gráfico de diferenças entre os dois municípios
    output$comparacao_grafico <- echarts4r::renderEcharts4r({
      r <- comparacao()
      if (is.null(r)) {
        return(grafico_vazio(""))
      }
      grafico_diferencas(
        comparacao = r,
        nome_a = nome_municipio(dados, municipio()),
        nome_b = nome_municipio(dados, cod_comparacao())
      )
    })

    # Montando a tabela complementar com os valores dos dois municípios
    output$comparacao_tabela <- shiny::renderUI({
      r <- comparacao()
      if (is.null(r)) {
        return(NULL)
      }
      nome_a <- nome_municipio(dados, municipio())
      nome_b <- nome_municipio(dados, cod_comparacao())

      # Montando as linhas da tabela com os valores e as diferen\u00e7as
      linhas <- lapply(seq_len(nrow(r)), function(i) {
        diferenca <- r$delta[i]
        classe <- if (is.na(diferenca) || diferenca == 0) {
          "delta--neutro"
        } else if (diferenca > 0) {
          "delta--pior"
        } else {
          "delta--melhor"
        }
        sinal <- if (!is.na(diferenca) && diferenca > 0) "+" else ""
        htmltools::tags$tr(
          htmltools::tags$th(scope = "row", r$nome[i]),
          htmltools::tags$td(formatar_numero(r$valor_a[i])),
          htmltools::tags$td(formatar_numero(r$valor_b[i])),
          htmltools::tags$td(class = classe, paste0(sinal, formatar_numero(diferenca)))
        )
      })

      htmltools::tags$table(
        class = "tabela-comparacao",
        htmltools::tags$thead(
          htmltools::tags$tr(
            htmltools::tags$th(scope = "col", "Medida"),
            htmltools::tags$th(scope = "col", nome_a),
            htmltools::tags$th(scope = "col", nome_b),
            htmltools::tags$th(scope = "col", "Diferen\u00e7a")
          )
        ),
        htmltools::tags$tbody(linhas)
      )
    })
  })
}


