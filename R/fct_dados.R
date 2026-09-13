# =============================================================================
#   PREPARAÇÃO E CONSULTA DOS DADOS DO IBISMA
#   Centraliza as transformações da base bruta em formatos prontos para o
#   painel: valores por ano, categorias, rankings, séries e comparações.
# =============================================================================

# Criando um cache em memória para evitar recálculos repetidos por sessão
.ibisma_cache <- new.env(parent = emptyenv())

#' Obtendo a base preparada do IBISMA com cache
#'
#' @return Lista retornada por preparar_dados(), preparada apenas uma vez.
#' @noRd
dados_ibisma <- function() {
  # Preparando a base na primeira chamada e reutilizando no restante do processo
  if (is.null(.ibisma_cache$dados)) {
    .ibisma_cache$dados <- preparar_dados(df_ibisma)
  }
  .ibisma_cache$dados
}

#' Descobrindo o município padrão de abertura do painel
#'
#' @param dados Lista retornada por preparar_dados().
#' @return Código do município mais vulnerável do ano mais recente.
#' @noRd
municipio_padrao <- function(dados = dados_ibisma()) {
  # Buscando o município com o maior IBISMA no último ano disponível
  ano <- max(dados$anos)
  base <- valores_ano(dados, ano, "indice_final")
  base$codmunres[which.max(base$valor)]
}

#' Preparando a base do IBISMA para uso no painel
#'
#' @param df Base bruta (por padrão o objeto df_ibisma disponível em data/).
#' @return Lista com a base larga, a base longa, o cadastro de municípios e os anos.
#' @noRd
preparar_dados <- function(df = df_ibisma) {
  # Guardando a base original com os valores ainda na escala 0 a 1
  largo <- df

  # Convertendo todas as medidas para o formato longo e para a escala 0 a 100
  longo <- tidyr::pivot_longer(
    df,
    cols = c("indice_final", BLOCOS$medida),
    names_to = "medida",
    values_to = "valor"
  )
  longo$valor <- 100 * longo$valor

  # Mantendo no formato longo apenas as colunas necessárias para gráficos
  longo <- longo[, c(
    "ano", "codmunres", "medida", "valor",
    "municipio", "sigla_uf", "uf", "regiao", "r_saude", "macro_r_saude"
  )]
  longo <- longo[order(longo$ano, longo$codmunres, longo$medida), ]
  row.names(longo) <- NULL

  # Montando o cadastro único de municípios usado em filtros e seletores
  municipios <- unique(df[, c(
    "codmunres", "municipio", "sigla_uf", "uf",
    "regiao", "r_saude", "macro_r_saude"
  )])
  municipios <- municipios[order(municipios$municipio), ]
  row.names(municipios) <- NULL

  # Devolvendo a lista com tudo o que as seções do painel precisam
  list(
    largo = largo,
    longo = longo,
    municipios = municipios,
    anos = sort(unique(df$ano))
  )
}

#' Calculando os pontos de corte das cinco categorias
#'
#' @param valores Vetor numérico com os valores de uma medida em um ano.
#' @return Vetor com os quatro quintis que separam as cinco categorias.
#' @noRd
cortes_categorias <- function(valores) {
  # Calculando os quintis da distribuição, ignorando valores ausentes
  unname(stats::quantile(valores, probs = PROBS_CORTES, na.rm = TRUE))
}

#' Classificando valores nas cinco categorias de vulnerabilidade
#'
#' @param valores Vetor numérico com os valores a classificar.
#' @param cortes Vetor com os quatro pontos de corte das categorias.
#' @return Fator ordenado de "Muito baixo" a "Muito alto", com NA nos ausentes.
#' @noRd
categorizar <- function(valores, cortes) {
  # Localizando a faixa de cada valor; o findInterval tolera cortes repetidos
  posicoes <- findInterval(valores, vec = cortes)
  # Convertendo a faixa no fator ordenado das cinco categorias
  factor(
    CATEGORIAS[posicoes + 1],
    levels = CATEGORIAS,
    ordered = TRUE
  )
}

#' Montando a tabela anual com todas as medidas, categorias e rankings
#'
#' @param dados Lista retornada por preparar_dados().
#' @param ano Ano de referência.
#' @return Data frame com uma linha por município e medida.
#' @noRd
tabela_ano <- function(dados, ano) {
  # Usando o cache para não recalcular o mesmo ano várias vezes
  chave <- paste0("ano_", ano)
  if (!is.null(.ibisma_cache[[chave]])) {
    return(.ibisma_cache[[chave]])
  }

  # Calculando valores, categorias e posições para cada medida do ano
  tabela <- lapply(MEDIDAS$medida, function(m) {
    # Filtrando as linhas do ano e da medida corrente
    base <- dados$longo[dados$longo$ano == ano & dados$longo$medida == m, ]

    # Calculando cortes e categorias com base na distribuição do ano
    cortes <- cortes_categorias(base$valor)
    base$categoria <- categorizar(base$valor, cortes)

    # Ranqueando nacionalmente (posição 1 = município mais vulnerável)
    base$pos_nac <- rank(-base$valor, ties.method = "min", na.last = "keep")
    base$total_nac <- sum(!is.na(base$valor))

    # Ranqueando dentro da UF de cada município
    base$pos_uf <- stats::ave(
      -base$valor,
      base$sigla_uf,
      FUN = function(v) rank(v, ties.method = "min", na.last = "keep")
    )
    base$total_uf <- stats::ave(
      !is.na(base$valor),
      base$sigla_uf,
      FUN = sum
    )

    base
  })
  tabela <- do.call(rbind, tabela)
  row.names(tabela) <- NULL

  # Guardando o resultado no cache e devolvendo a tabela
  .ibisma_cache[[chave]] <- tabela
  tabela
}

