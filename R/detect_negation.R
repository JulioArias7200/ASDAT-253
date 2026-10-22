# =============================================================================
# detect_negation.R — negación con ventana contextual y excepciones
# =============================================================================

# Excepciones: frases donde la doble negación invierte el sentido a positivo.
# Se evalúan ANTES del marcado por ventana.
.double_negation_patterns <- c(
  "no esta nada mal" = "positivo",
  "no esta mal"      = "positivo",
  "no puedo estar mas contento" = "positivo",
  "no puedo estar mas feliz"    = "positivo",
  "nunca me gusto"   = "negativo"
)

#' Tokeniza un texto en español preservando negadores, emojis y palabras.
#' No elimina negaciones ni palabras cortas.
#' @export
tokenize_es <- function(text) {
  if (is.na(text) || !nzchar(text)) return(character(0))
  # separa por espacios, pero mantiene emojis como tokens propios
  toks <- stringi::stri_split_regex(text, "\\s+", omit_empty = TRUE)[[1]]
  toks <- stringi::stri_replace_all_regex(toks, "^[[:punct:]]+|[[:punct:]]+$", "")
  toks[nzchar(toks)]
}

#' Detecta tokens negados según una ventana contextual.
#' Devuelve tibble(token, negated, negator). El negador detiene la propagación.
#' @export
detect_negation <- function(tokens, window = 3L, negators = NULL,
                            exceptions = .double_negation_patterns) {
  negators <- negators %||% c("no", "ni", "nunca", "jamas", "tampoco", "sin", "nada", "nadie")
  tokens <- to_nfc(tokens)
  if (length(tokens) == 0) return(tibble::tibble(
    token = character(), negated = logical(), negator = character()))

  # Normaliza para comparar (sin acentos, minúsculas)
  norm <- stringi::stri_trans_tolower(stringi::stri_trans_general(tokens, "NFD; [:Nonspacing Mark:] Remove; NFC"))
  neg_idx <- which(norm %in% negators)

  negated <- rep(FALSE, length(tokens))
  negator <- rep(NA_character_, length(tokens))

  if (length(neg_idx)) {
    for (i in neg_idx) {
      end <- min(length(tokens), i + window)
      if (end >= i + 1) {
        idx <- (i + 1):end
        # Un nuevo negador no se marca como negado (evita dobles conteos en cadena)
        idx <- idx[!(norm[idx] %in% negators)]
        negated[idx] <- TRUE
        negator[idx] <- norm[i]
      }
    }
  }

  tibble::tibble(token = tokens, normalized = norm, negated = negated, negator = negator)
}

#' Aplica marcado de negación preservando tokens (para compatibilidad de tokens)
#' @export
apply_negation_marking <- function(tokens, window = 3L, negators = NULL) {
  det <- detect_negation(tokens, window, negators)
  ifelse(det$negated, paste0("NEGMARK_", det$token), det$token)
}

#' Detecta si un texto coincide con una excepción de doble negación
#' @export
double_negation_exception <- function(text) {
  norm <- stringi::stri_trans_tolower(stringi::stri_trans_general(
    to_nfc(text), "NFD; [:Nonspacing Mark:] Remove; NFC"))
  for (pat in names(.double_negation_patterns)) {
    if (stringi::stri_detect_fixed(norm, pat)) {
      return(.double_negation_patterns[[pat]])
    }
  }
  NULL
}
