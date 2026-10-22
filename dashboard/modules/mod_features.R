# =============================================================================
# mod_features.R — V2: características lingüísticas superficiales
# =============================================================================
mod_features_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "V2 · Características lingüísticas"),
    shiny::uiOutput(ns("kpis")),
    as_card(title = "Evolución mensual", icon = "activity",
      shiny::selectInput(ns("metric"), "Métrica",
        choices = c(
          "Palabras por mensaje" = "n_words",
          "Longitud media de palabra" = "mean_word_len",
          "Signos de interrogación" = "n_questions",
          "Signos de exclamación" = "n_exclamations",
          "Emojis por mensaje" = "n_emojis",
          "Proporción de mayúsculas" = "upper_ratio",
          "Palabras únicas (proporción)" = "unique_ratio",
          "Repeticiones de caracteres" = "n_repeated_chars"
        )),
      as_echart(ns("line"), "340px")
    ),
    shiny::fluidRow(
      shiny::column(6, as_card(title = "Distribución de longitud (caracteres)",
        icon = "grid", as_echart(ns("hist"), "340px"))),
      shiny::column(6, as_card(title = "Resumen descriptivo", icon = "list",
        DT::DTOutput(ns("table"))))
    )
  )
}

mod_features_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    feats <- shiny::reactive(data$v2_features$features)

    output$kpis <- shiny::renderUI({
      f <- feats()
      if (is.null(f) || !nrow(f)) {
        return(shiny::p(class = "as-muted",
          "No hay resultados V2. Ejecute scripts/05f_features.R."))
      }
      as_kpi_grid(
        as_kpi(nrow(f), "Mensajes", icon = "chat", raw = nrow(f)),
        as_kpi(mean(f$n_words), "Palabras / mensaje", icon = "file",
               variant = "is-cyan", raw = mean(f$n_words), decimals = 1),
        as_kpi(100 * mean(f$n_emojis > 0), "Con emoji", icon = "smile",
               variant = "is-pink", raw = 100 * mean(f$n_emojis > 0),
               decimals = 1, suffix = "%"),
        as_kpi(100 * mean(f$n_questions > 0), "Con pregunta", icon = "search",
               variant = "is-green", raw = 100 * mean(f$n_questions > 0),
               decimals = 1, suffix = "%")
      )
    })

    monthly <- shiny::reactive({
      f <- feats(); if (is.null(f) || !nrow(f)) return(tibble::tibble())
      features_by_period(f, f$date, period = "month")
    })

    as_render_echart(session, ns("line"), {
      d <- monthly(); if (!nrow(d)) return(NULL)
      metric <- input$metric %||% "n_words"
      if (!metric %in% names(d)) return(NULL)
      opt_line(d$period, stats::setNames(list(d[[metric]]), metric),
               title = "Media mensual", x_name = "Mes", y_name = "Media")
    })

    as_render_echart(session, ns("hist"), {
      f <- feats(); if (is.null(f) || !nrow(f)) return(NULL)
      br <- c(0, 20, 40, 60, 80, 120, 200, 300, 500, Inf)
      h <- graphics::hist(f$n_chars, breaks = br, plot = FALSE)
      lab <- c("0-20", "21-40", "41-60", "61-80", "81-120", "121-200",
               "201-300", "301-500", ">500")
      opt_vbar(lab, h$counts, title = "Distribución de caracteres",
               y_name = "Mensajes")
    })

    output$table <- DT::renderDT({
      f <- feats(); if (is.null(f) || !nrow(f)) return(NULL)
      s <- feature_summary(f)
      s[, -1] <- lapply(s[, -1], function(x) round(x, 2))
      DT::datatable(s, options = list(pageLength = 18, scrollX = TRUE),
                    rownames = FALSE)
    })
  })
}
