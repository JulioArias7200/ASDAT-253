# =============================================================================
# R/14_topicos_frecuencia.R — Minería Exhaustiva de Tópicos de Frecuencia
#
# Uso: Rscript R/14_topicos_frecuencia.R  (o Rscript scripts/14_topicos_frecuencia.R)
#
# Procesa la totalidad de la base de datos (23.371 mensajes de Neon PostgreSQL)
# y extrae las dimensiones completas de frecuencia temática:
#   1. Prevalencia y distribución de tópicos en el corpus (theta)
#   2. Distribución y probabilidad de términos por tópico (beta, tfidf, term-score)
#   3. Frecuencia temporal por mes/año y estacionalidad
#   4. Cruce de frecuencias: Tópico vs. 18 Emociones y Polaridad
#   5. N-gramas característicos (bigramas y trigramas) por tópico
#   6. Coherencia semántica UMass por tópico
#
# Genera datasets estructurados en data/results/ listos para ingesta en Neon DB.
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(slam)
  library(topicmodels)
})

cat("\n")
cat("=============================================================================\n")
cat("  PASO 14 — Minería Integral de Tópicos de Frecuencia (Corpus Completo)\n")
cat("=============================================================================\n\n")

# ---------------------------------------------------------------------------
# 1. Localizar y Cargar Datos
# ---------------------------------------------------------------------------
cat("  [1/6] Cargando el corpus consolidado de la base de datos...\n")

posibles_csv <- c(
  "data/interim/mensajes_corpus_neon.csv",
  "../data/interim/mensajes_corpus_neon.csv"
)
csv_path <- posibles_csv[file.exists(posibles_csv)][1]

if (!is.na(csv_path)) {
  cat("     Leyendo desde CSV exportado de Neon DB:", csv_path, "\n")
  df_msgs <- read.csv(csv_path, stringsAsFactors = FALSE, encoding = "UTF-8")
} else {
  posibles_json <- c("data/raw/result.json", "result.json", "../data/raw/result.json")
  json_path <- posibles_json[file.exists(posibles_json)][1]
  if (is.na(json_path)) {
    stop("No se encontró mensajes_corpus_neon.csv ni result.json.")
  }
  cat("     Leyendo desde JSON crudo:", json_path, "\n")
  raw_data <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
  msgs_raw <- raw_data$messages
  
  extraer_txt <- function(x) {
    if (is.null(x)) return("")
    if (is.character(x)) return(paste(x, collapse = " "))
    if (is.list(x)) {
      parts <- vapply(x, function(p) {
        if (is.character(p)) return(p)
        if (is.list(p) && !is.null(p$text)) return(as.character(p$text))
        return("")
      }, character(1))
      return(paste(parts, collapse = ""))
    }
    return(as.character(x))
  }
  
  df_msgs <- data.frame(
    message_id = vapply(msgs_raw, function(m) as.numeric(m$id %||% 0), numeric(1)),
    fecha = vapply(msgs_raw, function(m) as.character(m$date %||% ""), character(1)),
    texto = vapply(msgs_raw, function(m) extraer_txt(m$text), character(1)),
    polarity = 0,
    polarity_label = "indeterminado",
    emocion_dominante = "indeterminado",
    intensidad = 0,
    tiene_imagen = FALSE,
    es_sticker = FALSE,
    es_gif = FALSE,
    stringsAsFactors = FALSE
  )
}

n_total <- nrow(df_msgs)
cat(sprintf("     Total de mensajes cargados: %s\n", format(n_total, big.mark = ",")))

# ---------------------------------------------------------------------------
# 2. Preprocesamiento Lingüístico y Stopwords
# ---------------------------------------------------------------------------
cat("  [2/6] Limpieza de texto, tokenización y filtrado de stopwords...\n")

