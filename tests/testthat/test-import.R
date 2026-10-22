test_that("telegram_text une partes de texto y maneja cadenas", {
  expect_equal(telegram_text("hola"), "hola")
  parts <- list(list(type = "plain", text = "Mira "),
                list(type = "link", text = "https://example.com"),
                list(type = "plain", text = " ahora"))
  expect_equal(telegram_text(parts), "Mira https://example.com ahora")
  expect_equal(telegram_text(NULL), "")
})

test_that("import_telegram_json rechaza servicio y media sin texto", {
  cfg <- load_config()
  imp <- import_telegram_json(fixture("synthetic_telegram.json"), corpus_id = 1L,
                              batch_id = 1L, cfg = cfg)
  r <- imp$report
  expect_equal(r$n_total, 15)
  expect_equal(r$n_service, 1)
  expect_equal(r$n_media_no_text, 1)
  expect_equal(r$n_imported, 13)
  expect_equal(nrow(imp$messages), 13)
})

test_that("import_telegram_json marca duplicados de contenido para revisión", {
  cfg <- load_config()
  imp <- import_telegram_json(fixture("synthetic_telegram.json"), corpus_id = 1L,
                              batch_id = 1L, cfg = cfg)
  expect_equal(sum(imp$messages$review_pending), 1)
})

test_that("los timestamps se normalizan a UTC ISO-8601", {
  cfg <- load_config()
  imp <- import_telegram_json(fixture("synthetic_telegram.json"), corpus_id = 1L,
                              batch_id = 1L, cfg = cfg)
  expect_true(all(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$",
                        imp$messages$timestamp_utc)))
})

test_that("telegram_reactions normaliza el formato de reacciones", {
  r <- list(list(type = "emoji", count = 3L, emoji = "\U0001F44D"),
            list(type = "emoji", count = 1L, emoji = "\u2764"))
  out <- telegram_reactions(r)
  expect_equal(out[["\U0001F44D"]], 3L)
})