#' Obtendo os valores de uma medida em um ano
#'
#' @param dados Lista retornada por preparar_dados().
#' @param ano Ano de referência.
#' @param medida Identificador da medida ("indice_final", "bloco1"...).
#' @return Data frame com uma linha por município, já com categoria e rankings.
#' @noRd
valores_ano <- function(dados, ano, medida) {
  # Selecionando a medida desejada dentro da tabela anual
  tabela <- tabela_ano(dados, ano)
  tabela[tabela$medida == medida, ]
}

#' Calculando a mediana de referência do Brasil e da UF
#'
#' @param dados Lista retornada por preparar_dados().
#' @param medida Identificador da medida.
#' @param ano Ano de referência.
#' @param uf Sigla da UF para a mediana estadual (opcional).
#' @return Vetor nomeado com as medianas do Brasil e da UF.
#' @noRd
mediana_referencia <- function(dados, medida, ano, uf = NULL) {
  # Filtrando os valores da medida no ano desejado
  base <- dados$longo[dados$longo$ano == ano & dados$longo$medida == medida, ]

  # Calculando a mediana nacional e, quando pedido, a estadual
  brasil <- stats::median(base$valor, na.rm = TRUE)
  mediana_uf <- if (!is.null(uf)) {
    stats::median(base$valor[base$sigla_uf == uf], na.rm = TRUE)
  } else {
    NA_real_
  }
  c(brasil = brasil, uf = mediana_uf)
}

#' Montando o resumo completo de um município em um ano
#'
#' @param dados Lista retornada por preparar_dados().
#' @param codmunres Código do município.
#' @param ano Ano de referência.
#' @return Lista com identificação, valores, categorias e posições no ranking.
#' @noRd
resumo_municipio <- function(dados, codmunres, ano) {
  # Reunindo as linhas do município em todas as medidas do ano
  tabela <- tabela_ano(dados, ano)
  linhas <- tabela[tabela$codmunres == codmunres, ]

  # Identificando o município a partir das próprias linhas
  info <- dados$municipios[dados$municipios$codmunres == codmunres, ]
  if (nrow(info) == 0 || nrow(linhas) == 0) {
    return(NULL)
  }

  # Separando a linha do índice final e a dos seis blocos na ordem configurada
  linha_indice <- linhas[linhas$medida == "indice_final", ]
  blocos <- linhas[match(BLOCOS$medida, linhas$medida), ]
  blocos$nome <- nome_medida(blocos$medida)
  blocos$cor <- cor_medida(blocos$medida)

  # Montando a lista final consumida pelo módulo de perfil
  list(
    codmunres = codmunres,
    municipio = info$municipio,
    sigla_uf = info$sigla_uf,
    uf = info$uf,
    regiao = info$regiao,
    r_saude = info$r_saude,
    macro_r_saude = info$macro_r_saude,
    valor = linha_indice$valor,
    categoria = as.character(linha_indice$categoria),
    pos_nac = linha_indice$pos_nac,
    total_nac = linha_indice$total_nac,
    pos_uf = linha_indice$pos_uf,
    total_uf = linha_indice$total_uf,
    blocos = blocos
  )
}

#' Montando as séries das sete medidas de um município
#'
#' @param dados Lista retornada por preparar_dados().
#' @param codmunres Código do município.
#' @return Data frame com uma linha por ano e uma coluna por medida.
#' @noRd
series_municipio <- function(dados, codmunres) {
  # Filtrando as observações do município em todas as medidas
  base <- dados$longo[dados$longo$codmunres == codmunres, ]
  base <- base[!duplicated(base[c("ano", "medida")]), ]

  # Abrindo as medidas em colunas para desenhar as sete linhas juntas
  larga <- tidyr::pivot_wider(
    base[, c("ano", "medida", "valor")],
    names_from = "medida",
    values_from = "valor"
  )

  # Garantindo que todos os anos e medidas apareçam, mesmo sem dado
  anos <- data.frame(ano = dados$anos)
  serie <- merge(anos, larga, by = "ano", all.x = TRUE)
  faltantes <- setdiff(MEDIDAS$medida, names(serie))
  serie[faltantes] <- NA_real_
  serie[order(serie$ano), c("ano", MEDIDAS$medida)]
}

