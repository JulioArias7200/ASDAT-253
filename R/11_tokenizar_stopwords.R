# =============================================================================
# 11_tokenizar_stopwords.R — Tokenización y eliminación de stop words
#
# Uso: Rscript scripts/11_tokenizar_stopwords.R
#
# Lee DIRECTAMENTE de data/raw/result.json (o result.json) sin depender
# de pasos previos ni bases de datos.
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(quanteda)
  library(stringi)
  library(readr)
})

cat("\n")
cat("=============================================================================\n")
cat("  PASO 11 — Tokenización y eliminación de Stop Words (desde result.json)\n")
cat("=============================================================================\n\n")

# ---------------------------------------------------------------------------
# 1. Localizar y cargar result.json
# ---------------------------------------------------------------------------
posibles_rutas <- c("data/raw/result.json", "result.json", "../data/raw/result.json", "../result.json")
json_path <- posibles_rutas[file.exists(posibles_rutas)][1]
if (is.na(json_path)) {
  stop("No se encontró result.json en data/raw/ ni en el directorio actual.")
}

cat("  [1/5] Cargando:", json_path, "...\n")
raw_data <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
msgs_raw <- raw_data$messages
cat(sprintf("     Total de registros leídos en el JSON: %s\n", format(length(msgs_raw), big.mark = ",")))

# ---------------------------------------------------------------------------
# 2. Extraer y filtrar mensajes
# ---------------------------------------------------------------------------
cat("  [2/5] Extrayendo textos y descartando mensajes de servicio...\n")

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
n_servicio <- length(msgs_raw) - length(msgs_user)

textos_list <- lapply(msgs_user, function(m) extraer_texto(m$text))
textos <- unlist(textos_list, use.names = FALSE)
textos <- trimws(textos)
textos <- textos[nzchar(textos)]

cat(sprintf("     Eventos de servicio omitidos: %s\n", format(n_servicio, big.mark = ",")))
cat(sprintf("     Mensajes con texto a procesar: %s\n\n", format(length(textos), big.mark = ",")))

# ---------------------------------------------------------------------------
# 3. Normalizar y Tokenizar
# ---------------------------------------------------------------------------
cat("  [3/5] Normalizando texto y tokenizando...\n")

# Limpieza ligera: minúsculas, remover URLs y espacios redundantes
textos_norm <- stringi::stri_trans_tolower(textos)
textos_norm <- stringi::stri_replace_all_regex(textos_norm, "https?://\\S+|www\\.\\S+", "")
textos_norm <- stringi::stri_replace_all_regex(textos_norm, "[[:space:]]+", " ")
textos_norm <- stringi::stri_trim_both(textos_norm)

corpus_msgs <- quanteda::corpus(textos_norm)

tokens_raw <- quanteda::tokens(
  corpus_msgs,
  what              = "word",
  remove_punct      = TRUE,
  remove_symbols    = TRUE,
  remove_numbers    = TRUE,
  remove_url        = TRUE,
  remove_separators = TRUE,
  split_hyphens     = FALSE
)

n_tokens_raw <- sum(quanteda::ntoken(tokens_raw))
cat(sprintf("     Tokens iniciales (brutos): %s\n", format(n_tokens_raw, big.mark = ",")))

# ---------------------------------------------------------------------------
# 4. Eliminar Stop Words
# ---------------------------------------------------------------------------
cat("  [4/5] Eliminando stop words...\n")

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
all_stopwords <- unique(c(sw_es, sw_extra))

tokens_clean <- quanteda::tokens_remove(tokens_raw, pattern = all_stopwords, valuetype = "fixed")
tokens_clean <- quanteda::tokens_select(tokens_clean, min_nchar = 2)

n_tokens_clean <- sum(quanteda::ntoken(tokens_clean))
n_removidos <- n_tokens_raw - n_tokens_clean

cat(sprintf("     Stop words base:             %d palabras\n", length(sw_es)))
cat(sprintf("     Stop words extra (chat):     %d palabras\n", length(sw_extra)))
cat(sprintf("     Tokens después de filtrar:   %s\n", format(n_tokens_clean, big.mark = ",")))
cat(sprintf(
  "     Tokens eliminados:           %s (%.1f%%)\n\n",
  format(n_removidos, big.mark = ","), 100 * n_removidos / n_tokens_raw
))

# ---------------------------------------------------------------------------
# 5. Frecuencia y exportación a CSV
# ---------------------------------------------------------------------------
cat("  [5/5] Calculando frecuencias y guardando resultados...\n")

dfm_msgs <- quanteda::dfm(tokens_clean)
tot_freq <- colSums(dfm_msgs)
doc_freq <- quanteda::docfreq(dfm_msgs)
n_docs_total <- quanteda::ndoc(dfm_msgs)

ord <- order(tot_freq, decreasing = TRUE)
tabla_freq <- data.frame(
  rango = seq_along(ord),
  token = names(tot_freq)[ord],
  frecuencia = as.integer(tot_freq[ord]),
  docfreq = as.integer(doc_freq[names(tot_freq)[ord]]),
  pct_docs = round(100 * as.numeric(doc_freq[names(tot_freq)[ord]]) / n_docs_total, 2),
  stringsAsFactors = FALSE
)

cat("\n=============================================================================\n")
cat("  TOP 50 TOKENS MÁS FRECUENTES (sin stop words)\n")
cat("=============================================================================\n")
cat(sprintf("  %-5s  %-25s  %10s  %8s  %8s\n", "Rang.", "Token", "Frec.", "N.docs", "% docs"))
cat(sprintf("  %s\n", strrep("-", 65)))

top50 <- head(tabla_freq, 50)
for (i in seq_len(nrow(top50))) {
  cat(sprintf(
    "  %-5d  %-25s  %10s  %8s  %7.2f%%\n",
    top50$rango[i],
    top50$token[i],
    format(top50$frecuencia[i], big.mark = ","),
    format(top50$docfreq[i], big.mark = ","),
    top50$pct_docs[i]
  ))
}
cat("\n")

posibles_out <- c("data/results", "../data/results")
out_dir <- posibles_out[dir.exists(posibles_out)][1]
if (is.na(out_dir)) {
  out_dir <- "data/results"
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}
out_path <- file.path(out_dir, "tokens_frecuencia.csv")
readr::write_csv(tabla_freq, out_path)

cat(sprintf("  CSV guardado en: %s\n", out_path))
cat(sprintf("  Filas exportadas: %s\n\n", format(nrow(tabla_freq), big.mark = ",")))

cat("=============================================================================\n")
cat("  OK 11_tokenizar_stopwords (completado desde result.json)\n")
cat("=============================================================================\n\n")


# autor: Yoshua Aaron Cordova Avendaño
