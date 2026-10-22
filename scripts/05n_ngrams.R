# =============================================================================
# 05n_ngrams.R — unigramas, bigramas y n-gramas configurables (V2)
# Salida versionada en data/results/v2/ para no mezclar con resultados de V1.
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
keep <- !is.na(messages$text_norm) & nzchar(messages$text_norm)
texts <- messages$text_norm[keep]
cat("Documentos para n-gramas:", length(texts), "\n")

ng <- cfg_get(cfg, "ngrams")
handle <- audit_start(
  con, "ngrams_v2", corpus_id = messages$corpus_id[[1]] %||% NA,
  params = list(sizes = ng$sizes, min_count = ng$min_count,
                remove_stopwords = ng$remove_stopwords)
)

tab <- tryCatch(
  ngram_table(texts, sizes = ng$sizes, min_count = ng$min_count,
              cfg = cfg, remove_stopwords = ng$remove_stopwords),
  error = function(e) { audit_error(con, handle, e); stop(e) }
)

stopword_cmp <- tryCatch(
  compare_stopword_effect(texts, n = 1L, top = ng$top, cfg = cfg),
  error = function(e) NULL
)

print(utils::head(tab[tab$size == 1, , drop = FALSE], 15))

out <- list(
  table = tab,
  sizes = ng$sizes,
  stopword_comparison = stopword_cmp,
  n_documents = length(texts),
  remove_stopwords = ng$remove_stopwords,
  ngram_sizes = ng$sizes,
  generated_at = now_utc()
)
save_rds(out, results_path(file.path("v2", "ngrams.rds")))

audit_finish(con, handle, status = "completed", n_processed = length(texts),
             artifacts = "data/results/v2/ngrams.rds")
cat("OK 05n_ngrams\n")