stopwords_es <- c(
  "de", "la", "que", "el", "en", "y", "a", "los", "del", "se", "las", "por", "un", "para", "con", "no", 
  "una", "su", "al", "lo", "como", "mas", "más", "pero", "sus", "le", "ya", "o", "este", "si", "sí", 
  "porque", "esta", "entre", "cuando", "muy", "sin", "sobre", "tambien", "también", "me", "hasta", 
  "hay", "donde", "quien", "desde", "todo", "nos", "durante", "todos", "uno", "les", "ni", "contra", 
  "otros", "ese", "eso", "ante", "ellos", "e", "esto", "mi", "mí", "antes", "algunos", "que", "qué", 
  "unos", "yo", "otro", "otras", "otra", "el", "él", "tanto", "esa", "estos", "mucho", "quienes", 
  "nada", "muchos", "cual", "poco", "ella", "estar", "estas", "algunas", "algo", "nosotros", "mis", 
  "tu", "tú", "te", "ti", "tus", "ellas", "nosotras", "vosotros", "vosotras", "os", "mio", "mía", 
  "tuyo", "tuya", "suyo", "suya", "nuestro", "nuestra", "esos", "esas", "estoy", "estas", "esta", 
  "estamos", "estan", "están", "fue", "era", "han", "ha", "son", "es", "ser", "va", "van", "ir", 
  "hace", "hacer", "hacen", "dice", "dicen", "tener", "tiene", "tienen", "tenemos", "pasa", "pasar",
  # Stop words conversacionales de mensajería (Telegram)
  "hola", "buenas", "gracias", "favor", "disculpen", "alguien", "porfa", "link", "x2", "xd", "ok", 
  "jaja", "jajaja", "bro", "compa", "q", "d", "tmb", "ms", "https", "http", "t", "me", "joinchat"
)

limpiar_texto <- function(txt) {
  t <- tolower(txt)
  t <- gsub("https?://\\S+", " ", t)
  t <- gsub("[^a-záéíóúñü\\s]", " ", t)
  t <- gsub("\\s+", " ", t)
  trimws(t)
}

textos_limpios <- vapply(df_msgs$texto, limpiar_texto, character(1), USE.NAMES = FALSE)

# Tokenizar y eliminar stopwords
tokens_list <- strsplit(textos_limpios, "\\s+")
tokens_list <- lapply(tokens_list, function(toks) {
  toks <- toks[nchar(toks) >= 3]
  toks[!toks %in% stopwords_es]
})

# Índices con tokens válidos
doc_lens <- vapply(tokens_list, length, integer(1))
valid_docs <- which(doc_lens >= 2)
cat(sprintf("     Mensajes con al menos 2 tokens útiles: %s (%.1f%%)\n", 
            format(length(valid_docs), big.mark = ","), length(valid_docs)/n_total*100))

# ---------------------------------------------------------------------------
# 3. Construcción de la Matriz Documento-Término (DTM)
# ---------------------------------------------------------------------------
cat("  [3/6] Construyendo matriz documento-término (DTM)...\n")

filtered_tokens <- tokens_list[valid_docs]
all_terms <- unlist(filtered_tokens)
vocab_counts <- table(all_terms)

# Filtrar términos que aparecen al menos 3 veces en el corpus
vocab <- names(vocab_counts[vocab_counts >= 3])
vocab_map <- setNames(seq_along(vocab), vocab)
cat(sprintf("     Vocabulario depurado: %d términos únicos\n", length(vocab)))

# Construcción de índices triplet (i, j, v)
n_docs_valid <- length(valid_docs)
doc_indices <- integer(0)
term_indices <- integer(0)
term_counts <- integer(0)

# Batching para construir DTM rápido en memoria
triplets_list <- vector("list", n_docs_valid)
for (i in seq_along(valid_docs)) {
  toks <- filtered_tokens[[i]]
  toks <- toks[toks %in% vocab]
  if (length(toks) > 0) {
    tab <- table(toks)
    w_names <- names(tab)
    triplets_list[[i]] <- list(
      i = rep(i, length(w_names)),
      j = unname(vocab_map[w_names]),
      v = as.integer(tab)
    )
  }
}

non_empty <- which(vapply(triplets_list, function(x) !is.null(x), logical(1)))
all_i <- unlist(lapply(triplets_list[non_empty], function(x) x$i))
all_j <- unlist(lapply(triplets_list[non_empty], function(x) x$j))
all_v <- unlist(lapply(triplets_list[non_empty], function(x) x$v))

