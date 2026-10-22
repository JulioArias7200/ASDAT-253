test_that("detect_dictionary_columns reconoce encabezados en español", {
  df <- data.frame(a = "a", b = "alegria", c = "positivo", d = 1,
                   stringsAsFactors = FALSE)
  names(df) <- c("t\u00e9rmino", "categor\u00eda", "polaridad", "peso")
  m <- detect_dictionary_columns(df)
  expect_equal(unname(m[["term"]]), "t\u00e9rmino")
  expect_equal(unname(m[["category"]]), "categor\u00eda")
  expect_equal(unname(m[["polarity"]]), "polaridad")
  expect_equal(unname(m[["weight"]]), "peso")
})

test_that("map_dictionary_columns aplica un mapeo explícito", {
  df <- data.frame(a = "feliz", b = "alegria", stringsAsFactors = FALSE)
  out <- map_dictionary_columns(df, c(term = "a", category = "b"))
  expect_equal(names(out), c("term", "category"))
  expect_equal(out$term, "feliz")
})

test_that("validate_external_dictionary acepta filas válidas", {
  df <- data.frame(term = c("feliz", "triste"), category = c("alegria", "tristeza"),
                   polarity = c("positivo", "negativo"), weight = c(1, 2),
                   stringsAsFactors = FALSE)
  r <- validate_external_dictionary(df)
  expect_true(r$ok)
  expect_equal(r$n_valid, 2L)
  expect_true(all(c("normalized_term", "term_type", "dictionary_version")
                  %in% names(r$valid)))
})

test_that("validate_external_dictionary informa categorías desconocidas", {
  df <- data.frame(term = c("feliz", "raro"), category = c("alegria", "inexistente"),
                   stringsAsFactors = FALSE)
  r <- validate_external_dictionary(df)
  expect_true(r$ok)
  expect_equal(r$n_valid, 1L)
  expect_true("inexistente" %in% r$unknown_categories)
  expect_equal(nrow(r$invalid), 1L)
})

test_that("validate_external_dictionary detecta duplicados y los conserva una vez", {
  df <- data.frame(term = c("Feliz", "FELIZ", "triste"),
                   category = c("alegria", "alegria", "tristeza"),
                   stringsAsFactors = FALSE)
  r <- validate_external_dictionary(df)
  expect_equal(r$duplicates, 1L)
  expect_equal(r$n_valid, 2L)
})

test_that("validate_external_dictionary corrige polaridad y peso inválidos", {
  df <- data.frame(term = "feliz", category = "alegria",
                   polarity = "muy positivo", weight = "mucho",
                   stringsAsFactors = FALSE)
  r <- validate_external_dictionary(df)
  expect_equal(r$valid$polarity, "neutro")
  expect_equal(r$valid$weight, 1)
  expect_true(length(r$warnings) >= 2)
})

test_that("validate_external_dictionary rechaza archivos sin columnas obligatorias", {
  r <- validate_external_dictionary(data.frame(foo = "x"))
  expect_false(r$ok)
  expect_true(length(r$issues) >= 1)
})

test_that("read_external_dictionary lee CSV, JSON y TXT", {
  csv <- tempfile(fileext = ".csv")
  writeLines(c("termino;categoria;polaridad;peso",
               "feliz;alegria;positivo;1"), csv, useBytes = TRUE)
  d1 <- read_external_dictionary(csv)
  expect_true("termino" %in% names(d1))

  json <- tempfile(fileext = ".json")
  jsonlite::write_json(list(list(term = "feliz", category = "alegria")), json,
                       auto_unbox = TRUE)
  d2 <- read_external_dictionary(json)
  expect_equal(d2$term, "feliz")

  txt <- tempfile(fileext = ".txt")
  writeLines(c("feliz;alegria;positivo;1", "triste;tristeza;negativo;1"), txt,
             useBytes = TRUE)
  d3 <- read_external_dictionary(txt)
  expect_equal(nrow(d3), 2L)
})

test_that("import_external_dictionary crea versión sin sobrescribir el activo", {
  tmpdir <- tempfile("dict")
  dir.create(tmpdir, recursive = TRUE)
  cfg <- load_config()
  cfg$paths$dictionary <- file.path(tmpdir, "sentiment_dictionary.csv")
  readr::write_csv(data.frame(
    term = "base", normalized_term = "base", category = "alegria",
    polarity = "positivo", weight = 1, term_type = "palabra",
    language_variant = "es", negation_sensitive = TRUE,
    source = "test", notes = "", dictionary_version = "v1"
  ), cfg$paths$dictionary, na = "")

  df <- data.frame(term = c("feliz", "gracias"), category = c("alegria", "gratitud"),
                   stringsAsFactors = FALSE)
  res <- import_external_dictionary(df, label = "ext_test", cfg = cfg)

  expect_true(file.exists(res$path))
  expect_false(res$activated)
  active <- readr::read_csv(cfg$paths$dictionary, show_col_types = FALSE)
  expect_equal(active$term, "base")
  versions <- list_dictionary_versions(cfg)
  expect_true(any(versions$version == "ext_test"))
})

test_that("importar y activar reemplaza el activo dejando respaldo", {
  tmpdir <- tempfile("dict2")
  dir.create(tmpdir, recursive = TRUE)
  cfg <- load_config()
  cfg$paths$dictionary <- file.path(tmpdir, "sentiment_dictionary.csv")
  readr::write_csv(data.frame(
    term = "base", normalized_term = "base", category = "alegria",
    polarity = "positivo", weight = 1, term_type = "palabra",
    language_variant = "es", negation_sensitive = TRUE,
    source = "test", notes = "", dictionary_version = "v1"
  ), cfg$paths$dictionary, na = "")

  df <- data.frame(term = "feliz", category = "alegria", stringsAsFactors = FALSE)
  res <- import_external_dictionary(df, label = "ext_act", cfg = cfg, activate = TRUE)
  expect_true(res$activated)
  active <- readr::read_csv(cfg$paths$dictionary, show_col_types = FALSE)
  expect_equal(active$term, "feliz")
  backups <- list.files(dictionary_versions_dir(cfg), pattern = "^backup_")
  expect_true(length(backups) >= 1)
})
