# =============================================================================
# mod_markov.R — transiciones de estado (ECharts)
# =============================================================================
mod_markov_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Transiciones de estado (Markov)"),
    as_card(icon = "shuffle",
      shiny::p(class = "as-muted", "Modela el flujo cronológico del chat, ",
               "no cambios emocionales individuales.")),
    shiny::fluidRow(
      shiny::column(7, as_card(title = "Matriz de transición", icon = "grid",
                               as_echart(ns("matrix"), "380px"))),
      shiny::column(5, as_card(title = "Distribución estacionaria", icon = "pie",
                               as_echart(ns("stationary"), "380px")))
    ),
    shiny::div(class = "as-section-title", "Métricas de la cadena"),
    as_card(icon = "activity", DT::DTOutput(ns("metrics")))
  )
}

mod_markov_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    as_render_echart(session, ns("matrix"), {
      mk <- data$markov
      if (is.null(mk)) return(NULL)
      r <- mk$results[[1]]
      opt_heatmap(mk$states, r$P)
    })

    as_render_echart(session, ns("stationary"), {
      mk <- data$markov
      if (is.null(mk)) return(NULL)
      r <- mk$results[[1]]
      d <- data.frame(estado = names(r$stationary), pi = as.numeric(r$stationary))
      d <- d[d$pi > 0, ]
      opt_donut(d, "estado", "pi", palette = c(
        positivo = "#10b981", negativo = "#ef4444", neutro = "#64748b"))
    })

    output$metrics <- DT::renderDT({
      mk <- data$markov
      if (is.null(mk)) return(NULL)
      r <- mk$results[[1]]
      d <- data.frame(Estado = mk$states,
                      Estacionaria = round(as.numeric(r$stationary), 3),
                      Permanencia = round(as.numeric(r$residence), 2),
                      `Recuperación desde negativo` = round(r$recovery, 3))
      DT::datatable(d, options = list(pageLength = 6, dom = "t"), rownames = FALSE)
    })
  })
}
