test_that("validate_messages acepta el corpus canónico con advertencias", {
  cfg <- load_config()
  imp <- import_telegram_json(fixture("synthetic_telegram.json"), corpus_id = 1L,
                              batch_id = 1L, cfg = cfg)
  v <- validate_messages(imp$messages)
  expect_true(v$ok)
  expect_true("duplicate_content" %in% v$issues$type)
  expect_true(all(v$issues$severity[v$issues$type == "duplicate_content"] == "warning"))
})

test_that("validate_messages falla ante columnas faltantes", {
  bad <- tibble::tibble(message_id = 1L)
  v <- validate_messages(bad)
  expect_false(v$ok)
  expect_true("missing_columns" %in% v$issues$type)
})

test_that("validate_messages detecta timestamps inválidos", {
  bad <- tibble::tibble(
    message_id = 1:2, timestamp_utc = c("no-fecha", "2023-01-01T00:00:00Z"),
    text_original = c("a", "b"), message_type = c("message", "message"),
    sender_id = c("u1", "u2"))
  v <- validate_messages(bad)
  expect_false(v$ok)
  expect_true("bad_timestamp" %in% v$issues$type)
})

test_that("check_utf8 valida codificación", {
  res <- check_utf8(c("texto válido", "otro"))
  expect_true(res$ok)
  expect_equal(res$n_invalid, 0)
})
