# =============================================================================
# 08_evaluate.R — cobertura, validación manual y métricas
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

sentiments <- read_rds(results_path("sentiment.rds"))
corpus_id <- sentiments$corpus_id[[1]] %||% NA
handle <- audit_start(con, "evaluate", corpus_id = corpus_id)

cov <- dictionary_coverage(sentiments)
manual <- evaluate_against_manual(con, corpus_id, sentiments)

out <- list(coverage = cov, manual = manual)
save_rds(out, results_path("evaluation.rds"))
write_json_utf8(out, results_path("evaluation.json"))

cat(sprintf("Cobertura del diccionario: %.1f%%\n", 100 * cov$coverage))
cat(sprintf("Mensajes indeterminados:   %.1f%%\n", 100 * cov$indeterminate))
if (!isTRUE(manual$available)) {
  cat("Validación supervisada: NO disponible (faltan etiquetas manuales).\n")
} else {
  cat("Etiquetas manuales:", manual$n, "\n"); print(manual$metrics)
}

audit_finish(con, handle, status = "completed", n_processed = nrow(sentiments))
cat("OK 08_evaluate\n")
