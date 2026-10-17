test_that("score_message reconoce felicidad con emoji", {
  dict <- test_dictionary(); cfg <- load_config()
  s <- score_message("Estoy muy feliz \U0001F60A", dict, cfg)
  expect_equal(s$polarity_label, "positivo")
  expect_true("alegria" %in% s$detected_emotions)
  expect_equal(s$evidence_level, "suficiente")
  expect_gte(s$n_emoji, 1L)
})

test_that("score_message aplica negación léxica", {
  dict <- test_dictionary(); cfg <- load_config()
  s <- score_message("No estoy feliz", dict, cfg)
  expect_lt(s$polarity, 0)
  expect_equal(s$polarity_label, "negativo")
})

test_that("score_message resuelve la doble negación como positiva", {
  dict <- test_dictionary(); cfg <- load_config()
  s <- score_message("No está nada mal", dict, cfg)
  expect_equal(s$polarity_label, "positivo")
})

test_that("score_message con solo emoji triste da negativo/tristeza", {
  dict <- test_dictionary(); cfg <- load_config()
  s <- score_message("\U0001F622", dict, cfg)
  expect_equal(s$polarity_label, "negativo")
  expect_equal(s$dominant_emotion, "tristeza")
  expect_equal(s$evidence_level, "suficiente")
})

test_that("texto sin señales queda indeterminado, nunca neutral por defecto", {
  dict <- test_dictionary(); cfg <- load_config()
  s <- score_message("el grupo se reunió a las tres", dict, cfg)
  expect_equal(s$evidence_level, "sin_evidencia")
  expect_equal(s$polarity_label, "indeterminado")
})

test_that("analyze_sentiment devuelve una fila por mensaje y versión de diccionario", {
  cfg <- load_config()
  dict <- test_dictionary()
  imp <- import_telegram_json(fixture("synthetic_telegram.json"), corpus_id = 1L,
                              batch_id = 1L, cfg = cfg)
  msgs <- imp$messages
  cl <- clean_messages(msgs, cfg)
  res <- analyze_sentiment(cl$messages, dict, cfg)
  expect_equal(nrow(res), nrow(msgs))
  expect_true(all(c("message_id", "polarity_label", "evidence_level",
                    "dominant_emotion") %in% names(res)))
  expect_false(is.null(attr(res, "dictionary_version")))
})
