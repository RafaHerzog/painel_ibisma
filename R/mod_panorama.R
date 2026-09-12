# =============================================================================
#   MÓDULO PANORAMA
#   Reúne a visão geral e o ranking em uma única experiência: os dois blocos
#   compartilham os controles de medida, nível e ano, e a seleção de município
#   circula entre o mapa, o ranking e o perfil.
# =============================================================================

#' Interface do módulo Panorama
#'
#' @param id Identificador do módulo.
#' @return Elemento HTML da seção Panorama.
#' @noRd
mod_panorama_ui <- function(id) {
  ns <- shiny::NS(id)

  # Montando as opções de medida com o prefixo "Bloco" para leitura natural
  medidas <- opcoes_medidas()
  # Montando as opções de nível de análise a partir da configuração central
  niveis <- stats::setNames(NIVEIS_ANALISE$id, NIVEIS_ANALISE$rotulo)
  # Montando as opções de ano em ordem decrescente
  anos_ordem <- rev(anos_disponiveis())
  anos <- stats::setNames(anos_ordem, anos_ordem)

  htmltools::tags$section(
    id = "panorama",
    class = "secao-painel",
    htmltools::tags$div(
      class = "painel-container",
      # Cabeçalho editorial da seção
      titulo_secao(
        eyebrow = "Vis\u00e3o geral e ranking",
        titulo = "Onde est\u00e1 a inseguran\u00e7a em sa\u00fade materna?",
        descricao = TEXTO_ESCALA
      ),
      # Controles principais escritos como uma frase
      frase_controles(
        htmltools::tags$span(class = "controle-texto", "Mostrar"),
        seletor_inline(ns("medida"), medidas, selected = "indice_final", largura = "300px"),
        htmltools::tags$span(class = "controle-texto", "dos"),
        seletor_inline(ns("nivel"), niveis, selected = "municipio"),
        htmltools::tags$span(class = "controle-texto", "em"),
        seletor_inline(ns("ano"), anos, selected = max(anos_disponiveis()))
      ),
      # Organizando mapa e ranking lado a lado no desktop
      bslib::layout_columns(
        col_widths = bslib::breakpoints(sm = c(12, 12), lg = c(6, 6)),
        gap = "1.5rem",
        # ----- Bloco do mapa -----
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--mapa",
          htmltools::tags$div(
            class = "bloco-cabecalho",
            htmltools::tags$div(
              htmltools::tags$h3(class = "bloco-titulo", "Distribui\u00e7\u00e3o no territ\u00f3rio"),
              htmltools::tags$p(
                class = "bloco-descricao",
                "Passe o mouse para ver o valor e a categoria. Clique em um munic\u00edpio para abrir o perfil e destacar no ranking."
              )
            )
          ),
          # Área do mapa com altura responsiva
          htmltools::tags$div(
            class = "mapa-area",
            leaflet::leafletOutput(ns("mapa"), height = "100%")
          ),
          # Legenda das cinco categorias, recalculada por medida
          htmltools::tags$div(
            class = "mapa-legenda",
            shiny::uiOutput(ns("legenda"))
          )
        ),
        # ----- Bloco do ranking -----
        htmltools::tags$div(
          class = "painel-bloco painel-bloco--ranking",
          htmltools::tags$div(
            class = "bloco-cabecalho",
            htmltools::tags$h3(class = "bloco-titulo", "Ranking dos munic\u00edpios"),
            htmltools::tags$p(class = "bloco-descricao", shiny::textOutput(ns("ranking_resumo"), inline = TRUE))
          ),
          # Controle de escopo do ranking (Brasil ou uma UF)
          frase_controles(
            htmltools::tags$span(class = "controle-texto", "Ranking em"),
            seletor_inline(ns("escopo"), opcoes_escopo_ranking(), selected = "nacional")
          ),
          # Tabela interativa com a lista de municípios
          reactable::reactableOutput(ns("ranking")),
          htmltools::tags$p(
            class = "bloco-nota",
            "Valores de 0 a 100. A posi\u00e7\u00e3o 1\u00ba indica o munic\u00edpio mais vulner\u00e1vel do escopo escolhido."
          )
        )
      )
    )
  )
}

