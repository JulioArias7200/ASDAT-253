# =============================================================================
# bootstrap.R — inicializa el proyecto para los scripts
# =============================================================================

#' Carga todos los módulos, la configuración y asegura la base de datos.
#' @export
bootstrap <- function(root = NULL, init_db = TRUE) {
  if (is.null(root)) {
    wd <- getwd()
    root <- if (basename(wd) == "scripts") dirname(wd) else wd
  }
  root <- normalizePath(root, mustWork = TRUE)
  Sys.setenv(AS_TELEGRAM_ROOT = root)

  files <- list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)
  files <- files[basename(files) != "bootstrap.R"]
  for (f in sort(files)) source(f, encoding = "UTF-8")

  cfg <- load_config()
  if (init_db) ensure_database(cfg = cfg)
  list(root = root, cfg = cfg)
}

#' Rutas estándar de artefactos intermedios
#' @export
interim_path <- function(name) proj_path("data", "interim", name)
#' @export
processed_path <- function(name) proj_path("data", "processed", name)
#' @export
results_path <- function(name) proj_path("data", "results", name)

#' Guarda un objeto intermedio en RDS
#' @export
save_rds <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(x, path)
  invisible(path)
}

#' Lee un RDS intermedio
#' @export
read_rds <- function(path) readRDS(path)
