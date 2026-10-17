# =============================================================================
# report_figures.R — figuras, tablas y cifras ampliadas para el informe
# =============================================================================

# Emojis -> descriptor textual (evita glifos Unicode en LaTeX y en PNG)
EMOJI_SHORTCODE <- c(
  "\u2764\u200d\U0001F525" = "entusiasmo",
  "\U0001F449" = "se\u00f1alizaci\u00f3n",
  "\u2705"     = "confirmaci\u00f3n",
  "\U0001F539" = "vi\u00f1eta",
  "\U0001F4CD" = "ubicaci\u00f3n",
  "\U0001F680" = "impulso",
  "\U0001F4C5" = "calendario",
  "\U0001F4E2" = "anuncio",
  "\U0001F525" = "popular",
  "\U0001F440" = "atenci\u00f3n",
  "\U0001F517" = "enlace",
  "\U0001F393" = "graduaci\u00f3n",
  "\U0001F64F" = "gratitud",
  "\U0001F4DA" = "estudio",
  "\U0001F622" = "tristeza",
  "\u2728"     = "destacado",
  "\U0001F44D" = "aprobaci\u00f3n",
  "\U0001F44E" = "desaprobaci\u00f3n",
  "\U0001F923" = "risa",
  "\u2764"     = "afecto",
  "\U0001F44F" = "aplauso",
  "\U0001F601" = "alegr\u00eda",
  "\U0001F921" = "burla",
  "\U0001F631" = "sorpresa",
  "\U0001F92E" = "rechazo",
  "\u2764\uFE0F" = "afecto"
)

#' Convierte un emoji (o cadena con emojis) a un descriptor textual seguro
#' @export
emoji_shortcode <- function(x) {
  if (length(x) == 0) return(x)
  vapply(x, function(s) {
    if (is.na(s) || !nzchar(s)) return(s)
    s <- gsub("\uFE0F", "", s, fixed = TRUE)
    if (s %in% names(EMOJI_SHORTCODE)) return(unname(EMOJI_SHORTCODE[[s]]))
    cp <- utf8ToInt(s)
    if (all(cp < 128)) return(s)
    paste(sprintf("U+%X", cp), collapse = "+")
  }, character(1), USE.NAMES = FALSE)
}

#' Conteo de emojis de los mensajes (parseando emoji_list)
#' @export
emoji_counts <- function(messages) {
  v <- unlist(lapply(messages$emoji_list, function(x) parse_emoji_list(x)), use.names = FALSE)
  v <- v[!is.na(v) & nzchar(v)]
  if (!length(v)) return(integer(0))
  sort(table(v), decreasing = TRUE)
}

#' Conteo de reacciones (expande por count)
#' @export
reaction_counts <- function(messages) {
  v <- unlist(lapply(messages$reactions, function(x) {
    if (is.na(x) || !nzchar(x)) return(character(0))
    r <- tryCatch(jsonlite::fromJSON(x, simplifyVector = TRUE), error = function(e) list())
    if (!length(r)) return(character(0))
    rep(names(r), times = as.integer(unlist(r)))
  }), use.names = FALSE)
  if (!length(v)) return(integer(0))
  sort(table(v), decreasing = TRUE)
}

