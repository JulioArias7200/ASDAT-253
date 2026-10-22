# =============================================================================
# .Rprofile — AS_Telegram
# Activa renv y prepara el entorno de ejecución.
# =============================================================================

# --- GSL para topicmodels (Ubuntu con GSL extraído en prefijo de usuario) -----
.gsl_dir <- path.expand("~/opt/gsl/usr/lib/x86_64-linux-gnu")
if (dir.exists(.gsl_dir)) {
  .ld <- Sys.getenv("LD_LIBRARY_PATH")
  if (!grepl(.gsl_dir, .ld, fixed = TRUE)) {
    Sys.setenv(LD_LIBRARY_PATH = paste(c(.ld, .gsl_dir), collapse = ":"))
  }
}
rm(.gsl_dir)

# --- TinyTeX / herramientas locales en PATH ---------------------------------
.tt_bin <- path.expand("~/.TinyTeX/bin/x86_64-linux")
.user_bin <- path.expand("~/bin")
.path_extra <- c(.user_bin, .tt_bin)
.path_extra <- .path_extra[dir.exists(.path_extra)]
if (length(.path_extra)) {
  .p <- Sys.getenv("PATH")
  for (.d in rev(.path_extra)) if (!grepl(.d, .p, fixed = TRUE)) .p <- paste(.d, .p, sep = ":")
  Sys.setenv(PATH = .p)
}
rm(list = intersect(c(".tt_bin", ".user_bin", ".path_extra", ".p", ".d"), ls()))

# --- renv -------------------------------------------------------------------
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# --- Opciones del proyecto --------------------------------------------------
options(
  encoding = "UTF-8",
  stringsAsFactors = FALSE,
  warn = 1
)

# Fija la zona horaria canónica del corpus.
Sys.setenv(TZ = Sys.getenv("TZ", "America/La_Paz"))
