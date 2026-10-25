# Uso:  Rscript scripts/00_preprocesar.R data/raw/result.json [salida] [usuario]
# Acepta Telegram (.json), WhatsApp (.txt) o CSV generico. Escribe mensajes.csv, tokens.csv y bitacora_auto.csv
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Indique el archivo a procesar.")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source, encoding = "UTF-8"))
salida <- if (length(args) >= 2) args[2] else "data/processed"
res <- preprocess_chat(args[1], salida = salida, usuario = if (length(args) >= 3) args[3] else NULL)
print(res$bitacora[, c("paso", "filas_entrada", "filas_salida", "duracion_s")], n = 20)
cat("\nIdioma:", res$idioma$idioma, "| Salida en:", salida, "\n")
