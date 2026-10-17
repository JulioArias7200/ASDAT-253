# =============================================================================
# mod_audit.R — bitácora de ejecuciones y trazabilidad
# =============================================================================
mod_audit_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Bitácora de ejecuciones"),
    as_card(icon = "list",
      shiny::fluidRow(
        shiny::column(4, shiny::selectInput(ns("action"), "Acción", choices = NULL)),
        shiny::column(4, shiny::numericInput(ns("n"), "Últimos eventos", 100, 10, 1000, 10)),
        shiny::column(4, shiny::actionButton(ns("refresh"), "Actualizar", icon = shiny::icon("rotate")))
      )
    ),
    as_card(title = "Eventos", icon = "activity", DT::DTOutput(ns("events"))),
    as_card(title = "Ejecuciones del pipeline", icon = "database", DT::DTOutput(ns("runs")))
  )
}

mod_audit_server <- function(id, con) {
  shiny::moduleServer(id, function(input, output, session) {
    events <- shiny::reactive({
      input$refresh
      if (is.null(con)) return(NULL)
      audit_recent(con, input$n)
    })
    shiny::observe({
      e <- events(); if (is.null(e)) return(invisible(NULL))
      shiny::updateSelectInput(session, "action",
                               choices = c("(todas)" = "", sort(unique(e$action))))
    })
    output$events <- DT::renderDT({
      e <- events(); if (is.null(e)) return(NULL)
      if (nzchar(input$action)) e <- e[e$action == input$action, ]
      DT::datatable(e, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
    })
    output$runs <- DT::renderDT({
      input$refresh
      if (is.null(con)) return(NULL)
      d <- DBI::dbGetQuery(con, "SELECT run_id, stage AS action, status, n_processed,
                            n_discarded, warnings, errors, finished_at FROM pipeline_runs
                            ORDER BY run_id DESC LIMIT 50")
      DT::datatable(d, options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
    })
  })
}