#' Verificando se uma série tem algum valor para desenhar
#'
#' @param series Data frame retornado por series_municipio().
#' @return TRUE quando existe pelo menos um valor entre as sete medidas.
#' @noRd
series_tem_valor <- function(series) {
  any(!is.na(series[, MEDIDAS$medida]))
}

#' Gerando as opções de municípios para os seletores
#'
#' @param dados Lista retornada por preparar_dados().
#' @return Vetor nomeado em que os valores são os códigos e os nomes incluem a UF.
#' @noRd
opcoes_municipios <- function(dados) {
  # Montando rótulos legíveis e ordenados alfabeticamente
  municipios <- dados$municipios
  municipios <- municipios[order(municipios$municipio, municipios$sigla_uf), ]
  rotulos <- paste0(municipios$municipio, " (", municipios$sigla_uf, ")")
  stats::setNames(municipios$codmunres, rotulos)
}

#' Obtendo o nome de um município pelo código
#'
#' @param dados Lista retornada por preparar_dados().
#' @param codmunres Código do município.
#' @return Nome do município com a sigla da UF.
#' @noRd
nome_municipio <- function(dados, codmunres) {
  info <- dados$municipios[dados$municipios$codmunres == codmunres, ]
  if (nrow(info) == 0) {
    return("Munic\u00edpio")
  }
  paste0(info$municipio[1], " (", info$sigla_uf[1], ")")
}

#' Gerando as opções de medidas para os seletores
#'
#' @param prefixo_bloco Se TRUE, prefixa os blocos com a palavra "Bloco".
#' @return Vetor nomeado em que os valores são as colunas das medidas.
#' @noRd
opcoes_medidas <- function(prefixo_bloco = TRUE) {
  # Montando rótulos legíveis para a frase de controles do painel
  rotulos <- MEDIDAS$nome
  if (prefixo_bloco) {
    rotulos[rotulos != "IBISMA"] <- paste("Bloco", rotulos[rotulos != "IBISMA"])
  }
  stats::setNames(MEDIDAS$medida, rotulos)
}

#' Listando os anos disponíveis na base
#'
#' @return Vetor ordenado de anos.
#' @noRd
anos_disponiveis <- function() {
  sort(unique(df_ibisma$ano))
}

#' Montando as opções de escopo do ranking (Brasil ou uma UF)
#'
#' @param dados Lista retornada por preparar_dados() (opcional).
#' @return Vetor nomeado em que os valores são "nacional" ou a sigla da UF.
#' @noRd
opcoes_escopo_ranking <- function(dados = NULL) {
  # Obtendo a lista de UFs da base preparada ou diretamente dos dados
  municipios <- if (is.null(dados)) {
    unique(df_ibisma[, c("sigla_uf", "uf")])
  } else {
    unique(dados$municipios[, c("sigla_uf", "uf")])
  }
  municipios <- municipios[order(municipios$uf), ]

  # Acrescentando a opção nacional no início da lista
  stats::setNames(
    c("nacional", municipios$sigla_uf),
    c("Brasil (nacional)", paste0(municipios$uf, " (", municipios$sigla_uf, ")"))
  )
}

#' Obtendo o nome por extenso de uma unidade da federação
#'
#' @param sigla Sigla da UF.
#' @return Nome da UF correspondente à sigla.
#' @noRd
nome_uf <- function(sigla) {
  ufs <- unique(df_ibisma[, c("sigla_uf", "uf")])
  ufs$uf[match(sigla, ufs$sigla_uf)]
}

#' Formatando números na convenção brasileira
#'
#' @param x Vetor numérico.
#' @param decimais Número de casas decimais.
#' @return Vetor de texto com vírgula decimal.
#' @noRd
formatar_numero <- function(x, decimais = 1) {
  # Evitando erro em valores ausentes e formatando com vírgula
  ifelse(
    is.na(x),
    "Sem dados",
    formatC(x, format = "f", digits = decimais, decimal.mark = ",")
  )
}

#' Formatando inteiros na convenção brasileira
#'
#' @param x Vetor numérico.
#' @return Vetor de texto com separador de milhar.
#' @noRd
formatar_inteiro <- function(x) {
  ifelse(
    is.na(x),
    "Sem dados",
    format(round(x), big.mark = ".", decimal.mark = ",", scientific = FALSE)
  )
}

#' Montando o rótulo de posição no ranking
#'
#' @param posicao Posição do município.
#' @param total Número de municípios avaliados.
#' @return Texto no formato "1.234º de 5.570".
#' @noRd
rotulo_posicao <- function(posicao, total) {
  paste0(formatar_inteiro(posicao), "\u00ba de ", formatar_inteiro(total))
}

#' Produzindo a frase de leitura do percentil do IBISMA
#'
#' @param valor Valor do índice na escala 0 a 100.
#' @return Texto explicando o percentil de vulnerabilidade.
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
    "% dos municípios brasileiros em insegurança"
  )
}
