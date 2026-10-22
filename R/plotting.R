# =============================================================================
# plotting.R — gráficos reproducibles (ggplot2)
# =============================================================================

PALETTE <- c(positivo = "#2e7d32", negativo = "#b71c1c", neutro = "#616161",
             indeterminado = "#9e9e9e", accent = "#1e5aa0")

#' Serie temporal de polaridad promedio
#' @export
plot_polarity_temporal <- function(temporal, by = "day") {
  ggplot2::ggplot(temporal, ggplot2::aes(x = period, y = polarity_mean)) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
    ggplot2::geom_line(colour = PALETTE[["accent"]], linewidth = 0.7) +
    ggplot2::geom_point(colour = PALETTE[["accent"]], size = 1.3) +
    ggplot2::labs(x = "Periodo", y = "Polaridad promedio",
                  title = "Evolución temporal de la polaridad") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Volumen de mensajes por período
#' @export
plot_volume_temporal <- function(temporal) {
  ggplot2::ggplot(temporal, ggplot2::aes(x = period, y = n_messages)) +
    ggplot2::geom_col(fill = PALETTE[["accent"]]) +
    ggplot2::labs(x = "Periodo", y = "N.º de mensajes",
                  title = "Volumen de mensajes") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Distribución de polaridad
#' @export
plot_polarity_dist <- function(sentiments) {
  d <- as.data.frame(table(label = sentiments$polarity_label))
  names(d)[2] <- "n"
  d$pct <- d$n / sum(d$n)
  ggplot2::ggplot(d, ggplot2::aes(x = label, y = n, fill = label)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", 100 * pct)), vjust = -0.3, size = 3) +
    ggplot2::scale_fill_manual(values = PALETTE) +
    ggplot2::labs(x = "Polaridad", y = "N.º de mensajes", title = "Distribución de polaridad") +
    ggplot2::theme_minimal(base_size = 11) + ggplot2::theme(legend.position = "none")
}

#' Frecuencia de emociones (conteo de etiquetas detectadas)
#' @export
plot_emotion_freq <- function(sentiments, emotions = EMOTION_CATEGORIES) {
  counts <- emotion_totals(sentiments, emotions)
  d <- data.frame(category = names(counts), n = as.numeric(counts))
  d <- d[order(-d$n), ]
  d$category <- factor(d$category, levels = d$category)
  ggplot2::ggplot(d, ggplot2::aes(x = category, y = n)) +
    ggplot2::geom_col(fill = PALETTE[["accent"]]) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Emoción", y = "Ocurrencias", title = "Frecuencia de emociones") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Matriz de transición de Markov
#' @export
plot_transition_heatmap <- function(P, states) {
  df <- expand.grid(from = states, to = states)
  df$value <- as.vector(P)
  df$from <- factor(df$from, levels = states)
  df$to <- factor(df$to, levels = states)
  ggplot2::ggplot(df, ggplot2::aes(x = to, y = from, fill = value)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = ifelse(is.na(value), "-", sprintf("%.2f", value))), size = 3) +
    ggplot2::scale_fill_gradient(low = "#f5f5f5", high = PALETTE[["accent"]], na.value = "grey85") +
    ggplot2::labs(x = "Siguiente estado", y = "Estado actual", title = "Matriz de transición") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Totales de emociones a partir de la columna JSON
#' @export
emotion_totals <- function(sentiments, emotions = EMOTION_CATEGORIES) {
  totals <- stats::setNames(rep(0, length(emotions)), emotions)
  for (j in sentiments$emotion_scores) {
    x <- tryCatch(jsonlite::fromJSON(j, simplifyVector = TRUE), error = function(e) list())
    if (!length(x)) next
    for (e in names(x)) if (e %in% emotions) totals[[e]] <- totals[[e]] + as.numeric(x[[e]])
  }
  totals
}

#' Guarda un gráfico a PNG/SVG dentro del proyecto
#' @export
save_plot <- function(fig, path, width = 9, height = 5, dpi = 150) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, plot = fig, width = width, height = height, dpi = dpi,
                  units = "in", bg = "white")
  invisible(path)
}
