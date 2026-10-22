# =============================================================================
# mod_dictionary.R — gestión del diccionario emocional
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
  )
}

mod_dictionary_server <- function(id, cfg, con) {
  shiny::moduleServer(id, function(input, output, session) {
    rv <- shiny::reactiveValues(dict = NULL, version = NULL, msg = NULL)
    load <- function() {
      rv$dict <- tryCatch(load_dictionary(cfg = cfg), error = function(e) NULL)
      rv$version <- tryCatch(dictionary_version(cfg = cfg), error = function(e) NA)
    }
    load()

    output$table <- DT::renderDT({
      d <- rv$dict; if (is.null(d)) return(NULL)
      if (nzchar(input$search)) {
        q <- normalize_term(input$search)
        d <- d[grepl(q, d$normalized_term, fixed = TRUE), ]
      }
      if (nzchar(input$category)) d <- d[d$category == input$category, ]
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
    })

    output$feedback <- shiny::renderUI({
      v <- rv$version
      shiny::tagList(
        shiny::p(shiny::strong("Versión actual: "), ifelse(is.na(v), "—", v)),
        if (!is.null(rv$msg)) shiny::div(class = "alert alert-info", rv$msg))
    })
  })
}
