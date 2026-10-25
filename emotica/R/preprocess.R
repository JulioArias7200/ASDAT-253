# Pipeline completo. Cada paso queda en la bitacora automatica.
preprocess_chat <- function(path, adapter = "auto", mapping = NULL, config = cargar_config(),
                            sal = NULL, salida = NULL, usuario = NULL) {
  bitacora_iniciar(path, usuario)
  df <- ingest_chat(path, adapter, mapping)
  adapter <- attr(df, "adaptador")
  tz <- config$params$zona_horaria %si_vacio% "UTC"

  df <- ejecutar_paso("filtrar_eventos_de_servicio", df, function(d) {
    out <- d[is.na(d$tipo) | d$tipo == "message", ]
    attr(out, "detalle") <- sprintf("eliminados %d eventos que no son mensajes", nrow(d) - nrow(out)); out })

  df <- ejecutar_paso("normalizar_fechas", df, function(d) {
    p <- parse_fecha(d$fecha, tz); d$fecha <- p$fecha
    out <- d[!is.na(d$fecha), ]
    attr(out, "detalle") <- sprintf("formato=%s; tasa=%.3f; sin fecha valida=%d%s", p$formato, p$tasa,
      nrow(d) - nrow(out), if (isTRUE(p$ambiguo)) "; AVISO: dia/mes ambiguo, se asumio dia primero" else ""); out
  }, list(zona = tz))

  df <- ejecutar_paso("eliminar_duplicados", df, function(d) {
    clave <- if (adapter == "telegram") d$msg_id else
      paste(d$fecha, ifelse(is.na(d$autor), "", d$autor), d$texto, sep = "|")
    out <- d[!duplicated(clave), ]
    attr(out, "detalle") <- sprintf("duplicados=%d (clave=%s)", nrow(d) - nrow(out),
      if (adapter == "telegram") "msg_id" else "fecha+autor+texto"); out })

  df <- ejecutar_paso("anonimizar_autores", df, function(d) anonimizar_autores(d, sal), list(algoritmo = "sha256+sal"))
  df <- ejecutar_paso("enmascarar_pii", df, enmascarar_pii, list(patrones = names(.patrones_pii)))
  df <- ejecutar_paso("limpiar_texto", df, limpiar_texto)

  id <- detectar_idioma(df$texto_limpio, config$params$umbral_idioma %si_vacio% 0.10)
  df$idioma <- id$idioma
  bitacora_registrar("detectar_idioma", list(umbral = config$params$umbral_idioma), nrow(df), nrow(df),
    sprintf("idioma=%s; fracciones de stopwords: %s", id$idioma,
            paste(names(id$fracciones), id$fracciones, sep = "=", collapse = ", ")))

  df <- ejecutar_paso("marcar_anuncios", df, function(d) marcar_anuncios(d, config, id$idioma),
                      list(umbral = config$params$anuncios$umbral))

  df <- ejecutar_paso("asignar_periodos", df, function(d) {
    p <- asignar_periodo(d$fecha, config$seasons)
    d$temporada <- p$temporada; d$ciclo <- p$ciclo; d$periodo_id <- p$periodo_id
    tb <- table(d$periodo_id)
    attr(d, "detalle") <- paste(names(tb), as.integer(tb), sep = "=", collapse = "; "); d },
    list(temporadas = vapply(config$seasons, function(s) s$id, "")))

  cols <- c("msg_id", "fecha", "autor_hash", "texto", "texto_limpio", "idioma", "responde_a", "periodo_id")
  df <- df[, c(cols, setdiff(names(df), c(cols, "tipo")))]

  t0 <- proc.time()[["elapsed"]]
  tok <- tokenizar_mensajes(df, idioma = id$idioma, conservar = config$params$conservar_siempre)
  bitacora_registrar("tokenizar", list(columna = "texto_limpio"), sum(df$tiene_texto), nrow(tok),
    sprintf("filas_salida = tokens; stopwords marcadas=%d; emojis=%d", sum(tok$es_stopword), sum(tok$es_emoji)),
    proc.time()[["elapsed"]] - t0)

  res <- list(mensajes = df, tokens = tok, bitacora = bitacora_leer(), idioma = id)
  if (!is.null(salida)) {
    dir.create(salida, showWarnings = FALSE, recursive = TRUE)
    readr::write_csv(df, file.path(salida, "mensajes.csv"))
    readr::write_csv(tok, file.path(salida, "tokens.csv"))
    bitacora_guardar(file.path(salida, "bitacora_auto.csv"))
  }
  res
}
