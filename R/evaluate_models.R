# =============================================================================
# evaluate_models.R — validación manual y métricas (solo si hay etiquetas)
# =============================================================================

#' Métricas por categoría (precision, recall, F1) para clasificación multietiqueta
#' @export
multilabel_metrics <- function(predicted, reference, labels) {
  do.call(rbind, lapply(labels, function(l) {
    tp <- sum(predicted == l & reference == l)
    fp <- sum(predicted == l & reference != l)
    fn <- sum(predicted != l & reference == l)
    prec <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
    rec  <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
    f1   <- if (!is.na(prec) && !is.na(rec) && (prec + rec) > 0) 2 * prec * rec / (prec + rec) else NA_real_
    data.frame(label = l, tp = tp, fp = fp, fn = fn, precision = prec, recall = rec, f1 = f1)
  }))
}

#' Matriz de confusión (clasificación mutuamente excluyente)
#' @export
confusion_matrix <- function(predicted, reference, labels) {
  t <- table(factor(predicted, levels = labels), factor(reference, levels = labels))
  dimnames(t) <- list(Predicho = labels, Referencia = labels)
  t
}

#' Precisión/recall/F1 globales para etiqueta positiva (macro)
#' @export
binary_metrics <- function(predicted_positive, reference_positive) {
  tp <- sum(predicted_positive & reference_positive)
  fp <- sum(predicted_positive & !reference_positive)
  fn <- sum(!predicted_positive & reference_positive)
  prec <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
  rec  <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_
  f1   <- if (!is.na(prec) && !is.na(rec) && (prec + rec) > 0) 2 * prec * rec / (prec + rec) else NA_real_
  list(precision = prec, recall = rec, f1 = f1, tp = tp, fp = fp, fn = fn)
}

#' Cobertura del diccionario: proporción de mensajes con evidencia suficiente
#' @export
dictionary_coverage <- function(sentiments) {
  n <- nrow(sentiments)
  if (!n) return(list(coverage = NA, indeterminate = NA))
  list(
    coverage = mean(sentiments$evidence_level == "suficiente"),
    indeterminate = mean(sentiments$polarity_label == "indeterminado")
  )
}

#' Acuerdo entre anotadores (Cohen's kappa sobre etiquetas categóricas)
#' @export
cohens_kappa <- function(a, b, labels) {
  a <- factor(a, levels = labels); b <- factor(b, levels = labels)
  tab <- table(a, b)
  po <- sum(diag(tab)) / sum(tab)
  pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  if (pe == 1) return(NA_real_)
  (po - pe) / (1 - pe)
}

#' Guarda una etiqueta manual y registra en SQLite
#' @export
add_manual_label <- function(con, message_id, corpus_id, annotator,
                             polarity, emotions = character(0), notes = NA) {
  DBI::dbExecute(con,
    "INSERT INTO manual_labels (message_id, corpus_id, annotator, polarity,
       emotions, notes, labeled_at) VALUES (?,?,?,?,?,?,?)",
    params = list(message_id, corpus_id, annotator, polarity,
                  as_json(emotions), notes, now_utc()))
}

#' Evalúa el pipeline contra etiquetas manuales presentes en SQLite
#' @export
evaluate_against_manual <- function(con, corpus_id, sentiments) {
  labels <- DBI::dbGetQuery(con,
    "SELECT message_id, annotator, polarity FROM manual_labels WHERE corpus_id = ?",
    params = list(corpus_id))
  if (!nrow(labels)) return(list(available = FALSE, message = "No hay etiquetas manuales."))
  df <- dplyr::inner_join(labels, sentiments[, c("message_id", "polarity_label")], by = "message_id")
  labels_levels <- c("positivo", "negativo", "neutro", "indeterminado")
  cm <- confusion_matrix(df$polarity_label, df$polarity, labels_levels)
  metrics <- multilabel_metrics(df$polarity_label, df$polarity, labels_levels)
  list(available = TRUE, n = nrow(df), confusion = cm, metrics = metrics)
}
