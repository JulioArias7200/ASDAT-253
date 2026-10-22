# =============================================================================
# analyze_topics.R — tópicos con LDA sobre conteos (quanteda + topicmodels)
# =============================================================================

#' Construye el corpus y la matriz documento-término con quanteda
#' @export
build_dfm <- function(texts, cfg = load_config()) {
  tp <- cfg_get(cfg, "topics")
  corp <- quanteda::corpus(texts)
  toks <- quanteda::tokens(corp, remove_punct = TRUE, remove_numbers = TRUE,
                           remove_symbols = TRUE)
  toks <- quanteda::tokens_tolower(toks)
  toks <- quanteda::tokens_remove(toks, quanteda::stopwords("es"))
  dfm <- quanteda::dfm(toks)
  dfm <- quanteda::dfm_trim(dfm, min_docfreq = tp$min_df, docfreq_type = "count")
  dfm <- quanteda::dfm_trim(dfm, max_docfreq = tp$max_df, docfreq_type = "prop")
  dfm
}

#' Ajusta un modelo LDA sobre la DFM (conteos)
#' @export
fit_topics <- function(texts, k = 5L, cfg = load_config()) {
  tp <- cfg_get(cfg, "topics")
  dfm <- build_dfm(texts, cfg)
  # dfm_trim con docfreq_type="prop" requiere valores en [0,1]; min_df lo pasamos como conteo
  mat <- as.matrix(dfm)
  keep <- rowSums(mat) > 0
  model <- topicmodels::LDA(mat[keep, , drop = FALSE], k = k,
                            method = "Gibbs", control = list(seed = tp$seed, iter = 800))
  list(model = model, dfm = dfm, doc_ids = which(keep), k = k)
}

#' Términos más probables por tópico
#' @export
top_terms <- function(fit, n = 10) {
  beta <- topicmodels::posterior(fit$model)$terms
  vocab <- colnames(beta)
  lapply(seq_len(fit$k), function(t) {
    vocab[order(beta[t, ], decreasing = TRUE)][seq_len(min(n, length(vocab)))]
  })
}

#' Perplejidad para un rango de k (criterio auxiliar, no único)
#' @export
perplexity_by_k <- function(texts, k_range = 3:10, cfg = load_config()) {
  dfm <- build_dfm(texts, cfg)
  mat <- as.matrix(dfm)
  mat <- mat[rowSums(mat) > 0, , drop = FALSE]
  tp <- cfg_get(cfg, "topics")
  vapply(k_range, function(k) {
    m <- topicmodels::LDA(mat, k = k, method = "Gibbs",
                          control = list(seed = tp$seed, iter = 500))
    topicmodels::perplexity(m, newdata = mat)
  }, numeric(1))
}

#' Cruce tópico x emoción (usa el tópico dominante por documento)
#' @export
cross_topic_emotion <- function(fit, sentiments, emotions = EMOTION_CATEGORIES) {
  post <- topicmodels::posterior(fit$model)$topics
  dominant <- apply(post, 1, which.max)
  ids <- fit$dfm$docvars # no docvars; mantener orden
  # mapa posición -> message_id se resuelve fuera; aquí devolvemos tópico dominante
  tibble::tibble(row = seq_along(dominant), topic = dominant)
}

#' Guarda los tópicos a tabla legible
#' @export
topics_table <- function(fit, n = 10) {
  tt <- top_terms(fit, n)
  tibble::tibble(
    topic = seq_len(fit$k),
    top_words = vapply(tt, function(x) paste(x, collapse = ", "), character(1))
  )
}
