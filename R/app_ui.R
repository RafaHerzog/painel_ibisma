#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    # Deixando este chamado para adicionar os recursos externos do app
    golem_add_external_resources(),
    # Montando a página rolável com o tema visual do projeto
    bslib::page_fillable(
      padding = 0,
      gap = 0,
      fillable = FALSE,
      theme = tema_ibisma(),
      lang = "pt-BR",
      # Criando o ponto de ancoragem do topo da página
      htmltools::tags$a(id = "topo"),
      # Inserindo a barra de navegação por âncoras
      navbar_ibisma(),
      # Montando as seções do painel em página única
      htmltools::tags$main(
        class = "conteudo-painel",
        mod_onde_ui("onde"),
        mod_como_ui("como")
      ),
      # Inserindo o rodapé institucional
      rodape_ibisma()
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path(
    "www",
    app_sys("app/www")
  )

  # Definindo uma função local que evita cache antigo dos arquivos do painel
  recurso_com_versao <- function(caminho) {
    arquivo <- app_sys("app/www", caminho)
    versao <- format(file.info(arquivo)$mtime, "%Y%m%d%H%M%S")
    paste0("www/", caminho, "?v=", versao)
  }

  tags$head(
    favicon(),
    tags$title(paste0(TITULO_PAINEL, " \u2014 ", SUBTITULO_PAINEL)),
    tags$meta(
      name = "description",
      content = paste0(
        SUBTITULO_PAINEL,
        ": painel interativo com o índice e os seis blocos que compõem o IBISMA."
      )
    ),
    # Carregando a fonte institucional do Google Fonts
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(
      rel = "preconnect",
      href = "https://fonts.gstatic.com",
      crossorigin = ""
    ),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Source+Sans+Pro:ital,wght@0,300;0,400;0,600;0,700;1,400&display=swap"
    ),
    # Carregando o estilo e o script do painel com versão baseada na data
    tags$link(rel = "stylesheet", href = recurso_com_versao("global/custom.css")),
    tags$script(src = recurso_com_versao("global/funcoes_javascript.js"), defer = NA),
    golem::activate_js()
  )
}
