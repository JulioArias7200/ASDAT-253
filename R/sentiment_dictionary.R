# =============================================================================
# sentiment_dictionary.R — diccionario emocional editable y versionado
# =============================================================================

#' Las 18 categorías emocionales exigidas (más el estado sin_evidencia)
#' @export
EMOTION_CATEGORIES <- c(
  "alegria", "tristeza", "ira", "miedo", "sorpresa", "asco", "amor",
  "gratitud", "confianza", "anticipacion", "frustracion", "ansiedad",
  "esperanza", "orgullo", "verguenza", "diversion", "aburrimiento", "alivio"
)

.dict_cols <- c("term", "normalized_term", "category", "polarity", "weight",
                "term_type", "language_variant", "negation_sensitive", "source",
                "notes", "dictionary_version")

#' Normaliza un término para matching (minúsculas, sin acentos, NFC)
#' @export
normalize_term <- function(x) {
  x <- to_nfc(as.character(x))
  x <- stringi::stri_trans_tolower(x)
  stringi::stri_trans_general(x, "NFD; [:Nonspacing Mark:] Remove; NFC")
}

#' Carga el diccionario desde CSV (UTF-8)
#' @export
load_dictionary <- function(path = NULL, cfg = NULL) {
  path <- path %||% cfg_get(cfg %||% load_config(), "paths", "dictionary")
  path <- if (file.exists(path) || grepl("^(/|[A-Za-z]:[\\\\/])", path)) path else proj_path(path)
  if (!file.exists(path)) stop("No existe el diccionario: ", path)
  df <- readr::read_csv(path, show_col_types = FALSE,
                        locale = readr::locale(encoding = "UTF-8"))
  for (c in .dict_cols) if (!c %in% names(df)) df[[c]] <- NA
  df$weight <- as.numeric(df$weight)
  df$weight[is.na(df$weight)] <- 1
  # normalized_term: si falta, se calcula. Los emojis no se normalizan con NFD.
  is_emoji <- df$term_type == "emoji"
  calc <- ifelse(is_emoji, df$term, normalize_term(df$term))
  df$normalized_term[is.na(df$normalized_term) | !nzchar(df$normalized_term)] <-
    calc[is.na(df$normalized_term) | !nzchar(df$normalized_term)]
  attr(df, "path") <- path
  df
}

#' Versión del diccionario = hash corto del archivo
#' @export
dictionary_version <- function(path = NULL, cfg = NULL) {
  path <- path %||% cfg_get(cfg %||% load_config(), "paths", "dictionary")
  path <- if (file.exists(path)) path else proj_path(path)
  if (!file.exists(path)) return("v0")
  paste0("v", hash_file(path))
}

#' Valida el diccionario: columnas, categorías y unicidad
#' @export
validate_dictionary <- function(dict) {
  issues <- character(0)
  miss <- setdiff(.dict_cols, names(dict))
  if (length(miss)) issues <- c(issues, paste("Faltan columnas:", paste(miss, collapse = ", ")))
  bad_cat <- setdiff(unique(dict$category), EMOTION_CATEGORIES)
  if (length(bad_cat)) issues <- c(issues, paste("Categorías no reconocidas:", paste(bad_cat, collapse = ", ")))
  present <- intersect(EMOTION_CATEGORIES, unique(dict$category))
  if (length(present) < 18) issues <- c(issues, paste("Categorías presentes:", length(present), "de 18"))
  list(ok = length(issues) == 0, issues = issues, n_terms = nrow(dict),
       categories = length(present))
}

#' Guarda el diccionario y registra la nueva versión (auditable)
#' @export
save_dictionary <- function(dict, path = NULL, cfg = NULL, con = NULL, notes = NA) {
  path <- path %||% cfg_get(cfg %||% load_config(), "paths", "dictionary")
  path <- if (file.exists(path) || grepl("^(/|[A-Za-z]:[\\\\/])", path)) path else proj_path(path)
  readr::write_csv(dict[, .dict_cols], path, na = "")
  ver <- dictionary_version(path, cfg)
  if (!is.null(con)) {
    DBI::dbExecute(con, "INSERT OR REPLACE INTO dictionary_versions
      (version, created_at, n_terms, source_hash, notes) VALUES (?,?,?,?,?)",
      params = list(ver, now_utc(), nrow(dict), hash_file(path), notes))
  }
  invisible(ver)
}

#' Añade un término y registra el cambio
#' @export
add_term <- function(dict, term, category, polarity, weight = 1,
                     term_type = "word", language_variant = "es",
                     negation_sensitive = TRUE, source = "manual", notes = NA,
                     con = NULL) {
  if (!category %in% EMOTION_CATEGORIES) stop("Categoría inválida: ", category)
  new_row <- tibble::tibble(
    term = term, normalized_term = if (term_type == "emoji") term else normalize_term(term),
    category = category, polarity = polarity, weight = weight, term_type = term_type,
    language_variant = language_variant, negation_sensitive = negation_sensitive,
    source = source, notes = notes,
    dictionary_version = dict$dictionary_version[[1]] %||% "v1.0"
  )
  if (!is.null(con)) {
    DBI::dbExecute(con, "INSERT INTO dictionary_changes
      (version, timestamp, action, term, normalized_term, category, old_value, new_value, source, notes)
      VALUES (?,?,?,?,?,?,?,?,?,?)",
      params = list(new_row$dictionary_version, now_utc(), "add", term,
                    new_row$normalized_term, category, NA_character_,
                    as_json(list(polarity = polarity, weight = weight, type = term_type)),
                    source, notes))
  }
  dplyr::bind_rows(dict, new_row)
}

#' Añade emojis/entradas del lexicón legado como fuente de procedencia
#' @export
import_legacy_terms <- function(dict, legacy_path = proj_path("lexicons", "lexicon.json")) {
  if (!file.exists(legacy_path)) return(dict)
  raw <- read_json_utf8(legacy_path, simplify = TRUE)
  raw <- raw[!grepl("^_", names(raw))]
  add <- list()
  for (nm in names(raw)) {
    key <- normalize_term(nm)
    if (any(dict$normalized_term == key)) next
    score <- as.numeric(raw[[nm]])
    cat <- if (score > 0) "alegria" else if (score < 0) "tristeza" else "confianza"
    add[[length(add) + 1]] <- tibble::tibble(
      term = nm, normalized_term = key, category = cat,
      polarity = if (score > 0) "positivo" else if (score < 0) "negativo" else "neutro",
      weight = max(1, abs(score)), term_type = "word", language_variant = "es",
      negation_sensitive = TRUE, source = "legacy_python_lexicon",
      notes = "migrado del lexicón Python", dictionary_version = "v1.0"
    )
  }
  if (length(add)) dplyr::bind_rows(dict, add) else dict
}
