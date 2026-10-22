# =============================================================================
# dictionary_io.R — importación y versionado de diccionarios externos (V2)
# Esquema canónico: term, category, polarity, weight, language, notes, source.
# Nunca sobrescribe el diccionario vigente al importar: crea una versión nueva.
# =============================================================================

.dict_required <- c("term", "category")

.dictionary_synonyms <- list(
  term = c("term", "termino", "término", "word", "palabra", "expression",
           "expresion", "expresión"),
  category = c("category", "categoria", "categoría", "emotion", "emocion",
               "emoción", "label", "etiqueta"),
  polarity = c("polarity", "polaridad", "sentiment", "sentimiento", "valencia",
               "valence"),
  weight = c("weight", "peso", "intensity", "intensidad", "score", "strength"),
  language = c("language", "idioma", "lang", "lengua"),
  notes = c("notes", "notas", "note", "comentario", "procedencia"),
  source = c("source", "fuente", "origen", "provenance")
)

#' Directorio de versiones del diccionario (junto al diccionario activo)
#' @export
dictionary_versions_dir <- function(cfg = load_config()) {
  p <- cfg_get(cfg, "paths", "dictionary")
  p <- if (grepl("^(/|[A-Za-z]:[\\\\/])", p)) p else proj_path(p)
  file.path(dirname(p), "versions")
}

#' Ruta absoluta del diccionario activo
#' @export
active_dictionary_path <- function(cfg = load_config()) {
  p <- cfg_get(cfg, "paths", "dictionary")
  if (file.exists(p) || grepl("^(/|[A-Za-z]:[\\\\/])", p)) p else proj_path(p)
}

#' Formato canónico documentado (para mostrar en la interfaz)
#' @export
canonical_dictionary_schema <- function() {
  tibble::tibble(
    field = c("term", "category", "polarity", "weight", "language", "notes", "source"),
    required = c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
    default = c(NA, NA, "neutro", "1", "es", "", "import"),
    description = c(
      "Término o expresión (obligatorio).",
      "Categoría emocional; debe pertenecer a EMOTION_CATEGORIES.",
      "positivo | negativo | neutro.",
      "Peso/intensidad numérico > 0.",
      "Idioma o variante (por defecto es).",
      "Notas libres.",
      "Procedencia del término."
    )
  )
}

#' Lee un diccionario externo en CSV, JSON o TXT.
#' @export
read_external_dictionary <- function(path, format = NULL) {
  if (!file.exists(path)) stop("No existe el archivo: ", path)
  if (is.null(format)) format <- tools::file_ext(path)
  format <- tolower(format)

  if (format %in% c("csv", "tsv", "txt")) {
    first <- readLines(path, n = 1, warn = FALSE, encoding = "UTF-8")
    txt <- format == "txt"
    delim <- if (txt) ";" else if (grepl(";", first) && !grepl(",", first)) ";" else ","
    has_header <- grepl("term|termino|t\u00e9rmino|category|categoria|categor\u00eda|polarity|polaridad",
                        tolower(first))
    if (has_header) {
      df <- readr::read_delim(path, delim = delim, show_col_types = FALSE,
                              locale = readr::locale(encoding = "UTF-8"))
    } else {
      df <- readr::read_delim(path, delim = delim,
                              col_names = c("term", "category", "polarity", "weight"),
                              show_col_types = FALSE,
                              locale = readr::locale(encoding = "UTF-8"))
    }
    return(as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE))
  }

  if (format == "json") return(read_json_dictionary(path))
  stop("Formato no soportado: ", format, " (use CSV, JSON o TXT)")
}

