# =============================================================================
# 13_diccionario_emojis.R — Conteo y diccionario semántico de emojis
#
# Uso: Rscript scripts/13_diccionario_emojis.R
#
# Lee DIRECTAMENTE de data/raw/result.json (o result.json) sin depender
# de pasos previos ni bases de datos.
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(stringi)
  library(dplyr)
  library(readr)
})

cat("\n")
cat("=============================================================================\n")
cat("  PASO 13 — Diccionario de Emojis del Chat (desde result.json)\n")
cat("=============================================================================\n\n")

# ---------------------------------------------------------------------------
# 1. Localizar y cargar result.json
# ---------------------------------------------------------------------------
posibles_rutas <- c("data/raw/result.json", "result.json", "../data/raw/result.json", "../result.json")
json_path <- posibles_rutas[file.exists(posibles_rutas)][1]
if (is.na(json_path)) stop("No se encontró result.json")

cat("  [1/4] Cargando:", json_path, "...\n")
raw_data <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
msgs_raw <- raw_data$messages
cat(sprintf("     Total de registros en JSON: %s\n\n", format(length(msgs_raw), big.mark = ",")))

# ---------------------------------------------------------------------------
# 2. Extraer emojis de los textos y de las reacciones
# ---------------------------------------------------------------------------
cat("  [2/4] Extrayendo emojis de los mensajes y reacciones...\n")

emoji_regex <- paste0(
  "[",
  "\U0001F000-\U0001FAFF",  # pictogramas y símbolos
  "\U00002300-\U000023FF",  # símbolos técnicos
  "\U00002600-\U000027BF",  # dingbats y misceláneos
  "\U00002B00-\U00002BFF",  # flechas y símbolos
  "\U0001F1E6-\U0001F1FF",  # banderas
  "\U0000FE0F",             # variación
  "\U0000200D",             # ZWJ
  "]+"
)

extraer_texto <- function(txt) {
  if (is.null(txt)) return("")
  if (is.character(txt)) return(paste(txt, collapse = " "))
  if (is.list(txt)) {
    partes <- vapply(txt, function(p) {
      if (is.character(p)) return(p)
      if (is.list(p)) return(as.character(p$text %||% ""))
      as.character(p)
    }, character(1), USE.NAMES = FALSE)
    return(paste(partes, collapse = ""))
  }
  as.character(txt)
}

# Filtrar mensajes de usuario
msgs_user <- msgs_raw[vapply(msgs_raw, function(m) !identical(m$type, "service"), logical(1))]

# A. Emojis en el texto (vectorizado ultra rápido con C++ stringi)
textos_list <- lapply(msgs_user, function(m) extraer_texto(m$text))
textos_vec <- unlist(textos_list, use.names = FALSE)
hits_list <- stringi::stri_extract_all_regex(textos_vec, emoji_regex, omit_no_match = TRUE)
emojis_texto_todos <- unlist(hits_list, use.names = FALSE)
n_mensajes_con_emoji <- sum(vapply(hits_list, function(h) length(h) > 0, logical(1)))

# B. Emojis en las reacciones
reac_conteos <- list()
for (m in msgs_user) {
  if (!is.null(m$reactions) && length(m$reactions) > 0) {
    for (r in m$reactions) {
      e <- r$emoji %||% r$reaction
      cnt <- as.integer(r$count %||% 0)
      if (!is.null(e) && !is.na(e) && cnt > 0) {
        reac_conteos[[e]] <- (reac_conteos[[e]] %||% 0L) + cnt
      }
    }
  }
}

freq_texto <- if (length(emojis_texto_todos) > 0) table(emojis_texto_todos) else table(character(0))
cat(sprintf("     Emojis en texto: %s (en %d mensajes)\n",
            format(length(emojis_texto_todos), big.mark = ","), n_mensajes_con_emoji))
cat(sprintf("     Reacciones acumuladas: %s (en %d tipos de emoji)\n\n",
            format(sum(unlist(reac_conteos)), big.mark = ","), length(reac_conteos)))

