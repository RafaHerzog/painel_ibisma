# =============================================================================
#   FUNÇÕES AUXILIARES DO MAPA
#   Prepara a malha, os valores e os textos dos tooltips usados pelo leaflet,
#   além de definir o estilo-base do mapa do painel.
# =============================================================================

# Guardando a malha em memória para não reler o arquivo a cada sessão
.malha_cache <- new.env(parent = emptyenv())

#' Definindo uma função que carrega a malha municipal simplificada
#'
#' @return Objeto sf com os polígonos dos municípios brasileiros.
#' Usada em: fct_mapa.R (malha_do_ano) e mod_onde.R (destaque do município selecionado).
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

#' Definindo uma função que monta o texto HTML do tooltip de um município
#'
#' @param municipio Nome do município.
#' @param sigla_uf Sigla da unidade da federação.
#' @param valor Valor da medida exibida.
#' @param categoria Categoria de vulnerabilidade.
#' @param nome_medida Nome da medida exibida.
#' @param medida Identificador da medida exibida no mapa.
#' @return Texto HTML pronto para o tooltip do leaflet.
#' Usada em: fct_mapa.R (dados_mapa).
#' @noRd
tooltip_municipio <- function(municipio, sigla_uf, valor, categoria, nome_medida, medida) {
  # Tratando municípios sem dado no ano selecionado, vetorizadamente
  sem_dado <- is.na(valor)
  valor_texto <- ifelse(sem_dado, "\u2014", formatar_numero(valor))
  categoria_texto <- ifelse(sem_dado, "Sem dados", categoria)
  # Buscando a cor da categoria na rampa da medida exibida no mapa
  cor_cat <- cor_categoria(categoria, medida)
  # Escolhendo a cor de texto com melhor leitura sobre o selo da categoria
  cor_texto <- cor_texto_sobre(cor_cat)

  # Montando o HTML do tooltip com o nome, o valor e a categoria
  paste0(
    '<div class="tooltip-mapa">',
    '<div class="tooltip-mapa__titulo">', municipio, " <span>(", sigla_uf, ")</span></div>",
    '<div class="tooltip-mapa__linha">',
    '<span class="tooltip-mapa__rotulo">', nome_medida, "</span>",
    '<span class="tooltip-mapa__valor">', valor_texto, "</span>",
    "</div>",
    '<div class="tooltip-mapa__categoria" style="--cor-cat:', cor_cat, ';color:', cor_texto, '">',
    categoria_texto,
    "</div>",
    "</div>"
  )
}

#' Definindo uma função que prepara os dados anuais que alimentam o mapa
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @param medida Identificador da medida exibida.
#' @return Data frame com categoria, cor e tooltip prontos para o mapa.
#' Usada em: fct_mapa.R (malha_do_ano) e mod_onde.R (reactive do mapa).
#' @noRd
dados_mapa <- function(dados, ano, medida) {
  # Buscando os valores do ano e da medida selecionados
  base <- valores_ano(dados, ano, medida)

  # Definindo a cor de cada município conforme sua categoria
  base$cor <- cor_categoria(as.character(base$categoria), medida)

  # Montando o texto HTML exibido ao passar o mouse
  base$tooltip <- tooltip_municipio(
    municipio = base$municipio,
    sigla_uf = base$sigla_uf,
    valor = base$valor,
    categoria = as.character(base$categoria),
    nome_medida = nome_medida(medida)[1],
    medida = medida
  )
  base
}

#' Definindo uma função que junta a malha municipal aos valores do ano e da medida
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @param medida Identificador da medida exibida.
#' @return Objeto sf com geometria, cor e tooltip de cada município.
#' Usada em: mod_onde.R (desenho do mapa).
#' @noRd
malha_do_ano <- function(dados, ano, medida) {
  # Buscando a malha e os valores preparados para o mapa
  malha <- carregar_malha_municipios()
  base <- dados_mapa(dados, ano, medida)

  # Ligando cor e tooltip a cada município pela posição do código na malha
  indice <- match(malha$codmunres, base$codmunres)
  malha$cor <- base$cor[indice]
  malha$tooltip <- base$tooltip[indice]

  # Criando o identificador em texto exigido pelo leaflet para indexar as camadas
  malha$codmunres_txt <- as.character(malha$codmunres)
  malha
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

#' Definindo uma função que desenha os municípios no mapa
#'
#' As cores e os tooltips ficam fora da carga inicial e chegam logo depois,
#' pela mensagem tratada em funcoes_javascript.js, para o mapa abrir mais leve.
#'
#' @param mapa Objeto leaflet.
#' @param base Objeto sf retornado por malha_do_ano().
#' @return Objeto leaflet com a camada de municípios.
#' Usada em: mod_onde.R (desenho do mapa).
#' @noRd
desenhar_municipios <- function(mapa, base) {
  # Usando o código do município como identificador de cada polígono
  mapa |>
    leaflet::addPolygons(
      data = base,
      layerId = ~codmunres_txt,
      # Aumentando a opacidade para o fundo do mapa não clarear as cores
      fillColor = ~cor,
      fillOpacity = 0.95,
      # Desenhando as divisas municipais com um traço branco fino e leve
      color = "#FFFFFF",
      weight = 0.25,
      opacity = 0.65,
      # Desenhando a malha já simplificada, sem nova simplificação no cliente
      smoothFactor = 0,
      highlightOptions = leaflet::highlightOptions(
        weight = 1.2,
        color = COR_AZUL_ESCURO,
        fillOpacity = 0.95,
        bringToFront = TRUE
      )
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

#' Definindo uma função que envia ao navegador a atualização de cores e tooltips do mapa
#'
#' @param session Sessão do Shiny.
#' @param output_id Identificador do output do mapa.
#' @param base Data frame retornado por dados_mapa().
#' @return Nada; envia a mensagem para o JavaScript do painel.
#' Usada em: mod_onde.R (atualização das cores e tooltips).
#' @noRd
atualizar_municipios <- function(session, output_id, base) {
  # Convertendo os mapas de código para cor e tooltip em listas nomeadas
  # Evitando o aviso do jsonlite, que surge ao serializar vetores nomeados
  cores <- as.list(stats::setNames(base$cor, as.character(base$codmunres)))
  labels <- as.list(stats::setNames(base$tooltip, as.character(base$codmunres)))

  # Atualizando os polígonos já desenhados sem reenviar a geometria
  session$sendCustomMessage(
    "ibisma_mapa_atualiza",
    list(id = output_id, cores = cores, labels = labels)
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

