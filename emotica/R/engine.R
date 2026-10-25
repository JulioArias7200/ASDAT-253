# Motor de emociones. NUNCA nombra una emocion: todo sale de la taxonomia y del lexico (dinamico).
# Peso final de un hallazgo = peso_termino x factor_modificadores (intensificador/atenuador, ventana de 3 tokens)
#   - negado: no suma a su emocion; suma factor_negacion_opuesta x peso a la 'opuesta' si existe
#   - frases y regex tienen prioridad y "consumen" sus palabras (evita doble conteo; ej. "no aprobe" != "aprobe")
# puntaje = suma x (1 + senales de forma: !, MAYUSCULAS, alargamiento);  intensidad = 1 - exp(-puntaje/escala)
cargar_params_motor <- function(path = ruta_recurso("config", "engine.yml")) leer_yaml(path)

cargar_modificadores <- function(idioma = "es") {
  f <- ruta_recurso("resources", "modifiers", paste0(idioma, ".csv"))
  if (!file.exists(f)) return(tibble::tibble(termino = character(), tipo = character(), factor = numeric(), clave = character()))
  m <- readr::read_csv(f, col_types = readr::cols(.default = "c"), locale = readr::locale(encoding = "UTF-8"), progress = FALSE)
  m$factor <- as.numeric(m$factor); m$clave <- normalizar_clave(m$termino); m
}

