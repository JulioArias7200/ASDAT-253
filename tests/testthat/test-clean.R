test_that("normalize_text limpia ruido conservando emojis y negaciones", {
  cfg <- load_config()
  out <- normalize_text("MIRA https://example.com  ¡Hola!  😊", cfg)
  expect_false(grepl("https://example.com", out))
  expect_true(grepl("hola", out))
  expect_true(grepl("\U0001F60A", out))
})

test_that("normalize_text elimina menciones cuando la config lo indica", {
  cfg <- load_config()
  cfg$cleaning$strip_mentions <- TRUE
  out <- normalize_text("hola @usuario gracias", cfg)
  expect_false(grepl("@usuario", out))
})

test_that("normalize_text no elimina negaciones ni palabras cortas", {
  out <- normalize_text("No me gusto nada", load_config())
  expect_true(grepl("\\bno\\b", out))
  expect_true(grepl("\\bnada\\b", out))
})

test_that("is_url_only detecta URLs puras", {
  expect_true(is_url_only("https://example.com"))
  expect_false(is_url_only("mira https://example.com"))
})

test_that("word_count cuenta palabras", {
  expect_equal(word_count("una dos tres"), 3L)
  expect_equal(word_count(""), 0L)
})

test_that("clean_messages añade text_norm sin perder el original", {
  msgs <- tibble::tibble(text_original = c("HOLA  MUNDO", "😊 Feliz"))
  res <- clean_messages(msgs, load_config())
  expect_true("text_norm" %in% names(res$messages))
  expect_equal(res$messages$text_original, c("HOLA  MUNDO", "😊 Feliz"))
  expect_true(grepl("\U0001F60A", res$messages$text_norm[2]))
})
