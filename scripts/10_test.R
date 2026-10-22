# =============================================================================
# 10_test.R — ejecuta la suite de pruebas
# Uso: Rscript scripts/10_test.R
# =============================================================================
source("R/bootstrap.R")
bs <- bootstrap(root = if (basename(getwd()) == "scripts") dirname(getwd()) else getwd(),
                init_db = FALSE)

if (!requireNamespace("testthat", quietly = TRUE)) stop("Falta el paquete testthat")

res <- testthat::test_dir(proj_path("tests", "testthat"),
                          reporter = "summary", stop_on_failure = FALSE)
df <- as.data.frame(res)
n_fail <- sum(df$failed) + sum(df$error)
if (n_fail > 0) stop(sprintf("%d fallos en las pruebas", n_fail))
cat("OK 10_test\n")
