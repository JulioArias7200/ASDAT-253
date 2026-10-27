# -*- coding: utf-8 -*-
"""
database/sync_topicos_frecuencia_neon.py
Sincroniza y persiste en Neon Serverless PostgreSQL los datasets de Tópicos de Frecuencia
generados por el script R/14_topicos_frecuencia.R:
  - data/results/topicos_catalogo.csv            -> topicos_catalogo
  - data/results/topicos_terminos_frecuencia.csv -> topicos_terminos
  - data/results/topicos_serie_temporal.csv      -> topicos_serie_temporal
  - data/results/topicos_emociones.csv           -> topicos_emociones
  - data/results/topicos_ngrams.csv              -> topicos_ngrams
  - data/results/topicos_asignacion_mensajes.csv -> UPDATE mensajes.topico_lda_id

Incluye DDL de creación de tablas, triggers CDC y registro en bitacora_procesos_mineria.
"""
import os
import sys
import time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor
from dotenv import load_dotenv

project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

load_dotenv(os.path.join(project_root, ".env"))
neon_conn_str = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")
if not neon_conn_str:
    raise ValueError("No se encontró NEON_CONECTION ni DATABASE_URL en el entorno o .env")

RESULTS_DIR = os.path.join(project_root, "data", "results")


def run_sync_topicos():
    print("\n" + "="*75)
    print("  SINCRONIZACIÓN DE TÓPICOS DE FRECUENCIA EN NEON POSTGRESQL (TGBase)")
    print("="*75)

    start_time = time.time()
    conn = psycopg2.connect(neon_conn_str)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # 1. Configurar contexto para CDC
        cur.execute("SELECT set_config('app.current_user', 'sync_topicos_frecuencia_14', true);")
        cur.execute("SELECT set_config('app.current_ip', '127.0.0.1', true);")
        cur.execute("SELECT set_config('app.current_endpoint', '/database/sync_topicos_frecuencia_neon.py', true);")

        print("\n  [1/5] Verificando estructuras DDL y tablas de tópicos en Neon...")
        ddl = """
        -- 1. Catálogo Maestro de Tópicos
        CREATE TABLE IF NOT EXISTS topicos_catalogo (
            topico_id            INTEGER PRIMARY KEY,
            nombre_etiqueta      VARCHAR(150) NOT NULL,
            descripcion_tematica TEXT,
            prevalencia_pct      NUMERIC(5,2) NOT NULL,
            total_mensajes       INTEGER NOT NULL,
            coherencia_score     NUMERIC(8,4),
            actualizado_en       TIMESTAMPTZ DEFAULT clock_timestamp()
        );

        -- 2. Términos y Frecuencia Probabilística por Tópico
        CREATE TABLE IF NOT EXISTS topicos_terminos (
            id                   SERIAL PRIMARY KEY,
            topico_id            INTEGER REFERENCES topicos_catalogo(topico_id) ON DELETE CASCADE,
            termino              VARCHAR(100) NOT NULL,
            frecuencia_abs       INTEGER NOT NULL,
            beta_prob            NUMERIC(8,6) NOT NULL,
            tfidf_score          NUMERIC(8,4),
            term_score_blei      NUMERIC(8,4),
            ranking_pos          INTEGER NOT NULL,
            UNIQUE(topico_id, termino)
        );
        CREATE INDEX IF NOT EXISTS idx_tt_topico_id ON topicos_terminos(topico_id);
        CREATE INDEX IF NOT EXISTS idx_tt_termino ON topicos_terminos(termino);

        -- 3. Serie Temporal de Frecuencia por Tópico
        CREATE TABLE IF NOT EXISTS topicos_serie_temporal (
            id                   SERIAL PRIMARY KEY,
            topico_id            INTEGER REFERENCES topicos_catalogo(topico_id) ON DELETE CASCADE,
            anio_mes             VARCHAR(7) NOT NULL,
            volumen_mensajes     INTEGER NOT NULL,
            polaridad_media      NUMERIC(4,3),
            emocion_predominante VARCHAR(50),
            UNIQUE(topico_id, anio_mes)
        );
        CREATE INDEX IF NOT EXISTS idx_tst_topico_mes ON topicos_serie_temporal(topico_id, anio_mes);

        -- 4. Cruce Tópico vs. Emociones
        CREATE TABLE IF NOT EXISTS topicos_emociones (
            id                   SERIAL PRIMARY KEY,
            topico_id            INTEGER REFERENCES topicos_catalogo(topico_id) ON DELETE CASCADE,
            emocion              VARCHAR(50) NOT NULL,
            frecuencia           INTEGER NOT NULL,
            porcentaje_relativo  NUMERIC(5,2) NOT NULL,
            UNIQUE(topico_id, emocion)
        );
        CREATE INDEX IF NOT EXISTS idx_te_topico ON topicos_emociones(topico_id);

        -- 5. N-gramas Representativos por Tópico
        CREATE TABLE IF NOT EXISTS topicos_ngrams (
            id                   SERIAL PRIMARY KEY,
            topico_id            INTEGER REFERENCES topicos_catalogo(topico_id) ON DELETE CASCADE,
            ngram                VARCHAR(150) NOT NULL,
            tipo_ngram           VARCHAR(20) NOT NULL,
            frecuencia           INTEGER NOT NULL,
            UNIQUE(topico_id, ngram)
        );
        CREATE INDEX IF NOT EXISTS idx_tng_topico ON topicos_ngrams(topico_id);
        """
        cur.execute(ddl)
        print("        Estructuras DDL validadas y activas.")

        # 2. Cargar topicos_catalogo.csv
        p_catalogo = os.path.join(RESULTS_DIR, "topicos_catalogo.csv")
        if os.path.exists(p_catalogo):
            print("\n  [2/5] Sincronizando catálogo de tópicos (topicos_catalogo)...")
            df_cat = pd.read_csv(p_catalogo)
            upsert_cat_sql = """
            INSERT INTO topicos_catalogo (
                topico_id, nombre_etiqueta, descripcion_tematica, prevalencia_pct, 
                total_mensajes, coherencia_score
            ) VALUES %s
            ON CONFLICT (topico_id) DO UPDATE SET
                nombre_etiqueta = EXCLUDED.nombre_etiqueta,
                descripcion_tematica = EXCLUDED.descripcion_tematica,
                prevalencia_pct = EXCLUDED.prevalencia_pct,
                total_mensajes = EXCLUDED.total_mensajes,
                coherencia_score = EXCLUDED.coherencia_score,
                actualizado_en = clock_timestamp();
            """
            records_cat = [
                (
                    int(r["topico_id"]),
                    str(r["nombre_etiqueta"]),
                    str(r["descripcion_tematica"]),
                    float(r["prevalencia_pct"]),
                    int(r["total_mensajes"]),
                    float(r["coherencia_score"]) if pd.notna(r["coherencia_score"]) else None,
                )
                for _, r in df_cat.iterrows()
            ]
            execute_values(cur, upsert_cat_sql, records_cat, page_size=50)
            print(f"        Insertados/Actualizados {len(records_cat)} tópicos en topicos_catalogo.")

        # 3. Cargar topicos_terminos_frecuencia.csv
        p_term = os.path.join(RESULTS_DIR, "topicos_terminos_frecuencia.csv")
        if os.path.exists(p_term):
            print("\n  [3/5] Sincronizando términos de frecuencia (topicos_terminos)...")
            df_term = pd.read_csv(p_term)
            cur.execute("TRUNCATE TABLE topicos_terminos CASCADE;")
            insert_term_sql = """
            INSERT INTO topicos_terminos (
                topico_id, termino, frecuencia_abs, beta_prob, tfidf_score, term_score_blei, ranking_pos
            ) VALUES %s;
            """
            records_term = [
                (
                    int(r["topico_id"]),
                    str(r["termino"]),
                    int(r["frecuencia_abs"]),
                    float(r["beta_prob"]),
                    float(r["tfidf_score"]) if pd.notna(r["tfidf_score"]) else 0.0,
                    float(r["term_score_blei"]) if pd.notna(r["term_score_blei"]) else 0.0,
                    int(r["ranking_pos"])
                )
                for _, r in df_term.iterrows()
            ]
            execute_values(cur, insert_term_sql, records_term, page_size=200)
            print(f"        Insertados {len(records_term)} registros en topicos_terminos.")

        # 4. Cargar series temporales, emociones y n-gramas
        print("\n  [4/5] Sincronizando series temporales, emociones y n-gramas...")
        p_temp = os.path.join(RESULTS_DIR, "topicos_serie_temporal.csv")
        if os.path.exists(p_temp):
            df_temp = pd.read_csv(p_temp)
            cur.execute("TRUNCATE TABLE topicos_serie_temporal CASCADE;")
            insert_temp_sql = """
            INSERT INTO topicos_serie_temporal (
                topico_id, anio_mes, volumen_mensajes, polaridad_media, emocion_predominante
            ) VALUES %s;
            """
            records_temp = [
                (
                    int(r["topico_id"]),
                    str(r["anio_mes"]),
                    int(r["volumen_mensajes"]),
                    float(r["polaridad_media"]) if pd.notna(r["polaridad_media"]) else 0.0,
                    str(r["emocion_predominante"]) if pd.notna(r["emocion_predominante"]) else "indeterminado"
                )
                for _, r in df_temp.iterrows()
            ]
            execute_values(cur, insert_temp_sql, records_temp, page_size=200)
            print(f"        Insertados {len(records_temp)} puntos mensuales en topicos_serie_temporal.")

        p_emo = os.path.join(RESULTS_DIR, "topicos_emociones.csv")
        if os.path.exists(p_emo):
            df_emo = pd.read_csv(p_emo)
            cur.execute("TRUNCATE TABLE topicos_emociones CASCADE;")
            insert_emo_sql = """
            INSERT INTO topicos_emociones (
                topico_id, emocion, frecuencia, porcentaje_relativo
            ) VALUES %s;
            """
            records_emo = [
                (
                    int(r["topico_id"]),
                    str(r["emocion"]),
                    int(r["frecuencia"]),
                    float(r["porcentaje_relativo"])
                )
                for _, r in df_emo.iterrows()
            ]
            execute_values(cur, insert_emo_sql, records_emo, page_size=200)
            print(f"        Insertados {len(records_emo)} cruces en topicos_emociones.")

        p_ngr = os.path.join(RESULTS_DIR, "topicos_ngrams.csv")
        if os.path.exists(p_ngr):
            df_ngr = pd.read_csv(p_ngr)
            cur.execute("TRUNCATE TABLE topicos_ngrams CASCADE;")
            insert_ngr_sql = """
            INSERT INTO topicos_ngrams (
                topico_id, ngram, tipo_ngram, frecuencia
            ) VALUES %s;
            """
            records_ngr = [
                (
                    int(r["topico_id"]),
                    str(r["ngram"]),
                    str(r["tipo_ngram"]),
                    int(r["frecuencia"])
                )
                for _, r in df_ngr.iterrows()
            ]
            execute_values(cur, insert_ngr_sql, records_ngr, page_size=200)
            print(f"        Insertados {len(records_ngr)} n-gramas en topicos_ngrams.")

        # 5. Actualizar asignaciones en la tabla mensajes
        p_asig = os.path.join(RESULTS_DIR, "topicos_asignacion_mensajes.csv")
        if os.path.exists(p_asig):
            print("\n  [5/5] Actualizando asignación de tópicos en la tabla mensajes...")
            df_asig = pd.read_csv(p_asig)
            update_sql = """
            UPDATE mensajes AS m
            SET topico_lda_id = c.topico_id
            FROM (VALUES %s) AS c(message_id, topico_id)
            WHERE m.message_id = c.message_id;
            """
            records_asig = [
                (int(r["message_id"]), int(r["topico_id"]))
                for _, r in df_asig.iterrows()
            ]
            execute_values(cur, update_sql, records_asig, template="(%s, %s)", page_size=2000)
            print(f"        Actualizados {len(records_asig)} mensajes con su topico_lda_id.")

        # 6. Registrar en bitacora_procesos_mineria
        duracion_ms = int((time.time() - start_time) * 1000)
        cur.execute("""
            INSERT INTO bitacora_procesos_mineria (
                nombre_pipeline, fase, estado, parametros_json, metricas_json, duracion_ms, finalizado_en
            ) VALUES (
                'MODELADO_TOPICOS_FRECUENCIA',
                'SINCRONIZACION_NEON',
                'EXITOSO',
                '{"script": "database/sync_topicos_frecuencia_neon.py", "k": 5}'::jsonb,
                json_build_object('terminos_insertados', %s, 'mensajes_actualizados', %s),
                %s,
                clock_timestamp()
            );
        """, (len(records_term) if 'records_term' in locals() else 0, len(records_asig) if 'records_asig' in locals() else 0, duracion_ms))

        conn.commit()
        print("\n" + "="*75)
        print(f"  ¡SINCRONIZACIÓN EXITOSA EN NEON POSTGRESQL! (Duración: {duracion_ms / 1000.0:.2f} seg)")
        print("="*75 + "\n")

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] Falló la sincronización en Neon PostgreSQL: {e}")
        raise e
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    run_sync_topicos()
