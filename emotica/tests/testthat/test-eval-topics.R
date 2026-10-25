test_that("evaluacion: precision, recall, kappa y muestra", {
  m <- data.frame(msg_id = as.character(1:6), texto = c("feliz hoy dia", "estoy muy triste hoy", "gracias por todo amigos", "nada que decir aqui hoy", "estoy cansado de todo esto", "no entiendo nada de esto"), stringsAsFactors = FALSE)
  m$texto_limpio <- normalizar_texto(m$texto); m$idioma <- "es"; m$n_palabras <- 5
  s <- score_emotions(m)
  hoja <- tibble::tibble(msg_id = m$msg_id, emociones = c("alegria", "tristeza", "gratitud", "ninguna", "cansancio", "preocupacion"), intensidad = c("3", "4", "3", "", "3", "2"))
  ev <- evaluar_motor(s, hoja)
  expect_equal(ev$por_emocion$precision[ev$por_emocion$emocion_id == "alegria"], 1)
  expect_equal(ev$por_emocion$fn[ev$por_emocion$emocion_id == "preocupacion"], 1)
  expect_true(ev$global[["recall"]] < 1 && ev$global[["precision"]] < 1)
  h2 <- hoja; h2$emociones[2] <- "enojo"
  a <- acuerdo_etiquetadores(list(a = hoja, b = h2))
  expect_true(a$kappa < 1 && a$kappa > 0)
  ms <- muestra_para_etiquetar(m, s, n = 4, min_palabras = 3)
  expect_equal(nrow(ms$hoja), 4); expect_false("emocion_dominante_motor" %in% names(ms$hoja))
  expect_true(is.numeric(correlacion_intensidad(s, hoja)$spearman) || is.na(correlacion_intensidad(s, hoja)$spearman))
})

test_that("topicos: separa dos temas claros (NMF) y reporta periodo", {
  set.seed(3)
  a <- c("horario", "aula", "clase", "docente", "materia"); b <- c("pago", "banco", "deposito", "comprobante", "factura")
  dias <- sprintf("2024-06-%02d", 1:20)
  msgs <- do.call(rbind, lapply(seq_along(dias), function(i) { v <- if (i %% 2) a else b
    data.frame(msg_id = paste0(i, "_", 1:6), fecha = dias[i], periodo_id = "invierno_2024",
               texto_limpio = vapply(1:6, function(j) paste(sample(v, 4, TRUE), collapse = " "), ""), stringsAsFactors = FALSE) }))
  msgs$idioma <- "es"; msgs$temporada <- "invierno"; msgs$tiene_texto <- TRUE
  tok <- tokenizar_mensajes(msgs, idioma = "es")
  tk <- agrupar_documentos(tok, msgs, "dia", min_tokens = 5)
  dt <- matriz_doc_term(tk, min_docs = 2)
  mo <- ajustar_temas(dt$dtm, k = 2, metodo = "nmf", iter = 150)
  tt <- terminos_por_tema(mo, 5)
  grupo <- vapply(split(tt$termino, tt$tema), function(x) if (all(x %in% a)) "a" else if (all(x %in% b)) "b" else "mixto", "")
  expect_setequal(unname(grupo), c("a", "b"))
  expect_equal(nrow(temas_por_periodo(mo, dt$periodo)), 1)
  if (!requireNamespace("topicmodels", quietly = TRUE)) expect_error(ajustar_temas(dt$dtm, 2, "lda"), "topicmodels")
})
