# =============================================================================
# helper-setup.R — prepara el entorno para la suite testthat
# =============================================================================

find_as_root <- function() {
  p <- normalizePath(Sys.getenv("AS_TELEGRAM_ROOT", unset = getwd()), mustWork = FALSE)
  repeat {
    if (file.exists(file.path(p, "R", "bootstrap.R"))) return(p)
    parent <- dirname(p)
    if (identical(parent, p)) return(normalizePath(getwd(), mustWork = FALSE))
    p <- parent
  }
}

AS_ROOT <- find_as_root()
Sys.setenv(AS_TELEGRAM_ROOT = AS_ROOT)

source(file.path(AS_ROOT, "R", "bootstrap.R"), encoding = "UTF-8")
bootstrap(root = AS_ROOT, init_db = FALSE)

for (.m in sort(list.files(file.path(AS_ROOT, "dashboard", "modules"),
                           pattern = "\\.R$", full.names = TRUE))) {
  source(.m, encoding = "UTF-8")
}

#' Ruta a un fixture de pruebas
fixture <- function(name) file.path(AS_ROOT, "tests", "testthat", "fixtures", name)

#' Diccionario cargado perezosamente una sola vez
test_dictionary <- function() {
  if (is.null(getOption("as.test_dict"))) {
    options(as.test_dict = load_dictionary(cfg = load_config()))
  }
  getOption("as.test_dict")
}
