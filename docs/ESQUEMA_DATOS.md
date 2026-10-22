# ESQUEMA DE DATOS Y CONTRATOS DE MÓDULOS

Documento de referencia para la implementación en R. Define el formato canónico
interno, los contratos de entrada/salida de cada módulo y las convenciones.

## 1. Formato canónico de `messages`

Toda importación se transforma a un `tibble` con estas columnas (todas en UTF-8):

| Columna | Tipo R | Descripción |
|---|---|---|
| `message_id` | integer | Id original de Telegram |
| `corpus_id` | integer | Id interno del corpus |
| `batch_id` | integer | Lote de importación |
| `chat_id` | character | Id de chat (anonimizable) |
| `timestamp_utc` | POSIXct (UTC) | Fecha/hora en UTC (desde `date_unixtime`) |
| `timestamp_local` | POSIXct | Fecha/hora en `America/La_Paz` |
| `tz` | character | Zona horaria declarada |
| `sender_id` | character | Id anonimizado (`user######` o hash) |
| `sender_name` | character | Nombre (puede anonimizarse) |
| `text_original` | character | Texto intacto, sin alterar |
| `text_norm` | character | Texto normalizado (derivado, columna aparte) |
| `reply_to_id` | integer | Id del mensaje referenciado |
| `forwarded` | logical | Reenviado |
| `edited` | logical | Editado |
| `message_type` | character | `message` \| `service` |
| `media_type` | character | `photo`\|`file`\|`sticker`\|`animation`\|`video_file`\|`audio_file`\|`voice_message`\|`web_page`\|NA |
| `sticker_emoji` | character | Emoji del sticker, si existe |
| `emoji_list` | list/character | Emojis presentes en el texto |
| `reactions` | list | `{emoji: count}` |
| `source_file` | character | Archivo de origen (relativo) |
| `import_batch_id` | integer | Igual a `batch_id` |
| `review_pending` | logical | Requiere revisión manual |

### Reglas de texto
- `text_original`: si el export entrega `text` como lista de partes, se concatenan
  las partes de tipo `plain`/`link`/etc. conservando el contenido visible.
- `text_norm`: minúsculas, URLs según política, espacios normalizados, **emojis
  conservados**; no elimina negaciones ni palabras cortas.
- Nunca se sobrescribe `text_original`.

### Procedencia
Cada resultado debe declarar: `corpus_id`, `batch_id`, `run_id`,
`dictionary_version`, `code_version`, parámetros y fecha.

## 2. Diccionario emocional (`data/dictionary/sentiment_dictionary.csv`)

Columnas:
`term, normalized_term, category, polarity, weight, term_type, language_variant,
negation_sensitive, source, notes, dictionary_version`.

- `term_type`: `word` | `phrase` | `emoji` | `colloquial`.
- `polarity`: `positive` | `negative` | `neutral`.
- `weight`: intensidad opcional (default 1).
- 18 categorías: alegría, tristeza, ira, miedo, sorpresa, asco, amor, gratitud,
  confianza, anticipación, frustración, ansiedad, esperanza, orgullo, vergüenza,
  diversión, aburrimiento, alivio. Más `sin_evidencia` como estado (no término).

## 3. Contratos de módulos (`R/*.R`)

Convención: cada función devuelve `list(data = ..., meta = list(...))` cuando
produce datos auditables, o un `tibble` cuando es un helper puro. Los errores se
propagan como condiciones R y se registran en la bitácora por el orquestador.

### `config.R`
- `load_config(path = "config/config.yml")` → `list`
- `default_config()` → `list` (valores por defecto si no hay archivo local)

### `import_corpus.R`
- `import_telegram_json(path, corpus_id, batch_id, tz)` → `list(messages = tibble, report = list)`
- `import_csv(path, corpus_id, batch_id, schema)` → `list(messages, report)`
- `import_html(path, ...)` → opcional, documentado.
- **Salida:** tibble canónico + reporte (`n_total, n_imported, n_rejected, n_duplicated, n_pending, reasons`).
- **No elimina silenciosamente**: todo mensaje descartado queda contabilizado y/o en `review_pending`.

### `validate_corpus.R`
- `validate_messages(messages)` → `list(ok = logical, issues = tibble)`
- Comprueba esquema, tipos, nulos, fechas, ids duplicados, textos.

### `clean_text.R`
- `normalize_text(text, config)` → character (vectorizado)
- `clean_messages(messages, config)` → tibble (añade `text_norm`)

### `process_emojis.R`
- `extract_emojis(text)` → list de character
- `emoji_signal(emoji_list, dictionary)` → list(score, emotions)

### `detect_negation.R`
- `detect_negation(tokens, window = 3, exceptions)` → tibble(token, negated)
- `apply_negation(tokens, ...)` → character con marcado interno

### `sentiment_dictionary.R`
- `load_dictionary(path)` → tibble
- `dictionary_version(path)` → character (hash)
- `add_term(...)`, `save_dictionary(...)` (con historial)

### `analyze_sentiment.R`
- `score_message(text, dictionary, config)` → list(polarity, emotions, dominant, intensity, evidence_level, n_terms)
- `analyze_sentiment(messages, dictionary, config)` → tibble con una fila por mensaje
- Multietiqueta: varias emociones por mensaje; `evidence_level` ∈ `suficiente|insuficiente|sin_evidencia`.
- `combined` no se mezclará sin calibración: campos separados
  `polarity_lexical`, `emoji_signal`, `reaction_signal`.

### `analyze_temporal.R`
- `temporal_aggregate(messages, sentiments, by = "day|week|month")` → tibble
- `rolling_polarity(tbl, window)` → tibble
- Reporta frecuencias absolutas y proporciones normalizadas por volumen.

### `analyze_topics.R`
- `fit_topics(texts, k, method = "lda")` → list(model, doc_topics, terms)
- `topic_coherence(...)`, `choose_k(...)`, `cross_topic_emotion(...)`.

### `analyze_markov.R`
- `build_transition_matrix(states, order)` → matrix
- `stationary_distribution(P)`, `mean_residence_time(P)`, `mean_first_passage(P, from, to)`
- Estados sin observaciones se marcan explícitamente (no se inventan).

### `database.R`
- `ensure_database(path)`, `db_connect(path)`, `db_disconnect(con)`
- `insert_*`, `query_*` para cada tabla.

### `audit_log.R`
- `audit_start(action, ...)` → `run_id`
- `audit_finish(run_id, status, ...)`
- `audit_error(run_id, error)`
- Garantiza que una ejecución interrumpida quede `running`/`failed`, nunca `completed`.

### `report_generation.R`
- `render_report(corpus_id, ...)` → rutas de `.tex`/figuras/tablas.

### `plotting.R`
- Funciones `plot_*` que devuelven `ggplot`/`plotly`, sin rutas absolutas.

### `helpers.R`
- Utilidades (`%||%`, `hash_string`, `anon_id`, `read_json_utf8`, `write_json_utf8`).

## 4. Versión de código

`code_version` = hash corto del árbol de `R/` y `scripts/` (o "dev" si no hay Git).
