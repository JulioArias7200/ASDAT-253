# Marca anuncios, difusiones y spam con reglas ESTRUCTURALES (no emocionales), configurables y por idioma.
# Un anuncio no expresa la emocion del estudiante, asi que el motor y los temas lo excluyen (excluir_anuncios).
# Puntaje: +1 largo, +1 muchas lineas, +1 URL y texto, +1 muchos emojis, +1 varias menciones, +1 por palabra de aviso (max 2),
#          palabra fuerte (prefijo '!' en resources/anuncios/<idioma>.txt) = spam inmediato. Se marca si puntaje >= umbral.
cargar_palabras_anuncio <- function(idioma) {
  f <- ruta_recurso("resources", "anuncios", paste0(idioma, ".txt"))
  if (!file.exists(f)) return(list(debiles = character(), fuertes = character()))
  l <- trimws(leer_lineas_utf8(f)); l <- l[nzchar(l) & !grepl("^#", l)]
  list(debiles = normalizar_clave(l[!startsWith(l, "!")]), fuertes = normalizar_clave(sub("^!", "", l[startsWith(l, "!")])))
}

marcar_anuncios <- function(df, config = cargar_config(), idioma = NULL) {
  p <- config$params$anuncios
  umbral <- p$umbral %si_vacio% 2; min_chars <- p$min_chars %si_vacio% 280; min_lineas <- p$min_lineas %si_vacio% 4
  txt <- ifelse(is.na(df$texto), "", df$texto)
  k <- paste0(" ", normalizar_clave(txt), " ")
  n_pal <- stringi::stri_count_regex(txt, "[\\p{L}\\p{N}]+")
  pw <- cargar_palabras_anuncio(idioma %si_vacio% unique(df$idioma)[1])
  cuenta <- function(ws) if (length(ws)) Reduce(`+`, lapply(ws, function(w) as.integer(stringi::stri_detect_fixed(k, w)))) else rep(0L, length(k))
  n_deb <- cuenta(pw$debiles); n_fue <- cuenta(pw$fuertes)
  puntaje <- (nchar(txt) >= min_chars) + ((stringi::stri_count_fixed(txt, "\n") + 1) >= min_lineas) +
    (stringi::stri_count_fixed(txt, "<URL>") >= 1 & n_pal >= 6) + (stringi::stri_count_regex(txt, "\\p{Extended_Pictographic}") >= 4) +
    (stringi::stri_count_fixed(txt, "<USUARIO>") >= 2) + pmin(2L, n_deb) + 3L * (n_fue > 0)
  df$puntaje_anuncio <- as.integer(puntaje)
  df$es_anuncio <- puntaje >= umbral
  attr(df, "detalle") <- sprintf("anuncios/spam=%d (%.1f%%); spam fuerte=%d; umbral=%d", sum(df$es_anuncio), 100 * mean(df$es_anuncio), sum(n_fue > 0), umbral)
  df
}

# Mensajes que entran al analisis de emociones (con texto y, si se pide, sin anuncios)
mensajes_analizables <- function(mensajes, params = cargar_params_motor()) {
  ok <- !is.na(mensajes$texto_limpio) & nzchar(mensajes$texto_limpio)
  if (isTRUE(params$excluir_anuncios) && "es_anuncio" %in% names(mensajes)) ok <- ok & !(as.logical(mensajes$es_anuncio) %in% TRUE)
  ok
}
