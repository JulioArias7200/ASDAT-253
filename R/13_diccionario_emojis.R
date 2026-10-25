# =============================================================================
# 13_diccionario_emojis.R — Conteo y diccionario CONTEXTUAL de emojis
#
# Uso: Rscript scripts/13_diccionario_emojis.R
#
# Lee DIRECTAMENTE de data/raw/result.json (o result.json).
# El significado de cada emoji vive en un archivo aparte:
#   emojis_diccionario_contexto.csv   (editable en Excel / bloc de notas)
#
# Qué cambió respecto a la versión anterior
#   1. Cada emoji se cuenta por separado (antes "🥳🥳🎉🎉" era UN solo emoji).
#   2. Se normaliza ❤ / ❤️ y los tonos de piel (👍🏽 = 👍), para que el
#      diccionario realmente encuentre los emojis.
#   3. El significado es contextual (cómo se usa en ESTE chat), no el nombre
#      oficial de Unicode.
#   4. Se calcula el perfil de uso de cada emoji (anuncio vs. conversación,
#      inicio de línea, mensaje solo-emoji, pregunta) para respaldar el
#      significado con datos.
#   5. Los emojis sin definición se exportan a emojis_pendientes.csv con
#      ejemplos reales para completarlos fácilmente.
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(stringi)
  library(dplyr)
  library(readr)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

cat("\n")
cat("=============================================================================\n")
cat("  PASO 13 — Diccionario Contextual de Emojis del Chat (desde result.json)\n")
cat("=============================================================================\n\n")

# ---------------------------------------------------------------------------
# 1. Localizar archivos
# ---------------------------------------------------------------------------
buscar <- function(rutas) {
  r <- rutas[file.exists(rutas)][1]
  if (is.na(r)) NA_character_ else r
}

json_path <- buscar(c(
  "data/raw/result.json", "result.json",
  "../data/raw/result.json", "../result.json"
))
if (is.na(json_path)) stop("No se encontró result.json")

dic_path <- buscar(c(
  "data/results/emojis_diccionario_contexto.csv",
  "../data/results/emojis_diccionario_contexto.csv",
  "data/dictionary/emojis_diccionario_contexto.csv",
  "../data/dictionary/emojis_diccionario_contexto.csv",
  "emojis_diccionario_contexto.csv",
  "data/emojis_diccionario_contexto.csv",
  "data/raw/emojis_diccionario_contexto.csv",
  "scripts/emojis_diccionario_contexto.csv",
  "../emojis_diccionario_contexto.csv"
))
if (is.na(dic_path)) stop("No se encontró emojis_diccionario_contexto.csv (debe estar en data/results/, data/ o junto al script)")

cat("  [1/5] Cargando:", json_path, "...\n")
raw_data <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
msgs_raw <- raw_data$messages
cat(sprintf("     Total de registros en JSON: %s\n\n", format(length(msgs_raw), big.mark = ",")))

# ---------------------------------------------------------------------------
# 2. Expresión regular de UN emoji completo (con modificadores y secuencias ZWJ)
# ---------------------------------------------------------------------------
# base: pictogramas, símbolos, dingbats, flechas, formas (sin los tonos de piel sueltos)
base_emoji <- paste0(
  "[\\x{1F000}-\\x{1F3FA}\\x{1F400}-\\x{1FAFF}", # pictogramas, caras, gestos, objetos
  "\\x{2190}-\\x{21FF}", # flechas
  "\\x{2300}-\\x{23FF}", # técnicos (⏰ ⌚ ⏳)
  "\\x{25A0}-\\x{25FF}", # formas geométricas (● ▶)
  "\\x{2600}-\\x{27BF}", # misceláneos y dingbats (✅ ⚠ ❤)
  "\\x{2900}-\\x{297F}", # flechas suplementarias
  "\\x{2B00}-\\x{2BFF}", # flechas y símbolos (⬇ ⭐)
  "\\x{203C}\\x{2049}]" # ‼ ⁉
)
modif <- "[\\x{FE0F}\\x{20E3}\\x{1F3FB}-\\x{1F3FF}]*" # variación, keycap, tono de piel

