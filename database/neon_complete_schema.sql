-- =============================================================================
-- ESQUEMA FÍSICO INTEGRAL PARA NEON POSTGRESQL (SERVERLESS)
-- ASDAT-253: Minería de Texto, Sentimientos, Multimedia y Bitácora en Tiempo Real
-- =============================================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. Catálogo Institucional (Docentes y Materias)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS docentes (
    docente_id         VARCHAR(100) PRIMARY KEY,
    nombre_completo    VARCHAR(255) NOT NULL,
    materias_que_dicta TEXT,
    alias_regex        TEXT,
    creado_en          TIMESTAMPTZ DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS materias (
    codigo_materia        VARCHAR(50) PRIMARY KEY,
    nombre_materia        VARCHAR(255) NOT NULL,
    paralelos_disponibles VARCHAR(100),
    docentes_asignados    TEXT,
    alias_regex           TEXT,
    creado_en             TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- -----------------------------------------------------------------------------
-- 2. Tópicos Latentes (LDA)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lda_topicos (
    id              BIGSERIAL PRIMARY KEY,
    topico_id       INTEGER NOT NULL,
    nombre_etiqueta VARCHAR(255) NOT NULL,
    termino         VARCHAR(100) NOT NULL,
    beta_prob       FLOAT NOT NULL,
    ranking_pos     INTEGER NOT NULL,
    creado_en       TIMESTAMPTZ DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS idx_lda_topico_id ON lda_topicos(topico_id);
CREATE INDEX IF NOT EXISTS idx_lda_termino ON lda_topicos(termino);

-- -----------------------------------------------------------------------------
-- 3. Mensajes (Corpus Consolidado, Sentimiento, Features y Multimedia)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mensajes (
    message_id              BIGINT PRIMARY KEY,
    corpus_id               INTEGER DEFAULT 1,
    batch_id                INTEGER DEFAULT 1,
    chat_id                 VARCHAR(100),
    timestamp_utc           TIMESTAMPTZ NOT NULL,
    timestamp_local         TIMESTAMP NOT NULL,
    tz                      VARCHAR(50) DEFAULT 'America/La_Paz',
    sender_id               VARCHAR(100),
    sender_name             TEXT,
    text_original           TEXT,
    text_norm               TEXT,
    reply_to_id             BIGINT,
    forwarded               BOOLEAN DEFAULT FALSE,
    edited                  BOOLEAN DEFAULT FALSE,
    message_type            VARCHAR(50) DEFAULT 'message',
    media_type              VARCHAR(50),
    sticker_emoji           VARCHAR(50),
    emoji_list              JSONB DEFAULT '[]'::JSONB,
    reactions               JSONB DEFAULT '[]'::JSONB,
    source_file             VARCHAR(255) DEFAULT 'result.json',
    
    -- Sentimiento y Emociones (desde sentiment.rds)
    polarity                FLOAT DEFAULT 0.0,
    polarity_label          VARCHAR(50) DEFAULT 'indeterminado',
    emotion_scores          JSONB DEFAULT '[]'::JSONB,
    detected_emotions       JSONB DEFAULT '[]'::JSONB,
    dominant_emotion        VARCHAR(50),
    intensity               FLOAT DEFAULT 0.0,
    evidence_level          VARCHAR(50) DEFAULT 'sin_evidencia',
    n_terms                 INTEGER DEFAULT 0,
    emoji_signal            FLOAT DEFAULT 0.0,
    emoji_emotions          JSONB DEFAULT '[]'::JSONB,
    reaction_signal         FLOAT DEFAULT 0.0,
    reaction_emotions       JSONB DEFAULT '[]'::JSONB,
    
    -- Tópico Latente (desde topics.rds)
    topico_lda_id           INTEGER,
    
    -- Características Lingüísticas Superficiales (desde linguistic_features.rds)
    n_chars                 INTEGER DEFAULT 0,
    n_tokens                INTEGER DEFAULT 0,
    n_words                 INTEGER DEFAULT 0,
    n_unique_words          INTEGER DEFAULT 0,
    unique_ratio            FLOAT DEFAULT 0.0,
    mean_word_len           FLOAT DEFAULT 0.0,
    n_questions             INTEGER DEFAULT 0,
    n_exclamations          INTEGER DEFAULT 0,
    n_upper_words           INTEGER DEFAULT 0,
    upper_ratio             FLOAT DEFAULT 0.0,
    n_emojis                INTEGER DEFAULT 0,
    n_hashtags              INTEGER DEFAULT 0,
    n_mentions              INTEGER DEFAULT 0,
    n_urls                  INTEGER DEFAULT 0,
    n_repeated_chars        INTEGER DEFAULT 0,
    n_repeated_punct        INTEGER DEFAULT 0,
    n_intensity             INTEGER DEFAULT 0,
    
    -- Multimedia explícita (rescate de stickers, gifs y fotos)
    es_sticker              BOOLEAN DEFAULT FALSE,
    sticker_emocion         VARCHAR(50),
    es_gif                  BOOLEAN DEFAULT FALSE,
    gif_nombre              TEXT,
    tiene_imagen            BOOLEAN DEFAULT FALSE,
    ruta_imagen             TEXT,
    archivo_adjunto         TEXT,
    thumbnail_adjunto       TEXT,
    
    -- Trazabilidad
    importado_en            TIMESTAMPTZ DEFAULT clock_timestamp()
);

-- Índices de alto rendimiento para el Dashboard
CREATE INDEX IF NOT EXISTS idx_msg_timestamp_local ON mensajes(timestamp_local);
CREATE INDEX IF NOT EXISTS idx_msg_sender_id ON mensajes(sender_id);
CREATE INDEX IF NOT EXISTS idx_msg_dominant_emotion ON mensajes(dominant_emotion);
CREATE INDEX IF NOT EXISTS idx_msg_topico_lda ON mensajes(topico_lda_id);
CREATE INDEX IF NOT EXISTS idx_msg_polarity_label ON mensajes(polarity_label);
CREATE INDEX IF NOT EXISTS idx_msg_es_sticker ON mensajes(es_sticker);
CREATE INDEX IF NOT EXISTS idx_msg_es_gif ON mensajes(es_gif);
CREATE INDEX IF NOT EXISTS idx_msg_tiene_imagen ON mensajes(tiene_imagen);

-- -----------------------------------------------------------------------------
-- 4. Ponderaciones TF-IDF por Mensaje (122.971 registros)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tfidf_mensajes (
    id          BIGSERIAL PRIMARY KEY,
    message_id  BIGINT NOT NULL,
    termino     VARCHAR(100) NOT NULL,
    tf_count    INTEGER NOT NULL,
    df          INTEGER NOT NULL,
    idf         FLOAT NOT NULL,
    tf          FLOAT NOT NULL,
    tfidf       FLOAT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tfidf_msg_id ON tfidf_mensajes(message_id);
CREATE INDEX IF NOT EXISTS idx_tfidf_termino ON tfidf_mensajes(termino);
CREATE INDEX IF NOT EXISTS idx_tfidf_score_desc ON tfidf_mensajes(tfidf DESC);

-- -----------------------------------------------------------------------------
-- 5. Frecuencias de N-gramas (27.334 registros)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ngrams_frecuencias (
    id         BIGSERIAL PRIMARY KEY,
    size       INTEGER NOT NULL,
    ngram      VARCHAR(255) NOT NULL,
    count      INTEGER NOT NULL,
    prop       FLOAT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ngrams_size_count ON ngrams_frecuencias(size, count DESC);
CREATE INDEX IF NOT EXISTS idx_ngrams_term ON ngrams_frecuencias(ngram);

-- -----------------------------------------------------------------------------
-- 6. Métricas Temporales Agregadas (Diario, Semanal, Mensual)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS metricas_temporales (
    id               BIGSERIAL PRIMARY KEY,
    periodo_tipo     VARCHAR(20) NOT NULL CHECK (periodo_tipo IN ('daily', 'weekly', 'monthly')),
    fecha_inicio     DATE NOT NULL,
    n_messages       INTEGER NOT NULL,
    n_analyzed       INTEGER NOT NULL,
    polarity_mean    FLOAT DEFAULT 0.0,
    n_positive       INTEGER DEFAULT 0,
    n_negative       INTEGER DEFAULT 0,
    n_neutral        INTEGER DEFAULT 0,
    n_indeterminate  INTEGER DEFAULT 0,
    
    -- 18 Emociones
    alegria          INTEGER DEFAULT 0,
    tristeza         INTEGER DEFAULT 0,
    ira              INTEGER DEFAULT 0,
    miedo            INTEGER DEFAULT 0,
    sorpresa         INTEGER DEFAULT 0,
    asco             INTEGER DEFAULT 0,
    amor             INTEGER DEFAULT 0,
    gratitud         INTEGER DEFAULT 0,
    confianza        INTEGER DEFAULT 0,
    anticipacion     INTEGER DEFAULT 0,
    frustracion      INTEGER DEFAULT 0,
    ansiedad         INTEGER DEFAULT 0,
    esperanza        INTEGER DEFAULT 0,
    orgullo          INTEGER DEFAULT 0,
    verguenza        INTEGER DEFAULT 0,
    diversion        INTEGER DEFAULT 0,
    aburrimiento     INTEGER DEFAULT 0,
    alivio           INTEGER DEFAULT 0,
    
    prop_positive    FLOAT DEFAULT 0.0,
    prop_negative    FLOAT DEFAULT 0.0,
    prop_neutral     FLOAT DEFAULT 0.0,
    polarity_ma      FLOAT
);

CREATE INDEX IF NOT EXISTS idx_temp_tipo_fecha ON metricas_temporales(periodo_tipo, fecha_inicio);

-- -----------------------------------------------------------------------------
-- 7. Modelo de Markov y Dinámica Estocástica
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS markov_transiciones (
    id               BIGSERIAL PRIMARY KEY,
    estado_origen    VARCHAR(20) NOT NULL,
    estado_destino   VARCHAR(20) NOT NULL,
    conteo           INTEGER NOT NULL,
    probabilidad     FLOAT NOT NULL,
    prob_estacionaria FLOAT,
    tiempo_residencia FLOAT,
    tiempo_recuperacion FLOAT
);

-- -----------------------------------------------------------------------------
-- 8. Diccionario Emocional y de Jergas (320 términos)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS diccionario_sentimientos (
    id                 BIGSERIAL PRIMARY KEY,
    term               VARCHAR(100) NOT NULL,
    normalized_term    VARCHAR(100) NOT NULL,
    category           VARCHAR(50) NOT NULL,
    polarity           VARCHAR(20) NOT NULL,
    weight             FLOAT DEFAULT 1.0,
    term_type          VARCHAR(30) DEFAULT 'word',
    language_variant   VARCHAR(20) DEFAULT 'es',
    negation_sensitive BOOLEAN DEFAULT TRUE,
    source             VARCHAR(100),
    notes              TEXT,
    dictionary_version VARCHAR(50) DEFAULT 'v1'
);

CREATE INDEX IF NOT EXISTS idx_dict_term ON diccionario_sentimientos(normalized_term);
CREATE INDEX IF NOT EXISTS idx_dict_category ON diccionario_sentimientos(category);

-- -----------------------------------------------------------------------------
-- 9. GIFs y Animaciones Específicas (24 registros)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS gifs_animaciones (
    id               BIGSERIAL PRIMARY KEY,
    mensaje_id       BIGINT NOT NULL,
    fecha            TIMESTAMPTZ,
    usuario_nombre   TEXT,
    gif_nombre       TEXT,
    archivo_adjunto  TEXT,
    thumbnail_adjunto TEXT
);
CREATE INDEX IF NOT EXISTS idx_gifs_msg ON gifs_animaciones(mensaje_id);

-- -----------------------------------------------------------------------------
-- 10. Menciones de Docentes (para el Dashboard)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS menciones_docentes (
    id                  BIGSERIAL PRIMARY KEY,
    mensaje_id          BIGINT NOT NULL,
    docente_id          VARCHAR(100),
    docente_mencionado  TEXT,
    materia_mencionada  TEXT,
    codigo_materia      VARCHAR(50),
    fecha               TIMESTAMPTZ,
    usuario_nombre      TEXT,
    texto_limpio        TEXT,
    sentimiento_propio  VARCHAR(50),
    sentimiento_score   FLOAT,
    emocion_propia      VARCHAR(50)
);
CREATE INDEX IF NOT EXISTS idx_menc_docente ON menciones_docentes(docente_id);
CREATE INDEX IF NOT EXISTS idx_menc_materia ON menciones_docentes(codigo_materia);

-- -----------------------------------------------------------------------------
-- 11. Bitácora de Auditoría en Tiempo Real (Change Data Capture)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bitacora_cambios (
    bitacora_id         BIGSERIAL PRIMARY KEY,
    esquema             VARCHAR(63) NOT NULL DEFAULT 'public',
    tabla_afectada      VARCHAR(63) NOT NULL,
    operacion           VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')),
    registro_id         VARCHAR(100),
    datos_previos       JSONB,
    datos_nuevos        JSONB,
    diff_modificaciones JSONB,
    usuario_aplicacion  VARCHAR(100) DEFAULT 'sistema',
    ip_origen           VARCHAR(45),
    endpoint_origen     TEXT,
    transaccion_xid     BIGINT DEFAULT txid_current(),
    fecha_hora          TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_bitacora_tabla_op ON bitacora_cambios(tabla_afectada, operacion);
CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora_cambios(fecha_hora DESC);
CREATE INDEX IF NOT EXISTS idx_bitacora_registro ON bitacora_cambios(tabla_afectada, registro_id);
CREATE INDEX IF NOT EXISTS idx_bitacora_diff_gin ON bitacora_cambios USING gin (diff_modificaciones);

-- -----------------------------------------------------------------------------
-- 12. Bitácora de Procesos y Minería de Datos
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bitacora_procesos_mineria (
    proceso_id          BIGSERIAL PRIMARY KEY,
    nombre_pipeline     VARCHAR(100) NOT NULL,
    fase                VARCHAR(50) NOT NULL,
    estado              VARCHAR(20) NOT NULL CHECK (estado IN ('INICIADO', 'EN_PROCESO', 'EXITOSO', 'FALLIDO')),
    parametros_json     JSONB,
    metricas_json       JSONB,
    duracion_ms         INTEGER,
    mensaje_error       TEXT,
    iniciado_en         TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    finalizado_en       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_proc_mineria_estado ON bitacora_procesos_mineria(nombre_pipeline, estado);
CREATE INDEX IF NOT EXISTS idx_proc_mineria_fecha ON bitacora_procesos_mineria(iniciado_en DESC);

-- -----------------------------------------------------------------------------
-- 13. Función Trigger Genérica de Bitácora Inmediata
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registrar_bitacora_cambio()
RETURNS TRIGGER AS $$
DECLARE
    v_old_json JSONB := NULL;
    v_new_json JSONB := NULL;
    v_diff JSONB := '{}'::JSONB;
    v_key TEXT;
    v_pk_val TEXT := NULL;
    v_app_user TEXT;
    v_app_ip TEXT;
    v_app_endpoint TEXT;
BEGIN
    v_app_user     := NULLIF(current_setting('app.current_user', true), '');
    v_app_ip       := NULLIF(current_setting('app.current_ip', true), '');
    v_app_endpoint := NULLIF(current_setting('app.current_endpoint', true), '');

    IF (TG_OP = 'DELETE') THEN
        v_old_json := to_jsonb(OLD);
        v_pk_val := COALESCE(v_old_json->>'message_id', v_old_json->>'id', v_old_json->>'emoji', v_old_json->>'token', v_old_json->>'docente_id', v_old_json->>'codigo_materia', v_old_json->>'topico_id');
        
        INSERT INTO bitacora_cambios (
            tabla_afectada, operacion, registro_id, datos_previos, datos_nuevos, diff_modificaciones,
            usuario_aplicacion, ip_origen, endpoint_origen, fecha_hora
        ) VALUES (
            TG_TABLE_NAME, TG_OP, v_pk_val, v_old_json, NULL, NULL,
            COALESCE(v_app_user, 'db_user:' || current_user), v_app_ip, v_app_endpoint, clock_timestamp()
        );
        RETURN OLD;

    ELSIF (TG_OP = 'UPDATE') THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);
        v_pk_val := COALESCE(v_new_json->>'message_id', v_new_json->>'id', v_new_json->>'emoji', v_new_json->>'token', v_new_json->>'docente_id', v_new_json->>'codigo_materia', v_new_json->>'topico_id');

        FOR v_key IN SELECT jsonb_object_keys(v_new_json)
        LOOP
            IF v_new_json->v_key IS DISTINCT FROM v_old_json->v_key THEN
                v_diff := v_diff || jsonb_build_object(
                    v_key, jsonb_build_object('anterior', v_old_json->v_key, 'nuevo', v_new_json->v_key)
                );
            END IF;
        END LOOP;

        IF v_diff <> '{}'::JSONB THEN
            INSERT INTO bitacora_cambios (
                tabla_afectada, operacion, registro_id, datos_previos, datos_nuevos, diff_modificaciones,
                usuario_aplicacion, ip_origen, endpoint_origen, fecha_hora
            ) VALUES (
                TG_TABLE_NAME, TG_OP, v_pk_val, v_old_json, v_new_json, v_diff,
                COALESCE(v_app_user, 'db_user:' || current_user), v_app_ip, v_app_endpoint, clock_timestamp()
            );
        END IF;
        RETURN NEW;

    ELSIF (TG_OP = 'INSERT') THEN
        v_new_json := to_jsonb(NEW);
        v_pk_val := COALESCE(v_new_json->>'message_id', v_new_json->>'id', v_new_json->>'emoji', v_new_json->>'token', v_new_json->>'docente_id', v_new_json->>'codigo_materia', v_new_json->>'topico_id');

        INSERT INTO bitacora_cambios (
            tabla_afectada, operacion, registro_id, datos_previos, datos_nuevos, diff_modificaciones,
            usuario_aplicacion, ip_origen, endpoint_origen, fecha_hora
        ) VALUES (
            TG_TABLE_NAME, TG_OP, v_pk_val, NULL, v_new_json, NULL,
            COALESCE(v_app_user, 'db_user:' || current_user), v_app_ip, v_app_endpoint, clock_timestamp()
        );
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 14. Integridad Referencial y Relaciones Foreign Key
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS catalogo_topicos (
    topico_id       INTEGER PRIMARY KEY,
    nombre_etiqueta VARCHAR(255) NOT NULL,
    descripcion     TEXT,
    creado_en       TIMESTAMPTZ DEFAULT clock_timestamp()
);

ALTER TABLE tfidf_mensajes 
    ADD CONSTRAINT fk_tfidf_mensajes_mensaje 
    FOREIGN KEY (message_id) REFERENCES mensajes(message_id) 
    ON DELETE CASCADE;

ALTER TABLE gifs_animaciones 
    ADD CONSTRAINT fk_gifs_mensajes_mensaje 
    FOREIGN KEY (mensaje_id) REFERENCES mensajes(message_id) 
    ON DELETE CASCADE;

ALTER TABLE menciones_docentes 
    ADD CONSTRAINT fk_menciones_mensajes_mensaje 
    FOREIGN KEY (mensaje_id) REFERENCES mensajes(message_id) 
    ON DELETE CASCADE;

ALTER TABLE menciones_docentes 
    ADD CONSTRAINT fk_menciones_docentes_docente 
    FOREIGN KEY (docente_id) REFERENCES docentes(docente_id) 
    ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE menciones_docentes 
    ADD CONSTRAINT fk_menciones_materias_materia 
    FOREIGN KEY (codigo_materia) REFERENCES materias(codigo_materia) 
    ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE lda_topicos
    ADD CONSTRAINT fk_lda_topicos_catalogo
    FOREIGN KEY (topico_id) REFERENCES catalogo_topicos(topico_id)
    ON DELETE CASCADE;

ALTER TABLE mensajes
    ADD CONSTRAINT fk_mensajes_topicos
    FOREIGN KEY (topico_lda_id) REFERENCES catalogo_topicos(topico_id)
    ON DELETE SET NULL;
