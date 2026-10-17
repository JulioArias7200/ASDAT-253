# =============================================================================
# analyze_sentiment.R — análisis léxico multietiqueta en español
# Señales separadas: léxico, emojis, reacciones (no se mezclan sin calibrar)
# =============================================================================

#' Puntúa un mensaje. Devuelve lista con polaridad, emociones y evidencia.
#' @export
score_message <- function(text, dictionary, cfg = load_config(),
                          emojis = NULL, reactions = NULL) {
  sent_cfg <- cfg_get(cfg, "sentiment")
  neg_cfg  <- cfg_get(cfg, "negation")

  norm_text <- normalize_text(text, cfg)
  tokens <- tokenize_es(norm_text)
  det <- detect_negation(tokens, neg_cfg$window, neg_cfg$negators)

  lex_score <- 0
  emotion_counts <- list()
  n_terms <- 0L

  word_rows <- dictionary[dictionary$term_type != "emoji", , drop = FALSE]
  # índice por normalized_term
  idx <- split(seq_len(nrow(word_rows)), word_rows$normalized_term)

  if (length(tokens)) {
    for (i in seq_along(det$token)) {
      key <- det$normalized[[i]]
      rows <- idx[[key]]
      if (is.null(rows)) next
      n_terms <- n_terms + 1L
      negated <- det$negated[[i]]
      for (r in rows) {
        pol <- word_rows$polarity[[r]]
        w   <- word_rows$weight[[r]] %||% 1
        val <- if (identical(pol, "negativo")) -w else if (identical(pol, "positivo")) w else 0
        if (negated && isTRUE(word_rows$negation_sensitive[[r]])) val <- -val
        lex_score <- lex_score + val
        cat <- word_rows$category[[r]]
        emotion_counts[[cat]] <- (emotion_counts[[cat]] %||% 0) + 1L
      }
    }
  }

  # Frases multipalabra
  phrase_rows <- word_rows[word_rows$term_type == "phrase", , drop = FALSE]
  if (nrow(phrase_rows)) {
    for (r in seq_len(nrow(phrase_rows))) {
      if (stringi::stri_detect_fixed(norm_text, phrase_rows$normalized_term[[r]])) {
        n_terms <- n_terms + 1L
        pol <- phrase_rows$polarity[[r]]
        w <- phrase_rows$weight[[r]] %||% 1
        lex_score <- lex_score + if (identical(pol, "negativo")) -w else if (identical(pol, "positivo")) w else 0
        cat <- phrase_rows$category[[r]]
        emotion_counts[[cat]] <- (emotion_counts[[cat]] %||% 0) + 1L
      }
    }
  }

  # Excepción de doble negación ("no está nada mal" etc.)
  ex <- double_negation_exception(norm_text)
  if (!is.null(ex)) {
    lex_score <- if (identical(ex, "positivo")) abs(lex_score) + 1 else -abs(lex_score) - 1
    n_terms <- n_terms + 1L
  }

  # Emojis
  emojis <- emojis %||% process_emojis(text)
  esig <- emoji_signal(emojis, dictionary)
  n_emoji <- length(esig$matched)
  for (cat in names(esig$emotions)) {
    emotion_counts[[cat]] <- (emotion_counts[[cat]] %||% 0) + esig$emotions[[cat]]
  }

  # Evidencia = términos léxicos + emojis reconocidos (reacciones van aparte)
  n_evidence <- n_terms + n_emoji
  # Puntuación de texto = léxico + emojis del propio mensaje (peso configurable)
  text_score <- lex_score + esig$score * (sent_cfg$emoji_weight %||% 1)

  # Etiquetas
  label <- if (text_score > 0) "positivo" else if (text_score < 0) "negativo" else "neutro"
  evidence <- if (n_evidence == 0L) "sin_evidencia" else
    if (n_evidence < (sent_cfg$min_evidence_terms %||% 1L)) "insuficiente" else "suficiente"
  if (identical(evidence, "sin_evidencia")) label <- "indeterminado"

  detected <- if (length(emotion_counts)) {
    vals <- unlist(emotion_counts, use.names = TRUE)
    names(vals)[order(vals, decreasing = TRUE)]
  } else character(0)
  dominant <- if (length(detected)) detected[[1]] else NA_character_

  list(
    polarity = lex_score,
    text_polarity = text_score,
    polarity_label = label,
    emotion_scores = emotion_counts,
    detected_emotions = detected,
    dominant_emotion = dominant,
    intensity = abs(text_score),
    evidence_level = evidence,
    n_terms = n_evidence,
    n_emoji = n_emoji,
    emoji_signal_raw = esig$score,
    emoji_emotions = esig$emotions
  )
}

#' Analiza todo el corpus. Devuelve tibble por mensaje.
#' @export
analyze_sentiment <- function(messages, dictionary, cfg = load_config()) {
  dict_version <- dictionary_version(cfg = cfg)
  sent_cfg <- cfg_get(cfg, "sentiment")
  n <- nrow(messages)
  res <- vector("list", n)

  for (i in seq_len(n)) {
    m <- messages[i, ]
    text <- if (!is.na(m$text_norm) && nzchar(m$text_norm)) m$text_norm else m$text_original
    emojis <- parse_emoji_list(m$emoji_list)
    reactions <- tryCatch(jsonlite::fromJSON(m$reactions %||% "{}", simplifyVector = TRUE),
                          error = function(e) list())
    if (is.null(reactions) || !length(reactions)) reactions <- list()

    s <- score_message(text, dictionary, cfg, emojis = emojis)

    # Señal de reacciones (separada, no mezclada por defecto)
    react_score <- 0; react_emo <- list()
    rw <- sent_cfg$reaction_weight %||% 0
    if (length(reactions)) {
      for (emoji in names(reactions)) {
        rsig <- emoji_signal(emoji, dictionary)
        cnt <- as.integer(reactions[[emoji]])
        react_score <- react_score + rsig$score * cnt * rw
        for (cat in names(rsig$emotions)) react_emo[[cat]] <- (react_emo[[cat]] %||% 0) + rsig$emotions[[cat]] * cnt
      }
    }

    res[[i]] <- tibble::tibble(
      message_id = m$message_id,
      corpus_id = m$corpus_id,
      polarity = s$polarity,
      polarity_label = s$polarity_label,
      emotion_scores = as_json(s$emotion_scores),
      detected_emotions = as_json(s$detected_emotions),
      dominant_emotion = s$dominant_emotion %||% NA_character_,
      intensity = s$intensity,
      evidence_level = s$evidence_level,
      n_terms = s$n_terms,
      emoji_signal = round(s$emoji_signal_raw * (sent_cfg$emoji_weight %||% 1), 3),
      emoji_emotions = as_json(s$emoji_emotions),
      reaction_signal = round(react_score, 3),
      reaction_emotions = as_json(react_emo)
    )
  }
  out <- if (length(res)) dplyr::bind_rows(res) else tibble::tibble()
  attr(out, "dictionary_version") <- dict_version
  out
}
