# =============================================================================
# database.R — acceso a SQLite (trazabilidad, resultados, bitácora)
# =============================================================================

#' Conexión a la base de datos del proyecto
#' @export
db_connect <- function(path = NULL, cfg = NULL) {
  path <- path %||% cfg_get(cfg %||% load_config(), "paths", "database")
  path <- proj_path(path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(RSQLite::SQLite(), dbname = path)
  DBI::dbExecute(con, "PRAGMA foreign_keys = ON;")
  con
}

#' Cierra conexión de forma segura
#' @export
db_disconnect <- function(con) {
  if (!is.null(con) && DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  invisible(NULL)
}

#' Crea el esquema si no existe (idempotente)
#' @export
ensure_database <- function(path = NULL, cfg = NULL, schema = NULL) {
  schema <- schema %||% proj_path("database", "schema.sql")
  if (!file.exists(schema)) stop("No se encontró schema.sql: ", schema)
  con <- db_connect(path, cfg)
  on.exit(db_disconnect(con), add = TRUE)
  sql <- readLines(schema, warn = FALSE, encoding = "UTF-8")
  # Elimina líneas de comentario completas y divide en sentencias
  sql <- sql[!grepl("^\\s*--", sql)]
  sql <- paste(sql, collapse = "\n")
  stmts <- strsplit(sql, ";", fixed = TRUE)[[1]]
  stmts <- trimws(stmts)
  stmts <- stmts[nzchar(stmts)]
  for (s in stmts) {
    DBI::dbExecute(con, s)
  }
  invisible(path %||% cfg_get(cfg %||% load_config(), "paths", "database"))
}

#' Inserta/recupera un corpus
#' @export
db_upsert_corpus <- function(con, name, source_type, source_path = NA,
                             group_id = NA, group_name = NA, n_messages = NA,
                             notes = NA) {
  existing <- DBI::dbGetQuery(
    con, "SELECT corpus_id FROM corpus WHERE name = ? AND source_path IS ?",
    params = list(name, source_path)
  )
  if (nrow(existing)) return(existing$corpus_id[[1]])
  DBI::dbExecute(con,
    "INSERT INTO corpus (name, source_type, source_path, group_id, group_name,
       created_at, n_messages, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(name, source_type, source_path, group_id, group_name,
                  now_utc(), n_messages, notes)
  )
  DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id[[1]]
}

#' Crea un lote de importación y devuelve su id
#' @export
db_create_batch <- function(con, corpus_id, source_file, file_hash = NA,
                            n_total = NA, n_imported = NA, n_rejected = NA,
                            n_duplicated = NA, n_pending = NA,
                            params = NULL, status = "running") {
  DBI::dbExecute(con,
    "INSERT INTO import_batches (corpus_id, source_file, file_hash, imported_at,
       n_total, n_imported, n_rejected, n_duplicated, n_pending, params_json, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(corpus_id, source_file, file_hash, now_utc(),
                  n_total, n_imported, n_rejected, n_duplicated, n_pending,
                  as_json(params), status)
  )
  DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id[[1]]
}

#' Actualiza el resumen de un lote
#' @export
db_finalize_batch <- function(con, batch_id, n_total, n_imported,
                              n_rejected, n_duplicated, n_pending, status) {
  DBI::dbExecute(con,
    "UPDATE import_batches SET n_total=?, n_imported=?, n_rejected=?,
       n_duplicated=?, n_pending=?, status=? WHERE batch_id=?",
    params = list(n_total, n_imported, n_rejected, n_duplicated, n_pending,
                  status, batch_id)
  )
}

#' Inserta mensajes (data.frame/tibble canónico). Ignora duplicados.
#' @export
db_insert_messages <- function(con, messages) {
  if (!nrow(messages)) return(0L)
  cols <- c("message_id", "corpus_id", "batch_id", "chat_id", "timestamp_utc",
            "timestamp_local", "tz", "sender_id", "sender_name", "text_original",
            "text_norm", "reply_to_id", "forwarded", "edited", "message_type",
            "media_type", "sticker_emoji", "emoji_list", "reactions",
            "source_file", "import_batch_id", "review_pending", "created_at")
  df <- as.data.frame(messages)
  for (c in cols) if (!c %in% names(df)) df[[c]] <- NA
  df <- df[, cols, drop = FALSE]
  df$forwarded <- as.integer(df$forwarded)
  df$edited <- as.integer(df$edited)
  df$review_pending <- as.integer(df$review_pending)
  if (is.null(df$created_at) || all(is.na(df$created_at))) df$created_at <- now_utc()

  before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM messages")$n
  DBI::dbWriteTable(con, "messages", df, append = TRUE, row.names = FALSE)
  after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM messages")$n
  as.integer(after - before)
}

#' Inicia una ejecución de pipeline y devuelve run_id
#' @export
db_start_run <- function(con, stage, corpus_id = NA, batch_id = NA,
                         params = NULL, dictionary_version = NA) {
  DBI::dbExecute(con,
    "INSERT INTO pipeline_runs (stage, corpus_id, batch_id, started_at,
       code_version, dictionary_version, params_json, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'running')",
    params = list(stage, corpus_id, batch_id, now_utc(),
                  code_version(), dictionary_version, as_json(params))
  )
  DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id[[1]]
}

#' Finaliza una ejecución
#' @export
db_finish_run <- function(con, run_id, status = "completed", n_processed = NA,
                          n_discarded = NA, warnings = NA, errors = NA) {
  started <- DBI::dbGetQuery(con, "SELECT started_at FROM pipeline_runs WHERE run_id=?",
                             params = list(run_id))$started_at
  dur <- NA_real_
  if (length(started) && !is.na(started)) {
    dur <- as.numeric(difftime(as.POSIXct(now_utc(), tz = "UTC"),
                               as.POSIXct(started, tz = "UTC"), units = "secs"))
  }
  DBI::dbExecute(con,
    "UPDATE pipeline_runs SET finished_at=?, duration_s=?, n_processed=?,
       n_discarded=?, status=?, warnings=?, errors=? WHERE run_id=?",
    params = list(now_utc(), dur, n_processed, n_discarded, status,
                  warnings, errors, run_id))
}

#' Inserta resultados de sentimiento
#' @export
db_insert_sentiment <- function(con, res) {
  if (!nrow(res)) return(0L)
  df <- as.data.frame(res)
  cols <- c("run_id", "message_id", "corpus_id", "polarity", "polarity_label",
            "emotion_scores", "detected_emotions", "dominant_emotion", "intensity",
            "evidence_level", "n_terms", "dictionary_version", "created_at")
  for (c in cols) if (!c %in% names(df)) df[[c]] <- NA
  df <- df[, cols, drop = FALSE]
  DBI::dbWriteTable(con, "sentiment_results", df, append = TRUE, row.names = FALSE)
  nrow(df)
}

#' Registra un artefacto
#' @export
db_add_artifact <- function(con, run_id, type, path, description = NA) {
  DBI::dbExecute(con,
    "INSERT INTO artifacts (run_id, type, path, description, created_at)
     VALUES (?, ?, ?, ?, ?)",
    params = list(run_id, type, path, description, now_utc()))
}

#' Consulta genérica
#' @export
db_query <- function(con, sql, params = NULL) {
  DBI::dbGetQuery(con, sql, params = params)
}
