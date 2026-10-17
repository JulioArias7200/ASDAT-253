# =============================================================================
# 01_import.R — importa el corpus JSON de Telegram y lo persiste
# Uso: Rscript scripts/01_import.R
# =============================================================================

source("R/bootstrap.R")
bs <- bootstrap()
cfg <- bs$cfg
con <- db_connect(cfg = cfg)
on.exit(db_disconnect(con), add = TRUE)

json_rel <- cfg_get(cfg, "import", "telegram_json")
json_path <- if (file.exists(json_rel)) json_rel else proj_path(json_rel)
cat("Importando:", json_path, "\n")

res <- persist_telegram_import(json_path, con, cfg, json_rel = json_rel)
rep <- res$report

cat(sprintf("Importados: %d | rechazados: %d | duplicados: %d | total crudo: %d\n",
            res$n_inserted, rep$n_rejected, rep$n_duplicated, res$n_total))
cat("Corpus id:", res$corpus_id, "| batch id:", res$batch_id, "\n")
cat("OK 01_import\n")
