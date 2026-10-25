normalizar_clave <- function(x) stringi::stri_trans_general(stringi::stri_trans_tolower(x), "Latin-ASCII")

cargar_taxonomia <- function(path = ruta_recurso("resources", "taxonomy", "emotions.yml")) {
  y <- leer_yaml(path)
  tibble::tibble(
    id = vapply(y, function(e) as.character(e$id), ""),
    nombre = vapply(y, function(e) as.character(e$nombre %si_vacio% e$id), ""),
    valencia = vapply(y, function(e) as.character(e$valencia %si_vacio% "ambigua"), ""),
    activacion = vapply(y, function(e) as.character(e$activacion %si_vacio% "media"), ""),
    opuesta = vapply(y, function(e) as.character(e$opuesta %si_vacio% NA_character_), ""),
    activa = vapply(y, function(e) isTRUE(e$activa %si_vacio% TRUE), logical(1)))
}

guardar_taxonomia <- function(tax, path = ruta_recurso("resources", "taxonomy", "emotions.yml")) {
  l <- lapply(seq_len(nrow(tax)), function(i) {
    e <- list(id = tax$id[i], nombre = tax$nombre[i], valencia = tax$valencia[i],
              activacion = tax$activacion[i])
    if (!is.na(tax$opuesta[i])) e$opuesta <- tax$opuesta[i]
    e$activa <- tax$activa[i]; e })
  txt <- yaml::as.yaml(l)
  con <- file(path, "wb"); on.exit(close(con)); writeBin(charToRaw(enc2utf8(txt)), con)
  invisible(path)
}

cargar_lexicon <- function(idioma = "es") {
  vacio <- tibble::tibble(termino = character(), emocion_id = character(), peso = numeric(),
                          tipo = character(), fuente = character(), contexto = character(), clave = character())
  fs <- list.files(ruta_recurso("resources", "lexicons", idioma), pattern = "\\.csv$", full.names = TRUE)
  if (length(fs) == 0) return(vacio)
  lex <- do.call(rbind, lapply(fs, function(f) {
    d <- readr::read_csv(f, col_types = readr::cols(.default = "c"),
                         locale = readr::locale(encoding = "UTF-8"), progress = FALSE)
    if (!"fuente" %in% names(d)) d$fuente <- basename(f)
    if (!"contexto" %in% names(d)) d$contexto <- ""
    d$contexto[is.na(d$contexto)] <- ""
    d[, c("termino", "emocion_id", "peso", "tipo", "fuente", "contexto")] }))
  lex$peso <- as.numeric(lex$peso)
  lex$clave <- normalizar_clave(lex$termino)
  tibble::as_tibble(lex)
}

# Devuelve un data.frame de problemas (vacio = lexico valido)
validar_lexicon <- function(lex, tax) {
  p <- function(msg, filas) if (length(filas)) data.frame(problema = msg, termino = lex$termino[filas], emocion_id = lex$emocion_id[filas]) else NULL
  r <- rbind(
    p("emocion_id no existe en la taxonomia", which(!lex$emocion_id %in% tax$id)),
    p("peso fuera de (0, 3]", which(is.na(lex$peso) | lex$peso <= 0 | lex$peso > 3)),
    p("tipo invalido (palabra|frase|regex|emoji)", which(!lex$tipo %in% c("palabra", "frase", "regex", "emoji"))),
    p("duplicado (termino + emocion)", which(duplicated(paste(lex$clave, lex$emocion_id)))),
    if ("contexto" %in% names(lex)) p("contexto invalido (vacio|pregunta|no_pregunta)", which(!lex$contexto %in% c("", "pregunta", "no_pregunta"))))
  if (is.null(r)) data.frame(problema = character(), termino = character(), emocion_id = character()) else r
}

set_active <- function(tax, ids) { tax$activa <- tax$id %in% ids; tax }

