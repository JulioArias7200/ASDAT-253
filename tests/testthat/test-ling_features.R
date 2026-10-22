test_that("linguistic_features mide métricas verificables", {
  f <- linguistic_features("Hola MUNDO!! \u00bfqu\u00e9 tal? \U0001F60A\U0001F60A hola")
  expect_equal(f$n_words, 5L)
  expect_equal(f$n_unique_words, 4L)
  expect_equal(f$unique_ratio, 0.8)
  expect_equal(f$mean_word_len, 3.8)
  expect_equal(f$n_questions, 2L)
  expect_equal(f$n_exclamations, 2L)
  expect_equal(f$n_upper_words, 1L)
  expect_equal(f$n_emojis, 2L)
})

test_that("linguistic_features cuenta hashtags, menciones y URLs", {
  f <- linguistic_features("mira https://example.com @ana #curso")
  expect_equal(f$n_urls, 1L)
  expect_equal(f$n_mentions, 1L)
  expect_equal(f$n_hashtags, 1L)
})

test_that("linguistic_features detecta repeticiones e intensidad", {
  f <- linguistic_features("holaaa!!! jajaja")
  expect_equal(f$n_repeated_chars, 1L)
  expect_equal(f$n_repeated_punct, 1L)
  expect_equal(f$n_intensity, 1L)
})

test_that("texto vacío produce ceros sin errores", {
  f <- linguistic_features("")
  expect_equal(f$n_words, 0L)
  expect_equal(f$unique_ratio, 0)
  expect_equal(f$mean_word_len, 0)
})

test_that("linguistic_features_messages conserva message_id", {
  msgs <- tibble::tibble(message_id = c(10, 11),
                         text_original = c("uno dos", "tres"))
  f <- linguistic_features_messages(msgs)
  expect_equal(f$message_id, c(10, 11))
  expect_equal(f$n_words, c(2L, 1L))
})

test_that("feature_summary resume todas las métricas numéricas", {
  f <- linguistic_features(c("uno dos", "tres cuatro cinco"))
  s <- feature_summary(f)
  expect_true(all(c("feature", "mean", "median", "p90", "max") %in% names(s)))
  expect_true("n_words" %in% s$feature)
})

test_that("features_by_period agrega por mes", {
  f <- linguistic_features(c("uno", "dos tres", "cuatro"))
  d <- as.Date(c("2024-01-05", "2024-01-20", "2024-02-01"))
  out <- features_by_period(f, d, period = "month")
  expect_equal(nrow(out), 2L)
  expect_true(all(c("period", "n", "n_words") %in% names(out)))
  expect_equal(out$n[out$period == "2024-01"], 2L)
})
