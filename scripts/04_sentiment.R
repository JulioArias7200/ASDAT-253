# =============================================================================
# 04_sentiment.R — análisis de sentimiento multietiqueta
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
dict <- load_dictionary(cfg = cfg)
dict_ver <- dictionary_version(cfg = cfg)
cat("Diccionario:", nrow(dict), "términos | versión:", dict_ver, "\n")
vcat <- validate_dictionary(dict); cat("Categorías presentes:", vcat$categories, "/18\n")

corpus_id <- messages$corpus_id[[1]] %||% NA
handle <- audit_start(con, "sentiment", corpus_id = corpus_id,
                      dictionary_version = dict_ver,
                      params = cfg_get(cfg, "sentiment"))

res <- analyze_sentiment(messages, dict, cfg)

# Persistir en SQLite
res_db <- res
res_db$run_id <- handle$run_id
res_db$dictionary_version <- dict_ver
res_db$created_at <- now_utc()
db_insert_sentiment(con, res_db)

save_rds(res, results_path("sentiment.rds"))
write_json_utf8(list(dictionary_version = dict_ver,
                     coverage = dictionary_coverage(res)),
                results_path("sentiment_summary.json"))

audit_finish(con, handle, status = "completed", n_processed = nrow(res))
cat(sprintf("Analizados: %d mensajes\n", nrow(res)))
print(table(res$polarity_label))
cat(sprintf("Cobertura suficiente: %.1f%% | Indeterminados: %.1f%%\n",
            100 * mean(res$evidence_level == "suficiente"),
            100 * mean(res$polarity_label == "indeterminado")))
cat("OK 04_sentiment\n")
