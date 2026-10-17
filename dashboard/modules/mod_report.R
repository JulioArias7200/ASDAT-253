# =============================================================================
# mod_report.R — generación de artefactos e informe
# =============================================================================
mod_report_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Informe y artefactos"),
    as_card(icon = "file",
      shiny::p(class = "as-muted", "Genera figuras, tablas CSV/LaTeX, macros y, ",
               "si hay motor LaTeX disponible, el PDF completo."),
      shiny::actionButton(ns("generate"), "Generar artefactos",
                          icon = shiny::icon("file-lines"), class = "btn-primary"),
      shiny::actionButton(ns("compile"), "Compilar informe", icon = shiny::icon("file-pdf")),
      shiny::hr(),
      shiny::uiOutput(ns("status"))
    ),
    as_card(title = "Artefactos generados", icon = "list", DT::DTOutput(ns("artifacts")))
  )
}

mod_report_server <- function(id, data, con, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    rv <- shiny::reactiveValues(artifacts = character(0), msg = NULL)

    shiny::observeEvent(input$generate, {
      shiny::withProgress(message = "Generando artefactos...", value = 0.15, {
        res <- tryCatch({
          messages <- read_rds(processed_path("messages_clean.rds"))
          sentiments <- data$sentiments
          temporal <- data$temporal
          topics <- data$topics
          shiny::incProgress(0.35)
          a1 <- generate_report_artifacts(messages, sentiments, temporal$daily,
                   topics_tbl = if (!is.null(topics)) topics$topics else NULL,
                   data$markov, cfg = cfg, con = con, run_id = NA)
          shiny::incProgress(0.25)
          a2 <- generate_extra_figures(messages, sentiments, temporal, topics)
          a3 <- generate_extra_tables(messages, sentiments, temporal)
          a4 <- write_report_stats(messages, sentiments, temporal, topics, data$markov)
          c(a1, a2, a3, a4)
        }, error = function(e) { rv$msg <- conditionMessage(e); character(0) })
        rv$artifacts <- res
      })
    })

    shiny::observeEvent(input$compile, {
      comp <- tryCatch(render_report(), error = function(e) list(ok = FALSE, message = conditionMessage(e)))
      rv$msg <- if (isTRUE(comp$ok)) paste("PDF generado:", comp$pdf) else
        (comp$message %||% "No se pudo compilar")
    })

    output$status <- shiny::renderUI({
      if (is.null(rv$msg)) return(NULL)
      cls <- if (grepl("PDF generado", rv$msg)) "alert alert-success" else "alert alert-warning"
      shiny::div(class = cls, rv$msg)
    })
    output$artifacts <- DT::renderDT({
      if (!length(rv$artifacts))
        return(DT::datatable(data.frame(sin_artefactos = "Pulsa 'Generar artefactos'"), rownames = FALSE))
      d <- data.frame(archivo = basename(rv$artifacts), ruta = rv$artifacts)
      DT::datatable(d, options = list(pageLength = 20, scrollX = TRUE), rownames = FALSE)
    })
  })
}
