# Bitacora automatica (Contrato 4):
# paso, parametros, filas_entrada, filas_salida, huella_archivo, fecha_hora, usuario
# + extras: detalle, duracion_s
.bit <- new.env(parent = emptyenv())

bitacora_iniciar <- function(archivo = NA_character_, usuario = NULL) {
  .bit$filas <- list()
  .bit$usuario <- usuario %si_vacio% Sys.info()[["user"]]
  .bit$huella <- if (!is.na(archivo) && file.exists(archivo))
    digest::digest(archivo, algo = "sha256", file = TRUE) else NA_character_
  invisible(.bit$huella)
}

bitacora_registrar <- function(paso, parametros = list(), filas_entrada = NA, filas_salida = NA,
                               detalle = "", duracion_s = NA_real_) {
  if (is.null(.bit$filas)) bitacora_iniciar()
  pjson <- if (length(parametros) == 0) "{}" else
    as.character(jsonlite::toJSON(parametros, auto_unbox = TRUE, null = "null"))
  fila <- tibble::tibble(
    paso = paso, parametros = pjson,
    filas_entrada = as.integer(filas_entrada), filas_salida = as.integer(filas_salida),
    huella_archivo = .bit$huella %si_vacio% NA_character_,
    fecha_hora = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    usuario = .bit$usuario %si_vacio% NA_character_,
    detalle = as.character(detalle), duracion_s = round(duracion_s, 3)
  )
  .bit$filas[[length(.bit$filas) + 1]] <- fila
  invisible(fila)
}

bitacora_leer <- function() {
  if (length(.bit$filas) == 0) return(tibble::tibble())
  tibble::as_tibble(do.call(rbind, .bit$filas))
}

bitacora_guardar <- function(path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  readr::write_csv(bitacora_leer(), path)
  invisible(path)
}

# Ejecuta un paso f(df) -> df, midiendo filas y tiempo. Si f deja attr(,"detalle") se registra.
ejecutar_paso <- function(paso, df, f, parametros = list()) {
  t0 <- proc.time()[["elapsed"]]
  n_in <- nrow(df)
  out <- f(df)
  det <- attr(out, "detalle")
  attr(out, "detalle") <- NULL
  bitacora_registrar(paso, parametros, n_in, nrow(out), det %si_vacio% "",
                     proc.time()[["elapsed"]] - t0)
  out
}
