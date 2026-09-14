# Otimizando os logos institucionais do rodapé para o tamanho de exibição
# Executar na raiz do pacote: Rscript data-raw/otimiza_logos.R
# Cada PNG é recortado da moldura transparente, ganha uma borda uniforme e é
# reduzido ao tamanho máximo de exibição em telas de alta densidade.
# Logos negativos que vierem com o desenho escuro são convertidos para branco.
# Rodar de novo sobre os arquivos já otimizados é seguro: o resultado é estável.

suppressPackageStartupMessages(library(magick))

# Definindo as pastas dos logos que aparecem no rodapé do painel
pastas <- c(
  "inst/app/www/logos/realizacao",
  "inst/app/www/logos/financiadores"
)

# Definindo o limite em pixels, cerca de quatro vezes a exibição no painel
largura_maxima <- 480
altura_maxima <- 200

# Definindo a margem transparente acrescentada ao redor de cada logo
margem <- "8x8"

# Verificando se o desenho é escuro sobre o fundo transparente
desenho_escuro <- function(caminho) {
  pixels <- png::readPNG(caminho)

  # Considerando apenas as imagens RGBA, o formato dos logos baixados
  if (length(dim(pixels)) != 3 || dim(pixels)[3] != 4) return(FALSE)

  # Olhando apenas os pixels visíveis do desenho
  visivel <- pixels[, , 4] > 0.05
  if (!any(visivel)) return(FALSE)

  mean(pixels[, , 1:3][visivel]) < 0.5
}

# Percorrendo cada pasta com logos do rodapé
for (pasta in pastas) {
  arquivos <- list.files(pasta, pattern = "[.]png$", full.names = TRUE)

  # Percorrendo cada arquivo de logo da pasta
  for (arquivo in arquivos) {
    # Lendo o arquivo original
    imagem <- magick::image_read(arquivo)

    # Deixando em branco os logos negativos que vierem com o desenho escuro
    if (grepl("_negativo", arquivo) && desenho_escuro(arquivo)) {
      imagem <- magick::image_colorize(imagem, opacity = 100, color = "white")
      cat("Convertendo para branco:", basename(arquivo), "\n")
    }

    # Recortando a sobra transparente para o desenho ocupar a caixa toda
    imagem <- magick::image_trim(imagem)

    # Acrescentando uma margem transparente uniforme em todos os lados
    imagem <- magick::image_border(imagem, "none", margem)

    # Reduzindo a imagem dentro do limite, preservando a proporção
    imagem <- magick::image_resize(
      imagem,
      sprintf("%dx%d", largura_maxima, altura_maxima)
    )

    # Gravando o resultado por cima do arquivo original
    magick::image_write(imagem, arquivo, format = "png")

    # Informando o tamanho final de cada arquivo
    tamanho_kb <- file.size(arquivo) / 1024
    cat(sprintf("%-34s %6.1f KB\n", basename(arquivo), tamanho_kb))
  }
}
