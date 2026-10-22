# =============================================================================
# mod_import.R — carga y validación de un corpus Telegram
# =============================================================================
mod_import_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Cargar corpus"),
    as_card(icon = "upload",
      shiny::p(class = "as-muted", "Sube un export JSON de Telegram Desktop ",
               "(objeto JSON con el arreglo 'messages'). El sistema valida antes de guardar."),
      shiny::fileInput(ns("json"), "Export JSON de Telegram", accept = ".json"),
      shiny::actionButton(ns("preview"), "Analizar archivo", icon = shiny::icon("magnifying-glass")),
      shiny::hr(),
      shiny::uiOutput(ns("summary"))
    ),
    as_card(title = "Vista previa", icon = "list", DT::DTOutput(ns("preview_tbl"))),
    as_card(title = "Validación", icon = "target", DT::DTOutput(ns("validation"))),
    as_card(icon = "database",
      shiny::actionButton(ns("confirm"), "Confirmar e importar a la base",
                          icon = shiny::icon("database"), class = "btn-primary"),
      shiny::uiOutput(ns("result")))
  )
}

mod_import_server <- function(id, con, cfg) {
  shiny::moduleServer(id, function(input, output, session) {
    state <- shiny::reactiveValues(parsed = NULL, path = NULL, name = NULL)

    shiny::observeEvent(input$preview, {
      shiny::req(input$json)
      state$path <- input$json$datapath
      state$name <- input$json$name
      state$parsed <- tryCatch(
        import_telegram_json(state$path, corpus_id = 0L, batch_id = 0L, cfg = cfg,
                             source_file = state$name),
        error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
    })

    output$summary <- shiny::renderUI({
      p <- state$parsed; shiny::req(p)
      r <- p$report
      as_kpi_grid(
        as_kpi(r$n_total, "Mensajes crudos", icon = "chat", raw = r$n_total),
        as_kpi(r$n_imported, "Importables", icon = "upload", raw = r$n_imported, variant = "is-green"),
        as_kpi(r$n_rejected, "Rechazados", icon = "activity", raw = r$n_rejected, variant = "is-pink"),
        as_kpi(r$n_service, "Servicio / sin texto", icon = "list", raw = r$n_service, variant = "is-cyan")
      )
    })

    output$preview_tbl <- DT::renderDT({
      p <- state$parsed; shiny::req(p)
      d <- utils::head(p$messages, 15)
      show <- d[, c("message_id", "timestamp_utc", "sender_name", "text_original", "media_type")]
      names(show) <- c("ID", "Fecha (UTC)", "Emisor", "Texto", "Media")
      DT::datatable(show, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
    })

    output$validation <- DT::renderDT({
      p <- state$parsed; shiny::req(p)
      v <- validate_messages(p$messages)
      if (!nrow(v$issues)) return(DT::datatable(data.frame(resultado = "Sin incidencias"), rownames = FALSE))
      d <- data.frame(tipo = v$issues$type, detalle = v$issues$detail, severidad = v$issues$severity)
      DT::datatable(d, options = list(pageLength = 8, dom = "tp"), rownames = FALSE)
    })

    shiny::observeEvent(input$confirm, {
      shiny::req(state$parsed, state$path)
      if (is.null(con)) { shiny::showNotification("Sin conexión a la base de datos", type = "error"); return() }
      dest <- file.path(proj_path("data/raw"), state$name)
      dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
      ok <- file.copy(state$path, dest, overwrite = TRUE)
      res <- tryCatch(
        persist_telegram_import(dest, con, cfg,
                                json_rel = file.path("data/raw", state$name)),
        error = function(e) { shiny::showNotification(conditionMessage(e), type = "error"); NULL })
      output$result <- shiny::renderUI({
        shiny::req(res)
        shiny::div(class = "alert alert-success",
          sprintf("Importación completada: %d mensajes insertados (corpus %d, lote %d).%s",
                  res$n_inserted, res$corpus_id, res$batch_id,
                  if (!ok) " (aviso: no se pudo copiar el archivo a data/raw)" else ""))
      })
      if (!is.null(res)) shiny::showNotification("Importación registrada en la bitácora", type = "message")
    })
  })
}
