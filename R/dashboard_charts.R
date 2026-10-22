# =============================================================================
# dashboard_charts.R — utilidades de UI y gráficos para el dashboard
# Integra Apache ECharts (vía mensaje personalizado de Shiny) sin dependencias
# adicionales de R.
# =============================================================================

# -- Iconos SVG en línea (sin dependencia de fuentes externas) ----------------
.AS_ICONS <- list(
  chat     = '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
  pie      = '<path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/>',
  calendar = '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  percent  = '<line x1="19" y1="5" x2="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
  heart    = '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1.1 1.1L12 21l7.7-7.5 1.1-1.1a5.5 5.5 0 0 0 0-7.8z"/>',
  activity = '<polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>',
  grid     = '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/>',
  clock    = '<circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15 14"/>',
  sun      = '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  moon     = '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
  download = '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>',
  search   = '<circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>',
  refresh  = '<polyline points="23 4 23 10 17 10"/><path d="M20.5 15a9 9 0 1 1-2-9.5L23 10"/>',
  database = '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.7 4 3 9 3s9-1.3 9-3V5"/><path d="M3 12c0 1.7 4 3 9 3s9-1.3 9-3"/>',
  file     = '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>',
  book     = '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>',
  smile    = '<circle cx="12" cy="12" r="9"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/>',
  shuffle  = '<polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/><line x1="4" y1="4" x2="9" y2="9"/>',
  list     = '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
  upload   = '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>',
  layers   = '<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>',
  target   = '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>'
)

#' Devuelve un icono SVG en línea
#' @export
as_icon <- function(name, size = 20) {
  path <- .AS_ICONS[[name]] %||% .AS_ICONS[["target"]]
  htmltools::HTML(sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>',
    size, size, path))
}

#' Tarjeta contenedora con estilo del tema
#' @export
as_card <- function(title = NULL, ..., icon = NULL, class = NULL) {
  head <- if (!is.null(title)) {
    htmltools::div(class = "as-card-title",
      htmltools::span(class = "as-dot"),
      if (!is.null(icon)) htmltools::span(class = "as-card-icon", as_icon(icon, 18)),
      htmltools::span(title))
  }
  htmltools::div(class = paste("as-card", class),
    head, htmltools::div(class = "as-card-body", ...))
}

#' Tile KPI con contador animado
#' @export
as_kpi <- function(value, label, icon = "activity", sub = NULL, variant = "",
                   decimals = 0, suffix = "", prefix = "", raw = NULL) {
  num <- if (!is.null(raw)) raw else suppressWarnings(as.numeric(gsub("[^0-9.,-]", "", value)))
  if (is.na(num)) num <- 0
  cls <- paste("as-kpi", variant)
  htmltools::div(class = cls,
    htmltools::div(class = "as-kpi-head",
      htmltools::div(class = "as-kpi-icon", as_icon(icon)),
      htmltools::div(class = "as-kpi-label", label)),
    htmltools::div(class = "as-kpi-value",
      `data-countup` = format(num, scientific = FALSE),
      `data-decimals` = decimals,
      `data-suffix` = suffix,
      `data-prefix` = prefix,
      value),
    if (!is.null(sub)) htmltools::div(class = "as-kpi-sub", sub)
  )
}

#' Rejilla de KPIs
#' @export
as_kpi_grid <- function(...) htmltools::div(class = "as-kpi-grid as-reveal", ...)

#' Contenedor de gráfico ECharts
#' @export
as_echart <- function(id, height = "360px", class = "as-echart") {
  htmltools::div(id = id, class = class, style = sprintf("width:100%%;height:%s;", height))
}

#' Elimina entradas NULL de una opción ECharts (incompatibles con JSON)
#' @export
opt_clean <- function(o) o[!vapply(o, is.null, logical(1))]

#' Envía una opción de ECharts al cliente
#' @export
as_send_echart <- function(session, id, option) {
  session$sendCustomMessage("as_echart", list(id = id, option = opt_clean(option)))
}

#' Renderiza una opción de ECharts de forma reactiva
#' \code{as_render_echart(session, "id", { ...; return(option) })}
#' @export
as_render_echart <- function(session, id, expr, env = parent.frame()) {
  force(env)                 # captura el marco del llamador antes de diferir
  expr <- substitute(expr)
  shiny::observe({
    option <- eval(expr, envir = env)
    if (!is.null(option)) as_send_echart(session, id, option)
  })
}

# ---------------------------------------------------------------------------
# Constructores de opciones ECharts
# ---------------------------------------------------------------------------

.as_data_pairs <- function(df, name_col = 1, value_col = 2) {
  lapply(seq_len(nrow(df)), function(i) {
    list(name = as.character(df[[name_col]][i]), value = as.numeric(df[[value_col]][i]))
  })
}

#' Dona / pastel
#' @export
opt_donut <- function(df, name_col = 1, value_col = 2, title = NULL, palette = NULL) {
  o <- list(
    tooltip = list(trigger = "item", formatter = "{b}: {c} ({d}%)"),
    legend = list(bottom = 0, icon = "circle", itemWidth = 10, itemHeight = 10),
    series = list(list(
      type = "pie", radius = c("52%", "78%"), center = c("50%", "44%"),
      avoidLabelOverlap = TRUE,
      itemStyle = list(borderRadius = 8, borderWidth = 2, borderColor = "rgba(0,0,0,0)"),
      label = list(show = TRUE, formatter = "{b}\n{d}%", fontSize = 11),
      labelLine = list(length = 8, length2 = 8),
      emphasis = list(scale = TRUE, scaleSize = 8,
                      itemStyle = list(shadowBlur = 20, shadowColor = "rgba(99,102,241,.55)")),
      data = .as_data_pairs(df, name_col, value_col))))
  if (!is.null(palette)) o$color <- palette
  if (!is.null(title)) o$title <- list(text = title, left = "center", top = 0, textStyle = list(fontSize = 13))
  o
}

