# =============================================================================
# mod_dictionary.R — gestión del diccionario emocional (V1 + importación V2)
# =============================================================================
mod_dictionary_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Diccionario emocional"),
    as_card(icon = "book",
      shiny::p(class = "as-muted", "El diccionario es editable y versionado. ",
               "Cada cambio queda registrado en la bitácora con su versión."),
      shiny::fluidRow(
        shiny::column(6, shiny::textInput(ns("search"), "Buscar término")),
        shiny::column(6, shiny::selectInput(ns("category"), "Filtrar por categoría",
                                            choices = c("(todas)" = "", EMOTION_CATEGORIES)))
      ),
      DT::DTOutput(ns("table"))
    ),
    as_card(title = "Añadir término", icon = "target",
      shiny::fluidRow(
        shiny::column(3, shiny::textInput(ns("term"), "Término")),
        shiny::column(3, shiny::selectInput(ns("new_cat"), "Categoría", EMOTION_CATEGORIES)),
        shiny::column(2, shiny::selectInput(ns("new_pol"), "Polaridad",
                                            c("positivo", "negativo", "neutro"))),
        shiny::column(2, shiny::numericInput(ns("weight"), "Peso", 1, 0.1, 10, 0.1)),
        shiny::column(2, shiny::actionButton(ns("add"), "Añadir", class = "btn-primary"))
      ),
      shiny::uiOutput(ns("feedback")))
    ,
    as_card(title = "Importar diccionario externo", icon = "upload",
      shiny::p(class = "as-muted",
        "Admite CSV, JSON o TXT. Esquema canónico: ",
        shiny::tags$code("term, category, polarity, weight, language, notes, source"),
        ". Importar crea una nueva versión; nunca sobrescribe el diccionario vigente.",
        " Al activarla, el dashboard completo (sentimientos, temporal, transiciones, avatar",
        " y evaluación) se recalcula automáticamente con las palabras del grupo."),
      shiny::fluidRow(
        shiny::column(6, shiny::fileInput(ns("dict_file"), "Archivo",
          accept = c(".csv", ".tsv", ".txt", ".json"))),
        shiny::column(3, shiny::textInput(ns("version_label"), "Etiqueta de versión",
          placeholder = "import_AAAAMMDD_HHMMSS")),
        shiny::column(3, shiny::checkboxInput(ns("activate"),
          "Activar al importar", value = TRUE))
      ),
      shiny::uiOutput(ns("mapping_ui")),
      shiny::h6("Vista previa"),
      DT::DTOutput(ns("preview")),
      shiny::fluidRow(
        shiny::column(6, shiny::actionButton(ns("validate"), "Validar",
                                             class = "btn-secondary")),
        shiny::column(6, shiny::actionButton(ns("do_import"), "Importar como versión",
                                             class = "btn-primary"))
      ),
      shiny::uiOutput(ns("validation"))
    ),
    as_card(title = "Versiones del diccionario", icon = "layers",
      shiny::uiOutput(ns("versions_ui")),
      DT::DTOutput(ns("versions_table"))
    )
  )
}

