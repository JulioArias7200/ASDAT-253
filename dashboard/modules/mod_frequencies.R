# =============================================================================
# mod_frequencies.R — V2: frecuencias y exploración léxica
# =============================================================================
mod_frequencies_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "V2 · Frecuencias y exploración léxica"),
    shiny::uiOutput(ns("kpis")),
    as_card(title = "Evolución de un término", icon = "activity",
      shiny::fluidRow(
        shiny::column(5, shiny::selectInput(ns("term"), "Término", choices = NULL)),
        shiny::column(4, shiny::selectInput(ns("period"), "Periodo",
          choices = c("Mes" = "month", "Año" = "year"), selected = "month")),
        shiny::column(3, shiny::selectInput(ns("metric"), "Métrica",
          choices = c("Apariciones" = "count", "Documentos" = "docs")))
      ),
      as_echart(ns("series"), "360px")
    ),
    shiny::fluidRow(
      shiny::column(6, as_card(title = "Términos más extendidos", icon = "grid",
        shiny::p(class = "as-muted", "Frecuencia documental (en cuántos mensajes aparece)."),
        as_echart(ns("topbar"), "360px"))),
      shiny::column(6, as_card(title = "Tabla de términos", icon = "list",
        DT::DTOutput(ns("table"))))
    )
  )
}

mod_frequencies_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    tf <- shiny::reactive(data$v2_tfidf$tfidf)
    gl <- shiny::reactive(data$v2_tfidf$global)

    output$kpis <- shiny::renderUI({
      tfidf <- tf(); g <- gl()
      if (is.null(tfidf) || !nrow(tfidf)) {
        return(shiny::p(class = "as-muted",
          "No hay resultados V2. Ejecute scripts/06t_tfidf.R."))
      }
      as_kpi_grid(
        as_kpi(length(unique(tfidf$doc_id)), "Documentos", icon = "chat",
               raw = length(unique(tfidf$doc_id))),
        as_kpi(nrow(g), "Términos únicos", icon = "book", variant = "is-cyan",
               raw = nrow(g)),
        as_kpi(sum(tfidf$tf_count), "Apariciones", icon = "activity",
               variant = "is-green", raw = sum(tfidf$tf_count)),
        as_kpi(mean(g$df), "Docs por término (media)", icon = "percent",
               variant = "is-pink", raw = mean(g$df), decimals = 1)
      )
    })

    shiny::observe({
      g <- gl(); if (is.null(g) || !nrow(g)) return()
      ch <- utils::head(g$term, 30)
      shiny::updateSelectInput(session, "term", choices = stats::setNames(ch, ch),
                               selected = if (length(ch)) ch[[1]] else "")
    })

    series <- shiny::reactive({
      tfidf <- tf(); fe <- data$v2_features$features
      term <- input$term %||% ""
      if (is.null(tfidf) || is.null(fe) || !nzchar(term)) return(tibble::tibble())
      d <- tfidf[tfidf$term == term, , drop = FALSE]
      if (!nrow(d)) return(tibble::tibble())
      dates <- fe$date[match(d$doc_id, fe$message_id)]
      grp <- if (identical(input$period, "year")) format(dates, "%Y") else format(dates, "%Y-%m")
      out <- tibble::tibble(period = grp, count = d$tf_count, doc_id = d$doc_id)
      out <- out[!is.na(out$period), , drop = FALSE]
      out |>
        dplyr::group_by(period) |>
        dplyr::summarise(count = sum(count), docs = dplyr::n(),
                         .groups = "drop") |>
        dplyr::arrange(period)
    })

    as_render_echart(session, ns("series"), {
      d <- series(); if (!nrow(d)) return(NULL)
      val <- if (identical(input$metric, "docs")) d$docs else d$count
      opt_line(d$period, stats::setNames(list(val), input$term),
               title = sprintf("«%s» por %s", input$term,
                               if (identical(input$period, "year")) "año" else "mes"),
               x_name = "Periodo", y_name = "Frecuencia")
    })

    as_render_echart(session, ns("topbar"), {
      g <- gl(); if (is.null(g) || !nrow(g)) return(NULL)
      d <- utils::head(g[order(-g$df), , drop = FALSE], 15)
      opt_hbar(d, "term", "df", title = "Términos en más mensajes")
    })

    output$table <- DT::renderDT({
      g <- gl(); if (is.null(g) || !nrow(g)) return(NULL)
      d <- utils::head(g[order(-g$sum_tfidf), , drop = FALSE], 100)
      d$mean_tfidf <- round(d$mean_tfidf, 3)
      d$sum_tfidf <- round(d$sum_tfidf, 2)
      DT::datatable(d, options = list(pageLength = 12, scrollX = TRUE),
                    rownames = FALSE)
    })
  })
}