#' Lee un diccionario JSON (array de objetos o mapa término -> valor)
#' @export
read_json_dictionary <- function(path) {
  txt <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  obj <- jsonlite::fromJSON(txt, simplifyVector = TRUE)
  if (is.data.frame(obj)) {
    return(as.data.frame(obj, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (is.list(obj) && !is.null(names(obj))) {
    rows <- lapply(names(obj), function(k) {
      v <- obj[[k]]
      if (is.list(v)) {
        v$term <- v$term %||% k
        as.data.frame(v, stringsAsFactors = FALSE, check.names = FALSE)
      } else {
        data.frame(term = k, category = as.character(v), stringsAsFactors = FALSE)
      }
    })
    return(as.data.frame(dplyr::bind_rows(rows), stringsAsFactors = FALSE))
  }
  if (is.list(obj)) {
    return(as.data.frame(dplyr::bind_rows(lapply(
      obj, as.data.frame, stringsAsFactors = FALSE)), stringsAsFactors = FALSE))
  }
  stop("Formato JSON no reconocido: se esperaba un array de objetos o un mapa")
}

#' Detecta columnas del archivo externo y propone un mapeo canónico.
#' @export
detect_dictionary_columns <- function(df) {
  nm <- names(df)
  key <- normalize_term(nm)
  out <- character(0)
  for (canon in names(.dictionary_synonyms)) {
    syn <- normalize_term(.dictionary_synonyms[[canon]])
    idx <- match(syn, key)
    idx <- idx[!is.na(idx)]
    if (length(idx)) out[[canon]] <- nm[idx[[1]]]
  }
  out
}

#' Renombra/mapea columnas externas al esquema canónico.
#' @param mapping vector nombrado `canonico = "columna_externa"`.
#' @export
map_dictionary_columns <- function(df, mapping = NULL) {
  mapping <- mapping %||% detect_dictionary_columns(df)
  mapping <- mapping[!is.na(mapping) & nzchar(mapping)]
  mapping <- mapping[intersect(names(mapping), names(.dictionary_synonyms))]
  mapping <- mapping[mapping %in% names(df)]
  out <- list()
  for (canon in names(mapping)) out[[canon]] <- df[[mapping[[canon]]]]
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}

#' Valida un diccionario mapeado al esquema canónico.
#' @return lista con ok, issues, warnings, valid (tabla), invalid, duplicates,
#'   unknown_categories y contadores.
#' @export
validate_external_dictionary <- function(df, cfg = load_config()) {
  issues <- character(0); warnings <- character(0)
  missing <- setdiff(.dict_required, names(df))
  if (length(missing)) {
    issues <- c(issues, paste("Faltan columnas obligatorias:",
                              paste(missing, collapse = ", ")))
    return(list(ok = FALSE, issues = issues, warnings = warnings,
                n_total = nrow(df), n_valid = 0L,
                valid = tibble::tibble(), invalid = df, duplicates = 0L,
                unknown_categories = character(0)))
  }

  term <- trimws(as.character(df$term))
  cat_norm <- normalize_term(as.character(df$category))
  pol_norm <- normalize_term(as.character(df$polarity %||% rep("neutro", nrow(df))))
  lang <- as.character(df$language %||% rep("es", nrow(df)))
  notes <- as.character(df$notes %||% rep("", nrow(df)))
  source <- as.character(df$source %||% rep("import", nrow(df)))
  weight <- suppressWarnings(as.numeric(df$weight %||% rep(1, nrow(df))))

  pol_norm[is.na(pol_norm) | !nzchar(pol_norm)] <- "neutro"
  bad_pol <- !pol_norm %in% c("positivo", "negativo", "neutro")
  if (any(bad_pol)) {
    warnings <- c(warnings, sprintf("%d fila(s) con polaridad no válida; se usó 'neutro'.",
                                    sum(bad_pol)))
    pol_norm[bad_pol] <- "neutro"
  }
  bad_w <- is.na(weight) | weight <= 0
  if (any(bad_w)) {
    warnings <- c(warnings, sprintf("%d fila(s) con peso inválido; se usó 1.",
                                    sum(bad_w)))
    weight[bad_w] <- 1
  }

  unknown <- setdiff(unique(cat_norm[!cat_norm %in% EMOTION_CATEGORIES &
                                       nzchar(cat_norm)]), "")
  if (length(unknown)) {
    warnings <- c(warnings, paste("Categorías desconocidas:",
                                  paste(unknown, collapse = ", ")))
  }

  ok_row <- nzchar(term) & cat_norm %in% EMOTION_CATEGORIES
  invalid <- df[!ok_row, , drop = FALSE]
  if (nrow(invalid)) {
    invalid$reason <- ifelse(!nzchar(term[!ok_row]), "término vacío",
                             "categoría desconocida o vacía")
    warnings <- c(warnings, sprintf("%d fila(s) inválidas excluidas.",
                                    nrow(invalid)))
  }

  valid <- tibble::tibble(
    term = term[ok_row],
    normalized_term = ifelse(
      vapply(term[ok_row], function(t) has_emoji(t), logical(1)),
      term[ok_row], normalize_term(term[ok_row])),
    category = cat_norm[ok_row],
    polarity = pol_norm[ok_row],
    weight = weight[ok_row],
    term_type = ifelse(
      vapply(term[ok_row], function(t) has_emoji(t), logical(1)),
      "emoji", "palabra"),
    language_variant = lang[ok_row],
    negation_sensitive = TRUE,
    source = source[ok_row],
    notes = notes[ok_row],
    dictionary_version = NA_character_
  )

  dup <- duplicated(valid$normalized_term)
  if (any(dup)) {
    warnings <- c(warnings, sprintf("%d término(s) duplicado(s); se conserva el primero.",
                                    sum(dup)))
    valid <- valid[!dup, , drop = FALSE]
  }

  list(ok = nrow(valid) > 0L, issues = issues, warnings = warnings,
       n_total = nrow(df), n_valid = nrow(valid), valid = valid,
       invalid = invalid, duplicates = sum(dup),
       unknown_categories = unknown)
}

#' Importa un diccionario externo como nueva versión (sin sobrescribir el activo).
#' @param source ruta de archivo o data.frame ya leído.
#' @param label etiqueta de versión (por defecto `import_<fecha>`).
#' @param mapping mapeo canónico opcional.
#' @param activate si TRUE, además lo marca como diccionario activo (explícito).
#' @export
import_external_dictionary <- function(source, label = NULL, cfg = load_config(),
                                       con = NULL, mapping = NULL,
                                       activate = FALSE, notes = NA) {
  raw <- if (is.data.frame(source)) source else read_external_dictionary(source)
  mapped <- map_dictionary_columns(raw, mapping)
  report <- validate_external_dictionary(mapped, cfg)
  if (!report$ok) {
    stop(paste(c("Diccionario inválido:", report$issues, report$warnings),
               collapse = " | "))
  }

  label <- label %||% paste0("import_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  label <- gsub("[^A-Za-z0-9_.-]", "_", label)
  dir.create(dictionary_versions_dir(cfg), recursive = TRUE, showWarnings = FALSE)

  dict <- report$valid
  dict$dictionary_version <- label
  tmp <- tempfile(fileext = ".csv")
  readr::write_csv(dict[, .dict_cols], tmp, na = "")
  hash <- hash_file(tmp)
  target <- file.path(dictionary_versions_dir(cfg), paste0(label, "_", hash, ".csv"))
  if (file.exists(target)) {
    label <- paste0(label, "_", format(Sys.time(), "%H%M%S"))
    dict$dictionary_version <- label
    readr::write_csv(dict[, .dict_cols], tmp, na = "")
    hash <- hash_file(tmp)
    target <- file.path(dictionary_versions_dir(cfg), paste0(label, "_", hash, ".csv"))
  }
  file.copy(tmp, target, overwrite = TRUE)
  unlink(tmp)

  if (!is.null(con)) {
    DBI::dbExecute(con, "INSERT OR REPLACE INTO dictionary_versions
      (version, created_at, n_terms, source_hash, notes) VALUES (?,?,?,?,?)",
      params = list(label, now_utc(), nrow(dict), hash,
                    notes %||% "importación externa"))
    audit_event(con, "dictionary_import", params = list(
      label = label, n_terms = nrow(dict), duplicates = report$duplicates,
      unknown_categories = report$unknown_categories, activate = activate),
      status = "completed", artifacts = target)
  }

  activated <- FALSE
  if (isTRUE(activate)) {
    activate_dictionary_version(target, cfg = cfg, con = con,
                                note = "activado tras importación")
    activated <- TRUE
  }

  list(version = label, hash = hash, path = target, activated = activated,
       report = report, dictionary = dict)
}

#' Lista las versiones guardadas y marca la activa.
#' @export
list_dictionary_versions <- function(cfg = load_config()) {
  dir <- dictionary_versions_dir(cfg)
  active <- active_dictionary_path(cfg)
  files <- if (dir.exists(dir)) list.files(dir, pattern = "\\.csv$", full.names = TRUE) else character(0)
  if (file.exists(active)) files <- unique(c(active, files))
  if (!length(files)) {
    return(tibble::tibble(file = character(0), path = character(0),
                          version = character(0), n_terms = integer(0),
                          hash = character(0), active = logical(0),
                          modified = as.POSIXct(character(0))))
  }
  tibble::tibble(
    file = basename(files),
    path = files,
    version = sub("_[0-9a-f]{16}$", "",
                  sub("\\.csv$", "", basename(files))),
    n_terms = vapply(files, function(f) {
      n <- suppressWarnings(length(readLines(f, warn = FALSE)) - 1L)
      max(n, 0L)
    }, integer(1)),
    hash = vapply(files, hash_file, character(1)),
    active = normalizePath(files, mustWork = FALSE) ==
      normalizePath(active, mustWork = FALSE),
    modified = file.mtime(files)
  )
}

#' Activa una versión guardada (copiándola al diccionario vigente, con respaldo).
#' @export
activate_dictionary_version <- function(path, cfg = load_config(), con = NULL,
                                        note = NA) {
  if (!file.exists(path)) stop("No existe la versión: ", path)
  active <- active_dictionary_path(cfg)
  dir.create(dirname(active), recursive = TRUE, showWarnings = FALSE)

  if (file.exists(active)) {
    dir.create(dictionary_versions_dir(cfg), recursive = TRUE, showWarnings = FALSE)
    backup <- file.path(dictionary_versions_dir(cfg),
                        paste0("backup_", format(Sys.time(), "%Y%m%d_%H%M%S"),
                               "_", hash_file(active), ".csv"))
    file.copy(active, backup, overwrite = FALSE)
  }
  ok <- file.copy(path, active, overwrite = TRUE)
  if (!isTRUE(ok)) stop("No se pudo activar la versión del diccionario")
  ver <- dictionary_version(cfg = cfg)

  if (!is.null(con)) {
    DBI::dbExecute(con, "INSERT OR REPLACE INTO dictionary_versions
      (version, created_at, n_terms, source_hash, notes) VALUES (?,?,?,?,?)",
      params = list(sub("\\.csv$", "", basename(path)), now_utc(),
                    max(length(readLines(path, warn = FALSE)) - 1L, 0L),
                    hash_file(path),
                    note %||% paste("activado; hash activo", ver)))
    audit_event(con, "dictionary_activate",
                params = list(source = basename(path), active_hash = ver),
                status = "completed", artifacts = active)
  }
  invisible(ver)
}
