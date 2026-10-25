# Asigna temporada/periodo segun config/seasons.yml. Funciona para cualquier anio futuro o pasado.
asignar_periodo <- function(fecha, seasons) {
  md <- format(fecha, "%m-%d"); y <- as.integer(format(fecha, "%Y"))
  temporada <- rep("fuera_de_temporada", length(fecha)); ciclo <- rep(NA_integer_, length(fecha))
  for (s in seasons) {
    cruza <- s$inicio > s$fin
    dentro <- if (!cruza) md >= s$inicio & md <= s$fin else md >= s$inicio | md <= s$fin
    dentro[is.na(dentro)] <- FALSE
    anio <- ifelse(cruza & md >= s$inicio, y + 1L, y)
    temporada[dentro] <- s$id; ciclo[dentro] <- anio[dentro]
  }
  tibble::tibble(temporada = temporada, ciclo = ciclo,
                 periodo_id = ifelse(temporada == "fuera_de_temporada", "fuera", paste0(temporada, "_", ciclo)))
}
