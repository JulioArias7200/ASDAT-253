# =============================================================================
# mod_tfidf.R — V2: TF, IDF y TF-IDF
# =============================================================================
mod_tfidf_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "V2 · TF-IDF"),
    as_card(icon = "target",
      shiny::p(class = "as-muted",
        "TF = frecuencia del término en el mensaje; IDF = ln(N/df); ",
        "TF-IDF = TF × IDF. Documento = mensaje. Un término presente en todos ",
        "los mensajes recibe IDF 0 y por tanto no aporta peso.")),
    shiny::uiOutput(ns("kpis")),
    shiny::fluidRow(
      shiny::column(6, as_card(title = "Términos con mayor peso global",
        icon = "grid", as_echart(ns("topbar"), "380px"))),
      shiny::column(6, as_card(title = "Peso por mensaje", icon = "search",
        shiny::numericInput(ns("doc_id"), "ID de mensaje", value = NA),
        shiny::p(class = "as-muted small",
                 "El ID corresponde al mensaje de Telegram importado."),
        DT::DTOutput(ns("doc_table"))))
    ),
    as_card(title = "Tabla global de términos", icon = "list",
      DT::DTOutput(ns("table")))
  )
}

mod_tfidf_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    tf <- shiny::reactive(data$v2_tfidf$tfidf)
    gl <- shiny::reactive(data$v2_tfidf$global)
    top <- shiny::reactive(data$v2_tfidf$top)

    output$kpis <- shiny::renderUI({
      tfidf <- tf(); g <- gl()
      if (is.null(tfidf) || !nrow(tfidf)) {
        return(shiny::p(class = "as-muted",
          "No hay resultados V2. Ejecute scripts/06t_tfidf.R."))
      }
      as_kpi_grid(
        as_kpi(length(unique(tfidf$doc_id)), "Mensajes", icon = "chat",
               raw = length(unique(tfidf$doc_id))),
        as_kpi(nrow(g), "Términos", icon = "book", variant = "is-cyan",
               raw = nrow(g)),
        as_kpi(mean(tfidf$idf), "IDF medio", icon = "percent",
               variant = "is-pink", raw = mean(tfidf$idf), decimals = 2),
        as_kpi(max(g$sum_tfidf), "Peso máximo", icon = "activity",
               variant = "is-green", raw = max(g$sum_tfidf), decimals = 1)
      )
    })

    shiny::observe({
      tfidf <- tf(); if (is.null(tfidf) || !nrow(tfidf)) return()
      if (is.na(input$doc_id %||% NA)) {
        shiny::updateNumericInput(session, "doc_id", value = tfidf$doc_id[[1]])
      }
    })

    as_render_echart(session, ns("topbar"), {
      g <- gl(); if (is.null(g) || !nrow(g)) return(NULL)
      d <- utils::head(g[order(-g$sum_tfidf), , drop = FALSE], 15)
      opt_hbar(d, "term", "sum_tfidf", title = "Suma de TF-IDF")
    })

    output$doc_table <- DT::renderDT({
      d <- top(); id <- input$doc_id
      if (is.null(d) || is.null(id) || is.na(id)) return(NULL)
      d <- d[d$doc_id == id, c("term", "tf_count", "df", "idf", "tf", "tfidf"),
             drop = FALSE]
      if (!nrow(d)) return(NULL)
      d[, c("idf", "tf", "tfidf")] <- lapply(d[, c("idf", "tf", "tfidf")],
                                             function(x) round(x, 3))
      DT::datatable(d, options = list(dom = "t", pageLength = 10),
                    rownames = FALSE)
    })

    output$table <- DT::renderDT({
      g <- gl(); if (is.null(g) || !nrow(g)) return(NULL)
      d <- utils::head(g[order(-g$sum_tfidf), , drop = FALSE], 100)
      d[, c("sum_tfidf", "mean_tfidf")] <- lapply(
        d[, c("sum_tfidf", "mean_tfidf")], function(x) round(x, 3))
      DT::datatable(d, options = list(pageLength = 12, scrollX = TRUE),
                    rownames = FALSE)
    })
  })
}