# Agrega una emocion NUEVA sin tocar codigo. semillas: vector de texto, o numerico con nombres (nombre = termino, valor = peso)
add_emotion <- function(id, nombre, valencia, semillas, emojis = NULL, activacion = "media",
                        opuesta = NULL, idioma = "es", persistir = TRUE, taxonomy = cargar_taxonomia()) {
  if (!grepl("^[a-z][a-z0-9_]*$", id)) stop("id invalido: use minusculas, numeros y _ (ej. 'nostalgia').")
  if (id %in% taxonomy$id) stop("La emocion '", id, "' ya existe.")
  if (!valencia %in% c("positiva", "negativa", "ambigua")) stop("valencia debe ser positiva, negativa o ambigua.")
  if (!is.null(opuesta) && !opuesta %in% taxonomy$id) stop("La emocion opuesta '", opuesta, "' no existe.")
  pesos <- if (is.numeric(semillas) && !is.null(names(semillas))) as.numeric(semillas) else rep(1, length(semillas))
  terminos <- if (is.numeric(semillas) && !is.null(names(semillas))) names(semillas) else as.character(semillas)
  if (length(terminos) < 5) stop("Se necesitan al menos 5 semillas (recomendado: 8 a 15). Recibidas: ", length(terminos))
  avisos <- character()
  if (length(terminos) < 8) avisos <- c(avisos, "Pocas semillas (<8): la confianza y la cobertura seran bajas.")
  nuevo <- tibble::tibble(termino = terminos, emocion_id = id, peso = pesos,
                          tipo = ifelse(grepl("\\s", terminos), "frase", "palabra"), fuente = "usuario", contexto = "")
  if (length(emojis)) nuevo <- rbind(nuevo, tibble::tibble(termino = emojis, emocion_id = id, peso = 1,
                                                          tipo = "emoji", fuente = "usuario", contexto = ""))
  nuevo$clave <- normalizar_clave(nuevo$termino)
  existente <- cargar_lexicon(idioma)
  conf <- existente[existente$clave %in% nuevo$clave, c("termino", "emocion_id", "peso")]
  if (nrow(conf)) avisos <- c(avisos, sprintf("%d semilla(s) ya pertenecen a otra emocion (conflicto): %s",
                                              nrow(conf), paste(unique(conf$termino), collapse = ", ")))
  tax2 <- rbind(taxonomy, tibble::tibble(id = id, nombre = nombre, valencia = valencia, activacion = activacion,
                                         opuesta = opuesta %si_vacio% NA_character_, activa = TRUE))
  if (persistir) {
    guardar_taxonomia(tax2)
    dir.create(ruta_recurso("resources", "lexicons", idioma), showWarnings = FALSE, recursive = TRUE)
    readr::write_csv(nuevo[, c("termino", "emocion_id", "peso", "tipo", "fuente", "contexto")],
                     ruta_recurso("resources", "lexicons", idioma, paste0("usuario_", id, ".csv")))
  }
  bitacora_registrar("agregar_emocion", list(id = id, valencia = valencia, semillas = length(terminos),
                     emojis = length(emojis)), NA, nrow(nuevo), paste(avisos, collapse = " "))
  list(taxonomy = tax2, lexicon_nuevo = nuevo, conflictos = conf, avisos = avisos)
}

# Terminos candidatos que aparecen junto a las semillas (PMI a nivel de mensaje). La persona acepta o rechaza.
suggest_terms <- function(mensajes, semillas, n = 20, min_total = 5, idioma = NULL) {
  idioma <- idioma %si_vacio% unique(mensajes$idioma)[1]
  k <- normalizar_clave(mensajes$texto_limpio); k[is.na(k)] <- ""
  sem <- normalizar_clave(semillas)
  kk <- paste0(" ", k, " ")
  tiene <- Reduce(`|`, lapply(sem, function(s) stringi::stri_detect_fixed(kk, paste0(" ", s, " "))))
  if (sum(tiene) < 3) stop("Las semillas aparecen en menos de 3 mensajes del corpus: no hay base para sugerir.")
  toks <- lapply(stringi::stri_split_regex(k, "\\s+", omit_empty = TRUE), unique)
  tf_all <- table(unlist(toks)); tf_sem <- table(unlist(toks[tiene]))
  sw <- normalizar_clave(setdiff(cargar_stopwords(idioma), cargar_config()$params$conservar_siempre))
  cand <- setdiff(names(tf_sem)[tf_sem >= 3], c(sw, sem, ""))
  cand <- cand[nchar(cand) >= 3 & !grepl("^\\d+$", cand) & tf_all[cand] >= min_total]
  N <- length(toks); ns <- sum(tiene)
  pmi <- log2((as.numeric(tf_sem[cand]) / ns) / (as.numeric(tf_all[cand]) / N))
  out <- tibble::tibble(termino = cand, con_semilla = as.integer(tf_sem[cand]),
                        total = as.integer(tf_all[cand]), pmi = round(pmi, 2),
                        puntaje = round(pmi * log1p(as.numeric(tf_sem[cand])), 2))
  out <- out[order(-out$puntaje), ]
  utils::head(out, n)
}
