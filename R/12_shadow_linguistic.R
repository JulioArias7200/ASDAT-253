# =============================================================================
# 12_shadow_linguistic.R — Análisis de frecuencias lingüísticas (Shadow Linguistics)
#
# Uso: Rscript scripts/12_shadow_linguistic.R
#
# Lee DIRECTAMENTE de data/raw/result.json (o result.json) sin depender
# de pasos previos ni bases de datos.
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(quanteda)
  library(stringi)
  library(readr)
  library(dplyr)
})

cat("\n")
cat("=============================================================================\n")
cat("  PASO 12 — Frecuencias Lingüísticas / Shadow Linguistics (desde result.json)\n")
cat("=============================================================================\n\n")

print_tabla <- function(df, titulo, cols, anchos, n = 20) {
  cat(sprintf("\n  %s\n", titulo))
  total_w <- sum(anchos) + 2 * (length(anchos) - 1) + 4
  cat(sprintf("  %s\n", strrep("-", total_w)))
  header_line <- paste0("  ", paste(mapply(function(col, w) sprintf(paste0("%-", w, "s"), col), cols, anchos), collapse = "  "))
  cat(header_line, "\n")
  cat(sprintf("  %s\n", strrep("-", total_w)))
  for (i in seq_len(min(n, nrow(df)))) {
    row_strs <- mapply(function(col, w) sprintf(paste0("%-", w, "s"), as.character(df[[col]][i])), cols, anchos)
    cat(paste0("  ", paste(row_strs, collapse = "  ")), "\n")
  }
  cat("\n")
}

# ---------------------------------------------------------------------------
# 1. Cargar y extraer textos desde result.json
# ---------------------------------------------------------------------------
posibles_rutas <- c("data/raw/result.json", "result.json", "../data/raw/result.json", "../result.json")
json_path <- posibles_rutas[file.exists(posibles_rutas)][1]
if (is.na(json_path)) stop("No se encontró result.json")

cat("  [1/6] Cargando:", json_path, "...\n")
raw_data <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
msgs_raw <- raw_data$messages

extraer_texto <- function(txt) {
  if (is.null(txt)) {
    return("")
  }
  if (is.character(txt)) {
    return(paste(txt, collapse = " "))
  }
  if (is.list(txt)) {
    partes <- vapply(txt, function(p) {
      if (is.character(p)) {
        return(p)
      }
      if (is.list(p)) {
        return(as.character(p$text %||% ""))
      }
      as.character(p)
    }, character(1), USE.NAMES = FALSE)
    return(paste(partes, collapse = ""))
  }
  as.character(txt)
}

# Filtrar y extraer eficientemente
msgs_user <- msgs_raw[vapply(msgs_raw, function(m) !identical(m$type, "service"), logical(1))]
textos_list <- lapply(msgs_user, function(m) extraer_texto(m$text))
textos <- unlist(textos_list, use.names = FALSE)
textos <- trimws(textos)
textos <- textos[nzchar(textos)]
cat(sprintf("     Mensajes válidos procesados: %s\n", format(length(textos), big.mark = ",")))

# Normalización
textos_norm <- stringi::stri_trans_tolower(textos)
textos_norm <- stringi::stri_replace_all_regex(textos_norm, "https?://\\S+|www\\.\\S+", "")
textos_norm <- stringi::stri_replace_all_regex(textos_norm, "[[:space:]]+", " ")
textos_norm <- stringi::stri_trim_both(textos_norm)

corpus_msgs <- quanteda::corpus(textos_norm)

tokens_base <- quanteda::tokens(
  corpus_msgs,
  what              = "word",
  remove_punct      = TRUE,
  remove_symbols    = TRUE,
  remove_numbers    = TRUE,
  remove_url        = TRUE,
  remove_separators = TRUE,
  split_hyphens     = FALSE
)

