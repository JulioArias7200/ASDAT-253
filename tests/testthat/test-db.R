test_that("ensure_database crea el esquema completo y es idempotente", {
  db <- "data/interim/test_as.sqlite"
  p <- proj_path(db)
  if (file.exists(p)) unlink(p)
  ensure_database(path = db)
  ensure_database(path = db)  # idempotente
  con <- db_connect(path = db)
  on.exit({ db_disconnect(con); unlink(p) }, add = TRUE)
  tabs <- DBI::dbListTables(con)
  expect_true(all(c("corpus", "import_batches", "messages", "pipeline_runs",
                    "sentiment_results", "audit_events", "dictionary_versions",
                    "artifacts", "manual_labels") %in% tabs))
})

test_that("el flujo corpus -> lote -> mensajes -> bitácora persiste", {
  db <- "data/interim/test_as2.sqlite"
  p <- proj_path(db)
  if (file.exists(p)) unlink(p)
  ensure_database(path = db)
  con <- db_connect(path = db)
  on.exit({ db_disconnect(con); unlink(p) }, add = TRUE)

  cid <- db_upsert_corpus(con, "t", "telegram_json", "x", n_messages = 13)
  bid <- db_create_batch(con, cid, "f.json")
  imp <- import_telegram_json(fixture("synthetic_telegram.json"), corpus_id = cid,
                              batch_id = bid, cfg = load_config())
  n <- db_insert_messages(con, imp$messages)
  expect_equal(n, 13)
  expect_equal(db_query(con, "SELECT COUNT(*) AS n FROM messages")$n, 13)

  ev <- audit_event(con, "test_stage")
  expect_true(ev > 0)
  expect_gte(nrow(audit_recent(con, 5)), 1)
})
