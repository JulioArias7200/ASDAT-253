# =============================================================================
# analyze_temporal.R — agregación temporal de sentimiento y emociones
# =============================================================================

#' Une mensajes y resultados de sentimiento por message_id
#' @export
join_sentiment <- function(messages, sentiments) {
  df <- dplyr::inner_join(
    messages[, c("message_id", "corpus_id", "timestamp_utc", "sender_id")],
    sentiments, by = c("message_id", "corpus_id"))
  df$ts <- as.POSIXct(df$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  df
}

#' Agrega por día / semana / mes.
#' Devuelve frecuencias absolutas y proporciones normalizadas por volumen.
#' @export
temporal_aggregate <- function(df, by = c("day", "week", "month"),
                               emotions = EMOTION_CATEGORIES) {
  by <- match.arg(by)
  if (!nrow(df)) return(tibble::tibble())
  df <- df[!is.na(df$ts), ]
  df$period <- switch(by,
    day = as.Date(df$ts, tz = "UTC"),
    week = as.Date(cut(df$ts, breaks = "week", start.on.monday = TRUE)),
    month = as.Date(format(df$ts, "%Y-%m-01", tz = "UTC"))
  )
  # Emociones expandidas
  emo <- lapply(df$emotion_scores, function(j) {
    x <- tryCatch(jsonlite::fromJSON(j, simplifyVector = TRUE), error = function(e) list())
    as.list(x %||% list())
  })
  for (e in emotions) df[[e]] <- vapply(emo, function(x) as.numeric(x[[e]] %||% 0), numeric(1))

  agg <- df |>
    dplyr::group_by(period) |>
    dplyr::summarise(
      n_messages = dplyr::n(),
      n_analyzed = sum(evidence_level != "sin_evidencia"),
      polarity_mean = round(mean(polarity, na.rm = TRUE), 4),
      n_positive = sum(polarity_label == "positivo"),
      n_negative = sum(polarity_label == "negativo"),
      n_neutral = sum(polarity_label == "neutro"),
      n_indeterminate = sum(polarity_label == "indeterminado"),
      dplyr::across(dplyr::all_of(emotions), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      prop_positive = n_positive / n_messages,
      prop_negative = n_negative / n_messages,
      prop_neutral = n_neutral / n_messages
    )
  agg
}

#' Media móvil configurable de polaridad
#' @export
rolling_polarity <- function(df, window = 7) {
  if (!nrow(df)) return(df)
  df <- df[order(df$period), ]
  df$polarity_ma <- as.numeric(stats::filter(df$polarity_mean, rep(1 / window, window), sides = 2))
  df
}

#' Volumen de mensajes por período
#' @export
message_volume <- function(df, by = "day") {
  temporal_aggregate(df, by)[, c("period", "n_messages")]
}