dtm <- slam::simple_triplet_matrix(
  i = all_i,
  j = all_j,
  v = all_v,
  nrow = n_docs_valid,
  ncol = length(vocab),
  dimnames = list(as.character(valid_docs), vocab)
)

row_sums <- slam::row_sums(dtm)
keep_rows <- which(row_sums > 0)
dtm <- dtm[keep_rows, ]
docs_finales <- valid_docs[keep_rows]

cat(sprintf("     DTM final: %d documentos x %d términos (densidad: %.3f%%)\n",
            dtm$nrow, dtm$ncol, (length(dtm$v) / (dtm$nrow * dtm$ncol)) * 100))

# ---------------------------------------------------------------------------
# 4. Ajuste del Modelo LDA (K = 5 Tópicos Canónicos)
# ---------------------------------------------------------------------------
cat("  [4/6] Entrenando modelo LDA con muestreo de Gibbs (K = 5)...\n")
k <- 5L
set.seed(42)
lda_model <- topicmodels::LDA(
  dtm,
  k = k,
  method = "Gibbs",
  control = list(seed = 42, iter = 500, burnin = 100)
)

post <- topicmodels::posterior(lda_model)
theta <- post$topics # Documentos x Tópicos
beta <- post$terms   # Tópicos x Términos

# Tópico dominante por documento
topico_dominante <- apply(theta, 1, which.max)
prob_dominante <- apply(theta, 1, max)

# Asignación a df_msgs
df_msgs$topico_id <- NA_integer_
df_msgs$prob_topico <- 0.0
df_msgs$topico_id[docs_finales] <- topico_dominante
df_msgs$prob_topico[docs_finales] <- round(prob_dominante, 4)

# ---------------------------------------------------------------------------
# 5. Minería de Métricas de Frecuencia y Tablas Estructuradas
# ---------------------------------------------------------------------------
cat("  [5/6] Calculando métricas avanzadas de frecuencia y cruces analíticos...\n")

nombres_topicos <- c(
  "1. Trámites, Kardex y Pagos",
  "2. Interacción y Gestión de Clases",
  "3. Inscripción Presencial UMSA",
  "4. Grupos WhatsApp de Temporada",
  "5. Consultas a la Comunidad"
)

descripciones_topicos <- c(
  "Procedimientos administrativos de pago de matricula, boletas bancarias y validacion en Kardex.",
  "Coordinacion diaria de clases presenciales y virtuales, avisos de docentes y suspensiones.",
  "Logistica presencial en el campus universitario: formularios impresos, legalizaciones y ventanilla.",
  "Distribucion de enlaces de invitacion a grupos de WhatsApp para materias regulares y de temporada.",
  "Consultas abiertas entre estudiantes solicitando recomendaciones docentes y orientacion de asignaturas."
)

# 5.1. Catálogo Maestro de Tópicos
prev_counts <- table(factor(topico_dominante, levels = 1:k))
prev_pcts <- round(as.numeric(prev_counts) / length(topico_dominante) * 100, 2)

# Coherencia semántica UMass por tópico
bin_dtm <- dtm
bin_dtm$v <- rep(1L, length(bin_dtm$v))
doc_freqs <- slam::col_sums(bin_dtm)

coherencias <- numeric(k)
for (t in 1:k) {
  top_w_idx <- order(beta[t, ], decreasing = TRUE)[1:10]
  score <- 0
  for (m in 2:10) {
    w_m <- top_w_idx[m]
    d_m <- doc_freqs[w_m]
    for (l in 1:(m - 1)) {
      w_l <- top_w_idx[l]
      # Co-ocurrencia
      cooc <- sum(slam::row_sums(dtm[, c(w_m, w_l)]) >= 2)
      score <- score + log((cooc + 1) / (doc_freqs[w_l] + 1e-5))
    }
  }
  coherencias[t] <- round(score, 4)
}

