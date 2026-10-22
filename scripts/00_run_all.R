# =============================================================================
# 00_run_all.R — ejecuta el pipeline completo en orden (V1 + V2)
# Uso:
#   Rscript scripts/00_run_all.R            # todas las etapas
#   Rscript scripts/00_run_all.R 05n 06t    # solo las etapas cuyo nombre contenga
#                                           # alguno de los patrones indicados
# Cada etapa se ejecuta en un proceso R independiente para aislar su estado.
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)

etapas <- c(
  "01_import.R",
  "02_validate.R",
  "03_clean.R",
  "04_sentiment.R",
  "05_topics.R",
  "05n_ngrams.R",
  "05f_features.R",
  "06_temporal.R",
  "06t_tfidf.R",
  "07_markov.R",
  "08_evaluate.R",
  "09_generate_report.R"
)

if (length(args)) {
  keep <- Reduce(`|`, lapply(args, function(p) grepl(p, etapas, fixed = TRUE)))
  etapas <- etapas[keep]
}

if (!length(etapas)) stop("Ninguna etapa coincide con los patrones dados")

rscript <- file.path(R.home("bin"), "Rscript")
for (etapa in etapas) {
  message("==> ", etapa)
  status <- system2(rscript, file.path("scripts", etapa))
  if (!identical(status, 0L)) stop("Falló la etapa: ", etapa)
}
message("Pipeline completo sin errores")
