# =============================================================================
#   CONSULTA DOS DADOS PRONTOS DO IBISMA
#   O painel não faz contas sobre a base bruta: lê os arquivos gerados por
#   data-raw/cria_rda.R e devolve os recortes usados pelas seções.
# =============================================================================

# Criando um cache em memória para não reler os arquivos a cada sessão
.ibisma_cache <- new.env(parent = emptyenv())

#' Definindo uma função que obtém a base preparada do IBISMA com cache
#'
#' @return Lista com o cadastro de municípios, os anos e as séries temporais.
#' Usada em: app_server.R (abertura do app), fct_dados.R (internamente) e mod_como.R.
#' @noRd
dados_ibisma <- function() {
  # Lendo o arquivo uma única vez por processo e reutilizando depois
  if (is.null(.ibisma_cache$dados)) {
    dados <- readRDS(app_sys("app", "data", "dados_ibisma.rds"))
    # Apontando a pasta onde ficam as tabelas anuais geradas
    dados$pasta_tabelas <- app_sys("app", "data")
    .ibisma_cache$dados <- dados
  }
  .ibisma_cache$dados
}

#' Definindo uma função que lê a tabela anual em cache
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @return Data frame com uma linha por município e medida.
#' Usada em: fct_dados.R (valores_ano) e mod_como.R (resumo_municipio).
#' @noRd
tabela_ano <- function(dados, ano) {
  # Guardando em memória a tabela de cada ano já lida
  chave <- paste0("tabela_", dados$pasta_tabelas, "_", ano)
  if (!is.null(.ibisma_cache[[chave]])) {
    return(.ibisma_cache[[chave]])
  }

  # Lendo o arquivo gerado por data-raw/cria_rda.R
  arquivo <- file.path(
    dados$pasta_tabelas,
    sprintf("tabela_ano_%d.rds", ano)
  )
  if (!file.exists(arquivo)) {
    stop(
      "Tabela do ano ", ano, " n\u00e3o encontrada. ",
      "Rode data-raw/cria_rda.R para gerar os arquivos."
    )
  }
  .ibisma_cache[[chave]] <- readRDS(arquivo)
  .ibisma_cache[[chave]]
}

#' Definindo uma função que obtém os valores de uma medida em um ano
#'
#' @param dados Lista lida por dados_ibisma().
#' @param ano Ano de referência.
#' @param medida Identificador da medida ("indice_final", "bloco1"...).
#' @return Data frame com uma linha por município, já com categoria e rankings.
#' Usada em: fct_dados.R (municipio_padrao), fct_mapa.R (dados_mapa) e mod_onde.R (ranking).
#' @noRd
valores_ano <- function(dados, ano, medida) {
  # Selecionando a medida desejada dentro da tabela anual
  tabela <- tabela_ano(dados, ano)
  tabela[tabela$medida == medida, ]
}

#' Definindo uma função que descobre o município padrão de abertura do painel
#'
#' @param dados Lista lida por dados_ibisma().
#' @return Código do município mais vulnerável do ano mais recente.
#' Usada em: app_server.R (município de abertura) e mod_como.R (valor inicial do seletor).
#' @noRd
municipio_padrao <- function(dados = dados_ibisma()) {
  # Buscando o município com o maior IBISMA no último ano disponível
  ano <- max(dados$anos)
  base <- valores_ano(dados, ano, "indice_final")
  base$codmunres[which.max(base$valor)]
}

#' Definindo uma função que obtém as séries das sete medidas de um município
#'
#' @param dados Lista lida por dados_ibisma().
#' @param codmunres Código do município.
#' @return Data frame com uma linha por ano e uma coluna por medida.
#' Usada em: mod_como.R (evolução e comparação).
#' @noRd
series_municipio <- function(dados, codmunres) {
  # Selecionando as linhas do município na tabela de séries pronta
  serie <- dados$series[
    dados$series$codmunres == codmunres,
    c("ano", MEDIDAS$medida)
  ]
  row.names(serie) <- NULL
  serie
}

