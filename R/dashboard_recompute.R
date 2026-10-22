# =============================================================================
# dashboard_recompute.R — recálculo de resultados del dashboard en caliente
# Se usa cuando un grupo activa su propio diccionario: se reanalizan todos los
# mensajes con el diccionario nuevo y se actualizan los módulos del dashboard.
# =============================================================================

#' Recalcula sentimiento, agregados temporales, transiciones y evaluación
#' con el diccionario activo, escribiendo los artefactos (con respaldo previo).
#' @param progress función opcional de progreso; recibe `(stage, value)`.
#' @export
recompute_dashboard_results <- function(cfg = load_config(), con = NULL,
                                        progress = NULL) {
  messages <- read_rds(processed_path("messages_clean.rds"))
  dict <- load_dictionary(cfg = cfg)
  dict_ver <- dictionary_version(cfg = cfg)
  step <- function(stage, value) if (!is.null(progress)) progress(stage, value)

  # Respaldo del análisis anterior en data/results/backups/
  stamp <- gsub("[^0-9]", "", now_utc())
  bdir <- proj_path("data", "results", "backups")
  dir.create(bdir, recursive = TRUE, showWarnings = FALSE)
  for (f in c("sentiment.rds", "temporal.rds", "markov.rds", "evaluation.rds")) {
    p <- results_path(f)
    if (file.exists(p)) {
      file.copy(p, file.path(bdir, paste0(stamp, "_", f)), overwrite = TRUE)
    }
  }

  handle <- if (!is.null(con)) {
    audit_start(con, "recompute", corpus_id = messages$corpus_id[[1]] %||% NA,
                dictionary_version = dict_ver,
                params = c(cfg_get(cfg, "sentiment"), origen = "dashboard"))
  } else NULL
  finish <- function(status, ...) {
    if (!is.null(handle)) {
      tryCatch(audit_finish(con, handle, status = status, ...),
               error = function(e) invisible(NULL))
    }
  }

  # 1) Sentimiento con el diccionario activo
  step("Sentimiento", 0.35)
  res <- analyze_sentiment(messages, dict, cfg)
  save_rds(res, results_path("sentiment.rds"))
  write_json_utf8(list(dictionary_version = dict_ver,
                       coverage = dictionary_coverage(res)),
                  results_path("sentiment_summary.json"))

  # 2) Temporal (día/semana/mes)
  step("Temporal", 0.55)
  df <- join_sentiment(messages, res)
  daily <- rolling_polarity(temporal_aggregate(df, "day"), window = 7)
  weekly <- temporal_aggregate(df, "week")
  monthly <- temporal_aggregate(df, "month")
  temporal <- list(daily = daily, weekly = weekly, monthly = monthly)
  save_rds(temporal, results_path("temporal.rds"))

  # 3) Transiciones de estado
  step("Transiciones", 0.7)
  markov <- markov_analysis(df, cfg, per_user = isTRUE(cfg_get(cfg, "markov", "per_user")))
  save_rds(markov, results_path("markov.rds"))

  # 4) Evaluación (cobertura y validación manual si existe)
  step("Evaluación", 0.85)
  manual <- if (!is.null(con)) {
    tryCatch(evaluate_against_manual(con, messages$corpus_id[[1]] %||% NA, res),
             error = function(e) NULL)
  } else NULL
  evaluation <- list(coverage = dictionary_coverage(res), manual = manual)
  save_rds(evaluation, results_path("evaluation.rds"))
  write_json_utf8(evaluation, results_path("evaluation.json"))

  finish("completed", n_processed = nrow(res),
         artifacts = c("data/results/sentiment.rds", "data/results/temporal.rds",
                       "data/results/markov.rds", "data/results/evaluation.rds"))
  step("Listo", 1)

  list(sentiments = res, temporal = temporal, markov = markov,
       evaluation = evaluation, dictionary = dict, dictionary_version = dict_ver,
       n_messages = nrow(messages), n_analyzed = nrow(res))
}

#' Vuelca los resultados recalculados en los datos del dashboard (reactiveValues).
#' @export
apply_dashboard_recompute <- function(data, recomp) {
  if (is.null(recomp)) return(invisible(FALSE))
  keys <- intersect(names(recomp), c("sentiments", "temporal", "markov",
                                     "evaluation", "dictionary", "dictionary_version"))
  for (k in keys) data[[k]] <- recomp[[k]]
  invisible(TRUE)
}

#' Envía el estado agregado del avatar emocional a un host concreto.
#' @param n_messages número de mensajes del filtro (para la leyenda).
#' @export
send_avatar_state <- function(session, host_id, totals, n_messages = 0L,
                              emotion = NULL, label_fn = NULL) {
  props <- as.list(totals / sum(totals))
  dom <- if (!is.null(emotion)) emotion else names(totals)[which.max(totals)]
  lab <- if (!is.null(label_fn)) label_fn(dom) else dom
  session$sendCustomMessage("avatar_state", list(
    emotion = dom, label = lab, n = as.integer(n_messages),
    proportions = props, target = host_id))
}
