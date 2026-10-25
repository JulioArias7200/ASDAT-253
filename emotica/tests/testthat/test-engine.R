mk <- function(txt) {
  m <- data.frame(msg_id = as.character(seq_along(txt)), texto = txt, stringsAsFactors = FALSE)
  m$texto_limpio <- normalizar_texto(m$texto); m$idioma <- "es"; m
}
pt <- function(txt, emo) { s <- score_emotions(mk(txt)); s$puntaje[s$emocion_id == emo][1] %si_vacio% 0 }

test_that("lexico valido: ids existentes, pesos, tipos, sin duplicados, 15 emociones con >= 8 terminos", {
  tax <- cargar_taxonomia(); lex <- cargar_lexicon("es")
  expect_equal(nrow(validar_lexicon(lex, tax)), 0)
  expect_equal(nrow(tax), 15)
  expect_true(all(table(lex$emocion_id) >= 8))
})

test_that("pesos: intensificadores, signos y mayusculas aumentan; atenuadores reducen", {
  expect_gt(pt("estoy muy feliz", "alegria"), pt("estoy feliz", "alegria"))
  expect_gt(pt("estoy feliz!!!", "alegria"), pt("estoy feliz", "alegria"))
  expect_gt(pt("ESTOY MUY FELIZ", "alegria"), pt("estoy muy feliz", "alegria"))
  expect_lt(pt("estoy poco feliz", "alegria"), pt("estoy feliz", "alegria"))
})

test_that("el significado pesa: 'aprobe con 85' != 'aprobe raspando' != 'no aprobe'", {
  s <- score_emotions(mk(c("aprob\u00e9 con 85", "aprob\u00e9 raspando", "no aprob\u00e9")))
  g <- function(i, e) { x <- s$puntaje[s$msg_id == i & s$emocion_id == e]; if (length(x)) x else 0 }
  expect_gt(g("1", "alegria"), g("2", "alegria"))
  expect_gt(g("2", "tranquilidad"), g("2", "alegria"))
  expect_equal(g("3", "alegria"), 0)
  expect_gt(g("3", "decepcion"), 0)
})

test_that("negacion: no suma a su emocion, pasa a la opuesta con evidencia NEG", {
  s <- score_emotions(mk("no estoy tranquila"))
  expect_false("tranquilidad" %in% s$emocion_id)
  expect_true("preocupacion" %in% s$emocion_id)
  expect_true(grepl("NEG", s$evidencia[s$emocion_id == "preocupacion"]))
})

test_that("DINAMICO: active= limita las emociones evaluadas", {
  m <- mk(c("estoy feliz pero triste", "gracias"))
  s <- score_emotions(m, active = c("alegria", "tristeza"))
  expect_setequal(unique(s$emocion_id), c("alegria", "tristeza"))
  s2 <- score_emotions(m, taxonomy = set_active(cargar_taxonomia(), "gratitud"))
  expect_setequal(unique(s2$emocion_id), "gratitud")
})

test_that("DINAMICO: una emocion nueva funciona sin tocar codigo", {
  m <- mk(c("qu\u00e9 nostalgia de esos tiempos, extra\u00f1o la \u00e9poca", "hola"))
  expect_false("nostalgia" %in% score_emotions(m)$emocion_id)
  r <- add_emotion("nostalgia", "Nostalgia", "ambigua",
                   c(nostalgia = 1.5, "extra\u00f1o la \u00e9poca" = 1.2, recuerdos = 1, "viejos tiempos" = 1, "a\u00f1oro" = 1.2, "tiempos pasados" = 1),
                   emojis = "\U0001f570", persistir = FALSE)
  expect_true("nostalgia" %in% r$taxonomy$id)
  s <- score_emotions(m, taxonomy = r$taxonomy, lexicon = rbind(cargar_lexicon("es"), r$lexicon_nuevo))
  expect_true("nostalgia" %in% s$emocion_id)
  expect_error(add_emotion("x1", "X", "positiva", c("a", "b"), persistir = FALSE), "al menos 5")
  expect_error(add_emotion("alegria", "A", "positiva", letters[1:6], persistir = FALSE), "ya existe")
  c2 <- add_emotion("otra", "Otra", "positiva", c("feliz", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete"), persistir = FALSE)
  expect_true(nrow(c2$conflictos) >= 1)
})

test_that("DINAMICO: el codigo no menciona ninguna emocion por nombre", {
  ids <- cargar_taxonomia()$id
  codigo <- unlist(lapply(list.files(file.path(raiz(), "R"), full.names = TRUE), readLines, encoding = "UTF-8", warn = FALSE))
  codigo <- codigo[!grepl("^\\s*#", codigo)]
  for (id in ids) expect_false(any(grepl(paste0("\\b", id, "\\b"), codigo)), info = id)
})

test_that("idioma sin lexico: advierte y no inventa", {
  m <- mk("i am very happy"); m$idioma <- "en"
  expect_warning(s <- score_emotions(m, idioma = "en"), "Sin lexico")
  expect_equal(nrow(s), 0)
})

test_that("suggest_terms propone vecinos de las semillas", {
  txt <- c(rep("extra\u00f1o la universidad y los recuerdos de antes", 6), rep("recuerdos de la universidad nos hacen extra\u00f1o", 4), rep("quiero el horario de clases", 8))
  s <- suggest_terms(mk(txt), c("extra\u00f1o"), n = 5, min_total = 3)
  expect_true("recuerdos" %in% s$termino)
})

test_that("contexto: 'se puede' suma esperanza solo si NO es pregunta", {
  s <- score_emotions(mk(c("se puede lograr con esfuerzo", "\u00bfse puede inscribir hoy?")))
  expect_true("1" %in% s$msg_id[s$emocion_id == "esperanza"])
  expect_false("2" %in% s$msg_id[s$emocion_id == "esperanza"])
})

test_that("anuncios: marca difusiones y spam, no preguntas ni quejas reales", {
  anun <- paste0("\U0001F4E2 \u00a1Inscr\u00edbete GRATIS al taller!\n\U0001F5D3 Fecha: s\u00e1bado\n\U0001F551 Hora: 18:00\n\U0001F4BB Modalidad: virtual <URL>")
  m <- data.frame(msg_id = as.character(1:5), texto = c(anun, "alguien sabe si hay cupo? estoy muy preocupado",
        "No puede ser xd, otra vez sin cupo \U0001F621", paste(rep("la materia es muy dificil y el docente no explica bien, estoy cansado de reclamar", 4), collapse = " "),
        "Gana dinero r\u00e1pido con apuestas"), stringsAsFactors = FALSE)
  m$idioma <- "es"
  r <- marcar_anuncios(m)
  expect_equal(r$es_anuncio, c(TRUE, FALSE, FALSE, FALSE, TRUE))
})

test_that("el motor excluye anuncios (y se puede desactivar)", {
  m <- data.frame(msg_id = c("1", "2"), texto = c("estoy muy feliz", "estoy muy feliz"), stringsAsFactors = FALSE)
  m$texto_limpio <- normalizar_texto(m$texto); m$idioma <- "es"; m$es_anuncio <- c(TRUE, FALSE)
  expect_equal(score_emotions(m)$msg_id, "2")
  p <- cargar_params_motor(); p$excluir_anuncios <- FALSE
  expect_setequal(score_emotions(m, params = p)$msg_id, c("1", "2"))
})