# ---------------------------------------------------------------------------
# 3. Consolidar frecuencias totales (texto + reacciones)
# ---------------------------------------------------------------------------
cat("  [3/4] Consolidando frecuencias...\n")

todos_emojis <- unique(c(names(freq_texto), names(reac_conteos)))

freq_total <- data.frame(
  emoji            = todos_emojis,
  count_texto      = as.integer(freq_texto[todos_emojis]),
  count_reacciones = vapply(todos_emojis, function(e) as.integer(reac_conteos[[e]] %||% 0L), integer(1)),
  stringsAsFactors = FALSE
)
freq_total$count_texto[is.na(freq_total$count_texto)] <- 0L
freq_total$count_total <- freq_total$count_texto + freq_total$count_reacciones
freq_total <- freq_total[order(-freq_total$count_total), ]
freq_total$rango <- seq_len(nrow(freq_total))
freq_total <- freq_total[, c("rango", "emoji", "count_texto", "count_reacciones", "count_total")]

cat("\n=============================================================================\n")
cat("  RANKING DE EMOJIS — Top 50 más usados (texto + reacciones)\n")
cat("=============================================================================\n")
cat(sprintf("  %-5s  %-8s  %12s  %14s  %12s\n", "Rang.", "Emoji", "En texto", "En reacciones", "TOTAL"))
cat(sprintf("  %s\n", strrep("-", 60)))
for (i in seq_len(min(50, nrow(freq_total)))) {
  r <- freq_total[i, ]
  cat(sprintf("  %-5d  %-8s  %12s  %14s  %12s\n",
              r$rango, r$emoji,
              format(r$count_texto, big.mark = ","),
              format(r$count_reacciones, big.mark = ","),
              format(r$count_total, big.mark = ",")))
}
cat("\n")

out_dir <- "data/results"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_freq <- file.path(out_dir, "emojis_frecuencia.csv")
readr::write_csv(freq_total, out_freq)
cat(sprintf("  CSV frecuencias guardado en: %s\n", out_freq))

# ---------------------------------------------------------------------------
# 4. Diccionario semántico de emojis
# ---------------------------------------------------------------------------
cat("  [4/4] Asignando significado semántico...\n")

