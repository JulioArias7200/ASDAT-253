# =============================================================================
# import_corpus.R — importación del corpus (Telegram JSON / CSV)
# =============================================================================

#' Extrae el texto visible de una exportación de Telegram.
#' El campo `text` puede ser cadena o lista de partes ({type, text}).
#' @export
telegram_text <- function(x) {
  if (is.null(x)) return("")
  if (is.character(x) && length(x) == 1) return(x)
  parts <- vapply(x, function(p) {
    if (is.character(p)) return(p)
    if (is.list(p)) return(as.character(p$text %||% ""))
    as.character(p)
  }, character(1), USE.NAMES = FALSE)
  paste(parts, collapse = "")
}

#' Normaliza reacciones a lista nombrada {emoji: count}
#' @export
telegram_reactions <- function(r) {
  if (is.null(r) || length(r) == 0) return(list())
  out <- list()
  for (item in r) {
    emoji <- item$emoji %||% item$reaction %||% NA
    count <- item$count %||% 0
    if (!is.null(emoji) && !is.na(emoji)) out[[as.character(emoji)]] <- as.integer(count)
  }
  out
}

#' Determina el media_type de un mensaje de Telegram
#' @export
telegram_media_type <- function(m) {
  if (!is.null(m$media_type) && nzchar(m$media_type %||% "")) return(as.character(m$media_type))
  if (!is.null(m$photo)) return("photo")
  if (!is.null(m$file) || !is.null(m$file_name)) return("file")
  if (!is.null(m$sticker_emoji)) return("sticker")
  NA_character_
}

