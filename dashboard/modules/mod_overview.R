# =============================================================================
# mod_overview.R — resumen general (KPIs + ECharts)
# =============================================================================
mod_overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Panorama general"),
    shiny::uiOutput(ns("metrics")),
    shiny::fluidRow(
      shiny::column(6, as_card(title = "Distribución de polaridad", icon = "pie",
        as_echart(ns("dist"), "340px"))),
      shiny::column(6, as_card(title = "Emociones más frecuentes", icon = "heart",
        as_echart(ns("emo"), "340px")))
    ),
    shiny::fluidRow(
      shiny::column(7, as_card(title = "Volumen mensual de la conversación", icon = "activity",
        as_echart(ns("monthly"), "320px"))),
      shiny::column(5, as_card(title = "Emojis más usados", icon = "smile",
        as_echart(ns("emoji"), "320px")))
    ),
    shiny::div(class = "as-section-title", "Estado de la última ejecución"),
    as_card(icon = "database", DT::DTOutput(ns("last_run")))
  )
}

mod_overview_server <- function(id, data, con) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    output$metrics <- shiny::renderUI({
      s <- data$sentiments; m <- data$messages
      n_import <- if (!is.null(m)) nrow(m) else 0
      n_analyzed <- if (!is.null(s)) sum(s$evidence_level != "sin_evidencia") else 0
      n_pos <- if (!is.null(s)) sum(s$polarity_label == "positivo") else 0
      n_neg <- if (!is.null(s)) sum(s$polarity_label == "negativo") else 0
      cov <- if (!is.null(data$evaluation)) 100 * data$evaluation$coverage$coverage else 0
      n_send <- if (!is.null(m)) length(unique(m$sender_id)) else 0
      as_kpi_grid(
        as_kpi(n_import, "Mensajes importados", icon = "chat", variant = "",
               raw = n_import, sub = sprintf("%s emisores", format(n_send, big.mark = ".", decimal.mark = ","))),
        as_kpi(n_analyzed, "Con evidencia", icon = "target", variant = "is-cyan",
               raw = n_analyzed, sub = "nivel suficiente"),
        as_kpi(cov, "Cobertura", icon = "percent", variant = "is-pink",
               raw = cov, decimals = 1, suffix = "%", sub = "del diccionario"),
        as_kpi(n_pos - n_neg, "Balance +/−", icon = "activity", variant = "is-green",
               raw = n_pos - n_neg,
               sub = sprintf("%s pos · %s neg",
                             format(n_pos, big.mark = ".", decimal.mark = ","),
                             format(n_neg, big.mark = ".", decimal.mark = ",")))
      )
    })

    as_render_echart(session, ns("dist"), {
      s <- data$sentiments
      if (is.null(s)) return(NULL)
      d <- as.data.frame(table(label = s$polarity_label))
      d <- d[d$Freq > 0, ]
      opt_donut(d, "label", "Freq", palette = c(
        positivo = "#10b981", negativo = "#ef4444", neutro = "#64748b", indeterminado = "#cbd5e1"))
    })

    as_render_echart(session, ns("emo"), {
      s <- data$sentiments
      if (is.null(s)) return(NULL)
      tot <- emotion_totals(s)
      d <- data.frame(cat = names(tot), n = as.numeric(tot))
      d <- d[d$n > 0, ]
      opt_hbar(d, "cat", "n")
    })

    as_render_echart(session, ns("monthly"), {
      t <- data$temporal
      if (is.null(t) || is.null(t$monthly)) return(NULL)
      opt_vbar(t$monthly$period, t$monthly$n_messages, y_name = "Mensajes")
    })

    as_render_echart(session, ns("emoji"), {
      m <- data$messages
      if (is.null(m)) return(NULL)
      cnt <- emoji_counts(m)
      if (!length(cnt)) return(NULL)
      d <- utils::head(as.data.frame(cnt), 10)
      names(d) <- c("emoji", "n")
      d$label <- emoji_shortcode(as.character(d$emoji))
      opt_hbar(d, "label", "n")
    })

    output$last_run <- DT::renderDT({
      if (is.null(con)) return(NULL)
      d <- audit_recent(con, 10)
      DT::datatable(d, options = list(pageLength = 5, scrollX = TRUE, dom = "tp"),
                    rownames = FALSE)
    })
  })
}
