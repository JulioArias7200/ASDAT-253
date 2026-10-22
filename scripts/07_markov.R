# =============================================================================
# 07_markov.R — transiciones de estado emocional (cadena de Markov)
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(); cfg <- bs$cfg
con <- db_connect(cfg = cfg); on.exit(db_disconnect(con), add = TRUE)

messages <- read_rds(processed_path("messages_clean.rds"))
sentiments <- read_rds(results_path("sentiment.rds"))

df <- join_sentiment(messages, sentiments)
handle <- audit_start(con, "markov", corpus_id = messages$corpus_id[[1]] %||% NA,
                      params = list(order = cfg_get(cfg, "markov", "order")))

mk <- markov_analysis(df, cfg, per_user = isTRUE(cfg_get(cfg, "markov", "per_user")))
r <- mk$results[[1]]

cat("Matriz de transición P[origen -> destino]:\n"); print(round(r$P, 3))
cat("Distribución estacionaria:\n"); print(round(r$stationary, 3))
cat("Permanencia media (mensajes):\n"); print(round(r$residence, 2))
cat("Recuperación desde negativo:", r$recovery, "\n")

save_rds(mk, results_path("markov.rds"))
write_json_utf8(list(states = mk$states,
                     transition = r$P,
                     stationary = r$stationary,
                     residence = r$residence,
                     recovery = r$recovery),
                results_path("markov.json"))
save_plot(plot_transition_heatmap(r$P, mk$states),
          proj_path("reports", "figures", "transicion_markov.png"))

audit_finish(con, handle, status = "completed", n_processed = r$n)
cat("OK 07_markov\n")
