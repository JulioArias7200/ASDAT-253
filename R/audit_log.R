# =============================================================================
# audit_log.R — bitácora persistente (SQLite)
# Garantiza que una ejecución interrumpida nunca quede como "completed".
# =============================================================================

#' Registra un evento de bitácora y devuelve su id
#' @export
audit_event <- function(con, action, run_id = NA, corpus_id = NA, batch_id = NA,
                        n_messages = NA, params = NULL, status = "completed",
                        duration_s = NA, warnings = NA, errors = NA,
                        artifacts = NA, session_id = NA) {
  DBI::dbExecute(con,
    "INSERT INTO audit_events (run_id, timestamp, session_id, action, corpus_id,
       batch_id, n_messages, params_json, code_version, dictionary_version,
       status, duration_s, warnings, errors, artifacts)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(run_id, now_utc(), session_id, action, corpus_id, batch_id,
                  n_messages, as_json(params), code_version(), NA_character_,
                  status, duration_s, warnings, errors, as_json(artifacts))
  )
  DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id[[1]]
}

#' Inicia una etapa: crea run + evento "started"; devuelve ids
#' @export
audit_start <- function(con, action, corpus_id = NA, batch_id = NA,
                        params = NULL, dictionary_version = NA, session_id = NA) {
  run_id <- db_start_run(con, action, corpus_id, batch_id, params, dictionary_version)
  event_id <- audit_event(con, action, run_id = run_id, corpus_id = corpus_id,
                          batch_id = batch_id, params = params,
                          status = "started", session_id = session_id)
  list(run_id = run_id, event_id = event_id, t0 = Sys.time())
}

#' Finaliza una etapa registrando estado, duración y contadores
#' @export
audit_finish <- function(con, handle, status = "completed", n_processed = NA,
                         n_discarded = NA, warnings = NA, errors = NA,
                         artifacts = NA) {
  dur <- as.numeric(difftime(Sys.time(), handle$t0, units = "secs"))
  db_finish_run(con, handle$run_id, status, n_processed, n_discarded,
                warnings, errors)
  DBI::dbExecute(con,
    "UPDATE audit_events SET status=?, duration_s=?, n_messages=?, warnings=?,
       errors=?, artifacts=? WHERE event_id=?",
    params = list(status, dur, n_processed, warnings, errors,
                  as_json(artifacts), handle$event_id))
  invisible(dur)
}

#' Registra un error y marca la ejecución como fallida (nunca "completed")
#' @export
audit_error <- function(con, handle, error) {
  msg <- if (inherits(error, "condition")) conditionMessage(error) else as.character(error)
  try(audit_finish(con, handle, status = "failed", errors = msg), silent = TRUE)
  invisible(msg)
}

#' Orquestador: ejecuta una expresión en una etapa auditada.
#' Registra éxito o error y devuelve el valor de la expresión.
#' @export
run_stage <- function(con, action, expr, corpus_id = NA, batch_id = NA,
                      params = NULL, dictionary_version = NA, session_id = NA) {
  handle <- audit_start(con, action, corpus_id, batch_id, params,
                        dictionary_version, session_id)
  result <- tryCatch(
    force(expr),
    error = function(e) {
      audit_error(con, handle, e)
      stop(e)
    }
  )
  attr(result, "audit_handle") <- handle
  result
}

#' Lista los últimos eventos de bitácora
#' @export
audit_recent <- function(con, n = 50) {
  DBI::dbGetQuery(con,
    "SELECT event_id, timestamp, action, status, n_messages, duration_s,
            warnings, errors FROM audit_events
     ORDER BY event_id DESC LIMIT ?", params = list(n))
}
