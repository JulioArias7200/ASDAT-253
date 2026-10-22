# =============================================================================
# 06_temporal.R — evolución temporal de polaridad y emociones
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
sentiments <- read_rds(results_path("sentiment.rds"))

df <- join_sentiment(messages, sentiments)
handle <- audit_start(con, "temporal", corpus_id = messages$corpus_id[[1]] %||% NA)

daily <- rolling_polarity(temporal_aggregate(df, "day"), window = 7)
weekly <- temporal_aggregate(df, "week")
monthly <- temporal_aggregate(df, "month")

save_rds(list(daily = daily, weekly = weekly, monthly = monthly),
         results_path("temporal.rds"))

fig_dir <- proj_path("reports", "figures")
save_plot(plot_polarity_temporal(daily), file.path(fig_dir, "polaridad_diaria.png"))
save_plot(plot_volume_temporal(daily), file.path(fig_dir, "volumen_diario.png"))
save_plot(plot_polarity_dist(sentiments), file.path(fig_dir, "distribucion_polaridad.png"))
save_plot(plot_emotion_freq(sentiments), file.path(fig_dir, "frecuencia_emociones.png"))

audit_finish(con, handle, status = "completed", n_processed = nrow(df),
             artifacts = c("reports/figures/polaridad_diaria.png",
                           "reports/figures/volumen_diario.png"))
cat(sprintf("Días con actividad: %d | Semanas: %d | Meses: %d\n",
            nrow(daily), nrow(weekly), nrow(monthly)))
cat("OK 06_temporal\n")
