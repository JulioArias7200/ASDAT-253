make_fake_data <- function() {
  sentiments <- tibble::tibble(
    message_id = 1:4,
    polarity_label = c("positivo", "negativo", "indeterminado", "positivo"),
    evidence_level = c("suficiente", "suficiente", "sin_evidencia", "suficiente"),
    emotion_scores = c('{"alegria":1}', '{"tristeza":1}', '{}', '{"alegria":2}'),
    detected_emotions = c('["alegria"]', '["tristeza"]', '[]', '["alegria"]'),
    dominant_emotion = c("alegria", "tristeza", NA, "alegria"))
  messages <- tibble::tibble(
    message_id = 1:4,
    text_original = c("feliz", "triste", "neutro", "muy feliz"),
    timestamp_utc = c("2023-01-01T00:00:00Z", "2023-02-01T00:00:00Z",
                      "2023-03-01T00:00:00Z", "2023-04-01T00:00:00Z"),
    sender_id = c("s1", "s2", "s3", "s1"),
    sender_name = c("a", "b", "c", "a"),
    emoji_list = c("[]", "[]", "[]", "[]"))
  list(sentiments = sentiments, messages = messages)
}

test_that("filter_messages sin filtros devuelve todo", {
  d <- make_fake_data()
  df <- filter_messages(d)
  expect_equal(nrow(df), 4)
  expect_true("ts" %in% names(df))
})

test_that("filter_messages respeta polaridad y evidencia", {
  d <- make_fake_data()
  expect_equal(nrow(filter_messages(d, polarities = "positivo")), 2)
  expect_equal(nrow(filter_messages(d, evidence = "sin_evidencia")), 1)
})

test_that("filter_messages filtra por emociones detectadas", {
  d <- make_fake_data()
  expect_equal(nrow(filter_messages(d, emotions = "tristeza")), 1)
})

test_that("filter_messages filtra por rango de fechas", {
  d <- make_fake_data()
  df <- filter_messages(d, date_range = as.Date(c("2023-01-15", "2023-03-15")))
  expect_equal(nrow(df), 2)
})

test_that("emotion_totals agrega las puntuaciones JSON", {
  d <- make_fake_data()
  tot <- emotion_totals(d$sentiments)
  expect_equal(unname(tot[["alegria"]]), 3)
  expect_equal(unname(tot[["tristeza"]]), 1)
})

test_that("as_icon genera SVG en línea", {
  expect_match(as_icon("heart"), "<svg")
  expect_match(as_icon("no-existe"), "<svg")
})

test_that("opt_clean elimina entradas NULL", {
  o <- opt_clean(list(a = 1, b = NULL, c = 3))
  expect_equal(sort(names(o)), c("a", "c"))
})

test_that("constructores de opciones ECharts tienen la forma esperada", {
  d <- data.frame(a = c("x", "y"), b = c(2, 1))
  p <- opt_donut(d)
  expect_equal(p$series[[1]]$type, "pie")
  expect_equal(length(p$series[[1]]$data), 2)
  expect_equal(opt_hbar(d)$series[[1]]$type, "bar")
  expect_equal(opt_vbar(d$a, d$b)$series[[1]]$type, "bar")
  line <- opt_line(1:3, list(A = 1:3, B = 3:1))
  expect_equal(length(line$series), 2)
  P <- matrix(c(.5, .2, .3, .1, .6, .3, .2, .1, .7), 3, 3)
  hm <- opt_heatmap(c("positivo", "negativo", "neutro"), P)
  expect_equal(hm$series[[1]]$type, "heatmap")
  expect_equal(hm$visualMap$max, 100)
})

test_that("as_kpi produce un contador con atributos", {
  k <- as_kpi(1234, "Mensajes", icon = "chat")
  html <- as.character(k)
  expect_match(html, "as-kpi")
  expect_match(html, "data-countup")
})

test_that("mod_overview renderiza sus gráficos ECharts", {
  d <- make_fake_data()
  shiny::testServer(mod_overview_server, args = list(data = d, con = NULL), {
    session$setInputs()
    expect_error(session$flushReact(), NA)
  })
})

test_that("mod_overview ya no incluye el avatar (vive solo en su pestaña)", {
  ui_html <- as.character(mod_overview_ui("ov"))
  expect_false(grepl("as-avatar-host", ui_html, fixed = TRUE))
  expect_false(grepl("avatar_emo", ui_html, fixed = TRUE))
  expect_false(grepl("Estado de la última ejecución", ui_html, fixed = TRUE))
  expect_false(grepl("last_run", ui_html, fixed = TRUE))
})

test_that("apply_dashboard_recompute copia sólo las claves del dashboard", {
  rv <- shiny::reactiveValues()
  apply_dashboard_recompute(rv, list(sentiments = data.frame(x = 1),
                                     temporal = list(daily = 1),
                                     desconocida = "ignoralo"))
  expect_equal(shiny::isolate(nrow(rv$sentiments)), 1)
  expect_equal(shiny::isolate(names(rv$temporal)), "daily")
  expect_null(shiny::isolate(rv$desconocida))
})

test_that("los módulos de datos funcionan con reactiveValues (diccionario re-activado)", {
  d <- make_fake_data()
  rv <- shiny::reactiveValues(messages = d$messages, sentiments = d$sentiments,
                              topics = NULL, markov = NULL)
  shiny::testServer(mod_sentiment_server, args = list(data = rv), {
    session$setInputs()
    expect_error(session$flushReact(), NA)
  })
  shiny::testServer(mod_avatar_server, args = list(data = rv), {
    session$setInputs()
    expect_error(session$flushReact(), NA)
  })
  shiny::testServer(mod_overview_server, args = list(data = rv, con = NULL), {
    session$setInputs()
    expect_error(session$flushReact(), NA)
  })
})

test_that("opt_donut envia la paleta sin nombres (jsonlite)", {
  d <- data.frame(label = c("positivo", "negativo"), Freq = c(2, 1))
  o <- opt_donut(d, palette = c(positivo = "#10b981", negativo = "#ef4444"))
  expect_type(o$color, "character")
  expect_null(names(o$color))
})

test_that("mod_topics funciona con reactiveValues (bug tt)", {
  tv <- shiny::reactiveValues()
  tv$topics <- list(topics = data.frame(topic = 1:2, top_words = c("a, b", "c, d")))
  shiny::testServer(mod_topics_server, args = list(data = tv), {
    session$setInputs(topic = "1")
    expect_error(session$flushReact(), NA)
  })
})

