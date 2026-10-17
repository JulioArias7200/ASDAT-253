# =============================================================================
# 02_validate.R — validación estructural del corpus importado
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(interim_path("messages.rds"))
handle <- audit_start(con, "validate", corpus_id = messages$corpus_id[[1]] %||% NA)

val <- validate_messages(messages)
enc <- check_utf8(messages$text_original)

write_json_utf8(list(ok = val$ok, n = val$n, n_duplicates = val$n_duplicates,
                     issues = val$issues, utf8 = enc),
                interim_path("validation_report.json"))

audit_finish(con, handle, status = if (val$ok) "completed" else "failed",
             n_processed = val$n,
             warnings = if (nrow(val$issues)) paste(val$issues$type, collapse = "; ") else NA,
             errors = if (val$ok) NA else "Errores estructurales detectados")

cat(sprintf("Validación: %s | mensajes=%d | duplicados=%d | utf8_ok=%s\n",
            ifelse(val$ok, "OK", "CON ERRORES"), val$n, val$n_duplicates, enc$ok))
print(val$issues)
cat("OK 02_validate\n")