df_catalogo <- data.frame(
  topico_id = 1:k,
  nombre_etiqueta = nombres_topicos,
  descripcion_tematica = descripciones_topicos,
  prevalencia_pct = prev_pcts,
  total_mensajes = as.integer(prev_counts),
  coherencia_score = coherencias,
  stringsAsFactors = FALSE
)

# 5.2. Términos y Frecuencia Probabilística por Tópico (Top 25 términos por tópico)
df_terminos_list <- list()
corpus_word_counts <- slam::col_sums(dtm)

# Calcular term-score de Blei y Lafferty
log_beta <- log(beta + 1e-12)
mean_log_beta <- colMeans(log_beta)
term_score_mat <- beta * (log_beta - rep(mean_log_beta, each = k))

for (t in 1:k) {
  # Ranking por probabilidad posterior beta
  top_idx <- order(beta[t, ], decreasing = TRUE)[1:25]
  w_names <- colnames(beta)[top_idx]
  
  # Frecuencia absoluta en documentos dominados por este tópico
  dtm_sub <- dtm[topico_dominante == t, top_idx]
  sub_counts <- slam::col_sums(dtm_sub)
  
  # TF-IDF simple del término en el tópico
  tf <- sub_counts / sum(sub_counts)
  idf <- log(dtm$nrow / (corpus_word_counts[top_idx] + 1))
  tfidf <- round(tf * idf * 100, 4)
  
  df_t <- data.frame(
    topico_id = t,
    termino = w_names,
    frecuencia_abs = as.integer(sub_counts),
    beta_prob = round(beta[t, top_idx], 6),
    tfidf_score = tfidf,
    term_score_blei = round(term_score_mat[t, top_idx], 4),
    ranking_pos = 1:25,
    stringsAsFactors = FALSE
  )
  df_terminos_list[[t]] <- df_t
}
df_terminos <- do.call(rbind, df_terminos_list)

# 5.3. Serie Temporal de Frecuencia por Tópico (YYYY-MM)
df_msgs$anio_mes <- substr(df_msgs$fecha, 1, 7)
valid_time_msgs <- df_msgs[!is.na(df_msgs$topico_id) & nzchar(df_msgs$anio_mes) & df_msgs$anio_mes >= "2018-01", ]

time_agg <- aggregate(
  message_id ~ topico_id + anio_mes,
  data = valid_time_msgs,
  FUN = length
)
names(time_agg)[3] <- "volumen_mensajes"

pol_agg <- aggregate(
  polarity ~ topico_id + anio_mes,
  data = valid_time_msgs,
  FUN = function(x) round(mean(x, na.rm = TRUE), 3)
)
names(pol_agg)[3] <- "polaridad_media"

df_temporal <- merge(time_agg, pol_agg, by = c("topico_id", "anio_mes"))
df_temporal <- df_temporal[order(df_temporal$topico_id, df_temporal$anio_mes), ]

# Emoción predominante por mes en cada tópico
emocion_top_agg <- aggregate(
  emocion_dominante ~ topico_id + anio_mes,
  data = valid_time_msgs[valid_time_msgs$emocion_dominante != "indeterminado", ],
  FUN = function(x) {
    if (length(x) == 0) return("neutro")
    names(sort(table(x), decreasing = TRUE))[1]
  }
)
names(emocion_top_agg)[3] <- "emocion_predominante"
df_temporal <- merge(df_temporal, emocion_top_agg, by = c("topico_id", "anio_mes"), all.x = TRUE)
df_temporal$emocion_predominante[is.na(df_temporal$emocion_predominante)] <- "indeterminado"

# 5.4. Cruce de Tópico vs. 18 Emociones
df_emo_list <- list()
for (t in 1:k) {
  sub_emo <- df_msgs[df_msgs$topico_id == t & !is.na(df_msgs$topico_id), "emocion_dominante"]
  tab_emo <- table(sub_emo)
  df_e <- data.frame(
    topico_id = t,
    emocion = names(tab_emo),
    frecuencia = as.integer(tab_emo),
    porcentaje_relativo = round(as.numeric(tab_emo) / length(sub_emo) * 100, 2),
    stringsAsFactors = FALSE
  )
  df_emo_list[[t]] <- df_e[order(-df_e$frecuencia), ]
}
df_emociones <- do.call(rbind, df_emo_list)

