# =============================================================================
# 06t_tfidf.R — TF, IDF y TF-IDF por mensaje (V2)
# Documento = mensaje. Salidas en data/results/v2/.
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
keep <- !is.na(messages$text_norm) & nzchar(messages$text_norm)
texts <- messages$text_norm[keep]
ids <- messages$message_id[keep]
cat("Documentos para TF-IDF:", length(texts), "\n")

td <- cfg_get(cfg, "tfidf")
handle <- audit_start(
  con, "tfidf_v2", corpus_id = messages$corpus_id[[1]] %||% NA,
  params = list(tf_scheme = td$tf_scheme, min_df = td$min_df)
)

res <- tryCatch(
  compute_tfidf(texts, ids = ids, n = 1L, cfg = cfg,
                tf_scheme = td$tf_scheme, min_df = td$min_df),
  error = function(e) { audit_error(con, handle, e); stop(e) }
)

top <- tfidf_top_terms(res, n = td$top)
global <- tfidf_global(res)
print(utils::head(global, 15))

save_rds(list(tfidf = res, top = top, global = global,
              params = list(tf_scheme = td$tf_scheme, min_df = td$min_df,
                            document = "mensaje", idf = "ln(N/df)"),
              n_documents = length(texts), generated_at = now_utc()),
         results_path(file.path("v2", "tfidf.rds")))

if (isTRUE(td$export)) {
  dir.create(dirname(results_path(file.path("v2", "tfidf.csv"))),
             recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(res, results_path(file.path("v2", "tfidf.csv")))
}

audit_finish(con, handle, status = "completed", n_processed = length(texts),
             artifacts = "data/results/v2/tfidf.rds,data/results/v2/tfidf.csv")
cat("OK 06t_tfidf\n")
