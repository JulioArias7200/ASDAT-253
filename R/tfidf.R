# =============================================================================
# tfidf.R — TF, IDF y TF-IDF con metodología explícita
#
# Documento = un mensaje (por defecto). Fórmulas:
#   N    = número de documentos (mensajes)
#   df_t = número de documentos que contienen el término t
#   IDF  = ln(N / df_t)                      (término en todos los docs => 0)
#   TF   = "raw"  -> conteo en el documento
#          "prop" -> conteo / nº de tokens del documento
#          "log"  -> 1 + log10(conteo)
#   TF-IDF = TF * IDF
# El término es un n-grama (n = 1 por defecto); los n-gramas no cruzan
# límites de mensaje.
# =============================================================================

.empty_tfidf <- function() {
  tibble::tibble(
    doc_id = integer(0), term = character(0), tf_count = integer(0),
    df = integer(0), idf = numeric(0), tf = numeric(0), tfidf = numeric(0))
}

#' Calcula TF, IDF y TF-IDF para una colección de documentos.
#' @param texts vector de documentos (un mensaje por elemento).
#' @param ids identificadores de documento (por defecto 1..N).
#' @param n tamaño del n-grama usado como término.
#' @param tf_scheme "raw", "prop" o "log" (ver cabecera).
#' @param min_df descarta términos presentes en menos de `min_df` documentos.
#' @return tibble largo: doc_id, term, tf_count, df, idf, tf, tfidf.
#' @export
compute_tfidf <- function(texts, ids = NULL, n = 1L, cfg = load_config(),
                          remove_stopwords = TRUE,
                          tf_scheme = c("raw", "prop", "log"), min_df = 1L) {
  tf_scheme <- match.arg(tf_scheme)
  texts <- as.character(texts)
  texts[is.na(texts)] <- ""
  N <- length(texts)
  if (is.null(ids)) ids <- seq_len(N)
  if (length(ids) != N) stop("ids y texts deben tener el mismo largo")

  toks <- ngram_tokenize(texts, n = n, cfg = cfg,
                         remove_stopwords = remove_stopwords)
  v <- as.list(toks)
  doc_len <- lengths(v)
  terms <- unlist(v, use.names = FALSE)
  if (!length(terms)) return(.empty_tfidf())

  dt <- data.frame(doc = rep(seq_len(N), lengths(v)), term = terms,
                   stringsAsFactors = FALSE)
  agg <- dplyr::count(dt, doc, term, name = "tf_count")
  dffreq <- dplyr::count(agg, term, name = "df")
  agg <- dplyr::left_join(agg, dffreq, by = "term")
  agg <- agg[agg$df >= as.integer(min_df), , drop = FALSE]
  if (!nrow(agg)) return(.empty_tfidf())

  idf <- log(N / agg$df)
  tf <- switch(tf_scheme,
               raw = agg$tf_count,
               prop = agg$tf_count / pmax(doc_len[agg$doc], 1),
               log = 1 + log10(agg$tf_count))

  tibble::tibble(
    doc_id = ids[agg$doc],
    term = agg$term,
    tf_count = as.integer(agg$tf_count),
    df = as.integer(agg$df),
    idf = as.numeric(idf),
    tf = as.numeric(tf),
    tfidf = as.numeric(tf * idf)
  ) |>
    dplyr::arrange(doc_id, dplyr::desc(tfidf))
}

#' Términos de mayor peso por documento.
#' @export
tfidf_top_terms <- function(tfidf, n = 10L) {
  if (!nrow(tfidf)) return(tfidf)
  tfidf |>
    dplyr::group_by(doc_id) |>
    dplyr::slice_max(tfidf, n = n, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::arrange(doc_id, dplyr::desc(tfidf))
}

#' Peso global de cada término (suma de TF-IDF en todo el corpus).
#' @export
tfidf_global <- function(tfidf) {
  if (!nrow(tfidf)) {
    return(tibble::tibble(term = character(0), df = integer(0),
                          sum_tfidf = numeric(0), mean_tfidf = numeric(0)))
  }
  tfidf |>
    dplyr::group_by(term) |>
    dplyr::summarise(
      df = max(df),
      sum_tfidf = sum(tfidf),
      mean_tfidf = mean(tfidf),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(sum_tfidf))
}

#' Agrega el peso de los términos por periodo (day/week/month).
#' @param tfidf salida de `compute_tfidf`.
#' @param dates vector de fechas alineado con los documentos.
#' @param ids identificadores de documento usados en `tfidf`.
#' @export
tfidf_by_period <- function(tfidf, dates, ids = seq_along(dates),
                            period = c("day", "week", "month")) {
  period <- match.arg(period)
  if (!nrow(tfidf)) {
    return(tibble::tibble(period = character(0), term = character(0),
                          sum_tfidf = numeric(0)))
  }
  if (length(dates) != length(ids)) stop("dates e ids deben tener el mismo largo")
  d <- as.Date(dates)
  key <- switch(period,
                day = format(d, "%Y-%m-%d"),
                week = format(d, "%Y-W%V"),
                month = format(d, "%Y-%m"))
  map <- tibble::tibble(doc_id = ids, period = key)
  tfidf |>
    dplyr::inner_join(map, by = "doc_id") |>
    dplyr::filter(!is.na(period)) |>
    dplyr::group_by(period, term) |>
    dplyr::summarise(sum_tfidf = sum(tfidf), .groups = "drop") |>
    dplyr::arrange(period, dplyr::desc(sum_tfidf))
}