mod_dictionary_server <- function(id, cfg, con, data = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    rv <- shiny::reactiveValues(dict = NULL, version = NULL, msg = NULL,
                                raw = NULL, report = NULL, versions = NULL)

    load <- function() {
      rv$dict <- tryCatch(load_dictionary(cfg = cfg), error = function(e) NULL)
      rv$version <- tryCatch(dictionary_version(cfg = cfg), error = function(e) NA)
      rv$versions <- tryCatch(list_dictionary_versions(cfg = cfg),
                               error = function(e) NULL)
    }
    load()

    # Recálculo del dashboard cuando el diccionario activo cambia.
    recalcula_y_refresca <- function() {
      load()
      if (is.null(data)) return(invisible(NULL))
      cur <- tryCatch(dictionary_version(cfg = cfg), error = function(e) NA)
      if (identical(cur, data$dictionary_version)) return(invisible(NULL)) # sin cambios
      re <- tryCatch(
        shiny::withProgress(message = "Actualizando dashboard", value = 0.1, {
          recompute_dashboard_results(cfg = cfg, con = con,
            progress = function(stage, value) shiny::incProgress(0.25, detail = stage))
        }),
        error = function(e) {
          rv$msg <- paste("Error al recalcular el dashboard:", conditionMessage(e))
          NULL
        })
      if (!is.null(re)) {
        apply_dashboard_recompute(data, re)
        shiny::showNotification(
          sprintf("Dashboard actualizado: %d mensajes reanalizados con la versión %s del diccionario.",
                  re$n_analyzed, re$dictionary_version),
          duration = 8, type = "message")
        rv$msg <- "Diccionario activado y dashboard recalculado con el corpus completo."
      }
      invisible(NULL)
    }

    output$table <- DT::renderDT({
      d <- rv$dict; if (is.null(d)) return(NULL)
      if (nzchar(input$search %||% "")) {
        q <- normalize_term(input$search)
        d <- d[grepl(q, d$normalized_term, fixed = TRUE), ]
      }
      if (nzchar(input$category %||% "")) d <- d[d$category == input$category, ]
      DT::datatable(d[, c("term", "category", "polarity", "weight", "term_type",
                          "negation_sensitive", "source", "dictionary_version")],
                    options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE)
    })

    shiny::observeEvent(input$add, {
      shiny::req(nzchar(input$term), !is.null(rv$dict))
      rv$dict <- tryCatch(
        add_term(rv$dict, input$term, input$new_cat, input$new_pol,
                 weight = input$weight, con = con),
        error = function(e) { rv$msg <- conditionMessage(e); rv$dict })
      ver <- tryCatch(save_dictionary(rv$dict, cfg = cfg, con = con,
                                      notes = paste("alta manual:", input$term)),
                      error = function(e) { rv$msg <- conditionMessage(e); NA })
      rv$version <- ver
      rv$msg <- sprintf("Término añadido. Nueva versión del diccionario: %s", ver)
      shiny::updateTextInput(session, "term", value = "")
      load()
    })

    output$feedback <- shiny::renderUI({
      v <- rv$version
      shiny::tagList(
        shiny::p(shiny::strong("Versión actual: "), ifelse(is.na(v), "—", v)),
        if (!is.null(rv$msg)) shiny::div(class = "alert alert-info", rv$msg))
    })

    # --- Importación ---------------------------------------------------------
    shiny::observeEvent(input$dict_file, {
      f <- input$dict_file
      shiny::req(f)
      fmt <- tools::file_ext(f$name)
      rv$raw <- tryCatch(read_external_dictionary(f$datapath, format = fmt),
                         error = function(e) {
                           rv$msg <- paste("No se pudo leer el archivo:", conditionMessage(e))
                           NULL
                         })
      rv$report <- NULL
    })

    output$mapping_ui <- shiny::renderUI({
      shiny::req(rv$raw)
      cols <- names(rv$raw)
      det <- detect_dictionary_columns(rv$raw)
      mk <- function(input_id, label, canon) {
        shiny::selectInput(ns(input_id), label,
          choices = c("— no usar —" = "", stats::setNames(cols, cols)),
          selected = det[[canon]] %||% "")
      }
      shiny::tagList(
        shiny::h6("Mapeo de columnas"),
        shiny::fluidRow(
          shiny::column(3, mk("map_term", "Término (obligatorio)", "term")),
          shiny::column(3, mk("map_category", "Categoría (obligatorio)", "category")),
          shiny::column(3, mk("map_polarity", "Polaridad", "polarity")),
          shiny::column(3, mk("map_weight", "Peso", "weight"))
        )
      )
    })

    output$preview <- DT::renderDT({
      shiny::req(rv$raw)
      DT::datatable(utils::head(rv$raw, 8),
                    options = list(pageLength = 5, scrollX = TRUE), rownames = FALSE)
    })

    current_mapping <- function() {
      m <- c(term = input$map_term %||% "", category = input$map_category %||% "",
             polarity = input$map_polarity %||% "", weight = input$map_weight %||% "")
      m[nzchar(m)]
    }

    shiny::observeEvent(input$validate, {
      shiny::req(rv$raw)
      mapped <- tryCatch(map_dictionary_columns(rv$raw, current_mapping()),
                         error = function(e) { rv$msg <- conditionMessage(e); NULL })
      rv$report <- tryCatch(validate_external_dictionary(mapped),
                            error = function(e) {
                              list(ok = FALSE, issues = conditionMessage(e),
                                   warnings = character(0), n_total = nrow(mapped),
                                   n_valid = 0L, valid = NULL, invalid = NULL,
                                   duplicates = 0L, unknown_categories = character(0))
                            })
    })

    output$validation <- shiny::renderUI({
      r <- rv$report
      if (is.null(r)) return(NULL)
      cls <- if (isTRUE(r$ok)) "alert alert-success" else "alert alert-danger"
      shiny::div(class = cls,
        shiny::p(shiny::strong(
          sprintf("Filas leídas: %d · válidas: %d · duplicadas: %d",
                  r$n_total, r$n_valid, r$duplicates))),
        if (length(r$unknown_categories))
          shiny::p("Categorías desconocidas: ",
                   paste(r$unknown_categories, collapse = ", ")),
        if (length(r$issues))
          shiny::tags$ul(lapply(r$issues, shiny::tags$li)),
        if (length(r$warnings))
          shiny::tags$ul(lapply(r$warnings, shiny::tags$li))
      )
    })

    shiny::observeEvent(input$do_import, {
      shiny::req(rv$raw)
      rv$report <- rv$report %||% {
        mapped <- map_dictionary_columns(rv$raw, current_mapping())
        validate_external_dictionary(mapped)
      }
      if (!isTRUE(rv$report$ok)) {
        rv$msg <- "El diccionario no es válido: corrija los errores antes de importar."
        return()
      }
      label <- trimws(input$version_label %||% "")
      res <- tryCatch(
        import_external_dictionary(rv$raw, label = if (nzchar(label)) label else NULL,
                                   cfg = cfg, con = con, mapping = current_mapping(),
                                   activate = isTRUE(input$activate)),
        error = function(e) { rv$msg <- conditionMessage(e); NULL })
      if (!is.null(res)) {
        rv$msg <- sprintf("Importado como versión «%s» (%d términos)%s.",
                          res$version, nrow(res$dictionary),
                          if (isTRUE(res$activated)) "; activado" else "")
        if (isTRUE(res$activated)) recalcula_y_refresca() else load()
      }
    })

    # --- Versiones -----------------------------------------------------------
    output$versions_ui <- shiny::renderUI({
      v <- rv$versions
      if (is.null(v) || !nrow(v)) return(shiny::p(class = "as-muted", "Sin versiones guardadas."))
      shiny::tagList(
        shiny::selectInput(ns("active_version"), "Seleccionar versión",
          choices = stats::setNames(v$path,
            sprintf("%s · %d términos%s", v$version, v$n_terms,
                    ifelse(v$active, " (activo)", "")))),
        shiny::actionButton(ns("activate_version"), "Activar versión",
                            class = "btn-secondary")
      )
    })

    output$versions_table <- DT::renderDT({
      v <- rv$versions
      if (is.null(v) || !nrow(v)) return(NULL)
      DT::datatable(v[, c("version", "n_terms", "hash", "active", "modified")],
                    options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)
    })

    shiny::observeEvent(input$activate_version, {
      shiny::req(input$active_version)
      ver <- tryCatch(
        activate_dictionary_version(input$active_version, cfg = cfg, con = con,
                                    note = "activación manual desde dashboard"),
        error = function(e) { rv$msg <- conditionMessage(e); NA })
      rv$msg <- sprintf("Versión activada. Hash activo: %s", ver)
      recalcula_y_refresca()
    })
  })
}
