# =============================================================================
# 09_generate_report.R — figuras, tablas y artefactos del informe
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
sentiments <- read_rds(results_path("sentiment.rds"))
temporal <- read_rds(results_path("temporal.rds"))
markov <- read_rds(results_path("markov.rds"))
topics <- tryCatch(read_rds(results_path("topics.rds")), error = function(e) NULL)

handle <- audit_start(con, "report", corpus_id = messages$corpus_id[[1]] %||% NA)

artifacts <- generate_report_artifacts(
  messages, sentiments, temporal$daily,
  topics_tbl = if (!is.null(topics)) topics$topics else NULL,
  markov = markov, cfg = cfg, con = con, run_id = handle$run_id
)

extra_figs <- generate_extra_figures(messages, sentiments, temporal, topics)
extra_tabs <- generate_extra_tables(messages, sentiments, temporal)
stats <- write_report_stats(messages, sentiments, temporal, topics, markov)
artifacts <- c(artifacts, extra_figs, extra_tabs, stats)

audit_finish(con, handle, status = "completed", n_processed = nrow(sentiments),
             artifacts = artifacts)
cat("Artefactos generados:\n"); print(basename(artifacts))

# Intenta compilar si hay motor disponible
comp <- render_report()
if (isTRUE(comp$ok)) {
  cat("Informe compilado:", comp$pdf, "\n")
  if (length(comp$warnings) && !is.na(comp$warnings[1])) {
    cat("Avisos LaTeX:\n"); print(head(comp$warnings, 10))
  }
} else {
  cat("Compilación:", comp$message %||% "no disponible", "\n")
}
cat("OK 09_generate_report\n")
