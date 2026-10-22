# =============================================================================
# report_generation.R — figuras, tablas y artefactos del informe
# =============================================================================

#' Escapa caracteres especiales de LaTeX
#' @export
latex_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("\\", "\\textbackslash{}", x, fixed = TRUE)
  x <- gsub("([&%$#_{}])", "\\\\\\1", x)
  x <- gsub("~", "\\textasciitilde{}", x, fixed = TRUE)
  x <- gsub("^", "\\textasciicircum{}", x, fixed = TRUE)
  x
}

#' Escribe una tabla como CSV y como fragmento LaTeX (con escape seguro)
#' @export
write_table <- function(df, name, dir = proj_path("reports", "tables"),
                        caption = NULL, colspec = NULL, digits = 4) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  csv <- file.path(dir, paste0(name, ".csv"))
  tex <- file.path(dir, paste0(name, ".tex"))
  readr::write_csv(df, csv)

  pretty <- df
  for (j in seq_along(pretty)) {
    if (is.numeric(pretty[[j]])) {
      pretty[[j]] <- format(pretty[[j]], digits = digits)
    } else {
      pretty[[j]] <- emoji_shortcode(as.character(pretty[[j]]))
    }
  }
  pretty[] <- lapply(pretty, latex_escape)
  names(pretty) <- latex_escape(gsub("_", " ", names(pretty)))

  if (is.null(colspec)) {
    colspec <- paste(c("l", rep("r", ncol(df) - 1L)), collapse = "")
  }
  body <- apply(pretty, 1, function(r) paste(paste(r, collapse = " & "), "\\\\"))
  lines <- c(
    "\\begin{table}[htbp]", "\\centering", "\\small",
    sprintf("\\caption{%s}", caption %||% gsub("_", " ", name)),
    sprintf("\\label{tab:%s}", name),
    sprintf("\\begin{tabular}{%s}", colspec), "\\toprule",
    paste(paste(names(pretty), collapse = " & "), "\\\\"), "\\midrule",
    body, "\\bottomrule", "\\end{tabular}", "\\end{table}"
  )
  writeLines(lines, tex, useBytes = TRUE)
  c(csv, tex)
}

#' Escribe macros LaTeX con las cifras clave del análisis
#' @export
write_latex_macros <- function(messages, sentiments, temporal = NULL, markov = NULL,
                               path = proj_path("reports", "generated", "values.tex")) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  cov <- dictionary_coverage(sentiments)
  lab <- function(x) sum(sentiments$polarity_label == x)
  fmt <- function(x) format(x, big.mark = ".", decimal.mark = ",")
  n_dias <- if (!is.null(temporal)) length(unique(temporal$period)) else NA
  macros <- c(
    sprintf("\\renewcommand{\\nMensajes}{%s}", fmt(nrow(messages))),
    sprintf("\\renewcommand{\\nAnalizados}{%s}", fmt(nrow(sentiments))),
    sprintf("\\renewcommand{\\pctCobertura}{%.1f}", 100 * cov$coverage),
    sprintf("\\renewcommand{\\pctIndeterminado}{%.1f}", 100 * cov$indeterminate),
    sprintf("\\renewcommand{\\nPositivos}{%s}", fmt(lab("positivo"))),
    sprintf("\\renewcommand{\\nNegativos}{%s}", fmt(lab("negativo"))),
    sprintf("\\renewcommand{\\nNeutros}{%s}", fmt(lab("neutro"))),
    sprintf("\\renewcommand{\\nIndeterminados}{%s}", fmt(lab("indeterminado"))),
    sprintf("\\renewcommand{\\manualInicio}{%s}",
            format(min(as.Date(substr(messages$timestamp_utc, 1, 10))), "%Y")),
    sprintf("\\renewcommand{\\manualFin}{%s}",
            format(max(as.Date(substr(messages$timestamp_utc, 1, 10))), "%Y")),
    sprintf("\\renewcommand{\\nPeriodos}{%s}", ifelse(is.na(n_dias), 0, n_dias))
  )
  if (!is.null(markov) && length(markov$results)) {
    r <- markov$results[[1]]
    macros <- c(macros,
      sprintf("\\renewcommand{\\pctNeutro}{%.1f}", 100 * unname(r$stationary[["neutro"]])),
      sprintf("\\renewcommand{\\piNeutro}{%.1f}", 100 * unname(r$stationary[["neutro"]])),
      sprintf("\\renewcommand{\\recuperacionNegativa}{%.2f}", r$recovery))
  }
  writeLines(macros, path, useBytes = TRUE)
  invisible(path)
}

