# =============================================================================
# dashboard_data.R — carga de artefactos para el dashboard
# =============================================================================

#' Carga todos los artefactos disponibles para el dashboard.
#' Tolera ausencias (devuelve NULL y avisos).
#' @export
load_dashboard_data <- function(cfg = load_config()) {
  out <- list(warnings = character(0))
  rd <- function(p, what) {
    if (file.exists(p)) tryCatch(readRDS(p), error = function(e) {
      out$warnings <<- c(out$warnings, paste("No se pudo leer", what, ":", conditionMessage(e)))
      NULL
    }) else { out$warnings <<- c(out$warnings, paste("Falta", what)); NULL }
  }
  out$sentiments <- rd(results_path("sentiment.rds"), "sentiment.rds")
  out$messages <- rd(processed_path("messages_clean.rds"), "messages_clean.rds")
  out$temporal <- rd(results_path("temporal.rds"), "temporal.rds")
  out$topics <- rd(results_path("topics.rds"), "topics.rds")
  out$markov <- rd(results_path("markov.rds"), "markov.rds")
  out$evaluation <- rd(results_path("evaluation.rds"), "evaluation.rds")
  out$v2_ngrams <- rd(results_path(file.path("v2", "ngrams.rds")), "v2/ngrams.rds")
  out$v2_features <- rd(results_path(file.path("v2", "linguistic_features.rds")),
                        "v2/linguistic_features.rds")
  out$v2_tfidf <- rd(results_path(file.path("v2", "tfidf.rds")), "v2/tfidf.rds")
  out$dictionary <- tryCatch(load_dictionary(cfg = cfg), error = function(e) NULL)
  out$dictionary_versions <- tryCatch(list_dictionary_versions(cfg),
                                      error = function(e) NULL)
  out$dictionary_version <- dictionary_version(cfg = cfg)
  out$code_version <- code_version()
  out$import_report <- tryCatch(
    read_json_utf8(interim_path("import_report.json")), error = function(e) NULL)
  out
}

#' Tabla de mensajes filtrada según selección del usuario
#' @export
filter_messages <- function(data, emotions = NULL, date_range = NULL,
                            polarities = NULL, evidence = NULL) {
  s <- data$sentiments; m <- data$messages
  if (is.null(s) || is.null(m)) return(tibble::tibble())
  df <- dplyr::inner_join(
    s, m[, c("message_id", "text_original", "timestamp_utc", "sender_name")],
    by = "message_id")
  df$ts <- as.POSIXct(df$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  if (!is.null(date_range) && length(date_range) == 2 && !any(is.na(date_range))) {
    df <- df[as.Date(df$ts) >= date_range[1] & as.Date(df$ts) <= date_range[2], ]
  }
  if (!is.null(polarities) && length(polarities)) df <- df[df$polarity_label %in% polarities, ]
  if (!is.null(evidence) && length(evidence)) df <- df[df$evidence_level %in% evidence, ]
  if (!is.null(emotions) && length(emotions)) {
    keep <- vapply(df$detected_emotions, function(j) {
      emo <- tryCatch(as.character(unlist(jsonlite::fromJSON(j))), error = function(e) character(0))
      any(emo %in% emotions)
    }, logical(1))
    df <- df[keep, ]
  }
  df
}