diccionario_emojis <- data.frame(
  emoji = c(
    # Caras y emociones
    "😂","🤣","😭","😢","😅","😊","🙂","😁","😄","😀","😃","😆","😋","😍","🥰",
    "😘","🤩","😎","🤔","😐","😑","😒","😤","😠","😡","🤬","😫","😩","😞","😔",
    "😟","😕","🫤","😮","😯","😲","🥲","😪","🥱","😴","🤗","🤭","😬","🫠","😵",
    "🥳","🤓","🧐","😇","🤑","😈","👿","💀","🥺","🫡","🫣","🥹","😻","🤡",
    # Gestos y manos
    "👍","👎","👏","🙏","🤝","✌️","☝️","👆","👇","👈","👉","🤙","💪","🫶","❤️",
    "🤞","🫰","🤟","🤘","🖐️","✋","🤚","👋","🫲","🫳","🫴","🤜","🤛","👊","✊",
    # Corazones
    "❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❣️","💕","💞","💓","💗",
    "💖","💘","💝","💟","♥️","❤️‍🔥","❤️‍🩹",
    # Académico y oficina
    "📚","📖","✏️","📝","📋","🗂️","💻","🖥️","📱","⌨️","🖨️","💾","📊","📈","📉",
    "🏫","🎓","👨‍🏫","👩‍🏫","📐","📏","🔬","🔭","🧪","🧫","🧬","🔎","📌","📍","🗒️",
    # Clima / naturaleza
    "☀️","🌤️","⛅","🌧️","❄️","🌙","⭐","🌟","💫","✨","🌈","🌊","🔥","💥","🌺",
    # Comida
    "🍕","🍔","🌮","🍜","🍣","☕","🍺","🎂","🍰","🍫","🧃","🥤",
    # Misceláneos
    "🎉","🎊","🎈","🎁","🏆","🥇","🥈","🥉","👑","🚀","💯","⚡","🌀","🎯",
    "❗","‼️","⁉️","🚫","✅","❌","⚠️"
  ),
  significado_es = c(
    # Caras
    "Cara llorando de risa","Cara revolcándose de risa","Cara llorando con fuerza","Cara triste llorando",
    "Cara con sudor frío (alivio nervioso)","Cara sonriente con ojos cerrados","Cara ligeramente sonriente","Cara con amplia sonrisa",
    "Cara sonriente con ojos abiertos","Cara ampliamente sonriente","Cara alegre con boca abierta","Cara sonriente radiante",
    "Cara saboreando","Cara con ojos de corazón (enamorado)","Cara con tres corazones (afecto)",
    "Cara dando un beso","Cara con estrellas en los ojos (fascinado)","Cara con lentes (cool/confiado)","Cara pensativa",
    "Cara neutral","Cara inexpresiva","Cara de disgusto/desinterés","Cara resoplando (frustración)","Cara enojada",
    "Cara muy enojada","Cara furiosa con insultos","Cara exhausta","Cara angustiada","Cara decepcionada",
    "Cara reflexiva/pensativa","Cara preocupada","Cara confundida","Cara indecisa","Cara sorprendida",
    "Cara boquiabierta","Cara muy asombrada","Cara llorando de emoción","Cara con sueño",
    "Cara bostezando (aburrido)","Cara durmiendo","Cara de abrazo cálido","Cara tapando la boca (risita)",
    "Cara de mueca incómoda","Cara derritiéndose (vergüenza)","Cara mareada",
    "Cara de fiesta/celebración","Cara de nerd/estudioso","Cara con monóculo (crítico)","Cara de inocente",
    "Cara de dinero","Cara de diablillo sonriente","Cara de diablo enojado","Calavera (muerto de risa/peligro)",
    "Cara con ojos de súplica","Cara saludando militarmente","Cara asomándose tímidamente","Cara conteniendo lágrimas",
    "Cara de gato enamorado","Cara de payaso (ridículo)",
    # Gestos
    "Pulgar arriba (aprobación)","Pulgar abajo (desaprobación)","Aplausos","Manos juntas (gracias / por favor)",
    "Apretón de manos (acuerdo)","Victoria / paz","Dedo índice arriba (ojo)","Dedo apuntando arriba",
    "Dedo apuntando abajo","Dedo apuntando a la izquierda","Dedo apuntando a la derecha","Llamada telefónica",
    "Bíceps / fuerza","Corazón con manos","Corazón rojo",
    "Dedos cruzados (suerte)","Dedo pellizcando","Amor y paz","Mano cornuta (rock)","Mano abierta",
    "Mano levantada (alto/hola)","Dorso levantado","Saludo con la mano","Mano derecha","Mano izquierda",
    "Palma arriba","Puño derecho","Puño izquierdo","Golpe de puño","Puño cerrado (fuerza)",
    # Corazones
    "Corazón rojo (afecto)","Corazón naranja","Corazón amarillo","Corazón verde","Corazón azul","Corazón morado",
    "Corazón negro","Corazón blanco","Corazón marrón","Corazón roto (tristeza)","Exclamación de corazón",
    "Dos corazones","Corazones girando","Corazón latiendo","Corazón con destellos",
    "Corazón brillante","Corazón con flecha","Corazón con cinta","Decoración corazón",
    "Símbolo de corazón","Corazón en llamas (pasión)","Corazón vendado",
    # Académico
    "Libros (estudio)","Libro abierto","Lápiz","Libreta","Portapapeles","Carpeta de archivos",
    "Computadora portátil","Monitor de computadora","Teléfono móvil","Teclado","Impresora","Disquete (guardar)",
    "Gráfico de barras","Gráfico ascendente","Gráfico descendente",
    "Escuela/Universidad","Birrete (graduación)","Profesor","Profesora","Escuadra","Regla","Microscopio",
    "Telescopio","Tubo de ensayo","Placa de Petri","ADN","Lupa","Chincheta roja","Chincheta azul","Bloc de notas",
    # Clima
    "Sol","Sol con nubes","Nublado","Lluvia","Nieve","Luna","Estrella","Estrella brillante",
    "Destellos girando","Destellos","Arcoíris","Ola de mar","Fuego (tendencia/ardiente)","Explosión","Flor",
    # Comida
    "Pizza","Hamburguesa","Taco","Ramen","Sushi","Café","Cerveza","Pastel de cumpleaños","Rebanada de pastel",
    "Chocolate","Jugo","Bebida",
    # Misceláneos
    "Celebración con confeti","Fiesta","Globo","Regalo","Trofeo","Medalla de oro","Medalla de plata","Medalla de bronce",
    "Corona","Cohete (éxito/rapidez)","100 puntos (perfecto)","Rayo (energía)","Remolino","Diana (meta lograda)",
    "Signo de exclamación","Doble exclamación","Interrogación con exclamación","Prohibido","Aprobado/correcto",
    "Cruz roja (rechazado)","Advertencia"
  ),
  categoria_emocional = c(
    # Caras
    "alegría","alegría","tristeza","tristeza","alivio","alegría","alegría","alegría","alegría","alegría",
    "alegría","alegría","satisfacción","amor","amor",
    "amor","admiración","confianza","reflexión","neutral","neutral","desagrado","frustración","enojo","enojo",
    "enojo","agotamiento","angustia","decepción","reflexión",
    "preocupación","confusión","indecisión","sorpresa","sorpresa","sorpresa","emoción_mixta","sueño",
    "aburrimiento","sueño","calidez","humor","incomodidad","vergüenza","confusión",
    "celebración","intelectual","curioso","bondad","codicia","malicia","enojo","humor_negro","súplica",
    "respeto","timidez","emoción","amor","humor",
    # Gestos
    "aprobación","desaprobación","aprobación","gratitud","acuerdo","positivo","énfasis","dirección",
    "dirección","dirección","dirección","comunicación","fuerza","amor","amor",
    "esperanza","perfección","energía","rebeldía","saludo","saludo","saludo","saludo",
    "dirección","dirección","ofrecimiento","fuerza","fuerza","fuerza","fuerza",
    # Corazones
    "amor","amor","amor","amor","amor","amor","amor","amor","amor","tristeza","amor",
    "amor","amor","amor","amor",
    "amor","amor","amor","amor","amor","amor","amor",
    # Académico
    "neutral","neutral","neutral","neutral","neutral","neutral","neutral","neutral","neutral","neutral",
    "neutral","neutral","neutral","neutral","neutral",
    "neutral","logro","neutral","neutral","neutral","neutral","neutral","neutral","neutral","neutral",
    "neutral","neutral","neutral","neutral","neutral",
    # Clima
    "neutral","neutral","neutral","neutral","neutral","neutral","positivo","positivo",
    "positivo","positivo","positivo","neutral","intensidad","sorpresa","positivo",
    # Comida
    "neutro","neutro","neutro","neutro","neutro","neutro","neutro","celebración","celebración",
    "satisfacción","neutro","neutro",
    # Misceláneos
    "celebración","celebración","celebración","gratitud","logro","logro","logro","logro",
    "logro","entusiasmo","perfección","energía","neutral","logro",
    "énfasis","énfasis","confusión","negativo","positivo","negativo","advertencia"
  ),
  polaridad = c(
    # Caras
    "positivo","positivo","negativo","negativo","positivo","positivo","positivo","positivo","positivo","positivo",
    "positivo","positivo","positivo","positivo","positivo",
    "positivo","positivo","positivo","neutro","neutro","neutro","negativo","negativo","negativo","negativo",
    "negativo","negativo","negativo","negativo","neutro",
    "negativo","neutro","neutro","neutro","neutro","neutro","positivo","neutro",
    "neutro","neutro","positivo","neutro","negativo","neutro","neutro",
    "positivo","positivo","positivo","positivo","neutro","negativo","negativo","positivo","negativo",
    "positivo","neutro","positivo","positivo","neutro",
    # Gestos
    "positivo","negativo","positivo","positivo","positivo","positivo","neutro","neutro",
    "neutro","neutro","neutro","neutro","positivo","positivo","positivo",
    "positivo","positivo","positivo","neutro","positivo","positivo","positivo","positivo",
    "neutro","neutro","neutro","positivo","positivo","neutro","positivo",
    # Corazones
    "positivo","positivo","positivo","positivo","positivo","positivo","neutro","positivo","positivo","negativo","positivo",
    "positivo","positivo","positivo","positivo",
    "positivo","positivo","positivo","positivo","positivo","positivo","positivo",
    # Académico
    "neutro","neutro","neutro","neutro","neutro","neutro","neutro","neutro","neutro","neutro",
    "neutro","neutro","neutro","neutro","neutro",
    "neutro","positivo","neutro","neutro","neutro","neutro","neutro","neutro","neutro","neutro",
    "neutro","neutro","neutro","neutro","neutro",
    # Clima
    "positivo","positivo","neutro","negativo","neutro","neutro","positivo","positivo",
    "positivo","positivo","positivo","neutro","intenso","neutro","positivo",
    # Comida
    "neutro","neutro","neutro","neutro","neutro","neutro","neutro","positivo","positivo",
    "positivo","neutro","neutro",
    # Misceláneos
    "positivo","positivo","positivo","positivo","positivo","positivo","positivo","positivo",
    "positivo","positivo","positivo","positivo","neutro","positivo",
    "neutro","neutro","confuso","negativo","positivo","negativo","negativo"
  ),
  stringsAsFactors = FALSE
)

