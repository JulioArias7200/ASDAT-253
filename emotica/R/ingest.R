# Todos los adaptadores devuelven el mismo esquema "crudo canonico":
# msg_id, fecha(chr/POSIXct), autor_id, autor, texto, responde_a, tipo, + extras opcionales

detectar_adaptador <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "json") return("telegram")
  if (ext %in% c("csv", "tsv")) return("csv")
  if (ext == "txt") return("whatsapp")
  stop("Formato no reconocido: .", ext, ". Use json (Telegram), txt (WhatsApp) o csv.")
}

leer_telegram <- function(path) {
  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  msgs <- j$messages
  if (is.null(msgs)) stop("El JSON no tiene el campo 'messages': no parece una exportacion de Telegram.")
  aplanar <- function(t) {
    if (is.null(t)) return("")
    if (is.character(t)) return(paste(t, collapse = ""))
    paste(vapply(t, function(p) if (is.character(p)) p else as.character(p[["text"]] %si_vacio% ""),
                 character(1)), collapse = "")
  }
  chr <- function(f) vapply(msgs, function(m) { v <- f(m); if (is.null(v)) NA_character_ else as.character(v) }, character(1))
  tibble::tibble(
    msg_id = chr(function(m) m[["id"]]),
    fecha = chr(function(m) m[["date"]]),
    autor_id = chr(function(m) m[["from_id"]]),
    autor = chr(function(m) m[["from"]]),
    texto = vapply(msgs, function(m) aplanar(m[["text"]]), character(1)),
    responde_a = chr(function(m) m[["reply_to_message_id"]]),
    tipo = chr(function(m) m[["type"]]),
    tiene_foto = vapply(msgs, function(m) !is.null(m[["photo"]]), logical(1)),
    tipo_media = chr(function(m) m[["media_type"]] %si_vacio% m[["mime_type"]]),
    reenviado = vapply(msgs, function(m) !is.null(m[["forwarded_from"]]), logical(1)),
    editado = vapply(msgs, function(m) !is.null(m[["edited"]]), logical(1)),
    reacciones_total = vapply(msgs, function(m) {
      r <- m[["reactions"]]; if (is.null(r)) 0 else sum(vapply(r, function(z) as.numeric(z[["count"]] %si_vacio% 0), numeric(1)))
    }, numeric(1)))
}

leer_whatsapp <- function(path) {
  lin <- leer_lineas_utf8(path)
  lin <- stringi::stri_replace_all_regex(lin, "[\\x{200E}\\x{200F}\\x{202F}]", " ")
  patron <- "^\\[?(\\d{1,4}[/.-]\\d{1,2}[/.-]\\d{1,4}),?\\s+(\\d{1,2}:\\d{2}(?::\\d{2})?(?:\\s?[AaPp]\\.?\\s?[Mm]\\.?)?)\\]?\\s*[-\u2013]?\\s*([^:]{1,60}?):\\s(.*)$"
  m <- stringi::stri_match_first_regex(lin, patron)
  inicio <- !is.na(m[, 1])
  grupo <- cumsum(inicio)
  ok <- grupo > 0
  texto <- tapply(seq_along(lin)[ok], grupo[ok], function(ix) paste(c(m[ix[1], 5], lin[ix[-1]]), collapse = "\n"))
  filas <- which(inicio)
  hora <- stringi::stri_replace_all_regex(m[filas, 3], "(?i)([ap])\\.?\\s?m\\.?", "$1M")
  tibble::tibble(msg_id = as.character(seq_along(filas)),
                 fecha = paste(sub("[.-]", "/", m[filas, 2]), hora),
                 autor_id = NA_character_, autor = trimws(m[filas, 4]),
                 texto = unname(as.character(texto)), responde_a = NA_character_, tipo = "message")
}

leer_csv_generico <- function(path, mapping = NULL) {
  crudo <- readBin(path, "raw", 2e5)
  enc <- stringi::stri_enc_detect(crudo)[[1]]$Encoding[1]
  enc <- if (is.na(enc) || enc %in% c("ASCII", "UTF-8")) "UTF-8" else enc
  l1 <- readr::read_lines(path, n_max = 1, locale = readr::locale(encoding = enc))
  cuenta <- vapply(c(",", ";", "\t", "|"), function(d) stringi::stri_count_fixed(l1, d), numeric(1))
  delim <- names(cuenta)[which.max(cuenta)]
  df <- readr::read_delim(path, delim = delim, locale = readr::locale(encoding = enc),
                          col_types = readr::cols(.default = "c"), progress = FALSE, show_col_types = FALSE)
  esq <- detectar_esquema(df)
  mp <- if (is.null(mapping)) esq$mapping else utils::modifyList(esq$mapping, mapping)
  faltan <- setdiff(c("texto", "fecha"), names(mp))
  if (length(faltan) > 0)
    stop("No pude identificar la(s) columna(s): ", paste(faltan, collapse = ", "),
         ". Columnas disponibles: ", paste(names(df), collapse = ", "),
         ". Indique el mapeo con mapping = list(texto = '...', fecha = '...').")
  col <- function(campo) if (!is.null(mp[[campo]])) df[[mp[[campo]]]] else rep(NA_character_, nrow(df))
  out <- tibble::tibble(msg_id = as.character(col("id") %si_vacio% seq_len(nrow(df))),
                        fecha = col("fecha"), autor_id = NA_character_, autor = col("autor"),
                        texto = col("texto"), responde_a = as.character(col("responde_a")), tipo = "message")
  if (all(is.na(col("id")))) out$msg_id <- as.character(seq_len(nrow(df)))
  attr(out, "detalle") <- sprintf("codificacion=%s; separador=%s; mapeo=%s; confianza=%s", enc,
                                  if (delim == "\t") "TAB" else delim,
                                  paste(names(mp), unlist(mp), sep = "->", collapse = ", "),
                                  paste(names(esq$confianza), esq$confianza, sep = "=", collapse = ", "))
  out
}

ingest_chat <- function(path, adapter = "auto", mapping = NULL) {
  if (!file.exists(path)) stop("No existe el archivo: ", path)
  if (adapter == "auto") adapter <- detectar_adaptador(path)
  t0 <- proc.time()[["elapsed"]]
  df <- switch(adapter,
    telegram = leer_telegram(path),
    whatsapp = leer_whatsapp(path),
    csv = leer_csv_generico(path, mapping),
    stop("Adaptador desconocido: ", adapter))
  det <- attr(df, "detalle") %si_vacio% ""
  attr(df, "detalle") <- NULL
  bitacora_registrar("lectura_archivo", list(adaptador = adapter, archivo = basename(path),
                     bytes = file.size(path)), NA, nrow(df), det, proc.time()[["elapsed"]] - t0)
  attr(df, "adaptador") <- adapter
  df
}