sw_es <- quanteda::stopwords("es")
sw_extra <- c(
  "si", "no", "q", "k", "xq", "d", "x", "bn", "tb", "tmb", "tmbn",
  "xa", "xfa", "fa", "pa", "po", "ps", "pue", "pues",
  "jaja", "jeje", "jajaja", "jejeje", "jajajaja", "ja", "je",
  "ah", "eh", "oh", "uh", "mm", "mmm", "ok", "oka", "sip", "sep",
  "nop", "yep", "ya", "aja", "ajá", "hola", "buenas", "buen", "buena", "buenos",
  "gracias", "grac", "grax", "tnks", "thanks", "ese", "esa", "eso", "estos", "estas",
  "va", "van", "voy", "vamos", "fue", "era", "foto", "fotos", "video", "videos",
  "sticker", "gif", "mensaje", "chat", "grupo"
)
tokens_clean <- quanteda::tokens_remove(tokens_base, pattern = unique(c(sw_es, sw_extra)), valuetype = "fixed")
tokens_clean <- quanteda::tokens_select(tokens_clean, min_nchar = 2)

# ---------------------------------------------------------------------------
# 2. UNIGRAMAS
# ---------------------------------------------------------------------------
cat("  [2/6] Calculando unigramas...\n")
dfm_uni <- quanteda::dfm(tokens_clean)
tot_uni <- colSums(dfm_uni)
doc_uni <- quanteda::docfreq(dfm_uni)
ord_uni <- order(tot_uni, decreasing = TRUE)

uni_df <- data.frame(
  capa = "unigrama",
  rango = seq_along(ord_uni),
  termino = names(tot_uni)[ord_uni],
  frecuencia = as.integer(tot_uni[ord_uni]),
  n_docs = as.integer(doc_uni[names(tot_uni)[ord_uni]]),
  pct_docs = round(100 * as.numeric(doc_uni[names(tot_uni)[ord_uni]]) / ndoc(dfm_uni), 3),
  tfidf_prom = NA_real_,
  stringsAsFactors = FALSE
)

print_tabla(uni_df, "UNIGRAMAS — Top 20 palabras más frecuentes",
  c("rango", "termino", "frecuencia", "n_docs", "pct_docs"),
  c(6, 28, 12, 8, 8),
  n = 20
)

# ---------------------------------------------------------------------------
# 3. BIGRAMAS
# ---------------------------------------------------------------------------
cat("  [3/6] Calculando bigramas...\n")
tokens_bi <- quanteda::tokens_ngrams(tokens_clean, n = 2)
dfm_bi <- quanteda::dfm(tokens_bi)
tot_bi <- colSums(dfm_bi)
doc_bi <- quanteda::docfreq(dfm_bi)
ord_bi <- order(tot_bi, decreasing = TRUE)

bi_df <- data.frame(
  capa = "bigrama",
  rango = seq_along(ord_bi),
  termino = gsub("_", " ", names(tot_bi)[ord_bi]),
  frecuencia = as.integer(tot_bi[ord_bi]),
  n_docs = as.integer(doc_bi[names(tot_bi)[ord_bi]]),
  pct_docs = round(100 * as.numeric(doc_bi[names(tot_bi)[ord_bi]]) / ndoc(dfm_bi), 3),
  tfidf_prom = NA_real_,
  stringsAsFactors = FALSE
)

print_tabla(bi_df, "BIGRAMAS — Top 20 pares de palabras más frecuentes",
  c("rango", "termino", "frecuencia", "n_docs"),
  c(6, 38, 12, 8),
  n = 20
)

# ---------------------------------------------------------------------------
# 4. TRIGRAMAS
# ---------------------------------------------------------------------------
cat("  [4/6] Calculando trigramas...\n")
tokens_tri <- quanteda::tokens_ngrams(tokens_clean, n = 3)
dfm_tri <- quanteda::dfm(tokens_tri)
tot_tri <- colSums(dfm_tri)
doc_tri <- quanteda::docfreq(dfm_tri)
ord_tri <- order(tot_tri, decreasing = TRUE)