score_emotions <- function(mensajes, taxonomy = cargar_taxonomia(), lexicon = NULL, active = NULL,
                           idioma = NULL, params = cargar_params_motor()) {
  idioma <- idioma %si_vacio% unique(mensajes$idioma)[1]
  if (is.null(lexicon)) lexicon <- cargar_lexicon(idioma)
  vacio <- tibble::tibble(msg_id = character(), emocion_id = character(), puntaje = numeric(),
                          confianza = numeric(), evidencia = character(), intensidad = numeric(), nivel = character())
  if (nrow(lexicon) == 0) {
    warning(sprintf("Sin lexico para el idioma '%s': no hay cobertura, se devuelve una tabla vacia.", idioma))
    return(vacio)
  }
  desconocidas <- setdiff(unique(lexicon$emocion_id), taxonomy$id)
  if (length(desconocidas)) warning("Terminos con emocion_id fuera de la taxonomia (se ignoran): ", paste(desconocidas, collapse = ", "))
  activas <- taxonomy$id[taxonomy$activa]
  if (!is.null(active)) activas <- intersect(activas, active)
  lex <- lexicon[lexicon$emocion_id %in% activas, ]
  mods <- cargar_modificadores(idioma)

  idx <- which(mensajes_analizables(mensajes, params))
  k <- normalizar_clave(mensajes$texto_limpio[idx])
  raw <- stringi::stri_replace_all_regex(mensajes$texto[idx], "<[A-Z_]+>", " ")
  kk <- paste0(" ", k, " ")
  esp <- stringi::stri_detect_regex(mensajes$texto[idx], "[?\u00bf]")   # el mensaje es una pregunta
  hits <- list()
  add <- function(i, emo, contrib, evid, neg) {
    hits[[length(hits) + 1]] <<- data.frame(i = i, emocion_id = emo, contrib = contrib,
                                             evidencia = evid, neg = neg, stringsAsFactors = FALSE)
  }

  # 1) frases y regex (prioridad: las mas largas primero; una vez contadas se reemplazan por un marcador)
  fr <- lex[lex$tipo %in% c("frase", "regex"), ]
  for (cl in unique(fr$clave[order(-nchar(fr$clave))])) {
    f <- fr[fr$clave == cl, ]
    rx <- f$tipo[1] == "regex"
    n <- if (rx) stringi::stri_count_regex(kk, cl) else stringi::stri_count_fixed(kk, paste0(" ", cl, " "))
    w <- which(n > 0)
    if (length(w) == 0) next
    for (r in seq_len(nrow(f))) {
      wr <- switch(f$contexto[r], no_pregunta = w[!esp[w]], pregunta = w[esp[w]], w)
      if (length(wr)) add(wr, f$emocion_id[r], f$peso[r] * n[wr], f$termino[r], FALSE)
    }
    kk[w] <- if (rx) stringi::stri_replace_all_regex(kk[w], cl, " \u00a6 ") else
      stringi::stri_replace_all_fixed(kk[w], paste0(" ", cl, " "), " \u00a6 ")
  }

  # 2) palabras y emojis, con modificadores en una ventana hacia atras
  tokens <- stringi::stri_split_regex(trimws(kk), "\\s+", omit_empty = TRUE)
  nt <- lengths(tokens)
  tk <- data.frame(i = rep(seq_along(tokens), nt), pos = sequence(nt),
                   token = unlist(tokens, use.names = FALSE), stringsAsFactors = FALSE)
  tk$key <- paste(tk$i, tk$pos)
  mi <- match(tk$token, mods$clave)
  tk$mtipo <- mods$tipo[mi]; tk$mfac <- mods$factor[mi]
  lw <- lex[lex$tipo %in% c("palabra", "emoji"), c("clave", "emocion_id", "peso", "termino", "contexto")]
  hw <- merge(tk, lw, by.x = "token", by.y = "clave")
  hw <- hw[!((hw$contexto == "no_pregunta" & esp[hw$i]) | (hw$contexto == "pregunta" & !esp[hw$i])), ]
  if (nrow(hw) > 0) {
    neg <- rep(FALSE, nrow(hw)); fac <- rep(1, nrow(hw)); negtok <- rep(NA_character_, nrow(hw))
    for (L in seq_len(params$ventana_modificadores)) {
      j <- match(paste(hw$i, hw$pos - L), tk$key)
      t <- tk$mtipo[j]; f <- tk$mfac[j]
      esneg <- !is.na(t) & t == "negador"
      negtok[esneg & is.na(negtok)] <- tk$token[j][esneg & is.na(negtok)]
      neg <- neg | esneg
      esmod <- !is.na(t) & t %in% c("intensificador", "atenuador")
      fac[esmod] <- fac[esmod] * f[esmod]
    }
    fac <- pmin(pmax(fac, 0.3), 2)
    contrib <- hw$peso * fac
    evid <- ifelse(fac != 1, paste0(hw$termino, " x", round(fac, 2)), hw$termino)
    ok <- which(!neg)
    if (length(ok)) add(hw$i[ok], hw$emocion_id[ok], contrib[ok], evid[ok], FALSE)
    ng <- which(neg)
    if (length(ng)) {
      opu <- taxonomy$opuesta[match(hw$emocion_id[ng], taxonomy$id)]
      v <- !is.na(opu) & opu %in% activas
      if (any(v)) add(hw$i[ng][v], opu[v], params$factor_negacion_opuesta * contrib[ng][v],
                      paste0("NEG(", negtok[ng][v], ")+", hw$termino[ng][v]), TRUE)
    }
  }
  if (length(hits) == 0) return(vacio)
  H <- do.call(rbind, hits)
  key <- paste(H$i, H$emocion_id, sep = "\r"); ug <- unique(key); ix <- match(ug, key)
  agg <- data.frame(i = H$i[ix], emocion_id = H$emocion_id[ix],
                    base = as.numeric(tapply(H$contrib, key, sum)[ug]),
                    n_evid = as.integer(tapply(H$contrib, key, length)[ug]),
                    neg = as.logical(tapply(H$neg, key, any)[ug]),
                    evidencia = as.character(tapply(H$evidencia, key, function(x) paste(unique(x), collapse = " | "))[ug]),
                    stringsAsFactors = FALSE)

  # 3) senales de forma de escribir (sobre el texto original)
  s <- params$senales
  excl <- stringi::stri_count_fixed(raw, "!")
  caps <- stringi::stri_count_regex(raw, "\\b\\p{Lu}{3,}\\b")
  alarg <- stringi::stri_detect_regex(raw, "(\\p{L})\\1{2,}")
  mult <- 1 + pmin(s$tope, s$exclamacion * pmin(excl, s$exclamacion_max) + s$mayusculas * (caps >= 2) + s$alargamiento * alarg)
  agg$puntaje <- round(agg$base * mult[agg$i], 3)
  agg$intensidad <- round(1 - exp(-agg$puntaje / params$escala_intensidad), 3)
  nv <- params$niveles
  agg$nivel <- ifelse(agg$intensidad < nv$leve, "leve", ifelse(agg$intensidad < nv$moderada, "moderada",
                ifelse(agg$intensidad < nv$alta, "alta", "muy_alta")))
  agg$confianza <- round(pmin(1, pmax(0.1, (0.35 + 0.25 * pmin(agg$n_evid, 2) + 0.15 * (agg$n_evid >= 3)) *
                                        ifelse(agg$neg, 0.7, 1))), 2)
  pos <- idx[agg$i]
  out <- tibble::tibble(msg_id = as.character(mensajes$msg_id[pos]), emocion_id = agg$emocion_id,
                        puntaje = agg$puntaje, confianza = agg$confianza, evidencia = agg$evidencia,
                        intensidad = agg$intensidad, nivel = agg$nivel)
  if ("periodo_id" %in% names(mensajes)) out$periodo_id <- mensajes$periodo_id[pos]
  if ("temporada" %in% names(mensajes)) out$temporada <- mensajes$temporada[pos]
  out <- out[order(out$msg_id, -out$puntaje), ]
  attr(out, "cobertura") <- c(mensajes_con_texto = length(idx), con_emocion = length(unique(agg$i)))
  out
}
