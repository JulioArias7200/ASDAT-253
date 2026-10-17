test_that("normalize_term quita acentos y pasa a minúsculas", {
  expect_equal(normalize_term("FELÍZ"), "feliz")
  expect_equal(normalize_term("Corazón"), "corazon")
})

test_that("el diccionario carga con 18 categorías y valida", {
  dict <- load_dictionary(cfg = load_config())
  v <- validate_dictionary(dict)
  expect_true(v$ok)
  expect_equal(v$categories, 18)
  expect_gt(v$n_terms, 300)
})

test_that("dictionary_version es estable y no vacío", {
  ver <- dictionary_version(cfg = load_config())
  expect_type(ver, "character")
  expect_true(nzchar(ver))
})

test_that("add_term añade una fila válida y rechaza categorías inválidas", {
  dict <- test_dictionary()
  n0 <- nrow(dict)
  d2 <- add_term(dict, "testword", "alegria", "positivo", weight = 2)
  expect_equal(nrow(d2), n0 + 1)
  expect_equal(d2$normalized_term[nrow(d2)], "testword")
  expect_error(add_term(dict, "x", "categoria_inexistente", "positivo"))
})

test_that("save_dictionary escribe CSV y permite recargar", {
  dict <- test_dictionary()
  tmp <- tempfile(fileext = ".csv")
  save_dictionary(dict, path = tmp)
  expect_true(file.exists(tmp))
  back <- load_dictionary(path = tmp)
  expect_equal(nrow(back), nrow(dict))
})
