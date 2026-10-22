# =============================================================================
# validate_corpus.R — validación estructural del corpus canónico
# =============================================================================

.required_cols <- c("message_id", "timestamp_utc", "text_original", "message_type")

#' Valida los mensajes canónicos y devuelve issues
#' @export
validate_messages <- function(messages) {
  issues <- list()
  add <- function(type, detail, severity = "error") issues[[length(issues) + 1]] <<-
    tibble::tibble(type = type, detail = detail, severity = severity)

  if (!nrow(messages)) { add("empty", "El corpus no contiene filas"); return(.finalize_issues(issues, messages)) }

  miss <- setdiff(.required_cols, names(messages))
  if (length(miss)) {
    add("missing_columns", paste(miss, collapse = ", "))
    return(.finalize_issues(issues, messages))
  }

  if (!any(is.na(messages$message_id))) {
    dup <- messages$message_id[duplicated(messages$message_id)]
    if (length(dup)) add("duplicate_ids", paste(unique(dup), collapse = ", "))
  } else add("na_ids", "Existen message_id NA")

  bad_ts <- is.na(suppressWarnings(as.POSIXct(messages$timestamp_utc,
                                              format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
  if (any(bad_ts)) add("bad_timestamp", sprintf("%d filas con timestamp inválido", sum(bad_ts)))

  na_text <- is.na(messages$text_original)
  if (any(na_text)) add("na_text", sprintf("%d mensajes sin texto_original", sum(na_text)))

  if (!all(messages$message_type %in% c("message", "service")))
    add("unknown_type", "Hay tipos distintos de message/service")

  if (all(c("timestamp_utc", "sender_id", "text_original") %in% names(messages))) {
    key <- paste(messages$timestamp_utc, messages$sender_id, messages$text_original, sep = "|")
    ndc <- sum(duplicated(key))
    if (ndc) add("duplicate_content", sprintf("%d mensajes con contenido duplicado", ndc), "warning")
  }

  .finalize_issues(issues, messages)
}

.finalize_issues <- function(issues, messages) {
  issues_tbl <- if (length(issues)) dplyr::bind_rows(issues) else
    tibble::tibble(type = character(), detail = character(), severity = character())
  ok <- !any(issues_tbl$severity == "error")
  n_dup <- if ("message_id" %in% names(messages)) sum(duplicated(messages$message_id)) else NA_integer_
  list(ok = ok, issues = issues_tbl, n = nrow(messages),
       n_duplicates = n_dup,
       n_warnings = sum(issues_tbl$severity == "warning"))
}

#' Comprueba la codificación UTF-8 de los textos
#' @export
check_utf8 <- function(text) {
  valid <- vapply(text, function(t) isTRUE(stringi::stri_enc_isutf8(t)), logical(1),
                  USE.NAMES = FALSE)
  list(ok = all(valid), n_invalid = sum(!valid))
}
