# =============================================================================
# 05f_features.R — características lingüísticas superficiales (V2)
# Se calculan sobre el texto original (conserva mayúsculas y signos).
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
text_col <- cfg_get(cfg, "features", "text_col") %||% "text_original"
if (!text_col %in% names(messages)) text_col <- "text_original"

handle <- audit_start(
  con, "features_v2", corpus_id = messages$corpus_id[[1]] %||% NA,
  params = list(text_col = text_col)
)

feats <- tryCatch(
  linguistic_features_messages(messages, text_col = text_col, cfg = cfg),
  error = function(e) { audit_error(con, handle, e); stop(e) }
)

# Añade fecha para permitir análisis por periodo sin re-unir tablas
dates <- as.POSIXct(messages$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ",
                    tz = "UTC")
feats$date <- as.Date(dates)

summary_tbl <- feature_summary(feats)
print(summary_tbl)

save_rds(list(features = feats, summary = summary_tbl, text_col = text_col,
              n_messages = nrow(feats), generated_at = now_utc()),
         results_path(file.path("v2", "linguistic_features.rds")))

audit_finish(con, handle, status = "completed", n_processed = nrow(feats),
             artifacts = "data/results/v2/linguistic_features.rds")
cat("OK 05f_features\n")
