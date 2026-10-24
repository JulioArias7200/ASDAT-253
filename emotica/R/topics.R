# Topic modeling. Usa LDA (paquete topicmodels) si esta instalado; si no, NMF con divergencia KL (equivalente a pLSA), 100% base R.
agrupar_documentos <- function(tok, mensajes, por = c("dia", "ventana"), ventana = 25, min_tokens = 15,
                               quitar_emojis = TRUE, min_chars = 3, excluir_anuncios = TRUE) {
  por <- match.arg(por)
  if (excluir_anuncios && "es_anuncio" %in% names(mensajes))
    tok <- tok[tok$msg_id %in% as.character(mensajes$msg_id[!(as.logical(mensajes$es_anuncio) %in% TRUE)]), ]
  tk <- filtrar_tokens(tok, min_chars = min_chars)
  if (quitar_emojis) tk <- tk[!tk$es_emoji, ]
  i <- match(tk$msg_id, as.character(mensajes$msg_id))
  tk$doc <- if (por == "dia") substr(as.character(mensajes$fecha[i]), 1, 10) else {
    ord <- order(mensajes$fecha); rango <- integer(nrow(mensajes)); rango[ord] <- seq_along(ord)
    paste0("w", sprintf("%05d", (rango[i] - 1) %/% ventana)) }
  n <- table(tk$doc); tk <- tk[tk$doc %in% names(n)[n >= min_tokens], ]
  tk
}

matriz_doc_term <- function(tk, min_docs = 5, max_prop = 0.5) {
  docs <- sort(unique(tk$doc)); nd <- length(docs)
  dfreq <- tapply(tk$doc, tk$token, function(x) length(unique(x)))
  vocab <- sort(names(dfreq)[dfreq >= min_docs & dfreq <= max_prop * nd])
  tk <- tk[tk$token %in% vocab, ]
  idx <- (match(tk$token, vocab) - 1) * nd + match(tk$doc, docs)
  m <- matrix(tabulate(idx, nbins = nd * length(vocab)), nd, length(vocab), dimnames = list(docs, vocab))
  info <- tapply(tk$periodo_id, tk$doc, function(x) names(sort(table(x), decreasing = TRUE))[1])
  list(dtm = m[rowSums(m) > 0, , drop = FALSE], periodo = info[rownames(m)[rowSums(m) > 0]])
}

.nmf_kl <- function(V, k, iter = 200, seed = 1) {
  set.seed(seed); n <- nrow(V); p <- ncol(V)
  W <- matrix(stats::runif(n * k) + 0.1, n, k); H <- matrix(stats::runif(k * p) + 0.1, k, p)
  for (it in seq_len(iter)) {
    H <- H * (crossprod(W, V / (W %*% H + 1e-9))) / (colSums(W) %o% rep(1, p))
    W <- W * ((V / (W %*% H + 1e-9)) %*% t(H)) / (rep(1, n) %o% rowSums(H))
  }
  rs <- rowSums(H); theta <- W * rep(rs, each = n); theta <- theta / rowSums(theta)
  list(theta = theta, phi = H / rs)
}

ajustar_temas <- function(dtm, k = 8, metodo = c("auto", "lda", "nmf"), iter = 200, semilla = 1) {
  metodo <- match.arg(metodo)
  lda_ok <- requireNamespace("topicmodels", quietly = TRUE) && requireNamespace("slam", quietly = TRUE)
  if (metodo == "lda" && !lda_ok) stop("Instale topicmodels y slam: install.packages(c('topicmodels','slam'))")
  if (metodo == "lda" || (metodo == "auto" && lda_ok)) {
    m <- topicmodels::LDA(slam::as.simple_triplet_matrix(dtm), k = k, method = "Gibbs",
                          control = list(seed = semilla, iter = iter, burnin = iter %/% 4))
    po <- topicmodels::posterior(m); r <- list(theta = po$topics, phi = po$terms, metodo = "lda")
  } else { r <- .nmf_kl(dtm, k, iter, semilla); r$metodo <- "nmf" }
  rownames(r$theta) <- rownames(dtm); colnames(r$phi) <- colnames(dtm)
  rownames(r$phi) <- colnames(r$theta) <- paste0("tema_", seq_len(k)); r
}

# Terminos mas distintivos de cada tema (term-score de Blei y Lafferty: evita palabras generales)
terminos_por_tema <- function(modelo, n = 10) {
  phi <- modelo$phi + 1e-12
  ts <- phi * (log(phi) - rep(colMeans(log(phi)), each = nrow(phi)))
  do.call(rbind, lapply(seq_len(nrow(phi)), function(t)
    data.frame(tema = rownames(phi)[t], rank = seq_len(n), termino = colnames(phi)[order(-ts[t, ])[seq_len(n)]])))
}

coherencia_umass <- function(modelo, dtm, n = 10) {
  bin <- (dtm > 0) * 1; D <- colSums(bin)
  vapply(seq_len(nrow(modelo$phi)), function(t) {
    tw <- order(-modelo$phi[t, ])[seq_len(n)]; co <- crossprod(bin[, tw])
    s <- 0; for (i in 2:n) for (j in 1:(i - 1)) s <- s + log((co[i, j] + 1) / D[tw[j]]); s }, numeric(1))
}

elegir_k <- function(dtm, ks = c(4, 6, 8, 10, 12), iter = 100, metodo = "auto") {
  tibble::tibble(k = ks, coherencia = vapply(ks, function(k) mean(coherencia_umass(ajustar_temas(dtm, k, metodo, iter), dtm)), numeric(1)))
}

temas_por_periodo <- function(modelo, periodo) {
  th <- rowsum(modelo$theta, as.character(periodo)[match(rownames(modelo$theta), names(periodo))])
  th <- th / rowSums(th); round(th, 3)
}
