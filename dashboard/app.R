find_project_root <- function(start = getwd()) {
  p <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(p, "R", "bootstrap.R"))) return(p)
    parent <- dirname(p)
    if (identical(parent, p)) stop("No se encontró la raíz del proyecto (R/bootstrap.R)")
    p <- parent
  }
}

.root <- find_project_root()
setwd(.root)
source(file.path(.root, "R", "bootstrap.R"), encoding = "UTF-8")
.bs <- bootstrap(root = .root)
.cfg <- .bs$cfg

for (m in sort(list.files(file.path(.root, "dashboard", "modules"),
                          pattern = "\\.R$", full.names = TRUE))) {
  source(m, encoding = "UTF-8")
}

.data <- load_dashboard_data(.cfg)
.con <- tryCatch(db_connect(cfg = .cfg), error = function(e) NULL)
shiny::onStop(function() {
  if (!is.null(.con)) db_disconnect(.con)
})

# --- Recursos estáticos y encabezado ----------------------------------------
.head <- shiny::tags$head(
  shiny::tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
  shiny::tags$script(src = "echarts.min.js"),
  shiny::tags$link(rel = "stylesheet", href = "as_theme.css"),
  shiny::tags$link(rel = "stylesheet", href = "emotional_avatar.css"),
  shiny::tags$script(src = "as_app.js"),
  shiny::tags$script(src = "emotional_avatar.js")
)

.n_import <- if (!is.null(.data$messages)) nrow(.data$messages) else 0
.cov <- if (!is.null(.data$evaluation)) sprintf("%.1f%%", 100 * .data$evaluation$coverage$coverage) else "—"
.periodo <- if (!is.null(.data$messages)) {
  rng <- range(as.Date(substr(.data$messages$timestamp_utc, 1, 10)), na.rm = TRUE)
  sprintf("%s → %s", format(rng[1], "%b %Y"), format(rng[2], "%b %Y"))
} else "—"

.hero <- shiny::div(class = "as-hero",
  shiny::div(class = "as-hero-inner",
    shiny::div(
      shiny::h1("Proyecto - Analisis de Sentimientos - Mineria de Datos DAT-253"),
      shiny::p(class = "as-hero-sub",
               "Panel interactivo que visualizan los sentimientos y emociones de los mensajes de un grupo de Telegram, usando un diccionario de sentimientos y emociones."),
      shiny::div(class = "as-badges",
        shiny::span(class = "as-chip", as_icon("chat", 14), sprintf("%s mensajes", format(.n_import, big.mark = "."))),
        shiny::span(class = "as-chip", as_icon("target", 14), paste("cobertura", .cov)),
        shiny::span(class = "as-chip", as_icon("calendar", 14), .periodo)
      )
    ),
    shiny::div(class = "as-hero-controls",
      shiny::span(class = "as-chip", as_icon("clock", 14), shiny::span(id = "as-clock", "--:--:--")),
      shiny::tags$button(
        id = "as-theme-toggle", class = "btn btn-glass",
        title = "Cambiar tema claro/oscuro",
        onclick = "window.ASApp && window.ASApp.toggle()",
        "🌙"
      )
    )
  )
)

.footer <- shiny::div(class = "as-footer",
  shiny::div(class = "as-footer-inner",
    shiny::div(
      shiny::span(class = "as-footer-brand", "Mineria de Datos DAT-253"),
      shiny::span(class = "as-muted", " · Analisis de Sentimientos")
    ),
    shiny::div(class = "as-muted small",
      "Elaborado y diseñado por: ",
      "Colocan sus nombres jajaj"
    )
  )
)

.ui_content <- bslib::page_navbar(
  title = "DAT-253",
  theme = bslib::bs_theme(
    version = 5,
    primary = "#6366f1",
    secondary = "#8b5cf6",
    success = "#10b981",
    warning = "#f59e0b",
    danger = "#ef4444",
    bg = "#f4f6fb", fg = "#1e293b",
    base_font = bslib::font_collection("Inter", "Segoe UI", "system-ui", "sans-serif")
  ),
  fillable = FALSE,
  header = shiny::tagList(.head, .hero),
  footer = .footer,
  bslib::nav_panel(shiny::span(as_icon("grid", 16), " Resumen"), mod_overview_ui("overview")),
  bslib::nav_panel(shiny::span(as_icon("upload", 16), " Cargar corpus"), mod_import_ui("import")),
  bslib::nav_panel(shiny::span(as_icon("heart", 16), " Sentimientos"), mod_sentiment_ui("sentiment")),
  bslib::nav_panel(shiny::span(as_icon("activity", 16), " Temporal"), mod_temporal_ui("temporal")),
  bslib::nav_panel(shiny::span(as_icon("layers", 16), " Temas"), mod_topics_ui("topics")),
  bslib::nav_panel(shiny::span(as_icon("shuffle", 16), " Transiciones"), mod_markov_ui("markov")),
  bslib::nav_panel(shiny::span(as_icon("smile", 16), " Avatar emocional"), mod_avatar_ui("avatar")),
  bslib::nav_panel(shiny::span(as_icon("book", 16), " Diccionario"), mod_dictionary_ui("dictionary")),
  bslib::nav_panel(shiny::span(as_icon("list", 16), " Bitácora"), mod_audit_ui("audit")),
  bslib::nav_panel(shiny::span(as_icon("file", 16), " Informe"), mod_report_ui("report"))
)

ui <- .ui_content

server <- function(input, output, session) {
  mod_overview_server("overview", .data, .con)
  mod_import_server("import", .con, .cfg)
  mod_sentiment_server("sentiment", .data)
  mod_temporal_server("temporal", .data)
  mod_topics_server("topics", .data)
  mod_markov_server("markov", .data)
  mod_avatar_server("avatar", .data)
  mod_dictionary_server("dictionary", .cfg, .con)
  mod_audit_server("audit", .con)
  mod_report_server("report", .data, .con, .cfg)
}

shiny::shinyApp(ui, server)
