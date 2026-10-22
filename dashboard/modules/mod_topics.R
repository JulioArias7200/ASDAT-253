# =============================================================================
# mod_topics.R — tópicos de conversación (ECharts)
# =============================================================================
mod_topics_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Temas de conversación"),
    as_card(icon = "layers",
      shiny::p(class = "as-muted", "Agrupaciones exploratorias (LDA sobre conteos). ",
               "No son categorías objetivas."),
      shiny::selectInput(ns("topic"), "Tópico", choices = NULL)
    ),
    as_card(title = "Términos más probables", icon = "target",
            as_echart(ns("words"), "380px")),
    as_card(title = "Resumen de tópicos", icon = "list",
            DT::DTOutput(ns("table")))
  )
}

mod_topics_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    tt <- shiny::reactive(data$topics$topics)
    shiny::observe({
      t <- tt()
      if (!is.null(t)) shiny::updateSelectInput(session, "topic", choices = t$topic)
    })

    as_render_echart(session, ns("words"), {
      tt <- tt()
      if (is.null(tt) || is.null(input$topic)) return(NULL)
      sel <- tt[tt$topic == as.integer(input$topic), ]
      if (!nrow(sel)) return(NULL)
      w <- strsplit(sel$top_words[1], ", ")[[1]]
      d <- data.frame(word = w, n = rev(seq_along(w)))
      opt_hbar(d, "word", "n", title = paste("Tópico", input$topic))
    })

    output$table <- DT::renderDT({
      t <- tt()
      if (is.null(t)) return(NULL)
      DT::datatable(t, options = list(pageLength = 5, dom = "tp"), rownames = FALSE)
    })
  })
}
