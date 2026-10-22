# =============================================================================
# mod_audit.R — bitácora de ejecuciones, filtros y comparación (V1 + V2)
# =============================================================================
mod_audit_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Bitácora de ejecuciones"),
    as_card(icon = "list",
      shiny::fluidRow(
        shiny::column(3, shiny::selectInput(ns("action"), "Acción", choices = NULL)),
        shiny::column(2, shiny::selectInput(ns("status"), "Estado",
          choices = c("(todos)" = "", "completed", "started", "failed", "interrupted",
                      "running"))),
        shiny::column(2, shiny::dateInput(ns("date_from"), "Desde", value = NULL)),
        shiny::column(2, shiny::dateInput(ns("date_to"), "Hasta", value = NULL)),
        shiny::column(2, shiny::numericInput(ns("n"), "Últimos", 200, 10, 2000, 10)),
        shiny::column(1, shiny::actionButton(ns("refresh"), "Ver",
                                             icon = shiny::icon("rotate")))
      )
    ),
    as_card(title = "Eventos", icon = "activity", DT::DTOutput(ns("events"))),
    as_card(title = "Ejecuciones del pipeline", icon = "database",
            DT::DTOutput(ns("runs"))),
    as_card(title = "Comparar dos ejecuciones", icon = "shuffle",
      shiny::p(class = "as-muted",
        "Compara parámetros, diccionario usado y resultados procesados entre dos ",
        "ejecuciones. Las diferencias se marcan con «≠»."),
      shiny::fluidRow(
        shiny::column(6, shiny::selectInput(ns("run_a"), "Ejecución A", choices = NULL)),
        shiny::column(6, shiny::selectInput(ns("run_b"), "Ejecución B", choices = NULL))
      ),
      DT::DTOutput(ns("compare"))
    )
  )
}

mod_audit_server <- function(id, con) {
  shiny::moduleServer(id, function(input, output, session) {
    events <- shiny::reactive({
      input$refresh
      if (is.null(con)) return(NULL)
      audit_recent(con, input$n %||% 200)
    })

    shiny::observe({
      e <- events(); if (is.null(e)) return(invisible(NULL))
      shiny::updateSelectInput(session, "action",
                               choices = c("(todas)" = "", sort(unique(e$action))))
    })

    filtered_events <- shiny::reactive({
      e <- events(); if (is.null(e)) return(NULL)
      if (nzchar(input$action %||% "")) e <- e[e$action == input$action, ]
      if (nzchar(input$status %||% "")) e <- e[e$status == input$status, ]
      d <- as.Date(substr(e$timestamp, 1, 10))
      if (!is.null(input$date_from)) e <- e[!is.na(d) & d >= input$date_from, ]
      if (!is.null(input$date_to)) e <- e[!is.na(d) & d <= input$date_to, ]
      e
    })

    output$events <- DT::renderDT({
      e <- filtered_events(); if (is.null(e) || !nrow(e)) return(NULL)
      DT::datatable(e, options = list(pageLength = 10, scrollX = TRUE),
                    rownames = FALSE)
    })

    runs <- shiny::reactive({
      input$refresh
      if (is.null(con)) return(NULL)
      DBI::dbGetQuery(con, "SELECT run_id, stage, status, corpus_id, batch_id,
                            started_at, finished_at, duration_s, code_version,
                            dictionary_version, params_json, n_processed,
                            n_discarded, warnings, errors
                           FROM pipeline_runs
                           ORDER BY run_id DESC LIMIT 200")
    })

    output$runs <- DT::renderDT({
      d <- runs(); if (is.null(d) || !nrow(d)) return(NULL)
      if (nzchar(input$status %||% "")) d <- d[d$status == input$status, ]
      DT::datatable(d[, c("run_id", "stage", "status", "n_processed",
                          "dictionary_version", "started_at", "duration_s")],
                    options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
    })

    shiny::observe({
      d <- runs(); if (is.null(d) || !nrow(d)) return(invisible(NULL))
      ch <- stats::setNames(d$run_id,
        sprintf("#%s · %s · %s · %s", d$run_id, d$stage, d$status,
                substr(d$started_at, 1, 16)))
      shiny::updateSelectInput(session, "run_a", choices = ch,
                               selected = d$run_id[[1]])
      shiny::updateSelectInput(session, "run_b", choices = ch,
                               selected = d$run_id[[min(2, nrow(d))]])
    })

    output$compare <- DT::renderDT({
      d <- runs()
      if (is.null(d) || !nrow(d) || is.null(input$run_a) || is.null(input$run_b)) {
        return(NULL)
      }
      a <- d[d$run_id == as.integer(input$run_a), , drop = FALSE]
      b <- d[d$run_id == as.integer(input$run_b), , drop = FALSE]
      if (!nrow(a) || !nrow(b)) return(NULL)
      fields <- setdiff(names(d), "run_id")
      norm <- function(x) ifelse(is.na(x), "", as.character(x))
      out <- tibble::tibble(
        campo = fields,
        ejecucion_A = vapply(fields, function(f) norm(a[[f]][[1]]), character(1)),
        ejecucion_B = vapply(fields, function(f) norm(b[[f]][[1]]), character(1))
      )
      out$diferencia <- ifelse(out$ejecucion_A == out$ejecucion_B, "", "≠")
      DT::datatable(out, options = list(dom = "t", pageLength = 20, scrollX = TRUE),
                    rownames = FALSE)
    })
  })
}
