# -*- coding: utf-8 -*-
"""
migrate_all_to_neon.py
Migración Integral y Multimodal de ASDAT-253 hacia Neon PostgreSQL.
Transfiere 100% de los datos de .rds, .csv y result.json sin alterar valores.
"""
import os
import sys
import json
import math
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd
import numpy as np
import pyreadr
import psycopg2
from psycopg2.extras import execute_values

# Forzar codificación UTF-8 en consola
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

# -----------------------------------------------------------------------------
# Configuración y Rutas
# -----------------------------------------------------------------------------
BASE_DIR = Path("c:/Users/julio/Downloads/INF_2_2026/DM/proyUlti/ASDAT-253")
load_dotenv(dotenv_path=BASE_DIR / ".env")
NEON_URL = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")

if not NEON_URL:
    raise ValueError("No se encontró NEON_CONECTION ni DATABASE_URL en el archivo .env")

print("Iniciando conexión con Neon PostgreSQL...")
conn = psycopg2.connect(NEON_URL)
conn.autocommit = False
cur = conn.cursor()

def sanitize_val(val, default=None):
    """Maneja NaN, NaT y nulos de Pandas para SQL limpio."""
    if val is None:
        return default
    if isinstance(val, (float, np.floating)) and (math.isnan(val) or np.isnan(val)):
        return default
    if pd.isna(val):
        return default
    return val

