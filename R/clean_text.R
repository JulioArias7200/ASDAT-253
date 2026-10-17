# =============================================================================
# clean_text.R — limpieza y normalización (conserva texto original y emojis)
# =============================================================================

.url_re <- "https?://\\S+|www\\.\\S+"
.mention_re <- "@[A-Za-z0-9_]+"
.hashtag_re <- "#[[:alnum:]_áéíóúüñ]+"

#' Normaliza un vector de texto según la configuración.
#' Conserva emojis; no elimina negaciones ni palabras cortas.
#' @export
normalize_text <- function(text, cfg = load_config()) {
  x <- to_nfc(as.character(text))
  cl <- cfg_get(cfg, "cleaning")

  if (isTRUE(cl$lowercase)) x <- stringi::stri_trans_tolower(x)
  if (isTRUE(cl$remove_urls)) x <- stringi::stri_replace_all_regex(x, .url_re, cl$url_placeholder %||% "")
  if (isTRUE(cl$strip_mentions)) x <- stringi::stri_replace_all_regex(x, .mention_re, "")
  if (isTRUE(cl$strip_hashtags)) x <- stringi::stri_replace_all_regex(x, .hashtag_re, "")
  if (isTRUE(cl$collapse_whitespace)) {
    x <- stringi::stri_replace_all_regex(x, "[[:space:]]+", " ")
    x <- stringi::stri_trim_both(x)
  }
  x
}

#' Añade la columna `text_norm` a los mensajes; registra el antes/después.
#' @export
clean_messages <- function(messages, cfg = load_config()) {
  before <- messages$text_original
  messages$text_norm <- normalize_text(before, cfg)
  list(messages = messages, before = before, after = messages$text_norm)
}

#' Comprueba si un texto es solo URL
#' @export
is_url_only <- function(text) {
  stringi::stri_detect_regex(stringi::stri_trim_both(text), "^https?://\\S+$")
}

#' Número de palabras (aprox) de un texto
#' @export
word_count <- function(text) {
  vapply(text, function(t) length(stringi::stri_split_regex(t %||% "", "\\s+", omit_empty = TRUE)[[1]]),
         integer(1), USE.NAMES = FALSE)
}