#' Server do módulo Panorama
#'
#' @param id Identificador do módulo.
#' @param dados Lista retornada por preparar_dados().
#' @param municipio Reativo compartilhado com o município selecionado.
#' @return Nada; registra os outputs e observadores do módulo.
#' @noRd
mod_panorama_server <- function(id, dados, municipio) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Calculando os dados do mapa para a medida e o ano selecionados
    base_mapa <- shiny::reactive({
      dados_mapa(dados, as.integer(input$ano), input$medida)
    })

    # ----- Mapa -----

    # Desenhando o mapa uma única vez; as atualizações usam mensagens ao JS
    output$mapa <- leaflet::renderLeaflet({
      malha <- shiny::isolate(malha_do_ano(dados, as.integer(input$ano), input$medida))
      desenhar_ufs(desenhar_municipios(mapa_base(), malha)) |>
        htmlwidgets::onRender(
          sprintf(
            "function(el) {
               var w = HTMLWidgets.getInstance(el);
               if (w && w.getMap) {
                 var mapa = w.getMap();
                 mapa.invalidateSize();
                 mapa.fitBounds([[-34.5, -74.5], [6.5, -33.5]], {padding: [8, 8]});
               }
               Shiny.setInputValue('%s', Date.now(), {priority: 'event'});
             }",
            ns("mapa_pronto")
          )
        )
    })

    # Atualizando cores e tooltips do mapa quando muda o ano ou a medida
    shiny::observeEvent(list(input$ano, input$medida), {
      atualizar_municipios(session, ns("mapa"), base_mapa())
    }, ignoreInit = TRUE)

    # Destacando no mapa o município selecionado em qualquer parte do painel
    shiny::observe({
      shiny::req(input$mapa_pronto)
      selecionado <- municipio()
      proxy <- leaflet::leafletProxy(ns("mapa"), session = session)
      proxy <- leaflet::removeShape(proxy, "selecionado")
      if (!is.null(selecionado) && !is.na(selecionado)) {
        malha <- carregar_malha_municipios()
        destaque <- malha[malha$codmunres == selecionado, ]
        if (nrow(destaque) > 0) {
          proxy <- leaflet::addPolygons(
            proxy,
            data = destaque,
            layerId = "selecionado",
            fill = FALSE,
            color = COR_AZUL_ESCURO,
            weight = 2.4,
            opacity = 0.95,
            smoothFactor = 0,
            options = leaflet::pathOptions(interactive = FALSE)
          )
        }
      }
    })

    # Registrando o clique no mapa como seleção de município
    shiny::observeEvent(input$mapa_shape_click, {
      clique <- input$mapa_shape_click
      if (!is.null(clique$id) && !identical(clique$id, "selecionado")) {
        novo <- suppressWarnings(as.integer(clique$id))
        if (!is.na(novo) && !identical(novo, municipio())) {
          municipio(novo)
        }
      }
    })

    # ----- Legenda -----

    # Recriando a legenda sempre que a medida exibida mudar
    output$legenda <- shiny::renderUI({
      paleta <- paleta_mapa(input$medida)
      legenda_categorias(
        paleta = stats::setNames(paleta, CATEGORIAS),
        titulo = "N\u00edvel de inseguran\u00e7a"
      )
    })

    # ----- Ranking -----

    # Montando a tabela do ranking conforme medida, ano e escopo escolhidos
    tabela_ranking <- shiny::reactive({
      base <- valores_ano(dados, as.integer(input$ano), input$medida)
      escopo <- input$escopo
      if (!is.null(escopo) && !identical(escopo, "nacional")) {
        base <- base[base$sigla_uf == escopo, ]
      }
      base <- base[order(base$valor, decreasing = TRUE, na.last = TRUE), ]
      row.names(base) <- NULL
      base
    })

    # Escrevendo o texto com o total de municípios do ranking
    output$ranking_resumo <- shiny::renderText({
      tabela <- tabela_ranking()
      total <- sum(!is.na(tabela$valor))
      escopo <- input$escopo
      local <- if (identical(escopo, "nacional")) {
        "do Brasil"
      } else {
        paste0("de ", nome_uf(escopo))
      }
      paste0(
        formatar_inteiro(total), " munic\u00edpios ", local,
        " em ", input$ano, " \u00b7 ", nome_medida(input$medida)
      )
    })

    # Renderizando a tabela interativa com busca e ordenação
    output$ranking <- reactable::renderReactable({
      tabela <- tabela_ranking()

      # Montando apenas as colunas exibidas no ranking, com a posição no escopo
      exibicao <- data.frame(
        posicao = seq_len(nrow(tabela)),
        municipio = tabela$municipio,
        sigla_uf = tabela$sigla_uf,
        valor = tabela$valor,
        categoria = as.character(tabela$categoria),
        codmunres = tabela$codmunres,
        stringsAsFactors = FALSE
      )
      # Montando os selos de categoria de uma vez, de forma vetorizada
      exibicao$categoria_html <- montar_selos(exibicao$categoria)

      reactable::reactable(
        exibicao,
        searchable = TRUE,
        searchMethod = busca_sem_acento,
        language = reactable::reactableLang(
          searchPlaceholder = "Buscar munic\u00edpio...",
          noData = "Nenhum munic\u00edpio encontrado",
          pagePrevious = "Anterior",
          pageNext = "Pr\u00f3xima",
          pageInfo = "{rowStart}\u2013{rowEnd} de {rows} munic\u00edpios",
          pageSizeOptions = "Mostrar {rows}"
        ),
        defaultSorted = "posicao",
        defaultSortOrder = "asc",
        defaultPageSize = 12,
        pageSizeOptions = c(12, 25, 50),
        showPageSizeOptions = TRUE,
        showPageInfo = FALSE,
        highlight = TRUE,
        compact = TRUE,
        striped = FALSE,
        bordered = FALSE,
        onClick = "select",
        selection = "single",
        columns = list(
          posicao = reactable::colDef(
            name = "Pos.", width = 62, align = "right", sticky = "left",
            cell = reactable::JS(
              "function (cellInfo) { return cellInfo.value + '\u00ba'; }"
            )
          ),
          municipio = reactable::colDef(name = "Munic\u00edpio", minWidth = 170),
          sigla_uf = reactable::colDef(name = "UF", width = 54),
          valor = reactable::colDef(
            name = "Valor", width = 84, align = "right",
            cell = reactable::JS(
              "function (cellInfo) {
                 if (cellInfo.value === null) return 'Sem dados';
                 return cellInfo.value.toFixed(1).replace('.', ',');
               }"
            )
          ),
          categoria_html = reactable::colDef(
            name = "Categoria", width = 118, html = TRUE, sortable = FALSE
          ),
          categoria = reactable::colDef(show = FALSE),
          codmunres = reactable::colDef(show = FALSE)
        ),
        theme = tema_reactable()
      )
    })

    # Registrando a linha clicada no ranking como seleção de município
    shiny::observeEvent(reactable::getReactableState("ranking", "selected"), {
      linha <- reactable::getReactableState("ranking", "selected")
      if (!is.null(linha) && length(linha) > 0) {
        tabela <- tabela_ranking()
        novo <- tabela$codmunres[linha]
        if (!is.na(novo) && !identical(novo, municipio())) {
          municipio(novo)
        }
      }
    })

    # Acompanhando o município selecionado para posicionar o ranking nele
    shiny::observeEvent(municipio(), {
      selecionado <- municipio()
      if (is.null(selecionado) || is.na(selecionado)) return()
      tabela <- tabela_ranking()
      linha <- match(selecionado, tabela$codmunres)
      if (is.na(linha)) return()
      pagina <- ceiling(linha / 12)
      if (!identical(reactable::getReactableState("ranking", "selected"), linha)) {
        reactable::updateReactable("ranking", selected = linha, page = pagina)
      }
    }, ignoreInit = TRUE)

    # ----- Carregamento -----

    # Escondendo a tela de carregamento quando o mapa terminar de desenhar
    shiny::observeEvent(input$mapa_pronto, {
      waiter::waiter_hide()
    }, once = TRUE)
  })
}

