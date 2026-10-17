# =============================================================================
# mod_temporal.R — tendencias temporales (ECharts)
# =============================================================================
mod_temporal_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Tendencias temporales"),
    as_card(icon = "activity",
      shiny::fluidRow(
        shiny::column(4, shiny::radioButtons(ns("gran"), "Granularidad",
                      c("Diaria" = "daily", "Semanal" = "weekly", "Mensual" = "monthly"),
                      inline = TRUE)),
        shiny::column(4, shiny::sliderInput(ns("ma"), "Media móvil (períodos)", 1, 30, 7)),
        shiny::column(4, shiny::selectInput(ns("emo"), "Emoción a graficar",
                      c("(ninguna)" = "", EMOTION_CATEGORIES)))
      )
    ),
    as_card(title = "Evolución de la polaridad", icon = "activity",
            as_echart(ns("polarity"), "380px")),
    as_card(title = "Volumen de mensajes", icon = "chat",
            as_echart(ns("volume"), "280px"))
  )
}

mod_temporal_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    tbl <- shiny::reactive({
      key <- switch(input$gran, daily = "daily", weekly = "weekly", monthly = "monthly")
      t <- data$temporal[[key]]
      if (is.null(t)) return(NULL)
      rolling_polarity(t, window = input$ma)
    })

    as_render_echart(session, ns("polarity"), {
      t <- tbl(); if (is.null(t)) return(NULL)
      series <- list("Polaridad" = t$polarity_mean)
      if ("polarity_ma" %in% names(t)) series[["Media móvil"]] <- t$polarity_ma
      if (nzchar(input$emo) && input$emo %in% names(t)) {
        series[[input$emo]] <- t[[input$emo]]
      }
      opt_line(t$period, series, y_name = "Polaridad", area = TRUE)
    })

    as_render_echart(session, ns("volume"), {
      t <- tbl(); if (is.null(t)) return(NULL)
      opt_vbar(t$period, t$n_messages, y_name = "Mensajes")
    })
  })
}
