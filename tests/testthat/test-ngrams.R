test_that("ngram_frequencies cuenta unigramas correctamente", {
  texts <- c("hola mundo feliz", "hola hola")
  df <- ngram_frequencies(texts, n = 1L, remove_stopwords = FALSE)
  expect_equal(df$count[df$ngram == "hola"], 3L)
  expect_equal(df$count[df$ngram == "mundo"], 1L)
  expect_true(all(diff(df$count) <= 0))
})

test_that("los bigramas NO cruzan límites entre mensajes", {
  texts <- c("uno dos", "tres cuatro")
  df <- ngram_frequencies(texts, n = 2L, remove_stopwords = FALSE)
  expect_true("uno dos" %in% df$ngram)
  expect_true("tres cuatro" %in% df$ngram)
  expect_false("dos tres" %in% df$ngram)
})

test_that("las stopwords se eliminan pero los negadores se conservan", {
  texts <- c("no es bueno", "nunca es malo")
  df <- ngram_frequencies(texts, n = 1L, remove_stopwords = TRUE)
  expect_true("no" %in% df$ngram)
  expect_true("nunca" %in% df$ngram)
  expect_false("es" %in% df$ngram)
})

test_that("min_count filtra y prop es una frecuencia relativa válida", {
  texts <- c("a b", "a c", "a d")
  df <- ngram_frequencies(texts, n = 1L, min_count = 2L,
                          remove_stopwords = FALSE)
  expect_true(all(df$count >= 2L))
  expect_true(all(df$prop > 0 & df$prop <= 1))
  expect_equal(df$ngram[1], "a")
})

test_that("ngram_table integra varios tamaños", {
  texts <- c("uno dos tres", "uno dos cuatro")
  tab <- ngram_table(texts, sizes = 1:2, min_count = 1L, remove_stopwords = FALSE)
  expect_equal(sort(unique(tab$size)), c(1L, 2L))
  expect_true("uno dos" %in% tab$ngram[tab$size == 2L])
})

test_that("compare_stopword_effect devuelve antes/después", {
  texts <- c("de la casa", "de la calle")
  res <- compare_stopword_effect(texts, n = 1L, top = 10)
  expect_named(res, c("before", "after"))
  expect_true(any(res$before$ngram == "de"))
  expect_false(any(res$after$ngram == "de"))
})

test_that("ngram_frequencies_by agrupa por periodo", {
  texts <- c("hola mundo", "hola gente", "otra cosa")
  g <- c("2024-01", "2024-01", "2024-02")
  df <- ngram_frequencies_by(texts, g, n = 1L, top = 1, remove_stopwords = FALSE)
  expect_equal(nrow(df), 2L)
  expect_true(all(df$group %in% c("2024-01", "2024-02")))
})
