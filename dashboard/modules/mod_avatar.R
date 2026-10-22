# =============================================================================
# mod_avatar.R — avatar emocional agregado
# =============================================================================
.EMO_LABEL <- c(
  alegria = "Alegría", tristeza = "Tristeza", ira = "Ira", miedo = "Miedo",
  sorpresa = "Sorpresa", asco = "Asco", amor = "Amor", gratitud = "Gratitud",
  confianza = "Confianza", anticipacion = "Anticipación", frustracion = "Frustración",
  ansiedad = "Ansiedad", esperanza = "Esperanza", orgullo = "Orgullo",
  verguenza = "Vergüenza", diversion = "Diversión", aburrimiento = "Aburrimiento",
  alivio = "Alivio", sin_evidencia = "Sin evidencia suficiente",
  indeterminado = "Indeterminado"
)

mod_avatar_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "as-section-title", "Avatar emocional"),
    as_card(icon = "smile",
      shiny::p(class = "as-muted",
        "El avatar resume la emoción predominante del período seleccionado según el ",
        "modelo. Es una visualización agregada con fines exploratorios y no representa ",
        "el estado psicológico de ninguna persona.")),
    shiny::fluidRow(
      shiny::column(4, as_card(title = "Controles", icon = "target",
        shiny::dateRangeInput(ns("dates"), "Período"),
        shiny::selectInput(ns("override"), "Forzar emoción",
                           choices = c("Automático (predominante)" = "",
                                       stats::setNames(EMOTION_CATEGORIES, .EMO_LABEL[EMOTION_CATEGORIES]))),
        shiny::checkboxInput(ns("animate"), "Animación", value = TRUE))),
      shiny::column(8, as_card(title = "Estado emocional agregado", icon = "smile",
        shiny::div(class = "as-avatar-host", id = ns("host"))))
    ),
    as_card(title = "Proporciones por emoción", icon = "heart",
            DT::DTOutput(ns("proportions")))
  )
}

mod_avatar_server <- function(id, data) {
  shiny::moduleServer(id, function(input, output, session) {
    s <- data$sentiments; m <- data$messages
    if (!is.null(m)) {
      rng <- range(as.Date(substr(m$timestamp_utc, 1, 10)), na.rm = TRUE)
      shiny::updateDateRangeInput(session, "dates", start = rng[1], end = rng[2],
                                  min = rng[1], max = rng[2])
    }

    agg <- shiny::reactive({
      if (is.null(s)) return(NULL)
      df <- filter_messages(data, date_range = input$dates)
      if (!nrow(df)) return(NULL)
      tot <- emotion_totals(df)
      tot <- tot[tot > 0]
      if (!length(tot)) return(NULL)
      props <- tot / sum(tot)
      list(totals = tot, props = props, n = nrow(df))
    })

    output$proportions <- DT::renderDT({
      a <- agg(); if (is.null(a)) return(NULL)
      d <- data.frame(Emoción = .EMO_LABEL[names(a$props)],
                      Proporción = sprintf("%.1f%%", 100 * as.numeric(a$props)),
                      Ocurrencias = as.integer(a$totals))
      DT::datatable(d, options = list(pageLength = 8, dom = "tp"), rownames = FALSE)
    })

    shiny::observeEvent(list(input$override, input$dates, agg()), {
      a <- agg(); if (is.null(a)) return(invisible(NULL))
      emo <- if (nzchar(input$override)) input$override else names(a$props)[which.max(a$props)]
      lab <- .EMO_LABEL[[emo]] %||% emo
      session$sendCustomMessage("avatar_state", list(
        emotion = emo, label = lab, n = a$n, proportions = as.list(a$props)))
    })
  })
}
