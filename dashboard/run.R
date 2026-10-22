# =============================================================================
# run.R — lanza el dashboard Shiny de AS_Telegram
# Uso: Rscript dashboard/run.R   (o desde R: shiny::runApp("dashboard"))
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
port <- if (length(args) >= 1) as.integer(args[1]) else 3838L
host <- if (length(args) >= 2) args[2] else "127.0.0.1"

shiny::runApp(appDir = "dashboard", port = port, host = host, launch.browser = FALSE)
