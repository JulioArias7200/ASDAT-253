# Dashboard local con carga en vivo.  Uso:  shiny::runApp("app")   (desde la raiz del proyecto)
library(shiny)
raiz_proy <- if (file.exists("DESCRIPTION") && dir.exists("R")) normalizePath(".") else normalizePath("..")
options(emotica.raiz = raiz_proy, shiny.maxRequestSize = 500 * 1024^2)
for (f in list.files(file.path(raiz_proy, "R"), pattern = "\\.R$", full.names = TRUE)) source(f, encoding = "UTF-8", local = FALSE)

ui <- fluidPage(
  titlePanel("emotica: emociones en chats, en vivo"),
  sidebarLayout(
    sidebarPanel(width = 4,
      fileInput("archivo", "1. Cargue un chat (.json Telegram, .txt WhatsApp, .csv)", accept = c(".json", ".txt", ".csv", ".tsv")),
      uiOutput("mapeo_ui"),
      actionButton("procesar", "2. Procesar", class = "btn-primary"),
      textOutput("estado"),
      hr(),
      checkboxGroupInput("activas", "3. Emociones activas", choices = NULL),
      hr(),
      strong("4. Agregar una emoción nueva"),
      textInput("id_emo", "Identificador (minúsculas, sin espacios)", placeholder = "urgencia"),
      textInput("nombre_emo", "Nombre", placeholder = "Urgencia"),
      selectInput("valencia", "Valencia", c("positiva", "negativa", "ambigua")),
      textAreaInput("semillas", "Semillas (una por línea, mínimo 5; opcional 'termino=peso')", rows = 6),
      textInput("emojis", "Emojis (separados por espacio)"),
      checkboxInput("persistir", "Guardar en los archivos del proyecto", FALSE),
      actionButton("sugerir", "Sugerir términos"), actionButton("agregar", "Agregar emoción")),
    mainPanel(width = 8, tabsetPanel(
      tabPanel("Resumen", tableOutput("resumen"), selectInput("periodos", "Periodos", NULL, multiple = TRUE), plotOutput("grafico", height = 420)),
      tabPanel("Ejemplos", selectInput("emo_ej", "Emoción", NULL), tableOutput("ejemplos")),
      tabPanel("Bitácora", downloadButton("bajar_bitacora", "Descargar CSV"), tableOutput("bitacora")),
      tabPanel("Temas", numericInput("k_temas", "Número de temas", 8, 2, 20), actionButton("temas", "Ajustar temas"),
               tableOutput("terminos"), plotOutput("plot_temas", height = 380)),
      tabPanel("Sugerencias", tableOutput("sug"))))))

