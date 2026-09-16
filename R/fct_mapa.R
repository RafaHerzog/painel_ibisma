# =============================================================================
#   FUNÇÕES AUXILIARES DO MAPA
#   Prepara a malha, o desenho enviado por mensagem e os dados compactos que
#   alimentam o mapa, além de definir o estilo-base do mapa do painel.
# =============================================================================

# Guardando a malha e o desenho em memória para não reler os arquivos a cada sessão
.malha_cache <- new.env(parent = emptyenv())

#' Definindo uma função que carrega a malha municipal simplificada
#'
#' @return Objeto sf com os polígonos dos municípios brasileiros.
#' Usada em: fct_mapa.R (dados_mapa) e mod_onde.R (destaque do município selecionado).
#' @noRd
carregar_malha_municipios <- function() {
  # Lendo o arquivo apenas na primeira chamada e reutilizando depois
  if (is.null(.malha_cache$municipios)) {
    .malha_cache$municipios <- readRDS(
      app_sys("app", "data", "malha_municipios.rds")
    )
  }
  .malha_cache$municipios
}

#' Definindo uma função que carrega a malha estadual simplificada
#'
#' @return Objeto sf com os polígonos das unidades da federação.
#' Usada em: fct_mapa.R (desenhar_ufs).
#' @noRd
carregar_malha_ufs <- function() {
  # Lendo o arquivo apenas na primeira chamada e reutilizando depois
  if (is.null(.malha_cache$ufs)) {
    .malha_cache$ufs <- readRDS(
      app_sys("app", "data", "malha_ufs.rds")
    )
  }
  .malha_cache$ufs
}

#' Definindo uma função que carrega o desenho pronto dos municípios
#'
#' Guarda o texto dos polígonos e os identificadores das camadas gerados por
#' data-raw/cria_rda.R, evitando converter o sf a cada sessão do painel.
#'
#' @return Lista com o texto JSON dos polígonos e os códigos das camadas.
#' Usada em: fct_mapa.R (enviar_desenho_municipios) e testes do desenho.
#' @noRd
carregar_desenho_municipios <- function() {
  # Lendo o arquivo apenas na primeira chamada e reutilizando depois
  if (is.null(.malha_cache$desenho)) {
    arquivo <- app_sys("app", "data", "malha_mapa.rds")
    if (!file.exists(arquivo)) {
      stop(
        "Desenho do mapa n\u00e3o encontrado. ",
        "Rode data-raw/cria_rda.R para gerar o arquivo."
      )
    }
    .malha_cache$desenho <- readRDS(arquivo)
  }
  .malha_cache$desenho
}

#' Definindo uma função que prepara os dados compactos que alimentam o mapa
#'
#' Os valores ficam na ordem da malha (a mesma das camadas do mapa) e os textos
#' são curtos: o HTML do tooltip é montado no JavaScript do painel.
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @param medida Identificador da medida exibida.
#' @return Data frame com nome, UF, valor em texto e código da categoria.
#' Usada em: mod_onde.R (reactive do mapa).
#' @noRd
dados_mapa <- function(dados, ano, medida) {
  # Buscando os valores do ano e da medida selecionados
  base <- valores_ano(dados, ano, medida)

  # Alinhando os valores à ordem da malha, que é a ordem das camadas do mapa
  malha <- carregar_malha_municipios()
  indice <- match(malha$codmunres, base$codmunres)
  valor <- base$valor[indice]
  categoria <- as.character(base$categoria[indice])

  # Buscando nome e UF no cadastro para municípios sem valor no ano (ex.: Borá/2023)
  cadastro <- match(malha$codmunres, dados$municipios$codmunres)

  # Montando as colunas compactas consumidas pelo JavaScript do mapa
  data.frame(
    municipio = dados$municipios$municipio[cadastro],
    sigla_uf = dados$municipios$sigla_uf[cadastro],
    valor_texto = ifelse(is.na(valor), "\u2014", formatar_numero(valor)),
    categoria_cod = match(categoria, CATEGORIAS),
    stringsAsFactors = FALSE
  )
}

#' Definindo uma função que monta a mensagem com os dados do mapa
#'
#' A paleta, os rótulos das categorias e as cores de texto vão uma única vez
#' por mensagem; por município vão apenas nome, UF, valor e categoria.
#'
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @param medida Identificador da medida exibida no mapa.
#' @return Lista pronta para o sendCustomMessage do Shiny.
#' Usada em: fct_mapa.R (enviar_desenho_municipios e atualizar_municipios).
#' @noRd
mensagem_mapa <- function(output_id, base, medida) {
  list(
    id = output_id,
    medida = nome_medida(medida),
    municipios = base$municipio,
    ufs = base$sigla_uf,
    valores = base$valor_texto,
    categorias = base$categoria_cod,
    paleta = unname(PALETAS[[medida]]),
    rotulos = unname(CATEGORIAS),
    cores_texto = unname(cor_texto_sobre(PALETAS[[medida]])),
    cor_sem_dados = COR_SEM_DADOS,
    cor_texto_sem_dados = cor_texto_sobre(COR_SEM_DADOS)
  )
}