#' Convierte un mensaje crudo de Telegram a fila canónica
#' @export
parse_telegram_message <- function(m, corpus_id, batch_id, source_file, tz = "America/La_Paz") {
  ts_utc <- as.POSIXct(as.numeric(m$date_unixtime %||% NA), origin = "1970-01-01", tz = "UTC")
  text <- to_nfc(telegram_text(m$text))
  emojis <- process_emojis(text)
  list(
    message_id      = as.integer(m$id),
    corpus_id       = corpus_id,
    batch_id        = batch_id,
    chat_id         = NA_character_,
    timestamp_utc   = format(ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    timestamp_local = if (is.na(ts_utc)) NA_character_ else
      format(ts_utc, "%Y-%m-%dT%H:%M:%S", tz = tz),
    tz              = tz,
    sender_id       = as.character(m$from_id %||% m$actor_id %||% NA),
    sender_name     = as.character(to_nfc(m$from %||% m$actor %||% NA)),
    text_original   = text,
    text_norm       = NA_character_,
    reply_to_id     = as.integer(m$reply_to_message_id %||% NA),
    forwarded       = !is.null(m$forwarded_from),
    edited          = !is.null(m$edited),
    message_type    = as.character(m$type %||% "message"),
    media_type      = telegram_media_type(m),
    sticker_emoji   = as.character(m$sticker_emoji %||% NA),
    emoji_list      = as_json(emojis),
    reactions       = as_json(telegram_reactions(m$reactions)),
    source_file     = source_file,
    import_batch_id = batch_id,
    review_pending  = FALSE,
    created_at      = now_utc()
  )
}

#' Importa un export JSON de Telegram Desktop.
#' Devuelve list(messages = tibble, report = list) SIN escribir en disco.
#' @export
import_telegram_json <- function(path, corpus_id = 1L, batch_id = 1L,
                                 cfg = load_config(), source_file = NULL) {
  if (!file.exists(path)) stop("No existe el archivo: ", path)
  source_file <- source_file %||% basename(path)
  tz <- cfg_get(cfg, "project", "timezone")
  x <- read_json_utf8(path)
  msgs <- x$messages %||% list()
  cat("Mensajes crudos en el export:", length(msgs), "\n")

  reject_service <- isTRUE(cfg_get(cfg, "import", "reject_service"))
  keep_media <- isTRUE(cfg_get(cfg, "import", "keep_media_without_text"))

  rows <- list()
  reasons <- list()
  n_service <- 0L; n_media_no_text <- 0L; n_rejected <- 0L
  seen <- integer(0)

  for (m in msgs) {
    mid <- as.integer(m$id)
    if (mid %in% seen) {
      reasons[["duplicate_id"]] <- (reasons[["duplicate_id"]] %||% 0L) + 1L
      next
    }
    seen <- c(seen, mid)

    is_service <- identical(m$type, "service")
    if (is_service && reject_service) {
      n_service <- n_service + 1L; n_rejected <- n_rejected + 1L
      next
    }
    txt <- telegram_text(m$text)
    mt <- telegram_media_type(m)
    if (!nzchar(trimws(txt)) && !is.na(mt) && !keep_media) {
      n_media_no_text <- n_media_no_text + 1L; n_rejected <- n_rejected + 1L
      next
    }
    rows[[length(rows) + 1L]] <- parse_telegram_message(m, corpus_id, batch_id, source_file, tz)
  }

  messages <- if (length(rows)) dplyr::bind_rows(lapply(rows, as.data.frame)) else
    empty_messages()

  # Duplicados de contenido (mismo timestamp, emisor y texto): se marcan para revisión
  n_dup_content <- 0L
  if (nrow(messages)) {
    key <- paste(messages$timestamp_utc, messages$sender_id, messages$text_original, sep = "|")
    dupc <- duplicated(key)
    messages$review_pending <- dupc
    n_dup_content <- sum(dupc)
  }

  report <- list(
    source_file = source_file,
    n_total = length(msgs),
    n_imported = nrow(messages),
    n_rejected = n_rejected,
    n_duplicated = reasons[["duplicate_id"]] %||% 0L,
    n_duplicated_content = n_dup_content,
    n_service = n_service,
    n_media_no_text = n_media_no_text,
    reasons = reasons
  )
  list(messages = tibble::as_tibble(messages), report = report)
}

#' Estructura vacía del formato canónico
#' @export
empty_messages <- function() {
  tibble::tibble(
    message_id = integer(), corpus_id = integer(), batch_id = integer(),
    chat_id = character(), timestamp_utc = character(), timestamp_local = character(),
    tz = character(), sender_id = character(), sender_name = character(),
    text_original = character(), text_norm = character(), reply_to_id = integer(),
    forwarded = logical(), edited = logical(), message_type = character(),
    media_type = character(), sticker_emoji = character(), emoji_list = character(),
    reactions = character(), source_file = character(), import_batch_id = integer(),
    review_pending = logical(), created_at = character()
  )
}

#' Importa un CSV con esquema documentado
#' @export
import_csv <- function(path, corpus_id = 1L, batch_id = 1L, cfg = load_config(),
                       source_file = NULL) {
  if (!file.exists(path)) stop("No existe el archivo: ", path)
  source_file <- source_file %||% basename(path)
  tz <- cfg_get(cfg, "project", "timezone")
  df <- readr::read_csv(path, show_col_types = FALSE)
  req <- c("message_id", "timestamp_utc", "text_original")
  miss <- setdiff(req, names(df))
  if (length(miss)) stop("CSV sin columnas requeridas: ", paste(miss, collapse = ", "))
  n <- nrow(df)
  out <- tibble::tibble(
    message_id = as.integer(df$message_id),
    corpus_id = corpus_id, batch_id = batch_id,
    chat_id = df$chat_id %||% NA_character_,
    timestamp_utc = as.character(df$timestamp_utc),
    timestamp_local = as.character(df$timestamp_local %||% NA_character_),
    tz = tz,
    sender_id = as.character(df$sender_id %||% NA_character_),
    sender_name = as.character(df$sender_name %||% NA_character_),
    text_original = to_nfc(as.character(df$text_original)),
    text_norm = NA_character_,
    reply_to_id = as.integer(df$reply_to_id %||% NA_integer_),
    forwarded = as.logical(df$forwarded %||% FALSE),
    edited = as.logical(df$edited %||% FALSE),
    message_type = as.character(df$message_type %||% "message"),
    media_type = as.character(df$media_type %||% NA_character_),
    sticker_emoji = NA_character_,
    emoji_list = NA_character_, reactions = NA_character_,
    source_file = source_file, import_batch_id = batch_id,
    review_pending = FALSE, created_at = now_utc()
  )
  list(messages = out,
       report = list(source_file = source_file, n_total = n, n_imported = n,
                     n_rejected = 0L, n_duplicated = 0L, reasons = list()))
}

#' Importa y persiste un export JSON de Telegram en la base de datos,
#' registrando corpus, lote y bitácora. Devuelve un resumen.
#' @export
persist_telegram_import <- function(json_path, con, cfg = load_config(),
                                    json_rel = NULL) {
  if (!file.exists(json_path)) stop("No existe el archivo: ", json_path)
  raw <- read_json_utf8(json_path)
  source_file <- basename(json_path)
  file_hash <- hash_file(json_path)

  corpus_id <- db_upsert_corpus(
    con,
    name = raw$name %||% "corpus_telegram",
    source_type = "telegram_json",
    source_path = json_rel %||% json_path,
    group_id = as.character(raw$id %||% NA),
    group_name = raw$name %||% NA,
    n_messages = length(raw$messages)
  )
  batch_id <- db_create_batch(con, corpus_id, source_file, file_hash, status = "running")
  handle <- audit_start(con, "import", corpus_id, batch_id,
                        params = list(source_file = source_file))

  result <- tryCatch(
    import_telegram_json(json_path, corpus_id, batch_id, cfg, source_file),
    error = function(e) { audit_error(con, handle, e); stop(e) }
  )
  messages <- result$messages
  rep <- result$report

  existing <- db_query(con, "SELECT message_id FROM messages WHERE corpus_id = ?",
                       params = list(corpus_id))$message_id
  dup_db <- sum(messages$message_id %in% existing)
  if (dup_db > 0) messages <- messages[!(messages$message_id %in% existing), ]
  n_inserted <- db_insert_messages(con, messages)

  db_finalize_batch(con, batch_id, n_total = rep$n_total, n_imported = nrow(messages),
                    n_rejected = rep$n_rejected, n_duplicated = rep$n_duplicated + dup_db,
                    n_pending = 0L, status = "completed")
  audit_finish(con, handle, status = "completed", n_processed = n_inserted,
               warnings = sprintf("rechazados=%d duplicados=%d",
                                  rep$n_rejected, rep$n_duplicated + dup_db))

  full <- DBI::dbGetQuery(con, "SELECT * FROM messages WHERE corpus_id = ? ORDER BY message_id",
                          params = list(corpus_id))
  full$forwarded <- as.logical(full$forwarded)
  full$edited <- as.logical(full$edited)
  full$review_pending <- as.logical(full$review_pending)
  save_rds(full, interim_path("messages.rds"))
  write_json_utf8(rep, interim_path("import_report.json"))

  list(corpus_id = corpus_id, batch_id = batch_id, n_inserted = n_inserted,
       n_total = rep$n_total, report = rep, messages = messages)
}