tri_df <- data.frame(
  capa = "trigrama",
  rango = seq_along(ord_tri),
  termino = gsub("_", " ", names(tot_tri)[ord_tri]),
  frecuencia = as.integer(tot_tri[ord_tri]),
  n_docs = as.integer(doc_tri[names(tot_tri)[ord_tri]]),
  pct_docs = round(100 * as.numeric(doc_tri[names(tot_tri)[ord_tri]]) / ndoc(dfm_tri), 3),
  tfidf_prom = NA_real_,
  stringsAsFactors = FALSE
)

print_tabla(tri_df, "TRIGRAMAS — Top 20 secuencias de 3 palabras",
  c("rango", "termino", "frecuencia", "n_docs"),
  c(6, 48, 12, 8),
  n = 20
)

# ---------------------------------------------------------------------------
# 5. TF-IDF
# ---------------------------------------------------------------------------
cat("  [5/6] Calculando TF-IDF...\n")
dfm_tfidf <- quanteda::dfm_tfidf(dfm_uni, scheme_tf = "prop", scheme_df = "inversemax")
sum_tfidf <- colSums(dfm_tfidf)
tfidf_doc_mean <- sum_tfidf / pmax(doc_uni, 1)
ord_tfidf <- order(tfidf_doc_mean, decreasing = TRUE)

tfidf_df <- data.frame(
  capa = "tfidf",
  rango = seq_along(ord_tfidf),
  termino = names(tfidf_doc_mean)[ord_tfidf],
  frecuencia = as.integer(tot_uni[names(tfidf_doc_mean)[ord_tfidf]]),
  n_docs = as.integer(doc_uni[names(tfidf_doc_mean)[ord_tfidf]]),
  pct_docs = round(100 * as.numeric(doc_uni[names(tfidf_doc_mean)[ord_tfidf]]) / ndoc(dfm_uni), 3),
  tfidf_prom = round(as.numeric(tfidf_doc_mean[ord_tfidf]), 6),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# 6. Distribución de longitud y exportación
# ---------------------------------------------------------------------------
cat("  [6/6] Guardando resultados en CSV...\n")
ntoken_vec <- quanteda::ntoken(tokens_clean)
cuantiles <- quantile(ntoken_vec, probs = c(0, .25, .50, .75, .90, .95, .99, 1))

cat("\n  DISTRIBUCIÓN DE LONGITUD DE MENSAJES (tokens limpios)\n")
cat(sprintf("  %s\n", strrep("-", 45)))
cat(sprintf("  %-20s  %10s\n", "Percentil", "Tokens"))
cat(sprintf("  %s\n", strrep("-", 45)))
for (nm in names(cuantiles)) cat(sprintf("  %-20s  %10.1f\n", nm, cuantiles[[nm]]))
cat(sprintf("  %-20s  %10.1f\n", "Media", mean(ntoken_vec)))
cat(sprintf("  %-20s  %10.1f\n", "Desv. estándar", sd(ntoken_vec)))
cat(sprintf("  %-20s  %10d\n\n", "Mensajes vacíos", sum(ntoken_vec == 0)))

shadow_csv <- dplyr::bind_rows(
  head(uni_df, 500),
  head(bi_df, 200),
  head(tri_df, 100),
  head(tfidf_df, 200)
)

out_dir <- "data/results"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, "shadow_linguistic.csv")
readr::write_csv(shadow_csv, out_path)

cat(sprintf("  CSV guardado en: %s\n", out_path))
cat(sprintf("  Filas exportadas: %d\n\n", nrow(shadow_csv)))
cat("=============================================================================\n")
cat("  OK 12_shadow_linguistic (completado desde result.json)\n")
cat("=============================================================================\n\n")


# autor: Yoshua Aaron Cordova Avendaño