#' Genera figuras y tablas del informe a partir de los resultados
#' @export
generate_report_artifacts <- function(messages, sentiments, temporal, topics_tbl = NULL,
                                      markov = NULL, cfg = load_config(), con = NULL,
                                      run_id = NA) {
  fig_dir <- proj_path("reports", "figures")
  tab_dir <- proj_path("reports", "tables")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  artifacts <- character(0)
  artifacts <- c(artifacts, save_plot(plot_polarity_temporal(temporal),
                                      file.path(fig_dir, "polaridad_temporal.png")))
  artifacts <- c(artifacts, save_plot(plot_volume_temporal(temporal),
                                      file.path(fig_dir, "volumen_temporal.png")))
  artifacts <- c(artifacts, save_plot(plot_polarity_dist(sentiments),
                                      file.path(fig_dir, "distribucion_polaridad.png")))
  artifacts <- c(artifacts, save_plot(plot_emotion_freq(sentiments),
                                      file.path(fig_dir, "frecuencia_emociones.png")))

  cov <- dictionary_coverage(sentiments)
  resumen <- tibble::tibble(
    metrica = c("Mensajes analizados", "Cobertura suficiente", "Indeterminados",
                "Polaridad promedio"),
    valor = c(nrow(sentiments), sprintf("%.1f%%", 100 * cov$coverage),
              sprintf("%.1f%%", 100 * cov$indeterminate),
              sprintf("%.3f", mean(sentiments$polarity, na.rm = TRUE)))
  )
  artifacts <- c(artifacts, write_table(resumen, "resumen_general", tab_dir))
  artifacts <- c(artifacts, write_latex_macros(messages, sentiments, temporal,
                                               markov, proj_path("reports", "generated", "values.tex")))

  if (!is.null(topics_tbl)) {
    artifacts <- c(artifacts, write_table(topics_tbl, "topicos", tab_dir,
                                          caption = "T\\'erminos m\\'as probables por t\\'opico",
                                          colspec = "rp{11cm}"))
  }
  if (!is.null(markov) && length(markov$results)) {
    r <- markov$results[[1]]
    P <- r$P; states <- markov$states
    artifacts <- c(artifacts, save_plot(plot_transition_heatmap(P, states),
                                        file.path(fig_dir, "transicion_markov.png")))
    tab <- data.frame(estado = states, estacionaria = round(r$stationary, 3),
                      permanencia = round(r$residence, 2))
    artifacts <- c(artifacts, write_table(tab, "markov", tab_dir,
                                          caption = "Distribuci\\'on estacionaria y permanencia por estado"))
  }

  if (!is.null(con) && !is.na(run_id)) {
    for (a in artifacts) db_add_artifact(con, run_id, "figure_or_table", a)
  }
  artifacts
}

#' Compila el informe con pdflatex si está disponible
#' @export
render_report <- function(tex = proj_path("reports", "main.tex"), engine = "pdflatex") {
  if (!nzchar(Sys.which(engine))) {
    return(list(ok = FALSE, message = paste("Motor LaTeX no disponible:", engine)))
  }
  dir <- dirname(tex)
  old <- getwd(); on.exit(setwd(old))
  setwd(dir)
  base <- tools::file_path_sans_ext(basename(tex))
  run <- function(cmd, args) utils::capture.output(
    system2(cmd, args, stdout = TRUE, stderr = TRUE))
  # Primera pasada
  out <- run(engine, c("-interaction=nonstopmode", basename(tex)))
  # Bibliografía (si hay .bib y bibtex disponible)
  if (file.exists("references.bib") && nzchar(Sys.which("bibtex"))) {
    invisible(run("bibtex", base))
  }
  # Dos pasadas más para resolver índice, referencias y citas cruzadas
  invisible(run(engine, c("-interaction=nonstopmode", basename(tex))))
  invisible(run(engine, c("-interaction=nonstopmode", basename(tex))))
  pdf <- paste0(base, ".pdf")
  log_file <- paste0(base, ".log")
  errs <- character(0)
  if (file.exists(log_file)) {
    lg <- readLines(log_file, warn = FALSE, encoding = "UTF-8")
    errs <- grep("^!", lg, value = TRUE)
  }
  list(ok = file.exists(pdf), pdf = file.path(dir, pdf),
       warnings = if (length(errs)) errs else NA_character_,
       log = tail(out, 30))
}