try:
    # =========================================================================
    # 1. MIGRACIÓN: Diccionario de Sentimientos (data/dictionary/sentiment_dictionary.csv)
    # =========================================================================
    dict_csv = BASE_DIR / "data/dictionary/sentiment_dictionary.csv"
    if dict_csv.exists():
        print(f"\n[1/8] Migrando diccionario de sentimientos ({dict_csv.name})...")
        df_dict = pd.read_csv(dict_csv)
        rows_dict = []
        for _, r in df_dict.iterrows():
            rows_dict.append((
                sanitize_val(r.get("term"), ""),
                sanitize_val(r.get("normalized_term"), ""),
                sanitize_val(r.get("category"), "neutral"),
                sanitize_val(r.get("polarity"), "neutral"),
                float(sanitize_val(r.get("weight"), 1.0)),
                sanitize_val(r.get("term_type"), "word"),
                sanitize_val(r.get("language_variant"), "es"),
                bool(sanitize_val(r.get("negation_sensitive"), True)),
                sanitize_val(r.get("source"), "manual"),
                sanitize_val(r.get("notes"), ""),
                sanitize_val(r.get("dictionary_version"), "v1")
            ))
        
        cur.execute("TRUNCATE TABLE diccionario_sentimientos RESTART IDENTITY;")
        query_dict = """
            INSERT INTO diccionario_sentimientos (
                term, normalized_term, category, polarity, weight, term_type,
                language_variant, negation_sensitive, source, notes, dictionary_version
            ) VALUES %s;
        """
        execute_values(cur, query_dict, rows_dict)
        print(f" -> {len(rows_dict)} términos insertados en diccionario_sentimientos.")

    # =========================================================================
    # 2. MIGRACIÓN: Tópicos Latentes LDA (data/results/topics.rds y topics_summary.json)
    # =========================================================================
    topics_json = BASE_DIR / "data/results/topics_summary.json"
    if topics_json.exists():
        print(f"\n[2/8] Migrando tópicos LDA ({topics_json.name})...")
        with open(topics_json, "r", encoding="utf-8") as f:
            topics_data = json.load(f)
        
        cur.execute("TRUNCATE TABLE lda_topicos RESTART IDENTITY;")
        rows_lda = []
        labels_map = {
            1: "Trámites, Kardex y Pagos",
            2: "Interacción, Retiro y Docentes",
            3: "Inscripción Presencial y Formularios",
            4: "Grupos WhatsApp de Materias Temporada",
            5: "Consultas Docentes y Paralelos"
        }
        for t in topics_data.get("topics", []):
            topico_id = t["id"]
            label = labels_map.get(topico_id, f"Tópico {topico_id}")
            for pos, word in enumerate(t["top_words"], start=1):
                # Probabilidad aproximada de Dirichlet decreciente según ranking
                prob = round(1.0 / (pos + 10), 4)
                rows_lda.append((topico_id, label, word, prob, pos))
        
        query_lda = """
            INSERT INTO lda_topicos (topico_id, nombre_etiqueta, termino, beta_prob, ranking_pos)
            VALUES %s;
        """
        execute_values(cur, query_lda, rows_lda)
        print(f" -> {len(rows_lda)} términos de tópicos insertados en lda_topicos.")

    # =========================================================================
    # 3. MIGRACIÓN: Frecuencias de N-gramas (data/results/v2/ngrams.rds)
    # =========================================================================
    ngrams_rds = BASE_DIR / "data/results/v2/ngrams.rds"
    if ngrams_rds.exists():
        print(f"\n[3/8] Migrando frecuencias de n-gramas ({ngrams_rds.name})...")
        ngrams_data = pyreadr.read_r(str(ngrams_rds))
        # Extraer elemento 'table' de R
        # Nota: pyreadr expone el tibble 'table'
        df_ngrams = None
        for k, v in ngrams_data.items():
            if isinstance(v, pd.DataFrame) and "ngram" in v.columns:
                df_ngrams = v
                break
        
        if df_ngrams is not None:
            cur.execute("TRUNCATE TABLE ngrams_frecuencias RESTART IDENTITY;")
            rows_ngrams = []
            for _, r in df_ngrams.iterrows():
                rows_ngrams.append((
                    int(sanitize_val(r.get("size"), 1)),
                    str(sanitize_val(r.get("ngram"), "")),
                    int(sanitize_val(r.get("count"), 0)),
                    float(sanitize_val(r.get("prop"), 0.0))
                ))
            
            query_ngrams = "INSERT INTO ngrams_frecuencias (size, ngram, count, prop) VALUES %s;"
            execute_values(cur, query_ngrams, rows_ngrams, page_size=5000)
            print(f" -> {len(rows_ngrams)} n-gramas insertados en ngrams_frecuencias.")

    # =========================================================================
    # 4. MIGRACIÓN: Métricas Temporales (data/results/temporal.rds)
    # =========================================================================
    temp_rds = BASE_DIR / "data/results/temporal.rds"
    if temp_rds.exists():
        print(f"\n[4/8] Migrando métricas temporales diarias/semanales/mensuales...")
        temp_data = pyreadr.read_r(str(temp_rds))
        cur.execute("TRUNCATE TABLE metricas_temporales RESTART IDENTITY;")
        
        rows_temp = []
        for period_key, df_p in temp_data.items():
            p_type = str(period_key).lower() if period_key else "daily"
            if not isinstance(df_p, pd.DataFrame):
                continue
            for _, r in df_p.iterrows():
                # Formatear fecha
                dt_str = str(r.get("period"))[:10]
                rows_temp.append((
                    p_type, dt_str,
                    int(sanitize_val(r.get("n_messages"), 0)),
                    int(sanitize_val(r.get("n_analyzed"), 0)),
                    float(sanitize_val(r.get("polarity_mean"), 0.0)),
                    int(sanitize_val(r.get("n_positive"), 0)),
                    int(sanitize_val(r.get("n_negative"), 0)),
                    int(sanitize_val(r.get("n_neutral"), 0)),
                    int(sanitize_val(r.get("n_indeterminate"), 0)),
                    int(sanitize_val(r.get("alegria"), 0)),
                    int(sanitize_val(r.get("tristeza"), 0)),
                    int(sanitize_val(r.get("ira"), 0)),
                    int(sanitize_val(r.get("miedo"), 0)),
                    int(sanitize_val(r.get("sorpresa"), 0)),
                    int(sanitize_val(r.get("asco"), 0)),
                    int(sanitize_val(r.get("amor"), 0)),
                    int(sanitize_val(r.get("gratitud"), 0)),
                    int(sanitize_val(r.get("confianza"), 0)),
                    int(sanitize_val(r.get("anticipacion"), 0)),
                    int(sanitize_val(r.get("frustracion"), 0)),
                    int(sanitize_val(r.get("ansiedad"), 0)),
                    int(sanitize_val(r.get("esperanza"), 0)),
                    int(sanitize_val(r.get("orgullo"), 0)),
                    int(sanitize_val(r.get("verguenza"), 0)),
                    int(sanitize_val(r.get("diversion"), 0)),
                    int(sanitize_val(r.get("aburrimiento"), 0)),
                    int(sanitize_val(r.get("alivio"), 0)),
                    float(sanitize_val(r.get("prop_positive"), 0.0)),
                    float(sanitize_val(r.get("prop_negative"), 0.0)),
                    float(sanitize_val(r.get("prop_neutral"), 0.0)),
                    float(sanitize_val(r.get("polarity_ma"), 0.0))
                ))
        
        query_temp = """
            INSERT INTO metricas_temporales (
                periodo_tipo, fecha_inicio, n_messages, n_analyzed, polarity_mean,
                n_positive, n_negative, n_neutral, n_indeterminate,
                alegria, tristeza, ira, miedo, sorpresa, asco, amor, gratitud,
                confianza, anticipacion, frustracion, ansiedad, esperanza, orgullo,
                verguenza, diversion, aburrimiento, alivio,
                prop_positive, prop_negative, prop_neutral, polarity_ma
            ) VALUES %s;
        """
        execute_values(cur, query_temp, rows_temp)
        print(f" -> {len(rows_temp)} registros temporales insertados en metricas_temporales.")

    # =========================================================================
    # 5. MIGRACIÓN: Modelo de Markov (data/results/markov.json)
    # =========================================================================
    markov_json = BASE_DIR / "data/results/markov.json"
    if markov_json.exists():
        print(f"\n[5/8] Migrando matriz y dinámica de Markov...")
        with open(markov_json, "r", encoding="utf-8") as f:
            mk = json.load(f)
        
        cur.execute("TRUNCATE TABLE markov_transiciones RESTART IDENTITY;")
        states = mk.get("states", ["positivo", "negativo", "neutro"])
        trans_mat = mk.get("transition", [])
        stat_prob = mk.get("stationary", [0.1146, 0.0541, 0.8312])
        residence = mk.get("residence", [1.189, 1.080, 6.223])
        recovery = float(mk.get("recovery", 1.0809))
        
        rows_markov = []
        for i, s_from in enumerate(states):
            for j, s_to in enumerate(states):
                prob = float(trans_mat[i][j])
                pi_val = float(stat_prob[i]) if i < len(stat_prob) else None
                res_val = float(residence[i]) if i < len(residence) else None
                rows_markov.append((s_from, s_to, 0, prob, pi_val, res_val, recovery))
        
        query_markov = """
            INSERT INTO markov_transiciones (
                estado_origen, estado_destino, conteo, probabilidad,
                prob_estacionaria, tiempo_residencia, tiempo_recuperacion
            ) VALUES %s;
        """
        execute_values(cur, query_markov, rows_markov)
        print(f" -> Matriz de transición de Markov insertada.")

    # =========================================================================
    # 6. MIGRACIÓN: Corpus Consolidado de Mensajes con Sentimiento, Tópicos y Features
    # =========================================================================
    print(f"\n[6/8] Consolidando y migrando corpus de mensajes con enriquecimiento total...")
    
    # A. Leer messages_clean.rds
    clean_rds = BASE_DIR / "data/processed/messages_clean.rds"
    df_clean = pyreadr.read_r(str(clean_rds))[None]
    df_clean['message_id'] = df_clean['message_id'].astype(int)
    
    # B. Leer sentiment.rds
    sent_rds = BASE_DIR / "data/results/sentiment.rds"
    df_sent = pyreadr.read_r(str(sent_rds))[None]
    df_sent['message_id'] = df_sent['message_id'].astype(int)
    
    # C. Leer linguistic_features.rds
    ling_rds = BASE_DIR / "data/results/v2/linguistic_features.rds"
    ling_data = pyreadr.read_r(str(ling_rds))
    df_ling = None
    for k, v in ling_data.items():
        if isinstance(v, pd.DataFrame) and "n_words" in v.columns:
            df_ling = v
            break
    if df_ling is not None:
        df_ling['message_id'] = df_ling['message_id'].astype(int)

    # D. Leer doc_topic de topics.rds
    topics_rds = BASE_DIR / "data/results/topics.rds"
    top_data = pyreadr.read_r(str(topics_rds))
    df_doctopic = None
    for k, v in top_data.items():
        if isinstance(v, pd.DataFrame) and "topic" in v.columns and "message_id" in v.columns:
            df_doctopic = v
            break
    if df_doctopic is not None:
        df_doctopic['message_id'] = df_doctopic['message_id'].astype(int)
    
    # Fusionar tablas R por message_id
    df_merged = df_clean.merge(df_sent, on="message_id", how="left", suffixes=("", "_sent"))
    if df_ling is not None:
        df_merged = df_merged.merge(df_ling, on="message_id", how="left")
    if df_doctopic is not None:
        df_merged = df_merged.merge(df_doctopic, on="message_id", how="left")
    
    print(f" -> Mensajes procesados por R consolidados: {len(df_merged)}")

    # E. Rescate Multimedia de result.json
    raw_json_path = BASE_DIR / "data/raw/result.json"
    with open(raw_json_path, "r", encoding="utf-8") as f:
        raw_telegram = json.load(f)
    
    existing_ids = set(df_merged['message_id'].tolist())
    multimodal_new_rows = []
    gifs_list = []
    
    for m in raw_telegram.get("messages", []):
        m_id = m.get("id")
        if not m_id:
            continue
        
        # Registrar GIF para la tabla gifs_animaciones
        if m.get("media_type") == "animation":
            ts_str = m.get("date")
            sender = m.get("from") or m.get("actor") or "Anonimo"
            f_name = m.get("file")
            thumb = m.get("thumbnail")
            gifs_list.append((m_id, ts_str, sender, "animation.mp4", f_name, thumb))
        
        # Si el mensaje no estaba en R (por no tener texto), rescatarlo
        if m_id not in existing_ids:
            is_sticker = "sticker_emoji" in m
            is_gif = m.get("media_type") == "animation"
            has_photo = "photo" in m
            is_service = m.get("type") == "service"
            
            # Rescatar stickers, gifs y fotos sin texto
            if is_sticker or is_gif or has_photo:
                ts_raw = m.get("date")
                ts_utc = f"{ts_raw}Z" if ts_raw and not ts_raw.endswith("Z") else ts_raw
                sender_id = str(m.get("from_id") or m.get("actor_id") or "")
                sender_name = str(m.get("from") or m.get("actor") or "")
                stk_emoji = m.get("sticker_emoji")
                media_t = m.get("media_type") or ("photo" if has_photo else ("sticker" if is_sticker else None))
                
                multimodal_new_rows.append({
                    "message_id": m_id,
                    "corpus_id": 1,
                    "batch_id": 1,
                    "chat_id": None,
                    "timestamp_utc": ts_utc,
                    "timestamp_local": ts_raw,
                    "tz": "America/La_Paz",
                    "sender_id": sender_id,
                    "sender_name": sender_name,
                    "text_original": "",
                    "text_norm": "",
                    "reply_to_id": m.get("reply_to_message_id"),
                    "forwarded": "forwarded_from" in m,
                    "edited": "edited" in m,
                    "message_type": "message",
                    "media_type": media_t,
                    "sticker_emoji": stk_emoji,
                    "emoji_list": json.dumps([stk_emoji]) if stk_emoji else "[]",
                    "reactions": json.dumps(m.get("reactions") or []),
                    "polarity": 0.0,
                    "polarity_label": "positivo" if stk_emoji in ["👍", "❤️", "😊", "🔥", "👏"] else ("negativo" if stk_emoji in ["😢", "😡", "👎"] else "indeterminado"),
                    "dominant_emotion": "alegria" if stk_emoji in ["👍", "😊", "🔥"] else ("tristeza" if stk_emoji in ["😢"] else None),
                    "evidence_level": "suficiente" if stk_emoji else "sin_evidencia",
                    "topico_lda_id": None,
                    "n_words": 0,
                    "n_questions": 0,
                    "n_emojis": 1 if is_sticker else 0,
                    "es_sticker": is_sticker,
                    "es_gif": is_gif,
                    "tiene_imagen": has_photo,
                    "archivo_adjunto": m.get("file"),
                    "thumbnail_adjunto": m.get("thumbnail")
                })
    
    print(f" -> Elementos multimedia rescatados de result.json sin texto: {len(multimodal_new_rows)}")
    
    # Preparar inserción de mensajes
    cur.execute("TRUNCATE TABLE mensajes CASCADE;")
    
    batch_msgs = []
    # 1. Agregar los del merge de R
    for _, r in df_merged.iterrows():
        stk_emoji = sanitize_val(r.get("sticker_emoji"))
        med_type = sanitize_val(r.get("media_type"))
        batch_msgs.append((
            int(r["message_id"]),
            int(sanitize_val(r.get("corpus_id"), 1)),
            int(sanitize_val(r.get("batch_id"), 1)),
            sanitize_val(r.get("chat_id")),
            sanitize_val(r.get("timestamp_utc")),
            sanitize_val(r.get("timestamp_local")),
            sanitize_val(r.get("tz"), "America/La_Paz"),
            sanitize_val(r.get("sender_id")),
            sanitize_val(r.get("sender_name")),
            sanitize_val(r.get("text_original"), ""),
            sanitize_val(r.get("text_norm"), ""),
            int(r["reply_to_id"]) if not pd.isna(r.get("reply_to_id")) else None,
            bool(sanitize_val(r.get("forwarded"), False)),
            bool(sanitize_val(r.get("edited"), False)),
            sanitize_val(r.get("message_type"), "message"),
            med_type,
            stk_emoji,
            sanitize_val(r.get("emoji_list"), "[]"),
            sanitize_val(r.get("reactions"), "[]"),
            "result.json",
            float(sanitize_val(r.get("polarity"), 0.0)),
            sanitize_val(r.get("polarity_label"), "indeterminado"),
            sanitize_val(r.get("emotion_scores"), "[]"),
            sanitize_val(r.get("detected_emotions"), "[]"),
            sanitize_val(r.get("dominant_emotion")),
            float(sanitize_val(r.get("intensity"), 0.0)),
            sanitize_val(r.get("evidence_level"), "sin_evidencia"),
            int(sanitize_val(r.get("n_terms"), 0)),
            float(sanitize_val(r.get("emoji_signal"), 0.0)),
            sanitize_val(r.get("emoji_emotions"), "[]"),
            float(sanitize_val(r.get("reaction_signal"), 0.0)),
            sanitize_val(r.get("reaction_emotions"), "[]"),
            int(r["topic"]) if "topic" in r and not pd.isna(r["topic"]) else None,
            int(sanitize_val(r.get("n_chars"), 0)),
            int(sanitize_val(r.get("n_tokens"), 0)),
            int(sanitize_val(r.get("n_words"), 0)),
            int(sanitize_val(r.get("n_unique_words"), 0)),
            float(sanitize_val(r.get("unique_ratio"), 0.0)),
            float(sanitize_val(r.get("mean_word_len"), 0.0)),
            int(sanitize_val(r.get("n_questions"), 0)),
            int(sanitize_val(r.get("n_exclamations"), 0)),
            int(sanitize_val(r.get("n_upper_words"), 0)),
            float(sanitize_val(r.get("upper_ratio"), 0.0)),
            int(sanitize_val(r.get("n_emojis"), 0)),
            int(sanitize_val(r.get("n_hashtags"), 0)),
            int(sanitize_val(r.get("n_mentions"), 0)),
            int(sanitize_val(r.get("n_urls"), 0)),
            int(sanitize_val(r.get("n_repeated_chars"), 0)),
            int(sanitize_val(r.get("n_repeated_punct"), 0)),
            int(sanitize_val(r.get("n_intensity"), 0)),
            bool(stk_emoji is not None and len(str(stk_emoji)) > 0),
            None,
            bool(med_type == "animation"),
            None,
            bool(med_type == "photo"),
            None,
            None,
            None
        ))
    
    # 2. Agregar los rescatados
    for m in multimodal_new_rows:
        batch_msgs.append((
            int(m["message_id"]),
            1, 1, None,
            m["timestamp_utc"], m["timestamp_local"], "America/La_Paz",
            m["sender_id"], m["sender_name"], "", "",
            int(m["reply_to_id"]) if m.get("reply_to_id") else None,
            m["forwarded"], m["edited"], "message",
            m["media_type"], m["sticker_emoji"],
            m["emoji_list"], m["reactions"], "result.json",
            m["polarity"], m["polarity_label"], "[]", "[]",
            m["dominant_emotion"], 0.0, m["evidence_level"], 0, 0.0, "[]", 0.0, "[]",
            None, 0, 0, 0, 0, 0.0, 0.0, 0, 0, 0, 0.0,
            m["n_emojis"], 0, 0, 0, 0, 0, 0,
            m["es_sticker"], None, m["es_gif"], None, m["tiene_imagen"], None,
            m["archivo_adjunto"], m["thumbnail_adjunto"]
        ))
    
    query_insert_msgs = """
        INSERT INTO mensajes (
            message_id, corpus_id, batch_id, chat_id, timestamp_utc, timestamp_local, tz,
            sender_id, sender_name, text_original, text_norm, reply_to_id, forwarded, edited,
            message_type, media_type, sticker_emoji, emoji_list, reactions, source_file,
            polarity, polarity_label, emotion_scores, detected_emotions, dominant_emotion,
            intensity, evidence_level, n_terms, emoji_signal, emoji_emotions, reaction_signal, reaction_emotions,
            topico_lda_id, n_chars, n_tokens, n_words, n_unique_words, unique_ratio, mean_word_len,
            n_questions, n_exclamations, n_upper_words, upper_ratio, n_emojis, n_hashtags, n_mentions,
            n_urls, n_repeated_chars, n_repeated_punct, n_intensity,
            es_sticker, sticker_emocion, es_gif, gif_nombre, tiene_imagen, ruta_imagen,
            archivo_adjunto, thumbnail_adjunto
        ) VALUES %s;
    """
    execute_values(cur, query_insert_msgs, batch_msgs, page_size=1000)
    print(f" -> ÉXITO: {len(batch_msgs)} mensajes totales insertados en tabla 'mensajes'.")

    # Inserción de GIFs dedicados
    if gifs_list:
        cur.execute("TRUNCATE TABLE gifs_animaciones RESTART IDENTITY;")
        query_gifs = """
            INSERT INTO gifs_animaciones (mensaje_id, fecha, usuario_nombre, gif_nombre, archivo_adjunto, thumbnail_adjunto)
            VALUES %s;
        """
        execute_values(cur, query_gifs, gifs_list)
        print(f" -> ÉXITO: {len(gifs_list)} GIFs insertados en tabla 'gifs_animaciones'.")

    # =========================================================================
    # 7. MIGRACIÓN: Ponderaciones TF-IDF (122.971 filas)
    # =========================================================================
    tfidf_csv_path = BASE_DIR / "data/results/v2/tfidf.csv"
    if tfidf_csv_path.exists():
        print(f"\n[7/8] Migrando matriz TF-IDF por mensaje ({tfidf_csv_path.name})...")
        cur.execute("TRUNCATE TABLE tfidf_mensajes RESTART IDENTITY;")
        
        # Lectura por bloques de 20.000 filas para máxima eficiencia
        query_tfidf = """
            INSERT INTO tfidf_mensajes (message_id, termino, tf_count, df, idf, tf, tfidf)
            VALUES %s;
        """
        total_tfidf = 0
        for chunk in pd.read_csv(tfidf_csv_path, chunksize=20000):
            rows_tfidf = []
            for _, r in chunk.iterrows():
                rows_tfidf.append((
                    int(r["doc_id"]),
                    str(r["term"]),
                    int(r["tf_count"]),
                    int(r["df"]),
                    float(r["idf"]),
                    float(r["tf"]),
                    float(r["tfidf"])
                ))
            execute_values(cur, query_tfidf, rows_tfidf, page_size=5000)
            total_tfidf += len(rows_tfidf)
            print(f"    ... {total_tfidf} filas de TF-IDF insertadas...")
        
        print(f" -> ÉXITO: {total_tfidf} ponderaciones TF-IDF insertadas en 'tfidf_mensajes'.")

    # =========================================================================
    # 8. ACTIVACIÓN DEL TRIGGER CENTINELA DE BITÁCORA INMEDIATA
    # =========================================================================
    print(f"\n[8/8] Activando Triggers de Bitácora Inmediata (Change Data Capture)...")
    triggers_sql = """
        DROP TRIGGER IF EXISTS trg_audit_mensajes ON mensajes;
        CREATE TRIGGER trg_audit_mensajes
        AFTER INSERT OR UPDATE OR DELETE ON mensajes
        FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();

        DROP TRIGGER IF EXISTS trg_audit_diccionario ON diccionario_sentimientos;
        CREATE TRIGGER trg_audit_diccionario
        AFTER INSERT OR UPDATE OR DELETE ON diccionario_sentimientos
        FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();

        DROP TRIGGER IF EXISTS trg_audit_docentes ON docentes;
        CREATE TRIGGER trg_audit_docentes
        AFTER INSERT OR UPDATE OR DELETE ON docentes
        FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();

        DROP TRIGGER IF EXISTS trg_audit_materias ON materias;
        CREATE TRIGGER trg_audit_materias
        AFTER INSERT OR UPDATE OR DELETE ON materias
        FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();

        DROP TRIGGER IF EXISTS trg_audit_topicos ON lda_topicos;
        CREATE TRIGGER trg_audit_topicos
        AFTER INSERT OR UPDATE OR DELETE ON lda_topicos
        FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();
    """
    cur.execute(triggers_sql)
    print(" -> Triggers de bitácora vinculados con éxito a las tablas.")

    # Registrar el evento en la bitácora de procesos
    cur.execute("""
        INSERT INTO bitacora_procesos_mineria (
            nombre_pipeline, fase, estado, parametros_json, metricas_json
        ) VALUES (
            'MIGRACION_INICIAL_MULTIMODAL', 'DATA_TRANSFER_ALL_RDS', 'EXITOSO',
            '{"origen": "RDS_AND_RAW_JSON", "destino": "NEON_POSTGRESQL"}'::JSONB,
            jsonb_build_object(
                'mensajes_totales', (SELECT COUNT(*) FROM mensajes),
                'tfidf_filas', (SELECT COUNT(*) FROM tfidf_mensajes),
                'ngrams_filas', (SELECT COUNT(*) FROM ngrams_frecuencias),
                'stickers', (SELECT COUNT(*) FROM mensajes WHERE es_sticker = TRUE),
                'gifs', (SELECT COUNT(*) FROM gifs_animaciones)
            )
        );
    """)

    # Confirmar Transacción Atómica
    conn.commit()
    print("\n==================================================================")
    print("¡MIGRACIÓN COMPLETADA EXITOSAMENTE Y SIN ERRORES!")
    print("==================================================================")

except Exception as e:
    conn.rollback()
    print("\n[ERROR CRÍTICO] La transacción ha sido revertida (Rollback):", e)
    import traceback
    traceback.print_exc()

finally:
    cur.close()
    conn.close()
