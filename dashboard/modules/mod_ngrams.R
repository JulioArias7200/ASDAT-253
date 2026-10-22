# =============================================================================
# mod_ngrams.R — V2: unigramas, bigramas y n-gramas
# =============================================================================
mod_ngrams_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "V2 · N-gramas"),
    as_card(icon = "layers",
      shiny::p(class = "as-muted",
        "Frecuencias de unigramas, bigramas y trigramas calculadas por mensaje ",
        "(los n-gramas nunca cruzan el límite entre mensajes). Las stopwords se ",
        "eliminan conservando negadores como «no», «nunca» o «jamás».")),
    as_card(title = "Explorador de n-gramas", icon = "search",
      shiny::fluidRow(
        shiny::column(3, shiny::selectInput(ns("size"), "Tamaño (N)",
          choices = c("Unigramas" = 1, "Bigramas" = 2, "Trigramas" = 3), selected = 1)),
        shiny::column(3, shiny::numericInput(ns("min_count"), "Frecuencia mínima",
                                            2, 1, 10000)),
        shiny::column(3, shiny::selectInput(ns("top"), "Mostrar",
          choices = c(10, 20, 30, 50), selected = 20)),
        shiny::column(3, shiny::selectInput(ns("group"), "Vista",
          choices = c("Ranking global" = "global", "Evolución mensual" = "month",
                      "Evolución anual" = "year")))
      ),
      shiny::conditionalPanel(
        sprintf("input['%s'] != 'global'", ns("group")),
        shiny::selectInput(ns("term"), "Término a seguir", choices = NULL)),
      as_echart(ns("chart"), "400px")
    ),
    shiny::fluidRow(
      shiny::column(7, as_card(title = "Datos", icon = "list",
                               DT::DTOutput(ns("table")))),
      shiny::column(5, as_card(title = "Efecto de quitar stopwords", icon = "refresh",
        shiny::h6("Antes"), DT::DTOutput(ns("cmp_before")),
        shiny::h6("Después"), DT::DTOutput(ns("cmp_after"))))
    )
  )
}

mod_ngrams_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    empty_note <- function() shiny::p(class = "as-muted",
      "No hay resultados V2. Ejecute scripts/05n_ngrams.R para generarlos.")

    size <- shiny::reactive(as.integer(input$size %||% 1))
    top <- shiny::reactive(as.integer(input$top %||% 20))

    global_tab <- shiny::reactive({
      d <- data$v2_ngrams
      if (is.null(d) || is.null(d$table)) return(tibble::tibble())
      tab <- d$table
      tab <- tab[tab$size == size() & tab$count >= (input$min_count %||% 1), , drop = FALSE]
      tab[order(-tab$count), , drop = FALSE]
    })

    shiny::observeEvent(size(), {
      g <- global_tab()
      ch <- utils::head(unique(g$ngram), 30)
      shiny::updateSelectInput(session, "term",
        choices = stats::setNames(ch, ch),
        selected = if (length(ch)) ch[[1]] else "")
    }, ignoreNULL = FALSE)

    series_tab <- shiny::reactive({
      if (identical(input$group, "global")) return(tibble::tibble())
      m <- data$messages
      term <- input$term %||% ""
      if (is.null(m) || !nzchar(term)) return(tibble::tibble())
      keep <- !is.na(m$text_norm) & nzchar(m$text_norm)
      d <- as.Date(substr(m$timestamp_utc[keep], 1, 10))
      grp <- if (identical(input$group, "year")) format(d, "%Y") else format(d, "%Y-%m")
      ngram_term_by_period(m$text_norm[keep], term, grp, n = size())
    })

    shown <- shiny::reactive({
      if (identical(input$group, "global")) {
        g <- global_tab(); utils::head(g, top())
      } else series_tab()
    })

    output$chart <- NULL
    as_render_echart(session, ns("chart"), {
      d <- shown()
      if (!nrow(d)) return(NULL)
      if (identical(input$group, "global")) {
        opt_hbar(d, "ngram", "count", title = "N-gramas más frecuentes")
      } else {
        opt_line(d$group, list(Frecuencia = d$count),
                 title = sprintf("«%s» por periodo", input$term),
                 x_name = "Periodo", y_name = "Apariciones")
      }
    })

    output$table <- DT::renderDT({
      d <- shown()
      if (!nrow(d)) return(NULL)
      DT::datatable(d, options = list(pageLength = 12, scrollX = TRUE),
                    rownames = FALSE)
    })

    cmp <- shiny::reactive(data$v2_ngrams$stopword_comparison)

    output$cmp_before <- DT::renderDT({
      d <- cmp()$before
      if (is.null(d) || !nrow(d)) return(NULL)
      DT::datatable(utils::head(d, 10), options = list(dom = "t", pageLength = 10),
                    rownames = FALSE)
    })
    output$cmp_after <- DT::renderDT({
      d <- cmp()$after
      if (is.null(d) || !nrow(d)) return(NULL)
      DT::datatable(utils::head(d, 10), options = list(dom = "t", pageLength = 10),
                    rownames = FALSE)
    })
  })
}
