test_that("build_dfm produce una matriz documento-término", {
  texts <- c("inscripción de materias y horarios", "pago del kardex y materias",
             "inscripción y pago de materias", "horarios y materias de carrera")
  dfm <- build_dfm(texts, load_config())
  expect_s4_class(dfm, "dfm")
  expect_gte(quanteda::ndoc(dfm), 1)
})

test_that("fit_topics ajusta un LDA y top_terms devuelve k listas", {
  texts <- rep(c("inscripción materias horario pago kardex",
                 "clase hoy retiro comunicado horarios",
                 "grupo materia semestre datos whatsapp"), 5)
  fit <- fit_topics(texts, k = 2L, cfg = load_config())
  expect_equal(fit$k, 2L)
  tt <- top_terms(fit, n = 5)
  expect_length(tt, 2)
  expect_true(all(vapply(tt, length, integer(1)) <= 5))
  tbl <- topics_table(fit, n = 5)
  expect_equal(nrow(tbl), 2)
  expect_true(all(c("topic", "top_words") %in% names(tbl)))
})
