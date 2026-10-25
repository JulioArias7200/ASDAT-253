# ---- Fechas: prueba varios formatos y elige el que mas filas interpreta ----
.ordenes_fecha <- c("YmdHMS", "YmdHM", "Ymd",
                    "dmYHMS", "dmYHM", "dmY", "mdYHMS", "mdYHM", "mdY",
                    "dmyHMS", "dmyHM", "dmy", "mdyHMS", "mdyHM", "mdy",
                    "dmYIMSp", "dmYIMp", "mdYIMSp", "mdYIMp",
                    "dmyIMSp", "dmyIMp", "mdyIMSp", "mdyIMp")

parse_fecha <- function(x, tz = "UTC") {
  if (inherits(x, "POSIXt")) return(list(fecha = x, formato = "POSIXct", tasa = 1, ambiguo = FALSE))
  num <- suppressWarnings(as.numeric(x))
  if (mean(!is.na(num)) > 0.9 && stats::median(num, na.rm = TRUE) > 1e9) {
    div <- if (stats::median(num, na.rm = TRUE) > 1e11) 1000 else 1
    return(list(fecha = as.POSIXct(num / div, origin = "1970-01-01", tz = tz),
                formato = "epoch", tasa = mean(!is.na(num)), ambiguo = FALSE))
  }
  x <- as.character(x)
  muestra <- x[!is.na(x) & nzchar(x)]
  if (length(muestra) == 0) return(list(fecha = as.POSIXct(rep(NA, length(x)), tz = tz),
                                        formato = NA, tasa = 0, ambiguo = FALSE))
  muestra <- muestra[round(seq(1, length(muestra), length.out = min(500, length(muestra))))]
  tasas <- vapply(.ordenes_fecha, function(o)
    mean(!is.na(suppressWarnings(lubridate::parse_date_time(muestra, o, tz = tz, quiet = TRUE)))),
    numeric(1))
  mejor <- which.max(tasas)
  # ambiguo si d/m y m/d rinden lo mismo
  ambiguo <- sum(tasas >= tasas[mejor] - 1e-9) > 1 && !startsWith(names(tasas)[mejor], "Y")
  ord <- names(tasas)[mejor]
  list(fecha = suppressWarnings(lubridate::parse_date_time(x, ord, tz = tz, quiet = TRUE)),
       formato = ord, tasa = tasas[[mejor]], ambiguo = ambiguo)
}

# ---- Deteccion automatica de columnas (para cualquier CSV) ----
detectar_esquema <- function(df, umbral = 0.45) {
  nms <- names(df)
  nl <- stringi::stri_trans_general(tolower(nms), "Latin-ASCII")
  pat <- list(
    fecha = "date|fecha|time|timestamp|datetime|hora|created|sent|^data$|^dia$",
    autor = "from|autor|author|user|usuario|sender|remitente|nombre|name|nick|persona|nome|^de$",
    texto = "text|texto|message|mensaje|mensagem|content|contenido|body|msg|comentario|comment|post",
    responde_a = "reply|respuesta|responde|parent|respond",
    id = "^id$|msg_id|message_id|^id_|_id$|mensaje_id|^n$")
  muestra <- df[round(seq(1, nrow(df), length.out = min(300, nrow(df)))), , drop = FALSE]
  sc <- lapply(names(pat), function(campo) {
    nombre <- as.numeric(grepl(pat[[campo]], nl))
    cont <- vapply(seq_along(nms), function(i) {
      v <- as.character(muestra[[i]]); v <- v[!is.na(v) & nzchar(v)]
      if (length(v) == 0) return(0)
      switch(campo,
        fecha = { if (mean(grepl("\\d", v)) < 0.9) 0 else parse_fecha(v)$tasa },
        texto = min(1, stats::median(nchar(v)) / 40),
        autor = { r <- length(unique(v)) / length(v); if (r > 0.001 && r < 0.6) 1 else 0.2 },
        id = { if (all(grepl("^\\d+$", v)) && length(unique(v)) == length(v)) 1 else 0 },
        responde_a = { if (mean(grepl("^\\d+$", v)) > 0.9) 0.5 else 0 })
    }, numeric(1))
    0.5 * nombre + 0.5 * cont
  })
  names(sc) <- names(pat)
  mapping <- list(); conf <- c(); usadas <- integer()
  for (campo in c("texto", "fecha", "autor", "id", "responde_a")) {
    s <- sc[[campo]]; s[usadas] <- -1
    i <- which.max(s)
    if (s[i] >= umbral) { mapping[[campo]] <- nms[i]; conf[campo] <- round(s[i], 2); usadas <- c(usadas, i) }
  }
  list(mapping = mapping, confianza = conf,
       faltan = setdiff(c("texto", "fecha"), names(mapping)), columnas = nms)
}
