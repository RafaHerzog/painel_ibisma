# Lendo a base de exemplo com os valores dos blocos e do índice para 2015 a 2024
df_ibisma <- read.csv("data-raw/databases/base_exemplo_ibisma.csv")

# Verificando se existem duplicatas
janitor::get_dupes(df_ibisma)

# Removendo as duplicatas
df_ibisma <- df_ibisma |>
  dplyr::distinct()

# Lendo uma base auxiliar de municípios
df_aux_municipios <- read.csv("data-raw/databases/tabela_aux_municipios.csv")

## Adionando uma coluna de sigla da UF
df_aux_municipios <- df_aux_municipios |>
  dplyr::mutate(
    sigla_uf = dplyr::case_when(
    uf == "Acre" ~ "AC",
    uf == "Alagoas" ~ "AL",
    uf == "Amapá" ~ "AP",
    uf == "Amazonas" ~ "AM",
    uf == "Bahia" ~ "BA",
    uf == "Ceará" ~ "CE",
    uf == "Distrito Federal" ~ "DF",
    uf == "Espírito Santo" ~ "ES",
    uf == "Goiás" ~ "GO",
    uf == "Maranhão" ~ "MA",
    uf == "Mato Grosso" ~ "MT",
    uf == "Mato Grosso do Sul" ~ "MS",
    uf == "Minas Gerais" ~ "MG",
    uf == "Pará" ~ "PA",
    uf == "Paraíba" ~ "PB",
    uf == "Paraná" ~ "PR",
    uf == "Pernambuco" ~ "PE",
    uf == "Piauí" ~ "PI",
    uf == "Rio de Janeiro" ~ "RJ",
    uf == "Rio Grande do Norte" ~ "RN",
    uf == "Rio Grande do Sul" ~ "RS",
    uf == "Rondônia" ~ "RO",
    uf == "Roraima" ~ "RR",
    uf == "Santa Catarina" ~ "SC",
    uf == "São Paulo" ~ "SP",
    uf == "Sergipe" ~ "SE",
    uf == "Tocantins" ~ "TO",
    TRUE ~ NA_character_
  ),
  .after = "uf"
)

# Enriquecendo a base do IBISMA com informações dos municípios
df_ibisma <- df_ibisma |>
  dplyr::left_join(df_aux_municipios, by = c("codmunres" = "codmun"))

# Criando o RDA
usethis::use_data(df_ibisma, overwrite = TRUE)
