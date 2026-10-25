# Validacion del motor con frases etiquetadas a mano (el equipo etiqueta; el motor se mide contra eso)
muestra_para_etiquetar <- function(mensajes, scores, n = 100, min_palabras = 4, prop_sin_emocion = 0.3, semilla = 2026) {
  set.seed(semilla)
  nw <- suppressWarnings(as.numeric(mensajes$n_palabras))
  ok <- mensajes[!is.na(mensajes$texto_limpio) & nzchar(mensajes$texto_limpio) & !is.na(nw) & nw >= min_palabras, ]
  dom <- scores[order(scores$msg_id, -scores$puntaje), ]; dom <- dom[!duplicated(dom$msg_id), ]
  con <- ok[ok$msg_id %in% dom$msg_id, ]; sin <- ok[!ok$msg_id %in% dom$msg_id, ]
  n_con <- round(n * (1 - prop_sin_emocion)); emos <- unique(dom$emocion_id)
  por <- ceiling(n_con / length(emos))
  elegidos <- unlist(lapply(emos, function(e) { ids <- intersect(con$msg_id, dom$msg_id[dom$emocion_id == e])
                                                if (length(ids) <= por) ids else sample(ids, por) }))
  elegidos <- if (length(elegidos) > n_con) sample(elegidos, n_con) else elegidos
  sin_ids <- sample(sin$msg_id, min(nrow(sin), n - length(elegidos)))
  ids <- sample(c(elegidos, sin_ids))
  i <- match(ids, mensajes$msg_id)
  list(hoja = tibble::tibble(msg_id = ids, texto = mensajes$texto[i], emociones = "", intensidad = "", etiquetador = ""),
       clave = tibble::tibble(msg_id = ids, estrato = ifelse(ids %in% sin_ids, "sin_emocion_motor", "con_emocion_motor"),
                              emocion_dominante_motor = dom$emocion_id[match(ids, dom$msg_id)]))
}

etiquetas_largas <- function(hoja) {
  e <- strsplit(tolower(trimws(as.character(hoja$emociones))), "\\s*[;,]\\s*")
  out <- tibble::tibble(msg_id = rep(hoja$msg_id, lengths(e)), emocion_id = unlist(e))
  out[!is.na(out$emocion_id) & nzchar(out$emocion_id) & out$emocion_id != "ninguna", ]
}

evaluar_motor <- function(scores, hoja, taxonomy = cargar_taxonomia(), umbral_confianza = 0) {
  ids <- hoja$msg_id[nzchar(trimws(as.character(hoja$emociones)))]
  et <- etiquetas_largas(hoja)
  pr <- scores[scores$msg_id %in% ids & scores$confianza >= umbral_confianza, ]
  K <- function(d) paste(d$msg_id, d$emocion_id)
  emos <- sort(unique(c(et$emocion_id, pr$emocion_id)))
  por <- do.call(rbind, lapply(emos, function(e) {
    h <- K(et[et$emocion_id == e, ]); m <- K(pr[pr$emocion_id == e, ])
    tp <- length(intersect(h, m)); fp <- length(setdiff(m, h)); fn <- length(setdiff(h, m))
    p <- if (tp + fp) tp / (tp + fp) else NA; r <- if (tp + fn) tp / (tp + fn) else NA
    data.frame(emocion_id = e, humano = length(h), motor = length(m), tp = tp, fp = fp, fn = fn,
               precision = round(p, 2), recall = round(r, 2), f1 = round(if (!is.na(p + r) && p + r > 0) 2 * p * r / (p + r) else NA, 2)) }))
  tp <- sum(por$tp); fp <- sum(por$fp); fn <- sum(por$fn)
  p <- tp / max(1, tp + fp); r <- tp / max(1, tp + fn)
  list(por_emocion = tibble::as_tibble(por), n_mensajes = length(ids),
       global = c(precision = round(p, 3), recall = round(r, 3), f1 = round(if (p + r > 0) 2 * p * r / (p + r) else 0, 3)))
}

kappa_cohen <- function(a, b) { if (length(a) == 0) return(NA_real_); po <- mean(a == b); pe <- mean(a) * mean(b) + mean(!a) * mean(!b); if (pe == 1) NA_real_ else (po - pe) / (1 - pe) }

# hojas: lista nombrada (una por etiquetador) con las mismas frases. kappa por pares sobre presencia de cada emocion.
acuerdo_etiquetadores <- function(hojas, emociones = cargar_taxonomia()$id) {
  ids <- Reduce(intersect, lapply(hojas, function(h) h$msg_id[nzchar(trimws(as.character(h$emociones)))]))
  M <- lapply(hojas, function(h) { et <- etiquetas_largas(h); as.vector(sapply(emociones, function(e) ids %in% et$msg_id[et$emocion_id == e])) })
  pares <- utils::combn(names(hojas), 2, simplify = FALSE)
  tibble::tibble(par = vapply(pares, paste, "", collapse = " vs "),
                 kappa = round(vapply(pares, function(p) kappa_cohen(M[[p[1]]], M[[p[2]]]), numeric(1)), 3), n_frases = length(ids))
}

# Calibracion de pesos: correlacion entre el puntaje del motor y la intensidad humana (1-5) de la emocion dominante
correlacion_intensidad <- function(scores, hoja) {
  dom <- scores[order(scores$msg_id, -scores$puntaje), ]; dom <- dom[!duplicated(dom$msg_id), ]
  h <- data.frame(msg_id = hoja$msg_id, humana = suppressWarnings(as.numeric(hoja$intensidad)))
  j <- merge(dom[, c("msg_id", "puntaje")], h[!is.na(h$humana), ], by = "msg_id")
  list(n = nrow(j), spearman = if (nrow(j) >= 5) round(stats::cor(j$puntaje, j$humana, method = "spearman"), 3) else NA_real_)
}