emoji_regex <- paste0(
  "(?:[\\x{1F1E6}-\\x{1F1FF}]{2}", # banderas (🇧🇴)
  "|", base_emoji, modif, # emoji base + modificadores
  "(?:\\x{200D}", base_emoji, modif, ")*)" # secuencias unidas con ZWJ (👩‍💻 ❤️‍🔥)
)

# Normaliza: quita selector de variación y tono de piel (❤️ == ❤ ; 👍🏽 == 👍)
norm_emoji <- function(x) stringi::stri_replace_all_regex(x, "[\\x{FE0F}\\x{1F3FB}-\\x{1F3FF}]", "")

# ---------------------------------------------------------------------------
# 3. Extraer emojis (texto y reacciones) con su contexto de uso
# ---------------------------------------------------------------------------
cat("  [2/5] Extrayendo emojis de los mensajes y reacciones...\n")

extraer_texto <- function(txt) {
  if (is.null(txt)) {
    return("")
  }
  if (is.character(txt)) {
    return(paste(txt, collapse = " "))
  }
  if (is.list(txt)) {
    partes <- vapply(txt, function(p) {
      if (is.character(p)) {
        return(p)
      }
      if (is.list(p)) {
        return(as.character(p$text %||% ""))
      }
      as.character(p)
    }, character(1), USE.NAMES = FALSE)
    return(paste(partes, collapse = ""))
  }
  as.character(txt)
}

msgs_user <- msgs_raw[vapply(msgs_raw, function(m) !identical(m$type, "service"), logical(1))]
textos_vec <- vapply(msgs_user, function(m) extraer_texto(m$text), character(1), USE.NAMES = FALSE)

# A. Emojis en el texto, UNO POR UNO, con rasgos de contexto
locs <- stringi::stri_locate_all_regex(textos_vec, emoji_regex)
idx_con_emoji <- which(!is.na(vapply(locs, function(x) x[1, 1], numeric(1))))

filas <- vector("list", length(idx_con_emoji))
for (j in seq_along(idx_con_emoji)) {
  i <- idx_con_emoji[j]
  t <- textos_vec[i]
  loc <- locs[[i]]
  em <- stringi::stri_sub(t, loc[, 1], loc[, 2])

  # "Anuncio": mensaje largo o con varias líneas (fichas de eventos, convocatorias)
  es_anuncio <- stringi::stri_count_fixed(t, "\n") >= 3 || nchar(t) > 300

  # "Solo emoji": el mensaje no tiene más que emojis y signos (reacción escrita)
  resto <- stringi::stri_replace_all_regex(t, emoji_regex, "")
  solo <- !nzchar(stringi::stri_replace_all_regex(resto, "[\\s\\x{FE0F}\\x{200D}.!\u00A1?\u00BF]", ""))

  # "Inicio de línea": el emoji abre la línea (funciona como viñeta o etiqueta de campo)
  prefijos <- stringi::stri_sub(t, 1, loc[, 1] - 1)
  ult_linea <- stringi::stri_replace_all_regex(prefijos, "(?s)^.*\n", "")
  ult_linea <- stringi::stri_replace_all_regex(ult_linea, paste0(emoji_regex, "|[\\s*_]"), "")

  filas[[j]] <- data.frame(
    emoji = norm_emoji(em),
    msg_i = i,
    pos = loc[, 1],
    anuncio = es_anuncio,
    inicio_linea = !nzchar(ult_linea),
    solo_emoji = solo,
    en_pregunta = (!es_anuncio) && stringi::stri_detect_fixed(t, "?"),
    stringsAsFactors = FALSE
  )
}
ocurrencias <- dplyr::bind_rows(filas)