#' Barras horizontales ordenadas
#' @export
opt_hbar <- function(df, name_col = 1, value_col = 2, color = NULL, title = NULL) {
  d <- df[order(-as.numeric(df[[value_col]])), ]
  lab <- rev(as.character(d[[name_col]])); val <- rev(as.numeric(d[[value_col]]))
  o <- list(
    grid = list(left = 8, right = 24, top = if (is.null(title)) 10 else 34, bottom = 8, containLabel = TRUE),
    tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
    xAxis = list(type = "value"),
    yAxis = list(type = "category", data = lab),
    series = list(list(
      type = "bar", data = val, barWidth = "60%",
      itemStyle = list(borderRadius = c(0, 6, 6, 0),
                       color = color %||% list(type = "linear", x = 0, y = 0, x2 = 1, y2 = 0,
                         colorStops = list(list(offset = 0, color = "#6366f1"), list(offset = 1, color = "#ec4899")))),
      emphasis = list(itemStyle = list(shadowBlur = 14, shadowColor = "rgba(99,102,241,.5)")),
      label = list(show = TRUE, position = "right", fontSize = 11))))
  if (!is.null(title)) o$title <- list(text = title, left = "center", top = 0, textStyle = list(fontSize = 13))
  o
}

#' Serie de líneas (con área opcional) y líneas múltiples
#' @export
opt_line <- function(x, series, title = NULL, area = TRUE, smooth = TRUE,
                     y_name = NULL, x_name = NULL) {
  cols <- list(
    list(offset = 0, color = "rgba(99,102,241,.28)"),
    list(offset = 1, color = "rgba(99,102,241,0)")
  )
  s <- lapply(seq_along(series), function(i) {
    si <- list(
      name = names(series)[i] %||% paste0("serie", i),
      type = "line", data = as.numeric(series[[i]]),
      smooth = smooth, symbol = "circle", symbolSize = 5, showSymbol = FALSE,
      lineStyle = list(width = 3),
      emphasis = list(focus = "series"))
    if (area && i == 1) {
      si$areaStyle <- list(color = list(type = "linear", x = 0, y = 0, x2 = 0, y2 = 1,
                                        colorStops = cols))
    }
    si
  })
  o <- list(
    grid = list(left = 8, right = 16, top = if (is.null(title)) 14 else 38, bottom = 8, containLabel = TRUE),
    tooltip = list(trigger = "axis"),
    legend = if (length(series) > 1) list(top = 0, icon = "roundRect") else NULL,
    xAxis = list(type = "category", data = as.character(x), boundaryGap = FALSE,
                 name = x_name, nameLocation = "middle", nameGap = 26),
    yAxis = list(type = "value", name = y_name),
    series = s)
  if (!is.null(title)) o$title <- list(text = title, left = "center", top = 0, textStyle = list(fontSize = 13))
  o
}

#' Barras verticales
#' @export
opt_vbar <- function(x, y, title = NULL, y_name = NULL, color = NULL) {
  o <- list(
    grid = list(left = 8, right = 16, top = if (is.null(title)) 14 else 38, bottom = 8, containLabel = TRUE),
    tooltip = list(trigger = "axis", axisPointer = list(type = "shadow")),
    xAxis = list(type = "category", data = as.character(x)),
    yAxis = list(type = "value", name = y_name),
    series = list(list(
      type = "bar", data = as.numeric(y), barWidth = "55%",
      itemStyle = list(borderRadius = c(6, 6, 0, 0),
                       color = color %||% list(type = "linear", x = 0, y = 0, x2 = 0, y2 = 1,
                         colorStops = list(list(offset = 0, color = "#8b5cf6"), list(offset = 1, color = "#6366f1")))),
      emphasis = list(itemStyle = list(shadowBlur = 14, shadowColor = "rgba(139,92,246,.5)")))))
  if (!is.null(title)) o$title <- list(text = title, left = "center", top = 0, textStyle = list(fontSize = 13))
  o
}

#' Mapa de calor
#' @export
opt_heatmap <- function(states, mat, title = NULL) {
  m <- round(mat * 100, 1)
  d <- expand.grid(y = seq_along(states) - 1L, x = seq_along(states) - 1L)
  d$v <- as.vector(t(m))
  d$v[is.na(d$v)] <- 0
  data <- lapply(seq_len(nrow(d)), function(i) list(d$x[i], d$y[i], d$v[i]))
  list(
    tooltip = list(position = "top", trigger = "item"),
    grid = list(left = 8, right = 16, top = if (is.null(title)) 16 else 40, bottom = 30, containLabel = TRUE),
    xAxis = list(type = "category", data = states, splitArea = list(show = TRUE), name = "Siguiente"),
    yAxis = list(type = "category", data = states, splitArea = list(show = TRUE), name = "Actual"),
    visualMap = list(min = 0, max = 100, calculable = TRUE, orient = "horizontal",
                     left = "center", bottom = 0, text = c("100%", "0%"),
                     inRange = list(color = c("#eef2ff", "#818cf8", "#4c1d95"))),
    series = list(list(name = "Transición", type = "heatmap", data = data,
      label = list(show = TRUE, formatter = "{c}%", fontSize = 11),
      emphasis = list(itemStyle = list(shadowBlur = 12, shadowColor = "rgba(0,0,0,.4)")))),
    title = if (is.null(title)) NULL else list(text = title, left = "center", top = 0, textStyle = list(fontSize = 13))
  )
}
