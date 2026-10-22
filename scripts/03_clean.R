# =============================================================================
# 03_clean.R — limpieza y normalización (conserva original y emojis)
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(interim_path("messages.rds"))
handle <- audit_start(con, "clean", corpus_id = messages$corpus_id[[1]] %||% NA)

cleaned <- clean_messages(messages, cfg)
out <- cleaned$messages
save_rds(out, processed_path("messages_clean.rds"))

# Persistir text_norm en la base
DBI::dbWithTransaction(con, {
  for (i in seq_len(nrow(out))) {
    DBI::dbExecute(con, "UPDATE messages SET text_norm = ? WHERE message_id = ? AND corpus_id = ?",
                   params = list(out$text_norm[[i]], out$message_id[[i]], out$corpus_id[[i]]))
  }
})

audit_finish(con, handle, status = "completed", n_processed = nrow(out))
cat(sprintf("Limpiados: %d mensajes\n", nrow(out)))
cat("Ejemplo original:", out$text_original[[1]], "\n")
cat("Ejemplo normalizado:", out$text_norm[[1]], "\n")
cat("OK 03_clean\n")
