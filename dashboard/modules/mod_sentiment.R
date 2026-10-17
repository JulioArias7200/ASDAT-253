# =============================================================================
# mod_sentiment.R — explorador de sentimientos con filtros (KPIs + ECharts)
# =============================================================================
mod_sentiment_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Explorador de sentimientos"),
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = 320,
        shiny::selectizeInput(ns("emotions"), "Emociones (incluir)",
                              choices = EMOTION_CATEGORIES, multiple = TRUE),
        shiny::dateRangeInput(ns("dates"), "Período"),
        shiny::checkboxGroupInput(ns("polarity"), "Polaridad",
                                  choices = c("positivo", "negativo", "neutro", "indeterminado"),
                                  selected = c("positivo", "negativo", "neutro")),
        shiny::selectInput(ns("evidence"), "Evidencia",
                           choices = c("todas", "suficiente", "insuficiente", "sin_evidencia"),
                           selected = "todas"),
        shiny::downloadButton(ns("dl"), "Exportar resultados filtrados", class = "btn-primary")
      ),
      shiny::uiOutput(ns("kpis")),
      shiny::fluidRow(
        shiny::column(6, as_card(title = "Emociones (filtradas)", icon = "heart",
                                 as_echart(ns("emo"), "330px"))),
        shiny::column(6, as_card(title = "Polaridad (filtrada)", icon = "pie",
                                 as_echart(ns("pol"), "330px")))
      ),
      as_card(title = "Mensajes asociados a los filtros", icon = "list",
              DT::DTOutput(ns("table")))
    )
  )
}

mod_sentiment_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    s <- data$sentiments; m <- data$messages
    if (!is.null(m)) {
      rng <- range(as.Date(substr(m$timestamp_utc, 1, 10)), na.rm = TRUE)
      shiny::updateDateRangeInput(session, "dates", start = rng[1], end = rng[2],
                                  min = rng[1], max = rng[2])
    }

    filtered <- shiny::reactive({
      ev <- if (identical(input$evidence, "todas")) NULL else input$evidence
      filter_messages(data, emotions = input$emotions, date_range = input$dates,
                      polarities = input$polarity, evidence = ev)
    })

    output$kpis <- shiny::renderUI({
      df <- filtered()
      n <- nrow(df)
      n_pos <- sum(df$polarity_label == "positivo")
      n_neg <- sum(df$polarity_label == "negativo")
      cov <- if (n) 100 * mean(df$evidence_level == "suficiente") else 0
      as_kpi_grid(
        as_kpi(n, "Mensajes filtrados", icon = "chat", raw = n, variant = ""),
        as_kpi(n_pos, "Positivos", icon = "smile", raw = n_pos, variant = "is-green"),
        as_kpi(n_neg, "Negativos", icon = "activity", raw = n_neg, variant = "is-pink"),
        as_kpi(cov, "Cobertura", icon = "percent", raw = cov, decimals = 1,
               suffix = "%", variant = "is-cyan")
      )
    })

    as_render_echart(session, ns("emo"), {
      df <- filtered()
      if (!nrow(df)) return(NULL)
      tot <- emotion_totals(df)
      d <- data.frame(cat = names(tot), n = as.numeric(tot)); d <- d[d$n > 0, ]
      if (!nrow(d)) return(NULL)
      opt_hbar(d, "cat", "n")
    })

    as_render_echart(session, ns("pol"), {
      df <- filtered()
      if (!nrow(df)) return(NULL)
      d <- as.data.frame(table(label = df$polarity_label)); d <- d[d$Freq > 0, ]
      if (!nrow(d)) return(NULL)
      opt_donut(d, "label", "Freq", palette = c(
        positivo = "#10b981", negativo = "#ef4444", neutro = "#64748b", indeterminado = "#cbd5e1"))
    })

    output$table <- DT::renderDT({
      df <- filtered()
      if (!nrow(df)) return(DT::datatable(data.frame(mensaje = "Sin resultados")))
      show <- df[, c("message_id", "ts", "sender_name", "text_original",
                     "polarity_label", "dominant_emotion", "evidence_level", "polarity")]
      names(show) <- c("ID", "Fecha", "Emisor", "Texto", "Polaridad", "Emoción", "Evidencia", "Score")
      DT::datatable(show, options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE)
    })
    output$dl <- shiny::downloadHandler(
      filename = function() paste0("sentimientos_filtrados_", Sys.Date(), ".csv"),
      content = function(file) readr::write_csv(filtered(), file)
    )
  })
}
