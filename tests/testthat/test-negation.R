test_that("tokenize_es conserva negadores y palabras cortas", {
  toks <- tokenize_es("no me gusto nada")
  expect_true(all(c("no", "nada") %in% toks))
})

test_that("detect_negation marca la ventana posterior al negador", {
  det <- detect_negation(tokenize_es("no estoy feliz"), window = 3L)
  feliz <- det[det$token == "feliz", ]
  expect_true(feliz$negated)
  expect_equal(feliz$negator, "no")
})

test_that("detect_negation no propaga más allá de la ventana", {
  det <- detect_negation(tokenize_es("no uno dos tres cuatro cinco"), window = 2L)
  expect_true(det$negated[det$token == "uno"])
  expect_true(det$negated[det$token == "dos"])
  expect_false(det$negated[det$token == "cuatro"])
})

test_that("doble negación se resuelve como excepción positiva", {
  expect_equal(double_negation_exception("esto no está nada mal"), "positivo")
  expect_equal(double_negation_exception("no puedo estar mas feliz"), "positivo")
  expect_null(double_negation_exception("está mal"))
})

test_that("apply_negation_marking prefija NEGMARK_", {
  marked <- apply_negation_marking(tokenize_es("no feliz"))
  expect_true(any(grepl("^NEGMARK_", marked)))
})
