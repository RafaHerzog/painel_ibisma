# Preparando a malha geográfica municipal e estadual usada pelo painel IBISMA
# Executar na raiz do pacote: Rscript data-raw/prepara_malha.R
# A malha é simplificada uma única vez e salva como RDS em inst/app/data
# Usando o rmapshaper (instalar com install.packages("rmapshaper"))

suppressPackageStartupMessages({
  library(geobr)
  library(sf)
  library(rmapshaper)
  library(dplyr)
})

# ---------------------------------------------------------------- municípios

# Baixando a malha municipal de origem do geobr (ano de referência 2020)
malha_municipios <- geobr::read_municipality(year = 2020, showProgress = FALSE)

# Criando a chave de 6 dígitos usada pela base do IBISMA (padrão DATASUS)
malha_municipios <- malha_municipios |>
  dplyr::mutate(
    codmunres = as.integer(substr(as.character(code_muni), 1, 6)),
    .before = "geometry"
  ) |>
  # Mantendo apenas as colunas necessárias para o painel
  dplyr::select(codmunres, sigla_uf = abbrev_state, geometry)

# Simplificando cada divisa uma única vez com o rmapshaper, sem abrir fendas
malha_municipios <- rmapshaper::ms_simplify(
  malha_municipios,
  keep = 0.01,
  keep_shapes = TRUE
)

# Convertendo para WGS84, o sistema esperado pelo leaflet
malha_municipios <- sf::st_transform(malha_municipios, 4326)

# Removendo geometrias vazias que possam ter surgido na simplificação
malha_municipios <- malha_municipios[!sf::st_is_empty(malha_municipios), ]

# ---------------------------------------------------------------- unidades da federação

# Baixando e simplificando a malha estadual (usada como contorno sobre o mapa)
malha_ufs <- geobr::read_state(year = 2020, showProgress = FALSE)
malha_ufs <- sf::st_simplify(malha_ufs, dTolerance = 2000)
malha_ufs <- sf::st_transform(malha_ufs, 4326)
malha_ufs <- malha_ufs |>
  dplyr::select(sigla_uf = abbrev_state, geometry)
malha_ufs <- malha_ufs[!sf::st_is_empty(malha_ufs), ]

# ---------------------------------------------------------------- validações

# Verificando a cobertura dos códigos municipais da base do IBISMA
load("data/df_ibisma.rda")
codigos_base <- unique(df_ibisma$codmunres)
codigos_malha <- malha_municipios$codmunres
cob <- mean(codigos_base %in% codigos_malha)
cat("Cobertura da malha:", round(100 * cob, 2), "% dos códigos municipais\n")
if (cob < 1) {
  cat("Códigos sem geometria:\n")
  print(setdiff(codigos_base, codigos_malha))
}

# Verificando se o número de municípios bate com o esperado para o Brasil
cat("Municípios na malha:", nrow(malha_municipios), "\n")
cat("UFs na malha:", nrow(malha_ufs), "\n")

# ---------------------------------------------------------------- salvamento

# Salvando os objetos preparados dentro do app (inst/app/data)
dir.create("inst/app/data", showWarnings = FALSE, recursive = TRUE)
saveRDS(malha_municipios, "inst/app/data/malha_municipios.rds", compress = "xz")
saveRDS(malha_ufs, "inst/app/data/malha_ufs.rds", compress = "xz")

# Reportando o tamanho final dos arquivos gerados
cat("malha_municipios.rds:", format(file.size("inst/app/data/malha_municipios.rds") / 1024^2, units = "MB"), "\n")
cat("malha_ufs.rds:", format(file.size("inst/app/data/malha_ufs.rds") / 1024^2, units = "MB"), "\n")