#' Definindo uma função que cria o mapa-base do painel
#'
#' @return Objeto leaflet sem camadas de dados.
#' Usada em: mod_onde.R (desenho do mapa).
#' @noRd
mapa_base <- function() {
  # Configurando um mapa limpo, sem tiles externos e com desenho em canvas
  leaflet::leaflet(
    options = leaflet::leafletOptions(
      preferCanvas = TRUE,
      attributionControl = FALSE,
      # Limitando o zoom mínimo ao enquadramento que mostra o Brasil inteiro
      minZoom = 4,
      maxZoom = 10,
      maxBoundsViscosity = 1.0,
      zoomControl = TRUE
    )
  ) |>
    # Impedindo que o usuário afaste ou arraste o mapa para fora do Brasil
    leaflet::setMaxBounds(
      lng1 = -75.0, lat1 = -34.5,
      lng2 = -32.0, lat2 = 6.0
    ) |>
    # Enquadrando o Brasil no carregamento inicial
    leaflet::fitBounds(lng1 = -74, lat1 = -34, lng2 = -34, lat2 = 6)
}

#' Definindo uma função que envia ao navegador o desenho e os dados dos municípios
#'
#' O texto dos polígonos e os identificadores das camadas vêm prontos de
#' data-raw/cria_rda.R, então a geometria não é convertida nem serializada a
#' cada sessão; o JavaScript cria as camadas com o próprio binding do leaflet.
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @param medida Identificador da medida exibida no mapa.
#' @return Nada; envia a mensagem para o JavaScript do painel.
#' Usada em: mod_onde.R (desenho inicial do mapa).
#' @noRd
enviar_desenho_municipios <- function(session, output_id, base, medida) {
  # Montando a mensagem com os dados e acrescentando o desenho pronto
  desenho <- carregar_desenho_municipios()
  mensagem <- mensagem_mapa(output_id, base, medida)
  mensagem$pgons <- desenho$pgons
  mensagem$layers <- desenho$layers

  # Criando as camadas e preenchendo cores e tooltips em uma única mensagem
  session$sendCustomMessage("ibisma_mapa_desenha", mensagem)
}

#' Definindo uma função que envia ao navegador a atualização de cores e tooltips do mapa
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @param medida Identificador da medida exibida no mapa.
#' @return Nada; envia a mensagem para o JavaScript do painel.
#' Usada em: mod_onde.R (atualização das cores e tooltips).
#' @noRd
atualizar_municipios <- function(session, output_id, base, medida) {
  # Atualizando os polígonos já desenhados sem reenviar a geometria
  session$sendCustomMessage(
    "ibisma_mapa_atualiza",
    mensagem_mapa(output_id, base, medida)
  )
}

#' Definindo uma função que desenha os contornos das unidades da federação
#'
#' @param mapa Objeto leaflet.
#' @return Objeto leaflet com a camada de contornos estaduais.
#' Usada em: mod_onde.R (desenho do mapa).
#' @noRd
desenhar_ufs <- function(mapa) {
  # Sobrepondo os limites estaduais sem interferir na interação dos municípios
  malha_ufs <- carregar_malha_ufs()
  mapa |>
    leaflet::addPolygons(
      data = malha_ufs,
      fill = FALSE,
      # Suavizando o contorno estadual para não competir com as divisas finas
      color = "#FFFFFF",
      weight = 0.8,
      opacity = 0.85,
      smoothFactor = 0,
      options = leaflet::pathOptions(interactive = FALSE)
    )
}

#' Definindo uma função que monta a legenda das cinco categorias do mapa
#'
#' @param paleta Vetor nomeado com as cores das categorias.
#' @param titulo Título curto da legenda.
#' @param com_sem_dados Incluir a entrada "Sem dados" (desativado no painel).
#' @return Elemento HTML com a legenda completa.
#' Usada em: mod_onde.R (legenda do mapa).
#' @noRd
legenda_categorias <- function(paleta = PALETAS$indice_final,
                               titulo = NULL, com_sem_dados = FALSE) {
  # Montando um item de legenda para cada categoria
  itens <- lapply(names(paleta), function(nome) {
    htmltools::tags$span(
      class = "legenda-item",
      htmltools::tags$span(class = "legenda-cor", style = paste0("background:", paleta[[nome]], ";")),
      htmltools::tags$span(class = "legenda-rotulo", nome)
    )
  })

  # Acrescentando a entrada de municípios sem dado, quando pedido
  if (com_sem_dados) {
    itens <- c(itens, list(
      htmltools::tags$span(
        class = "legenda-item legenda-item--sem-dados",
        htmltools::tags$span(class = "legenda-cor", style = paste0("background:", COR_SEM_DADOS, ";")),
        htmltools::tags$span(class = "legenda-rotulo", "Sem dados")
      )
    ))
  }

  htmltools::tags$div(
    class = "legenda-categorias",
    if (!is.null(titulo)) htmltools::tags$span(class = "legenda-titulo", titulo),
    htmltools::tags$div(class = "legenda-itens", itens)
  )
}

