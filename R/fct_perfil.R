# =============================================================================
#   COMPONENTES DO PERFIL DO MUNICÍPIO
#   Monta o palco de um município — identificação, pétalas dos seis blocos e
#   placar do IBISMA — de forma reutilizável para o município principal e para
#   o município de comparação.
# =============================================================================

# Definindo o texto que explica as pétalas e é exibido uma vez acima dos palcos
TEXTO_PETALAS <- paste(
  "Cada pétala representa um bloco do IBISMA: quanto maior a pétala,",
  "maior a insegurança naquele bloco. O ponto escuro marca a mediana",
  "do Brasil."
)

#' Montando o palco de um município
#'
#' @param municipio Linha do cadastro de municípios (nome, UF e território).
#' @param resumo Lista retornada por resumo_municipio() ou NULL sem dado no ano.
#' @param medianas Vetor com a mediana do Brasil por bloco (opcional).
#' @param ano Ano de referência exibido no placar.
#' @param comparado Indica se o palco é o do município de comparação.
#' @param rotulo Rótulo de hierarquia exibido acima do nome (opcional).
#' @return Elemento HTML com o palco completo.
#' @noRd
perfil_palco <- function(municipio, resumo, medianas = NULL, ano,
                         comparado = FALSE, rotulo = NULL) {
  # Reunindo as classes do palco e marcando quando ele é o comparado
  classes <- c("painel-bloco", "painel-bloco--palco")
  if (comparado) {
    classes <- c(classes, "painel-bloco--comparado")
  }

  # Montando a identificação do município a partir do cadastro
  valido <- !is.null(municipio) && nrow(municipio) > 0 && !is.na(municipio$codmunres[1])
  identificacao <- if (!valido) {
    estado_vazio("Selecione um município para ver o perfil.")
  } else {
    htmltools::tagList(
      # Nome e UF em um único destaque, sem elemento separado para a sigla
      htmltools::tags$h3(
        class = "perfil-nome",
        paste0(municipio$municipio[1], ", ", municipio$sigla_uf[1])
      ),
      htmltools::tags$div(
        class = "perfil-metricas",
        metrica_hero("Região", municipio$regiao[1]),
        metrica_hero("Unidade da federação", municipio$uf[1]),
        metrica_hero("Região de saúde", municipio$r_saude[1]),
        metrica_hero("Macrorregião de saúde", municipio$macro_r_saude[1])
      )
    )
  }

  # Montando as pétalas e o placar somente quando houver dado no ano
  corpo <- if (is.null(resumo)) {
    htmltools::tags$div(
      class = "perfil-palco__grafico",
      estado_vazio(
        paste(
          "Este município não possui dados no ano selecionado.",
          "Veja a evolução ao longo do tempo abaixo."
        ),
        icone = "circle-info"
      )
    )
  } else {
    htmltools::tagList(
      htmltools::tags$div(
        class = "perfil-palco__grafico",
        grafico_petalas(resumo$blocos, medianas = medianas)
      ),
      perfil_placar(resumo, ano)
    )
  }

  htmltools::tags$div(
    class = paste(classes, collapse = " "),
    if (!is.null(rotulo)) htmltools::tags$span(class = "palco-rotulo", rotulo),
    identificacao,
    corpo
  )
}

#' Montando o placar do IBISMA de um município
#'
#' @param resumo Lista retornada por resumo_municipio().
#' @param ano Ano de referência exibido no rótulo do valor.
#' @return Elemento HTML com valor, categoria e rankings.
#' @noRd
perfil_placar <- function(resumo, ano) {
  htmltools::tags$div(
    class = "perfil-placar",
    # Valor do IBISMA nomeado, com categoria e leitura do percentil
    htmltools::tags$div(
      class = "perfil-placar__indice",
      htmltools::tags$span(
        class = "perfil-placar__rotulo",
        paste0("IBISMA em ", ano)
      ),
      htmltools::tags$div(
        class = "perfil-indice__linha perfil-indice__linha--centro",
        htmltools::tags$span(
          class = "perfil-indice__valor",
          # Todos os valores do painel são exibidos com uma casa decimal
          formatar_numero(resumo$valor)
        ),
        htmltools::tags$span(class = "perfil-indice__escala", "de 100"),
        badge_categoria(resumo$categoria)
      ),
      htmltools::tags$p(
        class = "perfil-indice__frase",
        frase_percentil(resumo$valor)
      )
    ),
    # Ranking nacional à esquerda do placar
    htmltools::tags$div(
      class = "perfil-placar__ranking perfil-placar__ranking--brasil",
      metrica_hero(
        "Ranking Brasil",
        rotulo_posicao(resumo$pos_nac, resumo$total_nac)
      )
    ),
    # Ranking estadual à direita do placar
    htmltools::tags$div(
      class = "perfil-placar__ranking perfil-placar__ranking--uf",
      metrica_hero(
        paste0("Ranking na UF (", resumo$uf, ")"),
        rotulo_posicao(resumo$pos_uf, resumo$total_uf)
      )
    )
  )
}
