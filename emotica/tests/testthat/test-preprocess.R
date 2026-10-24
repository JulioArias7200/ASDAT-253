sal <- "sal-de-prueba"
telegram_mini <- function() {
  f <- tempfile(fileext = ".json")
  writeLines(enc2utf8('{"name":"x","messages":[
   {"id":1,"type":"service","date":"2024-05-02T10:00:00","text":"","actor":"Ana","action":"join"},
   {"id":2,"type":"message","date":"2023-12-20T10:00:00","from":"Ana Perez","from_id":"user1","text":"No estoy nada tranquila, llamame al 70123456 o a ana@correo.com https://x.com","text_entities":[]},
   {"id":3,"type":"message","date":"2024-02-29T08:00:00","from":"Luis","from_id":"user2","reply_to_message_id":2,"text":[{"type":"link","text":"https://a.b"}," holaaaa muy feliz \\ud83d\\ude0a?"],"text_entities":[]},
   {"id":4,"type":"message","date":"2024-03-15T08:00:00","from":"Luis","from_id":"user2","text":"fuera de temporada gracias","text_entities":[]},
   {"id":5,"type":"message","date":"2024-05-01T08:00:00","from":"Ana Perez","from_id":"user1","text":"inicio del invierno, la verdad no me gusta","text_entities":[]}]}'), f)
  f
}

test_that("telegram: columnas del contrato, sin nombres reales, sin servicio", {
  r <- preprocess_chat(telegram_mini(), sal = sal)
  m <- r$mensajes
  expect_true(all(c("msg_id","fecha","autor_hash","texto","texto_limpio","idioma","responde_a","periodo_id") %in% names(m)))
  expect_equal(nrow(m), 4)
  expect_false(any(c("autor", "autor_id") %in% names(m)))
  expect_false(any(grepl("Ana|Perez|Luis", unlist(m), ignore.case = TRUE)))
  expect_equal(length(unique(m$autor_hash)), 2)
})

test_that("PII enmascarada", {
  m <- preprocess_chat(telegram_mini(), sal = sal)$mensajes
  expect_false(any(grepl("70123456|ana@correo|https://", m$texto)))
  expect_true(grepl("<NUM_ID>", m$texto[1]) && grepl("<EMAIL>", m$texto[1]))
})

test_that("periodos cruzan el anio y soportan 29 de febrero", {
  m <- preprocess_chat(telegram_mini(), sal = sal)$mensajes
  expect_equal(m$periodo_id, c("verano_2024", "verano_2024", "fuera", "invierno_2024"))
  p <- asignar_periodo(as.POSIXct(c("2030-12-05", "2031-01-10", "2030-06-01"), tz = "UTC"), cargar_config()$seasons)
  expect_equal(p$periodo_id, c("verano_2031", "verano_2031", "invierno_2030"))
})

test_that("negaciones e intensificadores sobreviven a las stopwords", {
  r <- preprocess_chat(telegram_mini(), sal = sal)
  tk <- filtrar_tokens(r$tokens)
  expect_true(all(c("no", "muy", "nada") %in% tk$token))
  expect_false("de" %in% tk$token)
  expect_true("\U0001F60A" %in% tk$token)
  expect_true(r$mensajes$es_pregunta[2])
})

test_that("bitacora registra cada paso", {
  b <- preprocess_chat(telegram_mini(), sal = sal)$bitacora
  expect_true(all(c("lectura_archivo","normalizar_fechas","anonimizar_autores","enmascarar_pii","asignar_periodos","tokenizar") %in% b$paso))
  expect_true(all(c("paso","parametros","filas_entrada","filas_salida","huella_archivo","fecha_hora","usuario") %in% names(b)))
  expect_equal(b$filas_salida[b$paso == "filtrar_eventos_de_servicio"], 4)
})

test_that("CSV de otra universidad: separador ;, columnas en ingles/portugues, dd/mm/yyyy, otro idioma", {
  f <- tempfile(fileext = ".csv")
  n <- 30
  d <- data.frame(timestamp = sprintf("%02d/07/2025 10:%02d", (seq_len(n) %% 27) + 1, seq_len(n)),
                  sender = rep(c("Maria", "Joao", "Ana"), 10),
                  message = rep(c("I am very happy with the course and I think it was really good",
                                  "the teacher is not clear and we have a lot of questions about the exam",
                                  "thanks for all the help with the project it was great"), 10))
  write.table(d, f, sep = ";", row.names = FALSE, fileEncoding = "UTF-8")
  r <- preprocess_chat(f, sal = sal)
  expect_equal(r$idioma$idioma, "en")
  expect_equal(nrow(r$mensajes), n)
  expect_true(all(r$mensajes$periodo_id == "invierno_2025"))
  expect_true(any(grepl("mapeo=", r$bitacora$detalle)))
})

test_that("WhatsApp .txt", {
  f <- tempfile(fileext = ".txt")
  writeLines(enc2utf8(c("12/03/2024, 10:15 - Ana: hola a todos, muy buenos dias",
                        "continua en otra linea del mismo mensaje",
                        "12/03/2024, 10:20 - Luis: gracias por la ayuda, estoy tranquilo",
                        "12/03/2024, 10:21 - Se unio Pedro")), f)
  m <- preprocess_chat(f, sal = sal)$mensajes
  expect_equal(nrow(m), 2)
  expect_true(grepl("otra linea", m$texto[1]))
})

test_that("error claro si no se reconocen las columnas", {
  f <- tempfile(fileext = ".csv"); writeLines(c("a,b", "1,2"), f)
  expect_error(preprocess_chat(f, sal = sal), "No pude identificar")
})