#' Une sentimiento con marca temporal y componentes de fecha
#' @export
sentiment_with_time <- function(messages, sentiments) {
  df <- dplyr::inner_join(
    messages[, c("message_id", "timestamp_utc")],
    sentiments, by = "message_id")
  df$ts <- as.POSIXct(df$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  df$year <- format(df$ts, "%Y")
  df$month <- format(df$ts, "%Y-%m")
  df$weekday <- factor(weekdays(df$ts),
                       levels = c("Monday", "Tuesday", "Wednesday", "Thursday",
                                  "Friday", "Saturday", "Sunday"))
  df$hour <- factor(format(df$ts, "%H"), levels = sprintf("%02d", 0:23))
  df
}

# ----------------------------------------------------------------------------
# Figuras
# ----------------------------------------------------------------------------

#' Distribución del nivel de evidencia
#' @export
plot_evidence_dist <- function(sentiments) {
  d <- as.data.frame(table(level = sentiments$evidence_level))
  names(d)[2] <- "n"; d$pct <- d$n / sum(d$n)
  ggplot2::ggplot(d, ggplot2::aes(x = level, y = n, fill = level)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%d\n(%.1f%%)", n, 100 * pct)),
                       vjust = 1.2, size = 3, colour = "white") +
    ggplot2::scale_fill_manual(values = c(suficiente = "#1e5aa0",
                                          insuficiente = "#f9a825",
                                          sin_evidencia = "#9e9e9e")) +
    ggplot2::labs(x = "Nivel de evidencia", y = "N.º de mensajes",
                  title = "Evidencia disponible por mensaje") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none")
}

#' Composición de polaridad por mes (proporciones apiladas)
#' @export
plot_polarity_stacked <- function(temporal_monthly) {
  d <- temporal_monthly
  keep <- c("period", "n_positive", "n_negative", "n_neutral", "n_indeterminate")
  d <- d[, keep]
  long <- tidyr::pivot_longer(d, -period, names_to = "estado", values_to = "n")
  long$estado <- sub("^n_", "", long$estado)
  long$estado <- factor(long$estado,
                        levels = c("indeterminate", "neutral", "negative", "positive"))
  lab <- c(indeterminate = "indeterminado", neutral = "neutro",
           negative = "negativo", positive = "positivo")
  long$estado <- lab[as.character(long$estado)]
  ggplot2::ggplot(long, ggplot2::aes(x = period, y = n, fill = estado)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_manual(values = c(indeterminado = "#9e9e9e", neutro = "#616161",
                                          negativo = "#b71c1c", positivo = "#2e7d32")) +
    ggplot2::labs(x = "Mes", y = "N.º de mensajes", fill = "Polaridad",
                  title = "Composición mensual de la polaridad") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Mapa de calor emociones x año
#' @export
plot_emotion_heatmap <- function(messages, sentiments,
                                 emotions = EMOTION_CATEGORIES) {
  df <- sentiment_with_time(messages, sentiments)
  emo <- lapply(df$emotion_scores, function(j) {
    x <- tryCatch(jsonlite::fromJSON(j, simplifyVector = TRUE), error = function(e) list())
    as.list(x %||% list())
  })
  for (e in emotions) df[[e]] <- vapply(emo, function(x) as.numeric(x[[e]] %||% 0), numeric(1))
  agg <- df |>
    dplyr::group_by(year) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(emotions), ~ sum(.x, na.rm = TRUE)),
                     .groups = "drop")
  long <- tidyr::pivot_longer(agg, -year, names_to = "emotion", values_to = "n")
  ggplot2::ggplot(long, ggplot2::aes(x = year, y = emotion, fill = n)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::scale_fill_gradient(low = "#f5f5f5", high = "#1e5aa0") +
    ggplot2::labs(x = "Año", y = "Emoción", fill = "Ocurrencias",
                  title = "Emociones detectadas por año") +
    ggplot2::theme_minimal(base_size = 10)
}

#' Emojis más frecuentes
#' @export
plot_top_emojis <- function(messages, n = 15) {
  cnt <- emoji_counts(messages)
  if (!length(cnt)) return(ggplot2::ggplot())
  d <- utils::head(as.data.frame(cnt), n)
  names(d) <- c("emoji", "n")
  d$etiqueta <- make.unique(emoji_shortcode(as.character(d$emoji)))
  d$etiqueta <- factor(d$etiqueta, levels = rev(d$etiqueta))
  ggplot2::ggplot(d, ggplot2::aes(x = etiqueta, y = n)) +
    ggplot2::geom_col(fill = "#1e5aa0") +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Emoji (descriptor)", y = "Ocurrencias",
                  title = sprintf("Emojis más frecuentes (top %d)", n)) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Reacciones más frecuentes
#' @export
plot_top_reactions <- function(messages, n = 12) {
  cnt <- reaction_counts(messages)
  if (!length(cnt)) return(ggplot2::ggplot())
  d <- utils::head(as.data.frame(cnt), n)
  names(d) <- c("emoji", "n")
  d$etiqueta <- make.unique(emoji_shortcode(as.character(d$emoji)))
  d$etiqueta <- factor(d$etiqueta, levels = rev(d$etiqueta))
  ggplot2::ggplot(d, ggplot2::aes(x = etiqueta, y = n)) +
    ggplot2::geom_col(fill = "#5e35b1") +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Reacción (descriptor)", y = "Total",
                  title = sprintf("Reacciones más usadas (top %d)", n)) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Actividad por día de la semana
#' @export
plot_weekday <- function(messages) {
  ts <- as.POSIXct(messages$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  d <- as.data.frame(table(weekday = weekdays(ts)))
  names(d)[2] <- "n"
  d$weekday <- factor(d$weekday,
                      levels = c("Monday", "Tuesday", "Wednesday", "Thursday",
                                 "Friday", "Saturday", "Sunday"))
  traductor <- c(Monday = "lunes", Tuesday = "martes", Wednesday = "miércoles",
                 Thursday = "jueves", Friday = "viernes", Saturday = "sábado",
                 Sunday = "domingo")
  d$dia <- traductor[as.character(d$weekday)]
  ggplot2::ggplot(d, ggplot2::aes(x = stats::reorder(dia, n), y = n)) +
    ggplot2::geom_col(fill = "#00838f") +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Día de la semana", y = "N.º de mensajes",
                  title = "Actividad por día de la semana") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Actividad por hora del día
#' @export
plot_hour <- function(messages) {
  ts <- as.POSIXct(messages$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  d <- as.data.frame(table(hora = format(ts, "%H")))
  names(d)[2] <- "n"
  d$hora <- as.integer(as.character(d$hora))
  ggplot2::ggplot(d, ggplot2::aes(x = hora, y = n)) +
    ggplot2::geom_col(fill = "#ef6c00") +
    ggplot2::scale_x_continuous(breaks = seq(0, 23, 2)) +
    ggplot2::labs(x = "Hora del día (UTC)", y = "N.º de mensajes",
                  title = "Actividad por hora del día") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Volumen por mes
#' @export
plot_volume_monthly <- function(temporal_monthly) {
  ggplot2::ggplot(temporal_monthly, ggplot2::aes(x = period, y = n_messages)) +
    ggplot2::geom_col(fill = "#1e5aa0") +
    ggplot2::labs(x = "Mes", y = "N.º de mensajes", title = "Volumen mensual") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Prevalencia de tópicos (documentos dominados)
#' @export
plot_topic_prevalence <- function(topics) {
  dt <- topics$doc_topic
  if (is.null(dt)) return(ggplot2::ggplot())
  dominant <- if (is.data.frame(dt)) dt$topic
              else if (is.matrix(dt)) apply(dt, 1, which.max)
              else dt
  d <- as.data.frame(table(topic = dominant))
  names(d) <- c("topic", "n")
  d$pct <- d$n / sum(d$n) * 100
  ggplot2::ggplot(d, ggplot2::aes(x = stats::reorder(topic, n), y = n)) +
    ggplot2::geom_col(fill = "#1e5aa0") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", pct)), hjust = -0.1, size = 3) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Tópico", y = "Documentos dominados (%)",
                  title = "Prevalencia de tópicos") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Términos más frecuentes del corpus (tras limpieza)
#' @export
plot_top_terms <- function(messages, n = 20, cfg = load_config()) {
  txt <- messages$text_norm
  txt <- txt[!is.na(txt) & nzchar(txt)]
  toks <- quanteda::tokens(quanteda::corpus(utils::head(txt, 5000)))
  toks <- quanteda::tokens(toks, remove_punct = TRUE, remove_numbers = TRUE,
                           remove_symbols = TRUE)
  toks <- quanteda::tokens_tolower(toks)
  toks <- quanteda::tokens_remove(toks, quanteda::stopwords("es"))
  dfm <- quanteda::dfm(toks)
  tf <- quanteda::topfeatures(dfm, n)
  d <- data.frame(term = names(tf), n = as.numeric(tf))
  ggplot2::ggplot(d, ggplot2::aes(x = stats::reorder(term, n), y = n)) +
    ggplot2::geom_col(fill = "#2e7d32") +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Término", y = "Frecuencia",
                  title = sprintf("Términos más frecuentes (top %d)", n)) +
    ggplot2::theme_minimal(base_size = 11)
}

#' Histograma de polaridad léxica
#' @export
plot_polarity_hist <- function(sentiments) {
  d <- sentiments[sentiments$polarity != 0, ]
  ggplot2::ggplot(d, ggplot2::aes(x = polarity)) +
    ggplot2::geom_histogram(binwidth = 1, fill = "#1e5aa0", colour = "white") +
    ggplot2::labs(x = "Puntuación de polaridad léxica", y = "N.º de mensajes",
                  title = "Distribución de la polaridad (mensajes con señal ≠ 0)") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Mensajes por nivel de intensidad (mensajes con evidencia)
#' @export
plot_intensity_dist <- function(sentiments) {
  d <- sentiments[sentiments$evidence_level != "sin_evidencia", ]
  ggplot2::ggplot(d, ggplot2::aes(x = intensity)) +
    ggplot2::geom_bar(fill = "#b71c1c") +
    ggplot2::labs(x = "Intensidad (|puntuación|)", y = "N.º de mensajes",
                  title = "Intensidad de la señal emocional") +
    ggplot2::theme_minimal(base_size = 11)
}

# ----------------------------------------------------------------------------
# Generadores
# ----------------------------------------------------------------------------

#' Genera el conjunto ampliado de figuras del informe
#' @export
generate_extra_figures <- function(messages, sentiments, temporal, topics = NULL,
                                   fig_dir = proj_path("reports", "figures"),
                                   cfg = load_config()) {
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  arts <- character(0)
  add <- function(fig, name, w = 9, h = 5) {
    if (inherits(fig, "ggplot") && length(fig$layers)) {
      arts <<- c(arts, save_plot(fig, file.path(fig_dir, name), width = w, height = h))
    }
  }
  add(plot_evidence_dist(sentiments), "nivel_evidencia.png", 7, 5)
  add(plot_polarity_hist(sentiments), "hist_polaridad.png")
  add(plot_intensity_dist(sentiments), "intensidad.png")
  add(plot_volume_monthly(temporal$monthly), "volumen_mensual.png")
  add(plot_polarity_stacked(temporal$monthly), "polaridad_mensual_apilada.png", 10, 5)
  add(plot_emotion_heatmap(messages, sentiments), "emociones_por_anio.png", 9, 6)
  add(plot_top_emojis(messages, 15), "top_emojis.png", 7, 6)
  add(plot_top_reactions(messages, 12), "top_reacciones.png", 7, 5)
  add(plot_weekday(messages), "actividad_diasemana.png", 7, 5)
  add(plot_hour(messages), "actividad_hora.png", 9, 4)
  add(plot_top_terms(messages, 20), "top_terminos.png", 7, 6)
  if (!is.null(topics)) add(plot_topic_prevalence(topics), "prevalencia_topicos.png", 7, 4)
  arts
}

#' Genera el conjunto ampliado de tablas del informe
#' @export
generate_extra_tables <- function(messages, sentiments, temporal,
                                  tab_dir = proj_path("reports", "tables")) {
  dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)
  arts <- character(0)
  pct <- function(x) sprintf("%.1f\\%%", 100 * x)

  pol <- as.data.frame(table(polaridad = sentiments$polarity_label))
  names(pol)[2] <- "mensajes"
  pol$porcentaje <- pct(pol$mensajes / sum(pol$mensajes))
  arts <- c(arts, write_table(pol, "distribucion_polaridad", tab_dir,
                              caption = "Distribución de la polaridad"))

  ev <- as.data.frame(table(nivel = sentiments$evidence_level))
  names(ev)[2] <- "mensajes"; ev$porcentaje <- pct(ev$mensajes / sum(ev$mensajes))
  arts <- c(arts, write_table(ev, "nivel_evidencia", tab_dir,
                              caption = "Nivel de evidencia por mensaje"))

  tot <- emotion_totals(sentiments)
  emo <- data.frame(emocion = names(tot), ocurrencias = as.integer(tot))
  emo <- emo[order(-emo$ocurrencias), ]
  emo$sobre_analizados <- pct(emo$ocurrencias / sum(sentiments$evidence_level == "suficiente"))
  arts <- c(arts, write_table(utils::head(emo, 18), "frecuencia_emociones", tab_dir,
                              caption = "Frecuencia de emociones detectadas"))

  ec <- emoji_counts(messages)
  if (length(ec)) {
    d <- utils::head(as.data.frame(ec), 15); names(d) <- c("emoji", "ocurrencias")
    arts <- c(arts, write_table(d, "top_emojis", tab_dir,
                                caption = "Emojis más frecuentes"))
  }
  rc <- reaction_counts(messages)
  if (length(rc)) {
    d <- utils::head(as.data.frame(rc), 12); names(d) <- c("reaccion", "total")
    arts <- c(arts, write_table(d, "top_reacciones", tab_dir,
                                caption = "Reacciones más usadas"))
  }

  ts <- as.POSIXct(messages$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  yr <- as.data.frame(table(anio = format(ts, "%Y")))
  names(yr)[2] <- "mensajes"; yr$porcentaje <- pct(yr$mensajes / sum(yr$mensajes))
  arts <- c(arts, write_table(yr, "mensajes_por_anio", tab_dir,
                              caption = "Mensajes por año"))

  wd <- as.data.frame(table(dia = weekdays(ts))); names(wd)[2] <- "mensajes"
  tr <- c(Monday = "lunes", Tuesday = "martes", Wednesday = "miércoles",
          Thursday = "jueves", Friday = "viernes", Saturday = "sábado", Sunday = "domingo")
  wd$dia <- tr[as.character(wd$dia)]; wd <- wd[order(-wd$mensajes), ]
  wd$porcentaje <- pct(wd$mensajes / sum(wd$mensajes))
  arts <- c(arts, write_table(wd, "actividad_diasemana", tab_dir,
                              caption = "Actividad por día de la semana"))

  mt <- as.data.frame(table(tipo = ifelse(is.na(messages$media_type), "texto",
                                          messages$media_type)))
  names(mt)[2] <- "mensajes"; mt$porcentaje <- pct(mt$mensajes / sum(mt$mensajes))
  arts <- c(arts, write_table(mt, "tipos_media", tab_dir,
                              caption = "Tipos de contenido"))

  etl <- data.frame(
    etapa = c("Mensajes crudos", "Importados", "Rechazados (servicio)",
              "Rechazados (media sin texto)", "Duplicados de contenido",
              "Reenviados", "Editados", "Remitentes únicos"),
    valor = c(format(length(unique(messages$message_id)) + 6329, big.mark = "."),
              format(nrow(messages), big.mark = "."), "4.826", "1.503", "2",
              format(sum(messages$forwarded), big.mark = "."),
              format(sum(messages$edited), big.mark = "."),
              format(length(unique(messages$sender_id)), big.mark = ".")))
  arts <- c(arts, write_table(etl, "resumen_etl", tab_dir,
                              caption = "Resumen de la etapa de extracción y carga"))
  arts
}

#' Escribe un archivo de macros con cifras clave para el informe
#' @export
write_report_stats <- function(messages, sentiments, temporal, topics = NULL,
                               markov = NULL,
                               path = proj_path("reports", "generated", "stats.tex")) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  cov <- dictionary_coverage(sentiments)
  lab <- function(x) sum(sentiments$polarity_label == x)
  fmt <- function(x) format(x, big.mark = ".", decimal.mark = ",")
  ts <- as.POSIXct(messages$timestamp_utc, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ec <- emoji_counts(messages); rc <- reaction_counts(messages)
  tot <- emotion_totals(sentiments)
  top_emo <- names(tot)[which.max(tot)]
  wd <- table(weekdays(ts)); wd_top <- names(wd)[which.max(wd)]
  hr <- table(format(ts, "%H")); hr_top <- names(hr)[which.max(hr)]
  wd_tr <- c(Monday = "lunes", Tuesday = "martes", Wednesday = "miércoles",
             Thursday = "jueves", Friday = "viernes", Saturday = "sábado",
             Sunday = "domingo")
  m <- c(
    sprintf("\\renewcommand{\\nMensajes}{%s}", fmt(nrow(messages))),
    sprintf("\\renewcommand{\\nAnalizados}{%s}", fmt(nrow(sentiments))),
    sprintf("\\renewcommand{\\nSuficiente}{%s}", fmt(sum(sentiments$evidence_level == "suficiente"))),
    sprintf("\\renewcommand{\\nSinEvidencia}{%s}", fmt(sum(sentiments$evidence_level == "sin_evidencia"))),
    sprintf("\\renewcommand{\\pctCobertura}{%.1f}", 100 * cov$coverage),
    sprintf("\\renewcommand{\\pctIndeterminado}{%.1f}", 100 * cov$indeterminate),
    sprintf("\\renewcommand{\\nPositivos}{%s}", fmt(lab("positivo"))),
    sprintf("\\renewcommand{\\nNegativos}{%s}", fmt(lab("negativo"))),
    sprintf("\\renewcommand{\\nNeutros}{%s}", fmt(lab("neutro"))),
    sprintf("\\renewcommand{\\nIndeterminados}{%s}", fmt(lab("indeterminado"))),
    sprintf("\\renewcommand{\\pctPositivos}{%.1f}", 100 * lab("positivo") / sum(sentiments$evidence_level == "suficiente")),
    sprintf("\\renewcommand{\\pctNegativos}{%.1f}", 100 * lab("negativo") / sum(sentiments$evidence_level == "suficiente")),
    sprintf("\\renewcommand{\\manInicio}{%s}", format(min(ts, na.rm = TRUE), "%Y-%m-%d")),
    sprintf("\\renewcommand{\\manFin}{%s}", format(max(ts, na.rm = TRUE), "%Y-%m-%d")),
    sprintf("\\renewcommand{\\nRemitentes}{%s}", fmt(length(unique(messages$sender_id)))),
    sprintf("\\renewcommand{\\nReenviados}{%s}", fmt(sum(messages$forwarded, na.rm = TRUE))),
    sprintf("\\renewcommand{\\nEditados}{%s}", fmt(sum(messages$edited, na.rm = TRUE))),
    sprintf("\\renewcommand{\\diasActividad}{%s}", fmt(length(unique(as.Date(ts))))),
    sprintf("\\renewcommand{\\meses}{%s}", nrow(temporal$monthly)),
    sprintf("\\renewcommand{\\nTemas}{%s}", ifelse(is.null(topics), 0, nrow(topics$topics))),
    sprintf("\\renewcommand{\\emojiTop}{%s}", ifelse(length(ec), emoji_shortcode(names(ec)[1]), "--")),
    sprintf("\\renewcommand{\\emojiTopN}{%s}", ifelse(length(ec), fmt(as.integer(ec[1])), "0")),
    sprintf("\\renewcommand{\\reactTop}{%s}", ifelse(length(rc), emoji_shortcode(names(rc)[1]), "--")),
    sprintf("\\renewcommand{\\reactTopN}{%s}", ifelse(length(rc), fmt(as.integer(rc[1])), "0")),
    sprintf("\\renewcommand{\\emocionTop}{%s}", ifelse(is.null(top_emo), "--", top_emo)),
    sprintf("\\renewcommand{\\diaPico}{%s}", wd_tr[[wd_top]]),
    sprintf("\\renewcommand{\\horaPico}{%s}", sprintf("%s:00", hr_top)),
    sprintf("\\renewcommand{\\polaridadMedia}{%.3f}", mean(sentiments$polarity, na.rm = TRUE))
  )
  if (!is.null(markov) && length(markov$results)) {
    r <- markov$results[[1]]
    m <- c(m,
      sprintf("\\renewcommand{\\pctNeutro}{%.1f}", 100 * unname(r$stationary[["neutro"]])),
      sprintf("\\renewcommand{\\pctPositivoEst}{%.1f}", 100 * unname(r$stationary[["positivo"]])),
      sprintf("\\renewcommand{\\pctNegativoEst}{%.1f}", 100 * unname(r$stationary[["negativo"]])),
      sprintf("\\renewcommand{\\recuperacionNegativa}{%.2f}", r$recovery),
      sprintf("\\renewcommand{\\permanenciaPositivo}{%.2f}", unname(r$residence[["positivo"]])),
      sprintf("\\renewcommand{\\permanenciaNegativo}{%.2f}", unname(r$residence[["negativo"]])),
      sprintf("\\renewcommand{\\permanenciaNeutro}{%.2f}", unname(r$residence[["neutro"]])))
  }
  writeLines(m, path, useBytes = TRUE)
  invisible(path)
}