diccionario_emojis <- diccionario_emojis[!duplicated(diccionario_emojis$emoji), ]

diccionario_resultado <- merge(
  freq_total[, c("rango", "emoji", "count_total", "count_texto", "count_reacciones")],
  diccionario_emojis[, c("emoji", "significado_es", "categoria_emocional", "polaridad")],
  by = "emoji",
  all.x = TRUE
)

diccionario_resultado$significado_es[is.na(diccionario_resultado$significado_es)] <- "sin definición registrada"
diccionario_resultado$categoria_emocional[is.na(diccionario_resultado$categoria_emocional)] <- "sin clasificar"
diccionario_resultado$polaridad[is.na(diccionario_resultado$polaridad)] <- "neutro"

diccionario_resultado <- diccionario_resultado[order(diccionario_resultado$rango), ]

cat("\n=============================================================================\n")
cat("  DICCIONARIO SEMÁNTICO — Top 30 emojis con significado\n")
cat("=============================================================================\n")
cat(sprintf("  %-5s  %-8s  %8s  %-25s  %-15s  %-10s\n", "Rang.", "Emoji", "Total", "Significado", "Categoría", "Polaridad"))
cat(sprintf("  %s\n", strrep("-", 80)))
for (i in seq_len(min(30, nrow(diccionario_resultado)))) {
  r <- diccionario_resultado[i, ]
  sig <- substr(r$significado_es, 1, 25)
  if (nchar(r$significado_es) > 25) sig <- paste0(substr(sig, 1, 22), "...")
  cat(sprintf("  %-5d  %-8s  %8s  %-25s  %-15s  %-10s\n",
              r$rango, r$emoji,
              format(r$count_total, big.mark = ","),
              sig,
              substr(r$categoria_emocional, 1, 15),
              r$polaridad))
}
cat("\n")

out_dict <- file.path(out_dir, "emojis_diccionario.csv")
readr::write_csv(diccionario_resultado, out_dict)
cat(sprintf("  CSV diccionario guardado en: %s\n\n", out_dict))

cat("=============================================================================\n")
cat("  OK 13_diccionario_emojis (completado desde result.json)\n")
cat("=============================================================================\n\n")
