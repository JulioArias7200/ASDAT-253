# =============================================================================
# ngrams.R — unigramas, bigramas y n-gramas configurables (quanteda)
# Los n-gramas nunca cruzan límites de mensaje: cada documento se tokeniza
# por separado, por lo que no se concatenan mensajes independientes.
# =============================================================================

#' Stopwords en español conservando los negadores configurados.
#' `no`, `nunca`, `jamas`, etc. se preservan para no destruir la señal emocional.
#' @export
stopwords_es <- function(cfg = load_config(), preserve_negators = TRUE) {
  sw <- quanteda::stopwords("es")
  if (isTRUE(preserve_negators)) {
    neg <- cfg_get(cfg, "negation", "negators") %||% character(0)
    sw <- setdiff(sw, neg)
  }
  sw
}

#' Tokeniza una colección de mensajes en n-gramas.
#' @param texts vector de textos (un elemento = un documento/mensaje).
#' @param n tamaño del n-grama (1 = unigramas).
#' @param remove_stopwords elimina stopwords (conservando negadores).
#' @param drop_emoji_tokens quita emojis de la secuencia (se analizan aparte).
#' @return objeto `quanteda::tokens`.
#' @export
ngram_tokenize <- function(texts, n = 1L, cfg = load_config(),
                           remove_stopwords = TRUE, drop_emoji_tokens = TRUE) {
  n <- as.integer(n)
  if (is.na(n) || n < 1L) stop("n debe ser un entero >= 1")
  texts <- as.character(texts)
  texts[is.na(texts)] <- ""

  corp <- quanteda::corpus(texts)
  toks <- quanteda::tokens(corp, remove_punct = TRUE, remove_numbers = TRUE,
                           remove_symbols = TRUE)
  toks <- quanteda::tokens_tolower(toks)
  if (isTRUE(drop_emoji_tokens)) {
    toks <- quanteda::tokens_remove(toks, .emoji_class, valuetype = "regex")
  }
  if (isTRUE(remove_stopwords)) {
    toks <- quanteda::tokens_remove(toks, stopwords_es(cfg), valuetype = "fixed")
  }
  if (n > 1L) toks <- quanteda::tokens_ngrams(toks, n = n, concatenator = " ")
  toks
}

#' Frecuencias absolutas y relativas de n-gramas.
#' `prop` = frecuencia del n-grama / total de n-gramas retenidos.
#' @export
ngram_frequencies <- function(texts, n = 1L, min_count = 1L, cfg = load_config(),
                              remove_stopwords = TRUE, drop_emoji_tokens = TRUE) {
  toks <- ngram_tokenize(texts, n = n, cfg = cfg,
                         remove_stopwords = remove_stopwords,
                         drop_emoji_tokens = drop_emoji_tokens)
  v <- unlist(as.list(toks), use.names = FALSE)
  v <- v[!is.na(v) & nzchar(v)]
  if (!length(v)) {
    return(tibble::tibble(ngram = character(0), count = integer(0), prop = numeric(0)))
  }
  tb <- sort(table(v), decreasing = TRUE)
  out <- tibble::tibble(
    ngram = names(tb),
    count = as.integer(tb),
    prop = as.numeric(tb) / sum(as.numeric(tb))
  )
  out[out$count >= min_count, , drop = FALSE]
}

#' Tabla de unigramas/bigramas/n-gramas para varios tamaños a la vez.
#' @export
ngram_table <- function(texts, sizes = 1:3, min_count = 1L, cfg = load_config(),
                        remove_stopwords = TRUE) {
  sizes <- as.integer(sizes)
  res <- lapply(sizes, function(n) {
    df <- ngram_frequencies(texts, n = n, min_count = min_count, cfg = cfg,
                            remove_stopwords = remove_stopwords)
    if (!nrow(df)) return(NULL)
    df$size <- n
    df
  })
  res <- Filter(Negate(is.null), res)
  if (!length(res)) {
    return(tibble::tibble(ngram = character(0), count = integer(0),
                          prop = numeric(0), size = integer(0)))
  }
  dplyr::bind_rows(res)[, c("size", "ngram", "count", "prop")]
}

#' Compara la frecuencia de n-gramas antes y después de quitar stopwords.
#' @export
compare_stopword_effect <- function(texts, n = 1L, top = 20L, cfg = load_config()) {
  before <- ngram_frequencies(texts, n = n, cfg = cfg, remove_stopwords = FALSE)
  after <- ngram_frequencies(texts, n = n, cfg = cfg, remove_stopwords = TRUE)
  list(before = utils::head(before, top), after = utils::head(after, top))
}

#' Frecuencias de un n-grama concreto a lo largo de periodos.
#' @export
ngram_term_by_period <- function(texts, term, group, n = 1L,
                                 cfg = load_config(), remove_stopwords = TRUE) {
  if (length(texts) != length(group)) stop("texts y group deben tener el mismo largo")
  toks <- ngram_tokenize(texts, n = n, cfg = cfg,
                         remove_stopwords = remove_stopwords)
  v <- as.list(toks)
  cnt <- vapply(v, function(x) sum(x == term), integer(1))
  df <- tibble::tibble(group = as.character(group), count = cnt)
  df <- df[!is.na(df$group), , drop = FALSE]
  df |>
    dplyr::group_by(group) |>
    dplyr::summarise(count = sum(count), .groups = "drop") |>
    dplyr::arrange(group)
}

#' Frecuencias de n-gramas agrupadas por periodo u otra variable.
#' @param group vector del mismo largo que `texts` (p. ej. "2024-01").
#' @param top número de n-gramas por grupo.
#' @export
ngram_frequencies_by <- function(texts, group, n = 1L, top = 5L,
                                 cfg = load_config(), remove_stopwords = TRUE) {
  if (length(texts) != length(group)) stop("texts y group deben tener el mismo largo")
  group <- as.character(group)
  keep <- !is.na(group)
  texts <- texts[keep]; group <- group[keep]
  if (!length(texts)) {
    return(tibble::tibble(group = character(0), ngram = character(0),
                          count = integer(0)))
  }
  out <- lapply(sort(unique(group)), function(g) {
    df <- ngram_frequencies(texts[group == g], n = n, cfg = cfg,
                            remove_stopwords = remove_stopwords)
    df <- utils::head(df, top)
    if (!nrow(df)) return(NULL)
    df$group <- g
    df[, c("group", "ngram", "count")]
  })
  out <- Filter(Negate(is.null), out)
  if (!length(out)) {
    return(tibble::tibble(group = character(0), ngram = character(0),
                          count = integer(0)))
  }
  dplyr::bind_rows(out)
}
