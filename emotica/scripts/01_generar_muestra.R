# UNA persona genera la muestra y la comparte por canal privado (no por Git). Los cuatro etiquetan la MISMA hoja.
# Uso: Rscript scripts/01_generar_muestra.R data/processed 100
args <- commandArgs(trailingOnly = TRUE); dir <- if (length(args) >= 1) args[1] else "data/processed"
n <- if (length(args) >= 2) as.integer(args[2]) else 100
invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source, encoding = "UTF-8"))
m <- readr::read_csv(file.path(dir, "mensajes.csv"), col_types = readr::cols(.default = "c"), show_col_types = FALSE)
s <- score_emotions(m)
x <- muestra_para_etiquetar(m, s, n = n)
dir.create("etiquetado", showWarnings = FALSE)
readr::write_csv(x$hoja, "etiquetado/para_etiquetar.csv")
readr::write_csv(x$clave, "etiquetado/clave_motor_NO_ABRIR_antes_de_etiquetar.csv")
cat("Muestra de", nrow(x$hoja), "mensajes en etiquetado/para_etiquetar.csv\n")
