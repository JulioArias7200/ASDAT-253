cobertura_emociones <- function(scores, mensajes) {
  n <- sum(mensajes_analizables(mensajes)); c <- length(unique(scores$msg_id))
  tibble::tibble(mensajes_con_texto = n, con_emocion = c, cobertura = round(c / n, 4))
}

# Contrato "summarise_by_period": tasa por 1000 mensajes con texto, intensidad media y puntaje total
resumen_por_periodo <- function(scores, mensajes) {
  base <- table(mensajes$periodo_id[mensajes_analizables(mensajes)])
  g <- split(scores, list(scores$periodo_id, scores$emocion_id), drop = TRUE)
  out <- do.call(rbind, lapply(g, function(d) data.frame(
    periodo_id = d$periodo_id[1], emocion_id = d$emocion_id[1], mensajes = length(unique(d$msg_id)),
    intensidad_media = round(mean(d$intensidad), 3), puntaje_total = round(sum(d$puntaje), 1))))
  out$tasa_x1000 <- round(1000 * out$mensajes / as.numeric(base[out$periodo_id]), 1)
  rownames(out) <- NULL
  tibble::as_tibble(out[order(out$periodo_id, -out$tasa_x1000), ])
}