# 5.5. N-gramas Representativos por Tópico (Bigramas y Trigramas)
extraer_ngrams <- function(textos, n = 2, top_n = 10) {
  toks <- strsplit(textos, "\\s+")
  ngs <- unlist(lapply(toks, function(w) {
    w <- w[!w %in% stopwords_es & nchar(w) >= 3]
    if (length(w) >= n) {
      vapply(1:(length(w) - n + 1), function(idx) paste(w[idx:(idx + n - 1)], collapse = " "), character(1))
    } else {
      character(0)
    }
  }))
  if (length(ngs) == 0) return(character(0))
  tab <- sort(table(ngs), decreasing = TRUE)
  tab <- tab[tab >= 2]
  head(tab, top_n)
}

df_ngrams_list <- list()
for (t in 1:k) {
  sub_txts <- textos_limpios[df_msgs$topico_id == t & !is.na(df_msgs$topico_id)]
  bigs <- extraer_ngrams(sub_txts, n = 2, top_n = 10)
  trigs <- extraer_ngrams(sub_txts, n = 3, top_n = 5)
  
  if (length(bigs) > 0) {
    df_b <- data.frame(
      topico_id = t,
      ngram = names(bigs),
      tipo_ngram = "bigrama",
      frecuencia = as.integer(bigs),
      stringsAsFactors = FALSE
    )
    df_ngrams_list[[paste0(t, "_b")]] <- df_b
  }
  if (length(trigs) > 0) {
    df_tr <- data.frame(
      topico_id = t,
      ngram = names(trigs),
      tipo_ngram = "trigrama",
      frecuencia = as.integer(trigs),
      stringsAsFactors = FALSE
    )
    df_ngrams_list[[paste0(t, "_tr")]] <- df_tr
  }
}
df_ngrams <- do.call(rbind, df_ngrams_list)

# 5.6. Tabla de Asignación por Mensaje
df_asignaciones <- df_msgs[!is.na(df_msgs$topico_id), c("message_id", "topico_id", "prob_topico")]

# ---------------------------------------------------------------------------
# 6. Exportar Resultados Estructurados a data/results/
# ---------------------------------------------------------------------------
cat("  [6/6] Guardando datasets generados en data/results/...\n")
dir.create("data/results", recursive = TRUE, showWarnings = FALSE)

write.csv(df_catalogo, "data/results/topicos_catalogo.csv", row.names = FALSE, fileEncoding = "UTF-8")
write.csv(df_terminos, "data/results/topicos_terminos_frecuencia.csv", row.names = FALSE, fileEncoding = "UTF-8")
write.csv(df_temporal, "data/results/topicos_serie_temporal.csv", row.names = FALSE, fileEncoding = "UTF-8")
write.csv(df_emociones, "data/results/topicos_emociones.csv", row.names = FALSE, fileEncoding = "UTF-8")
write.csv(df_ngrams, "data/results/topicos_ngrams.csv", row.names = FALSE, fileEncoding = "UTF-8")
write.csv(df_asignaciones, "data/results/topicos_asignacion_mensajes.csv", row.names = FALSE, fileEncoding = "UTF-8")

cat("\n")
cat("=============================================================================\n")
cat("  ¡PROCESAMIENTO EN R FINALIZADO CON ÉXITO!\n")
cat("=============================================================================\n")
cat(sprintf("  ✓ Tópicos en catálogo:            %d\n", nrow(df_catalogo)))
cat(sprintf("  ✓ Términos ponderados exportados: %d\n", nrow(df_terminos)))
cat(sprintf("  ✓ Registros serie temporal:       %d\n", nrow(df_temporal)))
cat(sprintf("  ✓ Registros de cruce emocional:   %d\n", nrow(df_emociones)))
cat(sprintf("  ✓ N-gramas representativos:       %d\n", nrow(df_ngrams)))
cat(sprintf("  ✓ Mensajes asignados a tópicos:   %d\n", nrow(df_asignaciones)))
cat("  Archivos generados en data/results/ listos para sincronización con Neon DB.\n\n")