server <- function(input, output, session) {
  rv <- reactiveValues(res = NULL, tax = cargar_taxonomia(), lex = cargar_lexicon("es"), sug = NULL,
                       temas = NULL, err = NULL, cols = NULL, tick = 0)
  refrescar_emociones <- function(sel = NULL) {
    ch <- setNames(rv$tax$id, rv$tax$nombre)
    updateCheckboxGroupInput(session, "activas", choices = ch, selected = sel %si_vacio% rv$tax$id[rv$tax$activa])
    updateSelectInput(session, "emo_ej", choices = ch)
  }
  observe(refrescar_emociones()) |> bindEvent(TRUE, once = TRUE)

  output$mapeo_ui <- renderUI({
    req(rv$cols)
    tagList(helpText("No identifiqué las columnas. Indíquelas:"),
      selectInput("map_texto", "Texto", rv$cols), selectInput("map_fecha", "Fecha", rv$cols),
      selectInput("map_autor", "Autor", c("(ninguna)", rv$cols)))
  })

  observeEvent(input$procesar, {
    req(input$archivo)
    mp <- NULL
    if (!is.null(rv$cols) && !is.null(input$map_texto)) {
      mp <- list(texto = input$map_texto, fecha = input$map_fecha)
      if (!identical(input$map_autor, "(ninguna)")) mp$autor <- input$map_autor
    }
    r <- withProgress(message = "Preprocesando...", value = 0.3,
      tryCatch(preprocess_chat(input$archivo$datapath, mapping = mp, usuario = "dashboard"), error = function(e) e))
    if (inherits(r, "error")) {
      rv$err <- conditionMessage(r)
      if (grepl("Columnas disponibles", rv$err))
        rv$cols <- strsplit(sub(".*Columnas disponibles: (.*)\\. Indique.*", "\\1", rv$err), ", ")[[1]]
      return(invisible())
    }
    rv$err <- NULL; rv$cols <- NULL; rv$res <- r; rv$temas <- NULL; rv$tick <- rv$tick + 1
    per <- setdiff(sort(unique(r$mensajes$periodo_id)), "fuera")
    updateSelectInput(session, "periodos", choices = per, selected = per)
  })
  output$estado <- renderText({
    if (!is.null(rv$err)) paste("Error:", rv$err)
    else if (!is.null(rv$res)) sprintf("Listo: %d mensajes, idioma '%s'.", nrow(rv$res$mensajes), rv$res$idioma$idioma) else ""
  })

  scores <- reactive({
    req(rv$res)
    act <- if (is.null(input$activas)) rv$tax$id else input$activas
    withProgress(message = "Calculando emociones...", value = 0.5,
      score_emotions(rv$res$mensajes, set_active(rv$tax, act), rv$lex))
  })

  output$resumen <- renderTable({
    s <- scores(); cb <- cobertura_emociones(s, rv$res$mensajes)
    data.frame(Indicador = c("Mensajes con texto", "Con alguna emoción", "Cobertura", "Idioma detectado"),
               Valor = c(cb$mensajes_con_texto, cb$con_emocion, sprintf("%.1f %%", 100 * cb$cobertura), rv$res$idioma$idioma))
  })
  output$grafico <- renderPlot({
    s <- scores(); req(nrow(s) > 0, input$periodos)
    r <- resumen_por_periodo(s, rv$res$mensajes); r <- r[r$periodo_id %in% input$periodos, ]
    w <- tapply(r$tasa_x1000, list(r$emocion_id, r$periodo_id), sum); w[is.na(w)] <- 0
    par(mar = c(8, 4, 2, 1))
    barplot(t(w), beside = TRUE, las = 2, ylab = "mensajes por 1000", legend.text = colnames(w),
            args.legend = list(x = "topright", cex = 0.7), main = "Tasa de emociones por periodo")
  })
  output$ejemplos <- renderTable({
    s <- scores(); req(input$emo_ej); d <- s[s$emocion_id == input$emo_ej, ]; req(nrow(d) > 0)
    d <- utils::head(d[order(-d$puntaje), ], 20)
    data.frame(texto = substr(rv$res$mensajes$texto[match(d$msg_id, rv$res$mensajes$msg_id)], 1, 140),
               puntaje = d$puntaje, nivel = d$nivel, evidencia = d$evidencia)
  })
  output$bitacora <- renderTable({ rv$tick; bitacora_leer()[, c("paso", "filas_entrada", "filas_salida", "duracion_s", "detalle")] })
  output$bajar_bitacora <- downloadHandler("bitacora_auto.csv", function(file) readr::write_csv(bitacora_leer(), file))

  semillas_input <- reactive({
    l <- trimws(strsplit(input$semillas %si_vacio% "", "\n")[[1]]); l <- l[nzchar(l)]
    if (any(grepl("=", l))) { p <- strsplit(l, "="); setNames(vapply(p, function(x) if (length(x) > 1) as.numeric(x[2]) else 1, numeric(1)), vapply(p, `[`, "", 1)) } else l
  })
  observeEvent(input$sugerir, {
    req(rv$res)
    sm <- semillas_input(); sm <- if (is.numeric(sm)) names(sm) else sm
    rv$sug <- tryCatch(suggest_terms(rv$res$mensajes, sm, n = 20), error = function(e) data.frame(aviso = conditionMessage(e)))
  })
  output$sug <- renderTable(rv$sug)
  observeEvent(input$agregar, {
    r <- tryCatch(add_emotion(trimws(input$id_emo), input$nombre_emo, input$valencia, semillas_input(),
                              emojis = strsplit(trimws(input$emojis %si_vacio% ""), "\\s+")[[1]][nzchar(trimws(input$emojis %si_vacio% ""))],
                              persistir = isTRUE(input$persistir), taxonomy = rv$tax), error = function(e) e)
    if (inherits(r, "error")) return(showNotification(conditionMessage(r), type = "error", duration = 10))
    rv$tax <- r$taxonomy; rv$lex <- rbind(rv$lex, r$lexicon_nuevo); rv$tick <- rv$tick + 1
    refrescar_emociones(c(input$activas, trimws(input$id_emo)))
    showNotification(paste(c("Emoción agregada.", r$avisos), collapse = " "), type = "message", duration = 8)
  })

  observeEvent(input$temas, {
    req(rv$res)
    withProgress(message = "Ajustando temas...", value = 0.4, {
      tk <- agrupar_documentos(rv$res$tokens, rv$res$mensajes, "dia", min_tokens = 20)
      dt <- matriz_doc_term(tk, min_docs = 5)
      rv$temas <- list(modelo = ajustar_temas(dt$dtm, input$k_temas, "auto"), periodo = dt$periodo)
    })
  })
  output$terminos <- renderTable({
    req(rv$temas); tt <- terminos_por_tema(rv$temas$modelo, 8)
    data.frame(tema = unique(tt$tema), terminos = vapply(unique(tt$tema), function(t) paste(tt$termino[tt$tema == t], collapse = ", "), ""))
  })
  output$plot_temas <- renderPlot({
    req(rv$temas); tp <- temas_por_periodo(rv$temas$modelo, rv$temas$periodo); tp <- tp[rownames(tp) != "fuera", , drop = FALSE]
    par(mar = c(8, 4, 2, 1)); barplot(t(tp), las = 2, legend.text = colnames(tp), args.legend = list(x = "topright", cex = 0.7),
                                       ylab = "proporción", main = "Temas por periodo")
  })
}
shinyApp(ui, server)