# B. Emojis en las reacciones
reac_conteos <- list()
for (m in msgs_user) {
  if (!is.null(m$reactions) && length(m$reactions) > 0) {
    for (r in m$reactions) {
      e <- r$emoji %||% r$reaction
      cnt <- as.integer(r$count %||% 0)
      if (!is.null(e) && !is.na(e) && cnt > 0) {
        e <- norm_emoji(e)
        reac_conteos[[e]] <- (reac_conteos[[e]] %||% 0L) + cnt
      }
    }
  }
}

cat(sprintf(
  "     Emojis en texto: %s (en %s mensajes)\n",
  format(nrow(ocurrencias), big.mark = ","),
  format(length(idx_con_emoji), big.mark = ",")
))
cat(sprintf(
  "     Reacciones acumuladas: %s (en %d tipos de emoji)\n\n",
  format(sum(unlist(reac_conteos)), big.mark = ","), length(reac_conteos)
))

# ---------------------------------------------------------------------------
# 4. Consolidar frecuencias + perfil de uso
# ---------------------------------------------------------------------------
cat("  [3/5] Consolidando frecuencias y perfil de uso...\n")

perfil_texto <- ocurrencias %>%
  group_by(emoji) %>%
  summarise(
    count_texto = n(),
    pct_anuncio = round(100 * mean(anuncio), 1),
    pct_inicio_linea = round(100 * mean(inicio_linea), 1),
    pct_solo_emoji = round(100 * mean(solo_emoji), 1),
    pct_en_pregunta = round(100 * mean(en_pregunta), 1),
    .groups = "drop"
  )

reac_df <- data.frame(
  emoji            = names(reac_conteos),
  count_reacciones = as.integer(unlist(reac_conteos)),
  stringsAsFactors = FALSE
)

freq_total <- full_join(perfil_texto, reac_df, by = "emoji") %>%
  mutate(
    count_texto      = coalesce(count_texto, 0L),
    count_reacciones = coalesce(count_reacciones, 0L),
    count_total      = count_texto + count_reacciones
  ) %>%
  arrange(desc(count_total), emoji) %>%
  mutate(rango = row_number()) %>%
  select(
    rango, emoji, count_texto, count_reacciones, count_total,
    pct_anuncio, pct_inicio_linea, pct_solo_emoji, pct_en_pregunta
  )

cat("\n=============================================================================\n")
cat("  RANKING DE EMOJIS — Top 50 más usados (texto + reacciones)\n")
cat("=============================================================================\n")
cat(sprintf("  %-5s  %-8s  %12s  %14s  %12s\n", "Rang.", "Emoji", "En texto", "En reacciones", "TOTAL"))
cat(sprintf("  %s\n", strrep("-", 60)))
for (i in seq_len(min(50, nrow(freq_total)))) {
  r <- freq_total[i, ]
  cat(sprintf(
    "  %-5d  %-8s  %12s  %14s  %12s\n",
    r$rango, r$emoji,
    format(r$count_texto, big.mark = ","),
    format(r$count_reacciones, big.mark = ","),
    format(r$count_total, big.mark = ",")
  ))
}
cat("\n")

posibles_out <- c("data/results", "../data/results")
out_dir <- posibles_out[dir.exists(posibles_out)][1]
if (is.na(out_dir)) {
  out_dir <- "data/results"
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}
out_freq <- file.path(out_dir, "emojis_frecuencia.csv")
readr::write_csv(freq_total, out_freq)
cat(sprintf("  CSV frecuencias guardado en: %s\n", out_freq))

# ---------------------------------------------------------------------------
# 5. Diccionario contextual
# ---------------------------------------------------------------------------
cat(sprintf("  [4/5] Cargando diccionario contextual: %s\n", dic_path))

diccionario <- readr::read_csv(dic_path,
  col_types = cols(.default = col_character()),
  locale = locale(encoding = "UTF-8"), show_col_types = FALSE
)
diccionario$emoji <- norm_emoji(diccionario$emoji)
diccionario <- diccionario[!duplicated(diccionario$emoji), ]

