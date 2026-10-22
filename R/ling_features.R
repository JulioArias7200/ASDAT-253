# =============================================================================
# ling_features.R — características lingüísticas superficiales (por mensaje)
# NO es análisis sintáctico profundo: son indicadores verificables y acotados.
# Se calculan sobre el texto ORIGINAL para conservar mayúsculas y signos.
# =============================================================================

#' Características superficiales de un vector de textos.
#' Devuelve un tibble con una fila por mensaje.
#' @export
linguistic_features <- function(texts, cfg = load_config()) {
  texts <- as.character(texts)
  texts[is.na(texts)] <- ""

  rows <- lapply(texts, function(t) {
    words <- stringi::stri_extract_all_regex(
      t, "[\\p{L}\\p{N}]+(?:['\u2019][\\p{L}\\p{N}]+)?", omit_no_match = TRUE)[[1]]
    words <- words[!is.na(words)]
    n_words <- length(words)
    n_unique <- length(unique(stringi::stri_trans_tolower(words)))
    n_tokens <- length(stringi::stri_split_regex(
      stringi::stri_trim_both(t), "\\s+", omit_empty = TRUE)[[1]])

    tibble::tibble(
      n_chars = nchar(t, type = "chars"),
      n_tokens = as.integer(n_tokens),
      n_words = as.integer(n_words),
      n_unique_words = as.integer(n_unique),
      unique_ratio = if (n_words > 0) n_unique / n_words else 0,
      mean_word_len = if (n_words > 0) mean(nchar(words, type = "chars")) else 0,
      n_questions = as.integer(
        stringi::stri_count_fixed(t, "?") + stringi::stri_count_fixed(t, "\u00bf")),
      n_exclamations = as.integer(
        stringi::stri_count_fixed(t, "!") + stringi::stri_count_fixed(t, "\u00a1")),
      n_upper_words = as.integer(stringi::stri_count_regex(t, "\\b\\p{Lu}{2,}\\b")),
      upper_ratio = if (n_words > 0) {
        as.integer(stringi::stri_count_regex(t, "\\b\\p{Lu}{2,}\\b")) / n_words
      } else 0,
      n_emojis = as.integer(
        stringi::stri_count_regex(t, "\\p{Extended_Pictographic}")),
      n_hashtags = as.integer(stringi::stri_count_regex(t, "#[\\p{L}\\p{N}_]+")),
      n_mentions = as.integer(stringi::stri_count_regex(t, "@[A-Za-z0-9_]+")),
      n_urls = as.integer(stringi::stri_count_regex(t, "https?://\\S+|www\\.\\S+")),
      n_repeated_chars = as.integer(stringi::stri_count_regex(t, "(\\p{L})\\1{2,}")),
      n_repeated_punct = as.integer(stringi::stri_count_regex(t, "([!?.,])\\1{1,}")),
      n_intensity = as.integer(stringi::stri_count_regex(t, "[!?]{2,}"))
    )
  })

  if (!length(rows)) {
    return(tibble::tibble(
      n_chars = integer(0), n_tokens = integer(0), n_words = integer(0),
      n_unique_words = integer(0), unique_ratio = numeric(0),
      mean_word_len = numeric(0), n_questions = integer(0),
      n_exclamations = integer(0), n_upper_words = integer(0),
      upper_ratio = numeric(0), n_emojis = integer(0), n_hashtags = integer(0),
      n_mentions = integer(0), n_urls = integer(0), n_repeated_chars = integer(0),
      n_repeated_punct = integer(0), n_intensity = integer(0)))
  }
  dplyr::bind_rows(rows)
}

#' Añade las características a la tabla de mensajes (conserva `message_id`).
#' @export
linguistic_features_messages <- function(messages, text_col = "text_original",
                                         cfg = load_config()) {
  if (!text_col %in% names(messages)) {
    stop("No existe la columna de texto: ", text_col)
  }
  feat <- linguistic_features(messages[[text_col]], cfg)
  if ("message_id" %in% names(messages)) {
    feat <- dplyr::bind_cols(
      tibble::tibble(message_id = messages$message_id), feat)
  }
  feat
}

#' Resumen descriptivo de las características (para tabla del dashboard).
#' @export
feature_summary <- function(features) {
  num <- features[vapply(features, is.numeric, logical(1))]
  num <- num[, setdiff(names(num), "message_id"), drop = FALSE]
  if (!ncol(num) || !nrow(num)) {
    return(tibble::tibble(feature = character(0), mean = numeric(0),
                          median = numeric(0), p90 = numeric(0), max = numeric(0)))
  }
  tibble::tibble(
    feature = names(num),
    mean = vapply(num, mean, numeric(1), na.rm = TRUE),
    median = vapply(num, stats::median, numeric(1), na.rm = TRUE),
    p90 = vapply(num, function(x) stats::quantile(x, 0.9, na.rm = TRUE,
                                                  names = FALSE), numeric(1)),
    max = vapply(num, function(x) max(x, na.rm = TRUE), numeric(1))
  )
}

#' Media de las características por periodo (day/week/month).
#' @param dates vector de fechas o POSIXct del mismo largo que `features`.
#' @export
features_by_period <- function(features, dates,
                               period = c("day", "week", "month")) {
  period <- match.arg(period)
  if (length(dates) != nrow(features)) {
    stop("dates y features deben tener el mismo largo")
  }
  d <- as.Date(dates)
  key <- switch(period,
                day = format(d, "%Y-%m-%d"),
                week = format(d, "%Y-W%V"),
                month = format(d, "%Y-%m"))
  num <- features[vapply(features, is.numeric, logical(1))]
  num <- num[, setdiff(names(num), "message_id"), drop = FALSE]
  num$period <- key
  num <- num[!is.na(num$period), , drop = FALSE]
  if (!nrow(num)) {
    return(tibble::tibble(period = character(0), n = integer(0)))
  }
  num |>
    dplyr::group_by(period) |>
    dplyr::summarise(
      n = dplyr::n(),
      dplyr::across(dplyr::everything(), ~ mean(.x, na.rm = TRUE)),
      .groups = "drop"
    )
}
