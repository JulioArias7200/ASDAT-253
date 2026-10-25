# Compara nuestro motor con los resultados de otro repo (ej. Medina). Uso:
#   Rscript scripts/03_comparar_con_medina.R <ruta_repo_medina>
args <- commandArgs(trailingOnly = TRUE); medina <- if (length(args)) args[1] else "../ASDAT-253"
options(emotica.raiz = normalizePath("."))
invisible(lapply(list.files("R", pattern = "\\.R$", full.names = TRUE), source, encoding = "UTF-8"))
s_m <- readRDS(file.path(medina, "data/results/sentiment.rds"))
cat("\n== Medina: filas", nrow(s_m), "| polaridad:\n"); print(table(s_m$polarity_label))
cat("dominante (top 10):\n"); print(head(sort(table(s_m$dominant_emotion), decreasing = TRUE), 10))
cat("evidencia:\n"); print(table(s_m$evidence_level))
cat("intensidad (con emocion): mediana", median(s_m$intensity[!is.na(s_m$dominant_emotion)], na.rm = TRUE),
    "| emoji_signal no vacio:", sum(!is.na(s_m$emoji_signal) & s_m$emoji_signal != 0), "| reaccion no vacia:", sum(!is.na(s_m$reaction_signal) & s_m$reaction_signal != 0), "\n")
r <- preprocess_chat(file.path(medina, "data/raw/result.json"), usuario = "comparacion")
m <- r$mensajes; cat("\nRaw de Medina -> mensajes:", nrow(m), "| con texto:", sum(m$tiene_texto), "| rango:", format(min(m$fecha), "%Y-%m-%d"), "a", format(max(m$fecha), "%Y-%m-%d"), "\n")
s <- score_emotions(m)
tax <- cargar_taxonomia()
dom <- s[order(s$msg_id, -s$puntaje), ]; dom <- dom[!duplicated(dom$msg_id), ]
dom$val <- tax$valencia[match(dom$emocion_id, tax$id)]
j <- data.frame(msg_id = as.character(m$msg_id), periodo = m$periodo_id, stringsAsFactors = FALSE)
j$suya <- as.character(s_m$polarity_label[match(j$msg_id, as.character(s_m$message_id))])
j$suya_det <- j$msg_id %in% as.character(s_m$message_id[!is.na(s_m$dominant_emotion)])
j$nuestra_det <- j$msg_id %in% dom$msg_id
j$nuestra_val <- dom$val[match(j$msg_id, dom$msg_id)]
j <- j[j$msg_id %in% as.character(s_m$message_id), ]
cat("\nMensajes en comun:", nrow(j), "\n")
cat("Detecta alguna emocion -> solo Medina:", sum(j$suya_det & !j$nuestra_det), "| solo nuestro:", sum(!j$suya_det & j$nuestra_det), "| ambos:", sum(j$suya_det & j$nuestra_det), "| ninguno:", sum(!j$suya_det & !j$nuestra_det), "\n")
b <- j[j$suya_det & j$nuestra_det & j$nuestra_val %in% c("positiva", "negativa") & j$suya %in% c("positivo", "negativo"), ]
b$ns <- ifelse(b$nuestra_val == "positiva", "positivo", "negativo")
cat("Polaridad en mensajes con ambos y polar:", nrow(b), "| acuerdo:", round(mean(b$suya == b$ns), 3), "\n"); print(table(medina = b$suya, nuestro = b$ns))
kap <- kappa_cohen(b$suya == "positivo", b$ns == "positivo"); cat("kappa polaridad:", round(kap, 3), "\n")
dd <- merge(data.frame(msg_id = as.character(s_m$message_id), dom_m = s_m$dominant_emotion), dom[, c("msg_id", "emocion_id")], by = "msg_id")
cat("\nPares dominantes mas frecuentes (Medina | nuestro):\n"); print(head(sort(table(paste(dd$dom_m, "|", dd$emocion_id)), decreasing = TRUE), 12))
p <- j[grepl("^(invierno|verano)", j$periodo), ]
tb <- do.call(rbind, lapply(split(p, p$periodo), function(d) data.frame(n = nrow(d), cob_medina = round(mean(d$suya_det), 3), cob_nuestra = round(mean(d$nuestra_det), 3),
   neg_medina = round(mean(d$suya[d$suya_det] == "negativo"), 3), pos_medina = round(mean(d$suya[d$suya_det] == "positivo"), 3),
   neg_nuestra = round(mean(d$nuestra_val[d$nuestra_det] == "negativa"), 3), pos_nuestra = round(mean(d$nuestra_val[d$nuestra_det] == "positiva"), 3))))
cat("\nPor periodo (cobertura y signo entre los detectados):\n"); print(tb)
