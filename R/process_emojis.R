# =============================================================================
# process_emojis.R — extracción y señalización de emojis (NO se eliminan)
# =============================================================================

# Rango amplio de pictogramas + ZWJ + selectores + tonos de piel + banderas
.emoji_class <- paste0(
  "[",
  "\U0001F000-\U0001FAFF",  # pictogramas, símbolos, suplementarios
  "\U00002300-\U000023FF",  # símbolos técnicos
  "\U00002600-\U000027BF",  # símbolos y dingbats
  "\U00002B00-\U00002BFF",  # flechas y símbolos
  "\U0001F1E6-\U0001F1FF",  # banderas regionales
  "\U0000FE0F",             # variation selector-16
  "\U0000200D",             # ZWJ
  "]"
)

#' Extrae secuencias de emojis de un texto (vectorizado)
#' @export
process_emojis <- function(text) {
  if (length(text) == 0) return(character(0))
  res <- lapply(text, function(t) {
    if (is.na(t) || !nzchar(t)) return(character(0))
    stringi::stri_extract_all_regex(t, paste0(.emoji_class, "+"), omit_no_match = TRUE)[[1]]
  })
  if (length(text) == 1) return(res[[1]])
  res
}

#' ¿El texto contiene al menos un emoji?
#' @export
has_emoji <- function(text) {
  vapply(text, function(t) {
    if (is.na(t) || !nzchar(t)) return(FALSE)
    stringi::stri_detect_regex(t, .emoji_class)
  }, logical(1), USE.NAMES = FALSE)
}

#' Elimina emojis del texto (solo si el usuario decide descartarlos)
#' @export
strip_emojis <- function(text) {
  stringi::stri_replace_all_regex(text, .emoji_class, "")
}

#' Señal emocional de una lista de emojis según el diccionario.
#' Devuelve list(score, emotions = named counts, matched = emojis encontrados).
#' @export
emoji_signal <- function(emoji_vec, dictionary) {
  emo_rows <- dictionary[dictionary$term_type == "emoji", , drop = FALSE]
  score <- 0; counts <- list(); matched <- character(0)
  for (e in emoji_vec) {
    hit <- emo_rows[emo_rows$normalized_term == e, , drop = FALSE]
    if (nrow(hit)) {
      matched <- c(matched, e)
      for (i in seq_len(nrow(hit))) {
        w <- hit$weight[[i]] %||% 1
        pol <- hit$polarity[[i]]
        score <- score + if (identical(pol, "negativo")) -w else if (identical(pol, "positivo")) w else 0
        cat <- hit$category[[i]]
        counts[[cat]] <- (counts[[cat]] %||% 0) + 1
      }
    }
  }
  list(score = score, emotions = counts, matched = matched)
}

#' Parsea el campo JSON `emoji_list` de la tabla de mensajes
#' @export
parse_emoji_list <- function(x) {
  if (is.na(x) || !nzchar(x)) return(character(0))
  as.character(unlist(jsonlite::fromJSON(x, simplifyVector = TRUE)))
}