#' Definindo uma função que verifica se uma série tem algum valor para desenhar
#'
#' @param series Data frame retornado por series_municipio().
#' @return TRUE quando existe pelo menos um valor entre as sete medidas.
#' Usada em: mod_como.R (evolução e comparação).
#' @noRd
series_tem_valor <- function(series) {
  any(!is.na(series[, MEDIDAS$medida]))
}

#' Definindo uma função que obtém o nome de um município pelo código
#'
#' @param dados Lista lida por dados_ibisma().
#' @param codmunres Código do município.
#' @return Nome do município com a sigla da UF.
#' Usada em: mod_como.R (evolução e identificação dos gráficos).
#' @noRd
nome_municipio <- function(dados, codmunres) {
  info <- dados$municipios[dados$municipios$codmunres == codmunres, ]
  if (nrow(info) == 0) {
    return("Munic\u00edpio")
  }
  paste0(info$municipio[1], " (", info$sigla_uf[1], ")")
}

#' Definindo uma função que obtém o nome por extenso de uma unidade da federação
#'
#' @param sigla Sigla da UF.
#' @return Nome da UF correspondente à sigla.
#' Usada em: mod_onde.R (resumo do ranking).
#' @noRd
nome_uf <- function(sigla) {
  # Buscando o nome nos municípios já preparados, sem tocar na base bruta
  ufs <- unique(dados_ibisma()$municipios[, c("sigla_uf", "uf")])
  ufs$uf[match(sigla, ufs$sigla_uf)]
}

#' Definindo uma função que formata números na convenção brasileira
#'
#' @param x Vetor numérico.
#' @param decimais Número de casas decimais.
#' @return Vetor de texto com vírgula decimal.
#' Usada em: fct_dados.R (frase do percentil), fct_mapa.R (tooltip do mapa), fct_perfil.R (valor do índice) e fct_petalas.R (valor no disco).
#' @noRd
formatar_numero <- function(x, decimais = 1) {
  # Evitando erro em valores ausentes e formatando com vírgula
  ifelse(
    is.na(x),
    "Sem dados",
    formatC(x, format = "f", digits = decimais, decimal.mark = ",")
  )
}

#' Definindo uma função que formata inteiros na convenção brasileira
#'
#' @param x Vetor numérico.
#' @return Vetor de texto com separador de milhar.
#' Usada em: fct_dados.R (rótulo de posição) e mod_onde.R (resumo do ranking).
#' @noRd
formatar_inteiro <- function(x) {
  ifelse(
    is.na(x),
    "Sem dados",
    format(round(x), big.mark = ".", decimal.mark = ",", scientific = FALSE)
  )
}

#' Definindo uma função que monta o rótulo de posição no ranking
#'
#' @param posicao Posição do município.
#' @param total Número de municípios avaliados.
#' @return Texto no formato "1.234º de 5.570".
#' Usada em: fct_perfil.R (placar) e fct_petalas.R (tooltip da pétala).
#' @noRd
rotulo_posicao <- function(posicao, total) {
  paste0(formatar_inteiro(posicao), "\u00ba de ", formatar_inteiro(total))
}

#' Definindo uma função que produz a frase de leitura do percentil do IBISMA
#'
#' @param valor Valor do índice na escala 0 a 100.
#' @return Texto explicando o percentil de vulnerabilidade.
#' Usada em: fct_perfil.R (frase do placar).
#' @noRd
frase_percentil <- function(valor) {
  if (is.na(valor)) {
    return("Sem dado disponível para este ano.")
  }
  # Limitando a 99,9% para o município mais vulnerável não chegar a "100%"
  percentil <- min(valor, 99.9)
  # Usando a mesma casa decimal dos demais valores do painel
  paste0(
    "acima de ", formatar_numero(percentil),
    "% dos municípios em insegurança em saúde materna"
  )
}
