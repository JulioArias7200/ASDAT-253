-- =============================================================================
-- AS_Telegram — Esquema SQLite
-- Base de datos local de trazabilidad, resultados y bitácora.
-- Se crea automáticamente desde R/database.R (ensure_database()).
-- NO versionar el archivo .sqlite (ver .gitignore).
-- =============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- -----------------------------------------------------------------------------
-- Corpus: fuente de datos identificada (un export o conjunto de exports)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS corpus (
    corpus_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL,
    source_type   TEXT    NOT NULL,               -- telegram_json | telegram_html | csv | synthetic
    source_path   TEXT,                           -- ruta relativa al repo (no absoluta)
    group_id      TEXT,                           -- id de chat anonimizable
    group_name    TEXT,
    created_at    TEXT    NOT NULL,               -- ISO-8601 UTC
    n_messages    INTEGER,
    notes         TEXT
);

-- -----------------------------------------------------------------------------
-- Lotes de importación (una carga = un lote; permite cargas sucesivas)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS import_batches (
    batch_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    corpus_id     INTEGER NOT NULL,
    source_file   TEXT    NOT NULL,
    file_hash     TEXT,                           -- sha256 para idempotencia
    imported_at   TEXT    NOT NULL,
    n_total       INTEGER,
    n_imported    INTEGER,
    n_rejected    INTEGER,
    n_duplicated  INTEGER,
    n_pending     INTEGER,
    params_json   TEXT,
    status        TEXT    NOT NULL,               -- completed | failed | partial
    FOREIGN KEY (corpus_id) REFERENCES corpus(corpus_id)
);
CREATE INDEX IF NOT EXISTS idx_batch_corpus ON import_batches(corpus_id);

-- -----------------------------------------------------------------------------
-- Mensajes importados (texto original intacto + normalizado)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS messages (
    row_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id     INTEGER NOT NULL,              -- id original de Telegram
    corpus_id      INTEGER NOT NULL,
    batch_id       INTEGER NOT NULL,
    chat_id        TEXT,
    timestamp_utc  TEXT    NOT NULL,              -- ISO-8601 UTC
    timestamp_local TEXT,                         -- ISO-8601 zona America/La_Paz
    tz             TEXT,                          -- zona horaria declarada
    sender_id      TEXT,                          -- anonimizado
    sender_name    TEXT,                          -- puede anonimizarse
    text_original  TEXT,                          -- nunca se altera
    text_norm      TEXT,                          -- texto normalizado (derivado)
    reply_to_id    INTEGER,
    forwarded      INTEGER DEFAULT 0,
    edited         INTEGER DEFAULT 0,
    message_type   TEXT,                          -- message | service
    media_type     TEXT,
    sticker_emoji  TEXT,
    emoji_list     TEXT,                          -- JSON array
    reactions      TEXT,                          -- JSON objeto {emoji: count}
    source_file    TEXT,
    import_batch_id INTEGER,
    review_pending INTEGER DEFAULT 0,
    created_at     TEXT    NOT NULL,
    UNIQUE (corpus_id, message_id),
    FOREIGN KEY (corpus_id) REFERENCES corpus(corpus_id),
    FOREIGN KEY (batch_id)  REFERENCES import_batches(batch_id)
);
CREATE INDEX IF NOT EXISTS idx_msg_timestamp ON messages(timestamp_utc);
CREATE INDEX IF NOT EXISTS idx_msg_corpus    ON messages(corpus_id);
CREATE INDEX IF NOT EXISTS idx_msg_batch     ON messages(batch_id);
CREATE INDEX IF NOT EXISTS idx_msg_sender    ON messages(sender_id);

-- -----------------------------------------------------------------------------
-- Ejecuciones del pipeline (una fila por etapa ejecutada)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pipeline_runs (
    run_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    stage              TEXT    NOT NULL,          -- import|validate|clean|sentiment|temporal|topics|markov|report
    corpus_id          INTEGER,
    batch_id           INTEGER,
    started_at         TEXT    NOT NULL,
    finished_at        TEXT,
    duration_s         REAL,
    code_version       TEXT,
    dictionary_version TEXT,
    params_json        TEXT,
    n_processed        INTEGER,
    n_discarded        INTEGER,
    status             TEXT    NOT NULL,          -- running | completed | failed
    warnings           TEXT,
    errors             TEXT,
    FOREIGN KEY (corpus_id) REFERENCES corpus(corpus_id),
    FOREIGN KEY (batch_id)  REFERENCES import_batches(batch_id)
);
CREATE INDEX IF NOT EXISTS idx_run_stage  ON pipeline_runs(stage);
CREATE INDEX IF NOT EXISTS idx_run_status ON pipeline_runs(status);

