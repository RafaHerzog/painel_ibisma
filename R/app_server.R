#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # Preparando a base do IBISMA uma única vez por processo
  dados <- dados_ibisma()

  # Compartilhando o município selecionado entre as duas seções do painel
  municipio <- shiny::reactiveVal(municipio_padrao(dados))

  # Registrando o módulo da visão geral integrada ao ranking
  mod_panorama_server("panorama", dados = dados, municipio = municipio)

  # Registrando o módulo de perfil dos municípios
  mod_perfil_municipio_server("perfil", dados = dados, municipio = municipio)
}
