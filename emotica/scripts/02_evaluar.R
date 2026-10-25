# Uso: Rscript scripts/02_evaluar.R data/processed   (lee etiquetado/hoja_<nombre>.csv de cada integrante)
args <- commandArgs(trailingOnly = TRUE); dir <- if (length(args) >= 1) args[1] else "data/processed"
invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source, encoding = "UTF-8"))
m <- readr::read_csv(file.path(dir, "mensajes.csv"), col_types = readr::cols(.default = "c"), show_col_types = FALSE)
s <- score_emotions(m)
fs <- list.files("etiquetado", pattern = "^hoja_.*\\.csv$", full.names = TRUE)
if (length(fs) == 0) stop("Guarde cada hoja etiquetada como etiquetado/hoja_<nombre>.csv")
hojas <- setNames(lapply(fs, readr::read_csv, col_types = readr::cols(.default = "c"), show_col_types = FALSE),
                  sub("^hoja_|\\.csv$", "", basename(fs)))
if (length(hojas) >= 2) { cat("\n== Acuerdo entre etiquetadores (kappa por pares) ==\n"); print(as.data.frame(acuerdo_etiquetadores(hojas))) }
for (n in names(hojas)) { ev <- evaluar_motor(s, hojas[[n]]); ci <- correlacion_intensidad(s, hojas[[n]])
  cat("\n==", n, "==  global:", paste(names(ev$global), ev$global, collapse = " | "), "| spearman intensidad:", ci$spearman, "\n")
  print(as.data.frame(ev$por_emocion)) }
