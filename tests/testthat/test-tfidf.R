test_that("TF-IDF coincide con el cálculo manual", {
  texts <- c("a b a", "b c", "a c")
  res <- compute_tfidf(texts, remove_stopwords = FALSE, tf_scheme = "raw",
                       min_df = 1L)
  N <- 3
  idf <- log(N / 2)  # a, b y c aparecen en 2 documentos
  doc1 <- res[res$doc_id == 1, ]
  expect_equal(doc1$tf_count[doc1$term == "a"], 2L)
  expect_equal(doc1$tfidf[doc1$term == "a"], 2 * idf)
  expect_equal(doc1$tfidf[doc1$term == "b"], idf)
  expect_equal(nrow(res), 6L)  # 3 documentos x 2 términos cada uno
})

test_that("IDF es cero cuando el término aparece en todos los documentos", {
  res <- compute_tfidf(c("x y", "x z"), remove_stopwords = FALSE)
  expect_true(all(res$idf[res$term == "x"] == 0))
  expect_true(all(res$tfidf[res$term == "x"] == 0))
})

test_that("TF admite esquemas prop y log", {
  texts <- c("a b a")
  prop <- compute_tfidf(texts, remove_stopwords = FALSE, tf_scheme = "prop")
  expect_equal(prop$tf[prop$term == "a"], 2 / 3)
  logv <- compute_tfidf(texts, remove_stopwords = FALSE, tf_scheme = "log")
  expect_equal(logv$tf[logv$term == "a"], 1 + log10(2))
})

test_that("min_df descarta términos poco frecuentes", {
  res <- compute_tfidf(c("unico a", "b c"), remove_stopwords = FALSE,
                       min_df = 2L)
  expect_false("unico" %in% res$term)
  expect_true(nrow(res) == 0L)
})

test_that("tfidf_top_terms y tfidf_global resumen por documento y término", {
  res <- compute_tfidf(c("a a b", "b c c c"), remove_stopwords = FALSE)
  top <- tfidf_top_terms(res, n = 1L)
  expect_equal(nrow(top), 2L)
  expect_equal(top$term[top$doc_id == 1], "a")
  g <- tfidf_global(res)
  expect_true(all(c("term", "sum_tfidf") %in% names(g)))
  expect_equal(g$term[1], "c")
})

test_that("tfidf_by_period agrega pesos por mes e ids", {
  res <- compute_tfidf(c("a b", "a c", "d"), ids = c(10, 11, 12),
                       remove_stopwords = FALSE)
  d <- as.Date(c("2024-01-03", "2024-01-20", "2024-02-01"))
  out <- tfidf_by_period(res, d, ids = c(10, 11, 12), period = "month")
  expect_true(all(c("period", "term", "sum_tfidf") %in% names(out)))
  expect_equal(sort(unique(out$period)), c("2024-01", "2024-02"))
})

test_that("textos vacíos devuelven una tabla vacía con el esquema correcto", {
  res <- compute_tfidf(c("", "   "), remove_stopwords = FALSE)
  expect_equal(nrow(res), 0L)
  expect_named(res, c("doc_id", "term", "tf_count", "df", "idf", "tf", "tfidf"))
})
