cargar_stopwords <- function(idioma) {
  f <- ruta_recurso("resources", "stopwords", paste0(idioma, ".txt"))
  if (!file.exists(f)) return(character())
  unique(trimws(leer_lineas_utf8(f)))
}
# Cualquier archivo <idioma>.txt que se agregue a resources/stopwords/ queda disponible solo
idiomas_disponibles <- function() sub("\\.txt$", "", list.files(ruta_recurso("resources", "stopwords"), pattern = "\\.txt$"))

normalizar_texto <- function(x) {
  x <- stringi::stri_trans_nfc(x)
  x <- stringi::stri_replace_all_regex(x, "<[A-Z_]+>", " ")             # marcas de PII
  x <- stringi::stri_trans_tolower(x)
  x <- stringi::stri_replace_all_regex(x, "[\\x{FE0F}\\x{200D}\\x{1F3FB}-\\x{1F3FF}]", "")
  x <- stringi::stri_replace_all_regex(x, "(\\p{L})\\1{2,}", "$1$1")    # holaaaa -> holaa
  x <- stringi::stri_replace_all_regex(x, "[^\\p{L}\\p{M}\\p{N}\\p{Extended_Pictographic}\\s]", " ")
  x <- stringi::stri_replace_all_regex(x, "(\\p{Extended_Pictographic})", " $1 ")
  trimws(stringi::stri_replace_all_regex(x, "\\s+", " "))
}

extraer_emojis <- function(x) {
  e <- stringi::stri_extract_all_regex(x, "\\p{Extended_Pictographic}")
  vapply(e, function(z) if (length(z) == 1 && is.na(z)) "" else paste(z, collapse = " "), character(1))
}

limpiar_texto <- function(df) {
  df$es_pregunta <- stringi::stri_detect_regex(df$texto, "[?\u00bf]")
  df$emojis <- extraer_emojis(df$texto)
  df$texto_limpio <- normalizar_texto(df$texto)
  df$n_palabras <- stringi::stri_count_regex(df$texto_limpio, "[\\p{L}\\p{N}]+")
  df$tiene_texto <- nzchar(df$texto_limpio)
  attr(df, "detalle") <- sprintf("sin texto util=%d; con emojis=%d; preguntas=%d",
    sum(!df$tiene_texto), sum(nzchar(df$emojis)), sum(df$es_pregunta))
  df
}

# Idioma del archivo por proporcion de stopwords de cada idioma disponible (sin dependencias)
detectar_idioma <- function(texto_limpio, umbral = 0.10, muestra = 3000) {
  langs <- idiomas_disponibles()
  txt <- texto_limpio[nzchar(texto_limpio)]
  if (length(langs) == 0 || length(txt) == 0) return(list(idioma = "und", fracciones = numeric()))
  txt <- txt[round(seq(1, length(txt), length.out = min(muestra, length(txt))))]
  tt <- unlist(stringi::stri_split_regex(txt, "\\s+", omit_empty = TRUE))
  frac <- vapply(langs, function(l) mean(tt %in% cargar_stopwords(l)), numeric(1))
  list(idioma = if (max(frac) >= umbral) langs[which.max(frac)] else "und", fracciones = round(frac, 3))
}
