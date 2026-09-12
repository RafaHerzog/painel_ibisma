# =============================================================================
#   COMPONENTES DE INTERFACE REUTILIZÁVEIS
#   Reúne pedaços de UI usados por mais de uma seção do painel, garantindo
#   consistência visual e evitando repetição de código.
# =============================================================================

#' Definindo o tema bslib do painel
#'
#' @return Objeto bs_theme com as cores e fontes do projeto.
#' @noRd
tema_ibisma <- function() {
  bslib::bs_theme(
    version = 5,
    bg = "#FFFFFF",
    fg = COR_AZUL_ESCURO,
    primary = COR_IBISMA,
    secondary = COR_AZUL_CLARO,
    base_font = bslib::font_collection(
      "'Source Sans Pro'",
      "system-ui",
      "sans-serif"
    ),
    heading_font = bslib::font_collection(
      "'Source Sans Pro'",
      "system-ui",
      "sans-serif"
    ),
    "body-bg" = "#FFFFFF",
    "border-radius" = "12px",
    "font-size-base" = "1rem"
  )
}

#' Montando a barra de navegação fixa do painel
#'
#' @return Elemento HTML da navbar com âncoras para as seções.
#' @noRd
navbar_ibisma <- function() {
  # Montando uma navbar escura Bootstrap 5 com colapso automático em telas pequenas
  htmltools::tags$nav(
    class = "navbar navbar-expand-md navbar-dark navbar-ibisma",
    `aria-label` = "Navegação principal",
    id = "navbar-ibisma",
    htmltools::tags$div(
      class = "painel-container navbar-conteudo",
      # Ligando a marca do painel ao topo da página
      htmltools::tags$a(
        class = "navbar-brand",
        href = "#topo",
        `aria-label` = "Voltar ao topo",
        htmltools::tags$img(
          src = "www/logos/logo-oobr-curto.png",
          alt = "Observatório Obstétrico Brasileiro",
          class = "navbar-brand__logo"
        ),
        htmltools::tags$span(
          class = "navbar-brand__identidade",
          htmltools::tags$span(class = "navbar-brand__texto", TITULO_PAINEL),
          # Mantendo a descrição do índice visível apenas quando houver espaço
          htmltools::tags$span(
            class = "navbar-brand__descricao d-none d-lg-block",
            SUBTITULO_PAINEL
          )
        )
      ),
      # Criando o botão de menu para telas pequenas
      htmltools::tags$button(
        class = "navbar-toggler",
        type = "button",
        `data-bs-toggle` = "collapse",
        `data-bs-target` = "#menu-ibisma",
        `aria-controls` = "menu-ibisma",
        `aria-expanded` = "false",
        `aria-label` = "Abrir menu de navegação",
        htmltools::tags$span(class = "navbar-toggler-icon")
      ),
      # Listando as âncoras das seções do painel
      htmltools::tags$div(
        class = "collapse navbar-collapse",
        id = "menu-ibisma",
        htmltools::tags$ul(
          class = "navbar-nav ms-auto",
          htmltools::tags$li(
            class = "nav-item",
            htmltools::tags$a(class = "nav-link", href = "#panorama", "Panorama")
          ),
          htmltools::tags$li(
            class = "nav-item",
            htmltools::tags$a(class = "nav-link", href = "#perfil", "Perfil dos municípios")
          )
        )
      )
    )
  )
}

#' Montando o cabeçalho de uma seção do painel
#'
#' @param eyebrow Texto curto acima do título.
#' @param titulo Título principal da seção.
#' @param descricao Parágrafo de apoio (opcional).
#' @return Elemento HTML com o cabeçalho da seção.
#' @noRd
titulo_secao <- function(eyebrow, titulo, descricao = NULL) {
  htmltools::tags$header(
    class = "secao-cabecalho",
    htmltools::tags$span(class = "secao-eyebrow", eyebrow),
    htmltools::tags$h2(class = "secao-titulo", titulo),
    if (!is.null(descricao)) {
      htmltools::tags$p(class = "secao-descricao", descricao)
    }
  )
}

#' Atualizando o valor de um slimSelectInput pelo servidor
#'
#' @param session Sessão do Shiny.
#' @param input_id Identificador do input.
#' @param selecionado Valor que deve ficar selecionado.
#' @return Nada; envia a mensagem de atualização para o navegador.
#' @noRd
atualizar_seletor <- function(session, input_id, selecionado) {
  # Usando a função oficial do shinyWidgets para manter o slim select sincronizado
  shinyWidgets::updateSlimSelect(
    session = session,
    inputId = input_id,
    selected = as.character(selecionado)
  )
}

#' Criando um seletor inline integrado à frase de controles
#'
#' @param input_id Identificador do input.
#' @param choices Vetor nomeado de opções.
#' @param selected Valor selecionado inicialmente.
#' @param largura Largura do seletor (mínima).
#' @return Elemento HTML do seletor estilizado.
#' @noRd
seletor_inline <- function(input_id, choices, selected = NULL, largura = "auto") {
  shinyWidgets::slimSelectInput(
    inputId = input_id,
    label = NULL,
    choices = choices,
    selected = selected,
    width = largura,
    search = TRUE,
    placeholder = "Selecione"
  )
}

#' Montando a frase de controles com seletores embutidos
#'
#' @param ... Partes da frase, alternando textos e seletores.
#' @return Elemento HTML com a frase completa.
#' @noRd
frase_controles <- function(...) {
  htmltools::tags$div(class = "controles-inline", ...)
}

