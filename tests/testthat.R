# =============================================================================
# Runner de la suite testthat (estilo R CMD check)
# Ejecutar desde la raíz del proyecto:  Rscript tests/testthat.R
# =============================================================================
library(testthat)

root <- Sys.getenv("AS_TELEGRAM_ROOT", unset = normalizePath("."))
if (!file.exists(file.path(root, "R", "bootstrap.R"))) root <- normalizePath(".")
Sys.setenv(AS_TELEGRAM_ROOT = root)

testthat::test_dir(file.path(root, "tests", "testthat"),
                   reporter = "summary", stop_on_failure = FALSE)