-- -----------------------------------------------------------------------------
-- Resultados de sentimiento (una fila por mensaje y ejecución)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sentiment_results (
    result_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id             INTEGER NOT NULL,
    message_id         INTEGER NOT NULL,
    corpus_id          INTEGER NOT NULL,
    polarity           REAL,                      -- score léxico continuo
    polarity_label     TEXT,                      -- positive|negative|neutral|indeterminado
    emotion_scores     TEXT,                      -- JSON {categoria: score}
    detected_emotions  TEXT,                      -- JSON array
    dominant_emotion   TEXT,
    intensity          REAL,
    evidence_level     TEXT,                      -- suficiente|insuficiente|sin_evidencia
    n_terms            INTEGER,
    dictionary_version TEXT,
    created_at         TEXT NOT NULL,
    FOREIGN KEY (run_id) REFERENCES pipeline_runs(run_id)
);
CREATE INDEX IF NOT EXISTS idx_sent_msg_cat  ON sentiment_results(corpus_id, dominant_emotion);
CREATE INDEX IF NOT EXISTS idx_sent_msg_date ON sentiment_results(message_id);
CREATE INDEX IF NOT EXISTS idx_sent_run      ON sentiment_results(run_id);

-- -----------------------------------------------------------------------------
-- Versiones del diccionario emocional
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dictionary_versions (
    version      TEXT PRIMARY KEY,
    created_at   TEXT NOT NULL,
    n_terms      INTEGER,
    source_hash  TEXT,
    notes        TEXT
);

-- -----------------------------------------------------------------------------
-- Historial de cambios del diccionario (auditoría de ediciones)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dictionary_changes (
    change_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    version         TEXT NOT NULL,
    timestamp       TEXT NOT NULL,
    action          TEXT NOT NULL,                -- add | edit | remove
    term            TEXT,
    normalized_term TEXT,
    category        TEXT,
    old_value       TEXT,
    new_value       TEXT,
    source          TEXT,
    notes           TEXT,
    FOREIGN KEY (version) REFERENCES dictionary_versions(version)
);
CREATE INDEX IF NOT EXISTS idx_dictchange_cat ON dictionary_changes(category);

-- -----------------------------------------------------------------------------
-- Artefactos generados por cada ejecución
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS artifacts (
    artifact_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id      INTEGER,
    type        TEXT,                             -- figure | table | report | export | data
    path        TEXT,
    description TEXT,
    created_at  TEXT NOT NULL,
    FOREIGN KEY (run_id) REFERENCES pipeline_runs(run_id)
);
CREATE INDEX IF NOT EXISTS idx_artifact_run ON artifacts(run_id);

-- -----------------------------------------------------------------------------
-- Bitácora de eventos (incluye errores y operaciones no completadas)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_events (
    event_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id             INTEGER,
    timestamp          TEXT    NOT NULL,
    session_id         TEXT,
    action             TEXT    NOT NULL,
    corpus_id          INTEGER,
    batch_id           INTEGER,
    n_messages         INTEGER,
    params_json        TEXT,
    code_version       TEXT,
    dictionary_version TEXT,
    status             TEXT    NOT NULL,          -- started | completed | failed | interrupted
    duration_s         REAL,
    warnings           TEXT,
    errors             TEXT,
    artifacts          TEXT,
    FOREIGN KEY (run_id) REFERENCES pipeline_runs(run_id)
);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_events(action);
CREATE INDEX IF NOT EXISTS idx_audit_status ON audit_events(status);

-- -----------------------------------------------------------------------------
-- Etiquetado manual (validación) — una fila por mensaje anotado
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS manual_labels (
    label_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id    INTEGER NOT NULL,
    corpus_id     INTEGER NOT NULL,
    annotator     TEXT    NOT NULL,
    polarity      TEXT,
    emotions      TEXT,                           -- JSON array
    notes         TEXT,
    labeled_at    TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_label_msg ON manual_labels(message_id);