# Definindo a busca do reactable que ignora acentos e maiúsculas
busca_sem_acento <- reactable::JS(
  "function (rows, colunas, busca) {
     var normalizar = function (texto) {
       return String(texto)
         .normalize('NFD')
         .replace(/[\\u0300-\\u036f]/g, '')
         .toLowerCase();
     };
     var alvo = normalizar(busca).trim();
     if (alvo === '') return rows;
     return rows.filter(function (linha) {
       var texto = normalizar([linha.municipio, linha.sigla_uf].join(' '));
       return texto.indexOf(alvo) !== -1;
     });
   }"
)

#' Definindo o tema visual das tabelas reactable
#'
#' @return Objeto reactableTheme com as cores do projeto.
#' @noRd
tema_reactable <- function() {
  reactable::reactableTheme(
    color = COR_AZUL_ESCURO,
    backgroundColor = "#FFFFFF",
    borderColor = "#ECEEF2",
    stripedColor = "#F8F9FB",
    highlightColor = "#F3EEFA",
    cellPadding = "8px 10px",
    style = list(fontFamily = "'Source Sans Pro', system-ui, sans-serif", fontSize = "0.8125rem"),
    headerStyle = list(
      backgroundColor = "#FFFFFF",
      borderBottom = "1px solid #DDE1E8",
      color = "#5A6472",
      fontWeight = "600",
      textTransform = "uppercase",
      letterSpacing = "0.04em",
      fontSize = "0.6875rem"
    ),
    rowSelectedStyle = list(backgroundColor = "#EFE6F7", boxShadow = "inset 3px 0 0 0 #4B1D73"),
    searchInputStyle = list(
      backgroundColor = "#F8F9FB",
      border = "1px solid #DDE1E8",
      borderRadius = "10px",
      padding = "6px 10px",
      fontSize = "0.8125rem"
    ),
    pageButtonHoverStyle = list(backgroundColor = "#F3EEFA"),
    pageButtonActiveStyle = list(backgroundColor = "#4B1D73", color = "#FFFFFF")
  )
}