#' Criando o selo colorido de uma categoria
#'
#' @param categoria Rótulo da categoria.
#' @param cor Cor de fundo do selo (opcional).
#' @return Elemento HTML do selo.
#' @noRd
badge_categoria <- function(categoria, cor = NULL) {
  # Usando a cor da categoria quando nenhuma cor for informada
  if (is.null(cor) || is.na(cor)) {
    cor <- cor_categoria(categoria)
  }
  htmltools::tags$span(
    class = "badge-categoria",
    style = paste0(
      "--cor-fundo:", cor, ";",
      "color:", cor_texto_sobre(cor), ";"
    ),
    categoria
  )
}

#' Montando selos de categoria em HTML de forma vetorizada
#'
#' @param categorias Vetor de categorias.
#' @return Vetor de textos HTML com os selos coloridos.
#' @noRd
montar_selos <- function(categorias) {
  # Calculando as cores de fundo e de texto de uma só vez
  cores <- cor_categoria(categorias)
  sprintf(
    '<span class="badge-categoria" style="--cor-fundo:%s;color:%s">%s</span>',
    cores,
    cor_texto_sobre(cores),
    categorias
  )
}

#' Montando a legenda das cinco categorias do mapa
#'
#' @param paleta Vetor nomeado com as cores das categorias.
#' @param titulo Título curto da legenda.
#' @param com_sem_dados Incluir a entrada "Sem dados" (desativado no painel).
#' @return Elemento HTML com a legenda completa.
#' @noRd
legenda_categorias <- function(paleta = paleta_categorias(), titulo = NULL,
                               com_sem_dados = FALSE) {
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

#' Criando uma métrica do cabeçalho do perfil
#'
#' @param rotulo Rótulo da métrica.
#' @param valor Valor principal já formatado.
#' @param detalhe Texto auxiliar (opcional).
#' @return Elemento HTML da métrica.
#' @noRd
metrica_hero <- function(rotulo, valor, detalhe = NULL) {
  htmltools::tags$div(
    class = "metrica",
    htmltools::tags$span(class = "metrica-rotulo", rotulo),
    htmltools::tags$span(class = "metrica-valor", valor),
    if (!is.null(detalhe)) {
      htmltools::tags$span(class = "metrica-detalhe", detalhe)
    }
  )
}

#' Exibindo um estado vazio com mensagem amigável
#'
#' @param mensagem Texto explicativo.
#' @param icone Nome do ícone do fontawesome (opcional).
#' @return Elemento HTML do estado vazio.
#' @noRd
estado_vazio <- function(mensagem, icone = NULL) {
  htmltools::tags$div(
    class = "estado-vazio",
    if (!is.null(icone)) {
      # Envolvendo o ícone do fontawesome em um contêiner com classe de estilo
      htmltools::tags$span(class = "estado-vazio__icone", fontawesome::fa(icone))
    },
    htmltools::tags$p(class = "estado-vazio__texto", mensagem)
  )
}

#' Montando o rodapé institucional do painel
#'
#' @return Elemento HTML do rodapé.
#' @noRd
rodape_ibisma <- function() {
  # Definindo os logos e seus textos alternativos para o rodapé
  realizacao <- c(
    "logos/realizacao/logo_oobr.png" = "Observatório Obstétrico Brasileiro",
    "logos/realizacao/logo_fiocruz.png" = "Fiocruz",
    "logos/realizacao/logo_ufes.png" = "Universidade Federal do Espírito Santo",
    "logos/realizacao/logo_ufrj.png" = "Universidade Federal do Rio de Janeiro",
    "logos/realizacao/logo_medicina_usp.png" = "Faculdade de Medicina da USP"
  )
  financiadores <- c(
    "logos/financiadores/logo_bill_melinda.png" = "Bill & Melinda Gates Foundation",
    "logos/financiadores/logo_cnpq.png" = "CNPq",
    "logos/financiadores/logo_fapes.png" = "FAPES",
    "logos/financiadores/logo_ms.png" = "Ministério da Saúde"
  )

  # Montando uma faixa de logos a partir de um vetor nomeado
  faixa_logos <- function(logos) {
    htmltools::tags$div(
      class = "rodape-logos",
      lapply(names(logos), function(caminho) {
        htmltools::tags$img(
          src = paste0("www/", caminho),
          alt = logos[[caminho]],
          class = "rodape-logo"
        )
      })
    )
  }

  htmltools::tags$footer(
    class = "rodape-painel",
    htmltools::tags$div(
      class = "painel-container",
      htmltools::tags$div(
        class = "rodape-grade",
        htmltools::tags$div(
          class = "rodape-bloco",
          htmltools::tags$h3(class = "rodape-titulo", "Realização"),
          faixa_logos(realizacao)
        ),
        htmltools::tags$div(
          class = "rodape-bloco",
          htmltools::tags$h3(class = "rodape-titulo", "Financiamento"),
          faixa_logos(financiadores)
        )
      ),
      htmltools::tags$p(
        class = "rodape-nota",
        "Os dados apresentados são uma base de exemplo para desenvolvimento do painel. ",
        "O IBISMA é um índice relativo: seus valores representam o percentil de ",
        "vulnerabilidade dos municípios brasileiros, não uma medida absoluta."
      )
    )
  )
}
