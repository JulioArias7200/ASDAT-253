# Tabla larga de tokens: base para bigramas, tf-idf, topic modeling, frecuencias y diccionario de emojis.
# Devuelve TODOS los tokens con banderas; filtrar_tokens() aplica stopwords. Negaciones/intensificadores se conservan.
tokenizar_mensajes <- function(df, col = "texto_limpio", idioma = NULL, conservar = NULL) {
  idioma <- idioma %si_vacio% unique(df$idioma)[1]
  conservar <- conservar %si_vacio% cargar_config()$params$conservar_siempre
  sw <- setdiff(cargar_stopwords(idioma), conservar)
  df <- df[nzchar(df[[col]]), ]
  partes <- stringi::stri_split_regex(df[[col]], "\\s+", omit_empty = TRUE)
  n <- lengths(partes)
  tok <- tibble::tibble(msg_id = rep(df$msg_id, n), pos = sequence(n),
                        token = unlist(partes, use.names = FALSE))
  i <- match(tok$msg_id, df$msg_id)
  tok$periodo_id <- df$periodo_id[i]; tok$temporada <- df$temporada[i]
  tok$es_stopword <- tok$token %in% sw
  tok$es_emoji <- stringi::stri_detect_regex(tok$token, "^\\p{Extended_Pictographic}$")
  tok$es_numero <- stringi::stri_detect_regex(tok$token, "^\\p{N}+$")
  tok
}

filtrar_tokens <- function(tok, quitar_stopwords = TRUE, quitar_numeros = TRUE, min_chars = 2) {
  keep <- rep(TRUE, nrow(tok))
  if (quitar_stopwords) keep <- keep & !tok$es_stopword
  if (quitar_numeros) keep <- keep & !tok$es_numero
  keep <- keep & (tok$es_emoji | nchar(tok$token) >= min_chars)
  tok[keep, ]
}