diccionario_resultado <- freq_total %>%
  left_join(diccionario, by = "emoji") %>%
  mutate(
    sin_definicion      = is.na(significado_es),
    significado_es      = coalesce(significado_es, "sin definición registrada"),
    categoria_emocional = coalesce(categoria_emocional, "sin clasificar"),
    polaridad           = coalesce(polaridad, "neutro"),
    funcion             = coalesce(funcion, "sin clasificar"),
    registro            = coalesce(registro, "sin clasificar"),
    ironia              = coalesce(ironia, "no evaluado")
  ) %>%
  arrange(rango)

n_def <- sum(!diccionario_resultado$sin_definicion)
uso_def <- sum(diccionario_resultado$count_total[!diccionario_resultado$sin_definicion]) /
  sum(diccionario_resultado$count_total)
cat(sprintf(
  "     Emojis distintos: %d | con significado: %d | cobertura de uso: %.1f%%\n\n",
  nrow(diccionario_resultado), n_def, 100 * uso_def
))

cat("=============================================================================\n")
cat("  DICCIONARIO CONTEXTUAL — Top 30 emojis con significado\n")
cat("=============================================================================\n")
cat(sprintf("  %-5s  %-6s  %7s  %-20s  %-10s  %-9s\n", "Rang.", "Emoji", "Total", "Función", "Registro", "Polaridad"))
cat(sprintf("  %s\n", strrep("-", 70)))
for (i in seq_len(min(30, nrow(diccionario_resultado)))) {
  r <- diccionario_resultado[i, ]
  cat(sprintf(
    "  %-5d  %-6s  %7s  %-20s  %-10s  %-9s\n",
    r$rango, r$emoji, format(r$count_total, big.mark = ","),
    substr(r$funcion, 1, 20), substr(r$registro, 1, 10), r$polaridad
  ))
}
cat("\n")

out_dict <- file.path(out_dir, "emojis_diccionario.csv")
readr::write_csv(diccionario_resultado %>% select(-sin_definicion), out_dict)
cat(sprintf("  CSV diccionario guardado en: %s\n", out_dict))

# ---------------------------------------------------------------------------
# 6. Emojis pendientes de definir (con ejemplos reales del chat)
# ---------------------------------------------------------------------------
cat("  [5/5] Revisando emojis sin definición...\n")

pend <- diccionario_resultado %>% filter(sin_definicion)
if (nrow(pend) > 0) {
  ejemplo <- vapply(pend$emoji, function(e) {
    h <- ocurrencias[ocurrencias$emoji == e, ]
    if (nrow(h) == 0) {
      return("(solo aparece como reacción)")
    }
    t <- textos_vec[h$msg_i[1]]
    ini <- max(1, h$pos[1] - 45)
    gsub("\\s+", " ", stringi::stri_sub(t, ini, h$pos[1] + 45))
  }, character(1), USE.NAMES = FALSE)

  pendientes <- pend %>%
    mutate(ejemplo_en_chat = ejemplo) %>%
    select(
      rango, emoji, count_total, count_texto, count_reacciones,
      pct_anuncio, pct_inicio_linea, pct_solo_emoji, pct_en_pregunta, ejemplo_en_chat
    )

  out_pend <- file.path(out_dir, "emojis_pendientes.csv")
  readr::write_csv(pendientes, out_pend)
  cat(sprintf(
    "     %d emojis sin definir (%d usos). Revisa y agrega a %s:\n       %s\n",
    nrow(pend), sum(pend$count_total), basename(dic_path), out_pend
  ))
} else {
  cat("     Todos los emojis tienen definición.\n")
}

cat("\n=============================================================================\n")
cat("  OK 13_diccionario_emojis (completado desde result.json)\n")
cat("=============================================================================\n\n")


# autor: Yoshua Aaron Cordova Avendaño
