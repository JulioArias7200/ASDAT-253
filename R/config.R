# =============================================================================
# config.R — carga de configuración
# =============================================================================

#' Valores por defecto del proyecto (si no hay archivo de configuración)
default_config <- function() {
  list(
    project = list(name = "AS_Telegram", timezone = "America/La_Paz"),
    paths = list(
      data_raw = "data/raw",
      data_interim = "data/interim",
      data_processed = "data/processed",
      data_results = "data/results",
      dictionary = "data/dictionary/sentiment_dictionary.csv",
      database = "database/as_telegram.sqlite",
      logs = "logs",
      reports = "reports"
    ),
    import = list(
      telegram_json = "data/raw/result.json",
      reject_service = TRUE,
      keep_media_without_text = FALSE,
      min_word_count = 0,
      anonymize_names = FALSE
    ),
    cleaning = list(
      lowercase = TRUE,
      remove_urls = TRUE,
      url_placeholder = "",
      collapse_whitespace = TRUE,
      keep_emojis = TRUE,
      strip_mentions = FALSE,
      strip_hashtags = FALSE,
      lemmatize = FALSE,
      min_token_length = 2
    ),
    negation = list(
      window = 3L,
      negators = c("no", "ni", "nunca", "jamas", "tampoco", "sin", "nada", "nadie", "jama"),
      double_negation_flip = FALSE
    ),
    sentiment = list(
      min_evidence_terms = 1L,
      multiple_emotions = TRUE,
      reaction_weight = 0.0,
      emoji_weight = 1.0,
      lexical_weight = 1.0
    ),
    topics = list(
      method = "lda", k = 5L, k_range = c(3L, 10L), min_df = 3L,
      max_df = 0.85, ngram_range = c(1L, 2L), seed = 42L
    ),
    markov = list(
      order = 1L, states = c("positivo", "negativo", "neutro"), per_user = FALSE
    ),
    analysis = list(date_from = "2022-12-16", date_to = NULL, exclude_service = TRUE)
  )
}

#' Carga `config/config.yml` si existe; si no, `config.example.yml`; fusiona con defaults.
#' @export
load_config <- function(path = NULL) {
  base <- default_config()
  candidates <- if (!is.null(path)) path else c(
    proj_path("config", "config.yml"),
    proj_path("config", "config.example.yml")
  )
  candidates <- candidates[file.exists(candidates)]
  if (!length(candidates)) return(base)

  cfg <- yaml::read_yaml(candidates[[1]])
  merge_config(base, cfg)
}

#' Fusiona recursivamente la configuración cargada sobre los defaults.
merge_config <- function(base, override) {
  for (nm in names(override)) {
    if (is.list(override[[nm]]) && is.list(base[[nm]])) {
      base[[nm]] <- merge_config(base[[nm]], override[[nm]])
    } else {
      base[[nm]] <- override[[nm]]
    }
  }
  base
}

#' Accesor seguro: cfg$import$telegram_json
#' @export
cfg_get <- function(cfg, ...) {
  keys <- c(...)
  val <- cfg
  for (k in keys) val <- val[[k]]
  val
}
