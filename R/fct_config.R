# =============================================================================
#   CONFIGURAÇÕES CENTRAIS DO PAINEL
#   Reúne identificadores, rótulos, cores e parâmetros usados em todo o painel.
#   Manter tudo aqui evita valores espalhados pelo código e facilita a evolução.
# =============================================================================

# Definindo as cores institucionais do Observatório Obstétrico Brasileiro
COR_AZUL_ESCURO <- "#0A1E3C"
COR_AZUL_CLARO  <- "#32A0FF"
COR_AZUL_MEDIO  <- "#1E5AA0"
COR_AMARELO     <- "#FAC80F"
COR_VERDE       <- "#41BE3C"
COR_CORAL       <- "#E4572E"
COR_TEAL        <- "#00A6A6"

# Definindo a cor de referência do IBISMA e a escala de cinco categorias
COR_IBISMA <- "#4B1D73"

# Definindo a paleta sequencial do IBISMA (do menos para o mais vulnerável)
PALETA_IBISMA <- c(
  "Muito baixo" = "#EFE6F7",
  "Baixo"       = "#C9A8E4",
  "Médio"       = "#9F6FD0",
  "Alto"        = "#7239A8",
  "Muito alto"  = "#4B1D73"
)

# Definindo a cor usada para municípios/anos sem dado disponível
COR_SEM_DADOS <- "#D8DCE3"

# Definindo os seis blocos do IBISMA com seus nomes reais e cores de identificação
BLOCOS <- data.frame(
  medida = c("bloco1", "bloco2", "bloco3", "bloco4", "bloco5", "bloco6"),
  nome   = c(
    "Social",
    "Planejamento Reprodutivo",
    "Pré-natal",
    "Parto",
    "Sistema de saúde",
    "Clima"
  ),
  cor = c(
    COR_AMARELO,
    COR_VERDE,
    COR_AZUL_CLARO,
    COR_CORAL,
    COR_AZUL_MEDIO,
    COR_TEAL
  ),
  stringsAsFactors = FALSE
)

# Definindo todas as medidas que podem ser exibidas (o índice e os seis blocos)
MEDIDAS <- rbind(
  data.frame(
    medida = "indice_final",
    nome = "IBISMA",
    cor = COR_IBISMA,
    stringsAsFactors = FALSE
  ),
  BLOCOS
)

# Definindo os rótulos ordenados das cinco categorias de vulnerabilidade
CATEGORIAS <- c("Muito baixo", "Baixo", "Médio", "Alto", "Muito alto")

# Definindo os pontos de corte das categorias como quintis da distribuição
PROBS_CORTES <- c(0.2, 0.4, 0.6, 0.8)

# Definindo os níveis de análise geográfica disponíveis no painel
# Para habilitar novos níveis, basta acrescentar linhas com a variável geográfica
# correspondente (ex.: UF = "sigla_uf"; região = "regiao") e disponivel = TRUE
NIVEIS_ANALISE <- data.frame(
  id            = "municipio",
  rotulo        = "municípios",
  singular      = "município",
  variavel_geo  = "codmunres",
  disponivel    = TRUE,
  stringsAsFactors = FALSE
)

# Definindo textos institucionais reaproveitados em várias seções
TITULO_PAINEL      <- "IBISMA"
SUBTITULO_PAINEL   <- "Índice Brasileiro de Insegurança em Saúde Materna"
TEXTO_ESCALA       <- "O IBISMA varia de 0 a 100: quanto maior o valor, maior a insegurança em saúde materna do município."
TEXTO_CATEGORIAS   <- "As cinco categorias são definidas pelos quintis da distribuição dos municípios no ano selecionado."
