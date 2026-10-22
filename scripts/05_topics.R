# =============================================================================
# 05_topics.R — tópicos LDA (quanteda + topicmodels)
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
sentiments <- read_rds(results_path("sentiment.rds"))

# Textos analizables (con texto normalizado no vacío)
keep <- !is.na(messages$text_norm) & nzchar(messages$text_norm)
texts <- messages$text_norm[keep]
message_ids <- messages$message_id[keep]
cat("Documentos para tópicos:", length(texts), "\n")

k <- cfg_get(cfg, "topics", "k")
handle <- audit_start(con, "topics", corpus_id = messages$corpus_id[[1]] %||% NA,
                      params = list(k = k))

fit <- tryCatch(fit_topics(texts, k = k, cfg = cfg),
                error = function(e) { audit_error(con, handle, e); stop(e) })

tt <- topics_table(fit, n = 12)
print(tt)

# Tópico dominante por mensaje
post <- topicmodels::posterior(fit$model)$topics
dominant <- apply(post, 1, which.max)
doc_topic <- data.frame(message_id = message_ids[fit$doc_ids],
                        topic = dominant)

save_rds(list(fit = list(k = fit$k), topics = tt, doc_topic = doc_topic),
         results_path("topics.rds"))
write_json_utf8(list(k = fit$k, topics = lapply(seq_len(nrow(tt)), function(i)
  list(id = tt$topic[i], top_words = strsplit(tt$top_words[i], ", ")[[1]]))),
  results_path("topics_summary.json"))

audit_finish(con, handle, status = "completed", n_processed = length(texts))
cat("OK 05_topics\n")
