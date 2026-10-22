# =============================================================================
# helpers.R — utilidades transversales
# =============================================================================

#' Operador null-coalescing
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

#' Raíz del proyecto (directorio que contiene este repo)
project_root <- function() {
  # Permite override explícito; por defecto, directorio de trabajo actual.
  root <- Sys.getenv("AS_TELEGRAM_ROOT", unset = getwd())
  normalizePath(root, mustWork = FALSE)
}

#' Une ruta relativa a la raíz del proyecto (evita rutas absolutas de máquina)
#' @export
proj_path <- function(...) file.path(project_root(), ...)

#' Lee JSON en UTF-8 sin simplificar automáticamente a data.frame
#' @export
read_json_utf8 <- function(path, simplify = FALSE) {
  txt <- readLines(path, warn = FALSE, encoding = "UTF-8")
  jsonlite::fromJSON(paste(txt, collapse = "\n"), simplifyVector = simplify)
}

#' Escribe JSON en UTF-8 legible
#' @export
write_json_utf8 <- function(x, path, pretty = TRUE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::toJSON(
    x, auto_unbox = TRUE, pretty = pretty, null = "null", na = "null",
    force = TRUE, digits = NA
  ) |> writeLines(con = file(path, encoding = "UTF-8"))
  invisible(path)
}

#' Hash corto de una cadena (para hashes de diccionario/archivo)
#' @export
hash_string <- function(x) {
  substr(digest::digest(x, algo = "sha256"), 1, 16)
}

#' Hash de un archivo
#' @export
hash_file <- function(path) {
  substr(digest::digest(file = path, algo = "sha256"), 1, 16)
}

#' Anonimiza un identificador: "user12345" -> "u_ab12cd"
#' @export
anon_id <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  vapply(as.character(x), function(id) {
    if (is.na(id) || !nzchar(id)) return(NA_character_)
    paste0("u_", substr(hash_string(id), 1, 8))
  }, character(1), USE.NAMES = FALSE)
}

#' Versión del código: hash del contenido de R/ y scripts/ (o "dev")
#' @export
code_version <- function() {
  files <- c(
    list.files(proj_path("R"), pattern = "\\.R$", full.names = TRUE),
    list.files(proj_path("scripts"), pattern = "\\.R$", full.names = TRUE)
  )
  if (!length(files)) return("dev")
  content <- paste(vapply(files, function(f) {
    paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }, character(1)), collapse = "\n")
  paste0("v", hash_string(content))
}

#' Marca de tiempo UTC ISO-8601
#' @export
now_utc <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

#' Ejecuta una expresión registrando duración y capturando estado
#' @export
with_timer <- function(expr) {
  t0 <- Sys.time()
  value <- force(expr)
  list(value = value, duration = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}

#' Convierte a JSON una lista para guardar en SQLite
#' @export
as_json <- function(x) {
  if (is.null(x)) return(NA_character_)
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null"))
}

#' Asegura UTF-8 NFC en un vector de texto
#' @export
to_nfc <- function(x) {
  stringi::stri_trans_nfc(x)
}

#' Log simple a consola y opcionalmente a archivo
#' @export
log_info <- function(..., .file = NULL) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...))
  message(msg)
  if (!is.null(.file)) cat(msg, "\n", file = .file, append = TRUE)
  invisible(msg)
}
