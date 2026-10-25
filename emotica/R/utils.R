`%si_vacio%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a
}

raiz <- function() getOption("emotica.raiz", default = getwd())
ruta_recurso <- function(...) file.path(raiz(), ...)

# Carga la configuracion (periodos y parametros) desde archivos YAML
cargar_config <- function(seasons = ruta_recurso("config", "seasons.yml"),
                          params  = ruta_recurso("config", "preprocess.yml")) {
  list(seasons = leer_yaml(seasons), params = leer_yaml(params))
}

# Lee YAML siempre como UTF-8 desde los bytes (evita fallos en Windows o con locale "C")
leer_yaml <- function(path) {
  txt <- rawToChar(readBin(path, "raw", file.size(path)))
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

# Lineas de un archivo de texto UTF-8 leidas desde los bytes (no depende de options(encoding) ni del locale)
leer_lineas_utf8 <- function(path) {
  txt <- rawToChar(readBin(path, "raw", file.size(path)))
  Encoding(txt) <- "UTF-8"
  txt <- sub("^\ufeff", "", txt)
  strsplit(gsub("\r\n?", "\n", txt), "\n", fixed = TRUE)[[1]]
}
