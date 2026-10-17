# =============================================================================
# analyze_markov.R — transiciones de estado (cadena de Markov)
# =============================================================================

#' Mapea etiquetas de polaridad a estados de Markov
#' @export
to_state <- function(label, states = c("positivo", "negativo", "neutro")) {
  ifelse(label == "positivo", "positivo",
         ifelse(label == "negativo", "negativo", "neutro"))
}

#' Construye la matriz de transición. Las filas sin origen observado quedan NA
#' (no se inventan transiciones).
#' @export
build_transition_matrix <- function(sequence, states = c("positivo", "negativo", "neutro")) {
  n <- length(states); idx <- stats::setNames(seq_len(n), states)
  counts <- matrix(0, n, n, dimnames = list(states, states))
  seq <- sequence[!is.na(sequence)]
  if (length(seq) > 1) {
    for (i in seq_len(length(seq) - 1)) {
      a <- idx[[seq[i]]]; b <- idx[[seq[i + 1]]]
      if (!is.null(a) && !is.null(b)) counts[a, b] <- counts[a, b] + 1
    }
  }
  P <- counts
  for (i in seq_len(n)) {
    rs <- sum(counts[i, ])
    P[i, ] <- if (rs > 0) counts[i, ] / rs else NA_real_
  }
  list(counts = counts, P = P)
}

#' Distribución estacionaria (eigenvector izquierdo). NA si no es única/irreducible.
#' @export
stationary_distribution <- function(P) {
  if (any(is.na(P))) return(rep(NA_real_, nrow(P)))
  ev <- eigen(t(P))
  i <- which.min(abs(ev$values - 1))
  v <- Re(ev$vectors[, i]); v <- abs(v)
  if (sum(v) == 0) return(rep(NA_real_, nrow(P)))
  v / sum(v)
}

#' Tiempo medio de permanencia (1 / (1 - P[i,i]))
#' @export
mean_residence_time <- function(P, states) {
  d <- diag(P)
  out <- ifelse(is.na(d) | d >= 1, NA_real_, 1 / (1 - d))
  stats::setNames(out, states)
}

#' Tiempo medio de primera pasada desde `from` hacia cualquiera en `to`
#' @export
mean_first_passage <- function(P, from, to, states) {
  if (any(is.na(P))) return(NA_real_)
  n <- nrow(P); idx <- stats::setNames(seq_len(n), states)
  absorbing <- unname(idx[to])
  transient <- setdiff(seq_len(n), absorbing)
  if (idx[[from]] %in% absorbing) return(0)
  if (!length(transient)) return(Inf)
  Q <- P[transient, transient, drop = FALSE]
  m <- tryCatch(solve(diag(length(transient)) - Q, rep(1, length(transient))),
                error = function(e) rep(NA_real_, length(transient)))
  as.numeric(m[match(idx[[from]], transient)])
}

#' Análisis completo de Markov sobre mensajes con sentimiento
#' @export
markov_analysis <- function(df, cfg = load_config(), per_user = FALSE) {
  states <- cfg_get(cfg, "markov", "states") %||% c("positivo", "negativo", "neutro")
  df <- df[!is.na(df$ts), ]
  df <- df[order(df$ts), ]

  seqs <- list()
  if (isTRUE(per_user)) {
    for (u in unique(df$sender_id)) seqs[[u]] <- to_state(df$polarity_label[df$sender_id == u], states)
  } else {
    seqs[["global"]] <- to_state(df$polarity_label, states)
  }

  results <- lapply(names(seqs), function(nm) {
    tm <- build_transition_matrix(seqs[[nm]], states)
    pi <- stationary_distribution(tm$P)
    list(name = nm, n = length(seqs[[nm]]), counts = tm$counts, P = tm$P,
         stationary = stats::setNames(pi, states),
         residence = mean_residence_time(tm$P, states),
         recovery = mean_first_passage(tm$P, "negativo", c("positivo", "neutro"), states))
  })
  names(results) <- names(seqs)
  list(states = states, per_user = per_user, results = results, sequence = seqs[["global"]])
}
