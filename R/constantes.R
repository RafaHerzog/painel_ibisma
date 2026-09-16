# =============================================================================
#   CONSTANTES DO PAINEL IBISMA
#   Reúne o dicionário do índice (blocos, medidas e categorias), os níveis de
#   geração/distribuição do painel, as rampas de cores e os limiares de dados.
#   Aqui só moram valores estáticos: as funções de cor vivem em R/fct_cores.R
#   e a consulta dos nomes de exibição em R/fct_dados.R.
#   Manter tudo aqui evita valores espalhados pelo código e facilita a evolução.
# =============================================================================

# -----------------------------------------------------------------------------
#   CORES INSTITUCIONAIS E DE IDENTIFICAÇÃO
# -----------------------------------------------------------------------------

# Definindo as cores institucionais reaproveitadas no painel
# Usada em: app_ui.R (tema), fct_cores.R (texto de contraste) e desenhos do mapa,
# do ranking e dos gráficos (contornos e eixos).
COR_AZUL_ESCURO <- "#0A1E3C"
# As cores abaixo entram apenas na construção das rampas de PALETAS
COR_AZUL_CLARO  <- "#32A0FF"
COR_AZUL_MEDIO  <- "#1E5AA0"
COR_AMARELO     <- "#FAC80F"
COR_VERDE       <- "#41BE3C"
COR_CORAL       <- "#E4572E"
COR_TEAL        <- "#00A6A6"

# Definindo a cor de identificação do índice
# Usada em: app_ui.R (tema), fct_cores.R (rampa do índice) e testes das rampas.
COR_IBISMA <- "#4B1D73"

# Definindo a cor usada para municípios e anos sem dado disponível
# Usada em: fct_cores.R (categoria ausente) e fct_mapa.R (legenda).
COR_SEM_DADOS <- "#D8DCE3"

# -----------------------------------------------------------------------------
#   CATEGORIAS E RAMPAS DE COR
# -----------------------------------------------------------------------------

# Definindo os rótulos ordenados das cinco categorias de vulnerabilidade
# Usada em: tabelas anuais (níveis do fator), fct_cores.R (nomes dos tons de
# PALETAS), mod_onde.R (seletor de medida) e legenda do mapa.
CATEGORIAS <- c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto")

# Definindo as rampas de cinco tons de cada medida, na ordem das categorias
# A cor de identificação fica no tom central dos blocos e no tom mais alto do índice
# Usada em: fct_cores.R (cores de categoria e misturas), mod_onde.R (legenda) e
# testes das rampas.
PALETAS <- list(
  indice_final = stats::setNames(
    c("#D5C2E8", "#B592D6", "#915EC4", "#6B35A3", COR_IBISMA),
    CATEGORIAS
  ),
  bloco1 = stats::setNames(
    c("#FDEAA4", "#FCD857", COR_AMARELO, "#AD921D", "#655F2B"),
    CATEGORIAS
  ),
  bloco2 = stats::setNames(
    c("#B7E6B5", "#7AD276", COR_VERDE, "#2F8B3C", "#1F5B3C"),
    CATEGORIAS
  ),
  bloco3 = stats::setNames(
    c("#B1DBFF", "#70BCFF", COR_AZUL_CLARO, "#2576C1", "#194F86"),
    CATEGORIAS
  ),
  bloco4 = stats::setNames(
    c("#F5BFB0", "#EC896D", COR_CORAL, "#9E4532", "#5D3437"),
    CATEGORIAS
  ),
  bloco5 = stats::setNames(
    c("#AAC0DB", "#628CBC", COR_AZUL_MEDIO, "#184780", "#123562"),
    CATEGORIAS
  ),
  bloco6 = stats::setNames(
    c("#9EDDDD", "#4CC1C1", COR_TEAL, "#037A84", "#065264"),
    CATEGORIAS
  )
)

# -----------------------------------------------------------------------------
#   DICIONÁRIO DAS MEDIDAS
# -----------------------------------------------------------------------------

# Definindo as sete medidas na ordem canônica do painel
# A ordem manda nas colunas das séries, nos sete gráficos e nos seletores
# Usada em: fct_dados.R (colunas das séries), fct_graficos.R (sete cartões e
# eixos), fct_dados.R (nome_medida) e mod_como.R (laço dos gráficos).
MEDIDAS <- data.frame(
  medida = c(
    "indice_final",
    "bloco1",
    "bloco2",
    "bloco3",
    "bloco4",
    "bloco5",
    "bloco6"
  ),
  nome = c(
    "IBISMA",
    "Social",
    "Planejamento Reprodutivo",
    "Pré-natal",
    "Parto",
    "Sistema de saúde",
    "Clima"
  ),
  rotulo = c(
    "IBISMA",
    "Bloco Social",
    "Bloco Planejamento Reprodutivo",
    "Bloco Pré-natal",
    "Bloco Parto",
    "Bloco Sistema de saúde",
    "Bloco Clima"
  ),
  stringsAsFactors = FALSE
)

# Derivando a cor de identificação do tom central dos blocos e do topo do índice
# Usada em: fct_cores.R (cor_medida).
MEDIDAS$cor <- vapply(MEDIDAS$medida, function(medida) {
  tom <- if (identical(medida, "indice_final")) "Muito alto" else "Médio"
  unname(PALETAS[[medida]][tom])
}, character(1))

# Definindo os seis blocos como o recorte das medidas sem o índice
# Usada em: mod_como.R (pétalas e eixos), fct_graficos.R (grade da evolução) e
# fct_esqueleto.R (esqueleto da grade).
BLOCOS <- MEDIDAS[MEDIDAS$medida != "indice_final", ]
row.names(BLOCOS) <- NULL

# Definindo os percentis que cortam as cinco categorias na geração dos dados
# Usada em: data-raw/cria_rda.R (níveis das categorias de cada ano).
CORTES_PERCENTIS <- c(0.2, 0.4, 0.6, 0.8)
