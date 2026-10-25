# -*- coding: utf-8 -*-
"""
database/sync_results_to_neon.py
Sincroniza y enriquece Neon PostgreSQL con los resultados generados por los scripts:
  - R/11_tokenizar_stopwords.R -> data/results/tokens_frecuencia.csv
  - R/12_shadow_linguistic.R   -> data/results/shadow_linguistic.csv
  - R/13_diccionario_emojis.R  -> data/results/emojis_diccionario.csv + emojis_pendientes.csv
Registra la trazabilidad en bitacora_procesos_mineria y activa triggers CDC.
"""
import os
import sys
import time
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor
from dotenv import load_dotenv

# Asegurar que el directorio raíz del proyecto esté en sys.path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

load_dotenv(os.path.join(project_root, ".env"))
neon_conn_str = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")
if not neon_conn_str:
    raise ValueError("No se encontro NEON_CONECTION ni DATABASE_URL en el entorno o .env")

def run_sync():
    print("\n" + "="*70)
    print("  SINCRONIZACION Y ENRIQUECIMIENTO EN NEON POSTGRESQL (TGBase)")
    print("="*70)

    conn = psycopg2.connect(neon_conn_str)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Inyectar variables de contexto para la auditoria CDC
        cur.execute("SELECT set_config('app.current_user', 'ingesta_scripts_11_12_13', true);")
        cur.execute("SELECT set_config('app.current_ip', '127.0.0.1', true);")
        cur.execute("SELECT set_config('app.current_endpoint', '/database/sync_results_to_neon.py', true);")

        start_time = time.time()

        # ---------------------------------------------------------------------
        # 1. Crear Tablas DDL y Triggers si no existen
        # ---------------------------------------------------------------------
        print("\n  [1/4] Creando estructuras DDL y vinculando Triggers CDC...")

        ddl = """
        -- 1. Diccionario Contextual de Emojis
        CREATE TABLE IF NOT EXISTS diccionario_emojis (
            emoji                VARCHAR(50) PRIMARY KEY,
            rango                INTEGER NOT NULL,
            nombre               VARCHAR(150),
            significado_es       TEXT,
            funcion              VARCHAR(80),
            registro             VARCHAR(50),
            categoria_emocional  VARCHAR(80),
            polaridad            VARCHAR(30) DEFAULT 'neutro',
            ironia               VARCHAR(20) DEFAULT 'no',
            count_texto          INTEGER DEFAULT 0,
            count_reacciones     INTEGER DEFAULT 0,
            count_total          INTEGER DEFAULT 0,
            pct_anuncio          FLOAT DEFAULT 0.0,
            pct_inicio_linea     FLOAT DEFAULT 0.0,
            pct_solo_emoji       FLOAT DEFAULT 0.0,
            pct_en_pregunta      FLOAT DEFAULT 0.0,
            pendiente_definicion BOOLEAN DEFAULT FALSE,
            ejemplo_en_chat      TEXT,
            creado_en            TIMESTAMPTZ DEFAULT clock_timestamp(),
            actualizado_en       TIMESTAMPTZ DEFAULT clock_timestamp()
        );

        CREATE INDEX IF NOT EXISTS idx_emojis_polaridad ON diccionario_emojis(polaridad);
        CREATE INDEX IF NOT EXISTS idx_emojis_categoria ON diccionario_emojis(categoria_emocional);
        CREATE INDEX IF NOT EXISTS idx_emojis_total ON diccionario_emojis(count_total DESC);

        -- 2. Tokens y Frecuencia de Vocabulario
        CREATE TABLE IF NOT EXISTS tokens_frecuencia (
            rango        INTEGER NOT NULL,
            token        VARCHAR(100) PRIMARY KEY,
            frecuencia   INTEGER NOT NULL,
            docfreq      INTEGER NOT NULL,
            pct_docs     FLOAT NOT NULL,
            creado_en    TIMESTAMPTZ DEFAULT clock_timestamp()
        );

        CREATE INDEX IF NOT EXISTS idx_tokens_freq_desc ON tokens_frecuencia(frecuencia DESC);
        CREATE INDEX IF NOT EXISTS idx_tokens_docfreq ON tokens_frecuencia(docfreq DESC);

        -- 3. Shadow Linguistics (Capas de Unigramas, Bigramas, Trigramas y TF-IDF)
        CREATE TABLE IF NOT EXISTS shadow_linguistics (
            id           BIGSERIAL PRIMARY KEY,
            capa         VARCHAR(30) NOT NULL CHECK (capa IN ('unigrama', 'bigrama', 'trigrama', 'tfidf')),
            rango        INTEGER NOT NULL,
            termino      VARCHAR(255) NOT NULL,
            frecuencia   INTEGER NOT NULL,
            n_docs       INTEGER NOT NULL,
            pct_docs     FLOAT NOT NULL,
            tfidf_prom   FLOAT,
            creado_en    TIMESTAMPTZ DEFAULT clock_timestamp()
        );

        CREATE INDEX IF NOT EXISTS idx_shadow_capa_rango ON shadow_linguistics(capa, rango);
        CREATE INDEX IF NOT EXISTS idx_shadow_termino ON shadow_linguistics(termino);
        """
        cur.execute(ddl)

        # Vincular triggers CDC
        triggers_ddl = """
        DROP TRIGGER IF EXISTS trg_audit_diccionario_emojis ON diccionario_emojis;
        CREATE TRIGGER trg_audit_diccionario_emojis
            AFTER INSERT OR UPDATE OR DELETE ON diccionario_emojis
            FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();

        DROP TRIGGER IF EXISTS trg_audit_tokens_frecuencia ON tokens_frecuencia;
        CREATE TRIGGER trg_audit_tokens_frecuencia
            AFTER INSERT OR UPDATE OR DELETE ON tokens_frecuencia
            FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();

        DROP TRIGGER IF EXISTS trg_audit_shadow_linguistics ON shadow_linguistics;
        CREATE TRIGGER trg_audit_shadow_linguistics
            AFTER INSERT OR UPDATE OR DELETE ON shadow_linguistics
            FOR EACH ROW EXECUTE FUNCTION fn_registrar_bitacora_cambio();
        """
        cur.execute(triggers_ddl)
        conn.commit()
        print("      * Tablas e indices creados con triggers de auditoria activos.")

        # Registrar proceso en bitacora_procesos_mineria
        cur.execute("""
            INSERT INTO bitacora_procesos_mineria (nombre_pipeline, fase, estado, parametros_json)
            VALUES ('sync_results_scripts_11_12_13', 'ingesta_enriquecimiento', 'EN_PROCESO',
                    '{"archivos": ["tokens_frecuencia.csv", "shadow_linguistic.csv", "emojis_diccionario.csv"]}'::JSONB)
            RETURNING proceso_id;
        """)
        proceso_id = cur.fetchone()["proceso_id"]
        conn.commit()

        # ---------------------------------------------------------------------
        # 2. Cargar tokens_frecuencia.csv (12,581 filas)
        # ---------------------------------------------------------------------
        print("\n  [2/4] Ingestando tokens_frecuencia.csv...")
        df_tokens = pd.read_csv(os.path.join(project_root, "data/results/tokens_frecuencia.csv"))
        df_tokens = df_tokens.drop_duplicates(subset=["token"])
        
        records_tokens = [
            (int(row["rango"]), str(row["token"])[:100], int(row["frecuencia"]), int(row["docfreq"]), float(row["pct_docs"]))
            for _, row in df_tokens.iterrows()
        ]
        
        insert_tokens_sql = """
            INSERT INTO tokens_frecuencia (rango, token, frecuencia, docfreq, pct_docs)
            VALUES %s
            ON CONFLICT (token) DO UPDATE SET
                rango = EXCLUDED.rango,
                frecuencia = EXCLUDED.frecuencia,
                docfreq = EXCLUDED.docfreq,
                pct_docs = EXCLUDED.pct_docs;
        """
        execute_values(cur, insert_tokens_sql, records_tokens, page_size=2000)
        conn.commit()
        print(f"      * {len(records_tokens):,} tokens cargados y actualizados exitosamente.")

        # ---------------------------------------------------------------------
        # 3. Cargar shadow_linguistic.csv (1,000 filas)
        # ---------------------------------------------------------------------
        print("\n  [3/4] Ingestando shadow_linguistic.csv (Capas Unigramas, Bigramas, Trigramas, TF-IDF)...")
        df_shadow = pd.read_csv(os.path.join(project_root, "data/results/shadow_linguistic.csv"))
        
        cur.execute("TRUNCATE TABLE shadow_linguistics RESTART IDENTITY;")
        
        records_shadow = []
        for _, row in df_shadow.iterrows():
            tfidf_val = float(row["tfidf_prom"]) if pd.notna(row["tfidf_prom"]) else None
            records_shadow.append((
                str(row["capa"]),
                int(row["rango"]),
                str(row["termino"])[:255],
                int(row["frecuencia"]),
                int(row["n_docs"]),
                float(row["pct_docs"]),
                tfidf_val
            ))
            
        insert_shadow_sql = """
            INSERT INTO shadow_linguistics (capa, rango, termino, frecuencia, n_docs, pct_docs, tfidf_prom)
            VALUES %s;
        """
        execute_values(cur, insert_shadow_sql, records_shadow, page_size=1000)
        conn.commit()
        print(f"      * {len(records_shadow):,} registros estratificados de Shadow Linguistics ingestados.")

        # ---------------------------------------------------------------------
        # 4. Cargar emojis_diccionario.csv y emojis_pendientes.csv (433 filas)
        # ---------------------------------------------------------------------
        print("\n  [4/4] Ingestando diccionario contextual de emojis (texto + reacciones + contexto)...")
        df_emojis = pd.read_csv(os.path.join(project_root, "data/results/emojis_diccionario.csv"))
        df_pendientes = pd.read_csv(os.path.join(project_root, "data/results/emojis_pendientes.csv"))
        
        pend_dict = {}
        for _, row in df_pendientes.iterrows():
            pend_dict[str(row["emoji"])] = str(row["ejemplo_en_chat"]) if pd.notna(row.get("ejemplo_en_chat")) else None

        records_emojis = []
        for _, row in df_emojis.iterrows():
            em = str(row["emoji"])
            es_pendiente = em in pend_dict or row.get("significado_es") == "sin definición registrada"
            ejemplo = pend_dict.get(em)
            
            records_emojis.append((
                em[:50],
                int(row["rango"]),
                str(row["nombre"])[:150] if pd.notna(row.get("nombre")) else None,
                str(row["significado_es"]) if pd.notna(row.get("significado_es")) else None,
                str(row["funcion"])[:80] if pd.notna(row.get("funcion")) else None,
                str(row["registro"])[:50] if pd.notna(row.get("registro")) else None,
                str(row["categoria_emocional"])[:80] if pd.notna(row.get("categoria_emocional")) else None,
                str(row["polaridad"])[:30] if pd.notna(row.get("polaridad")) else 'neutro',
                str(row["ironia"])[:20] if pd.notna(row.get("ironia")) else 'no',
                int(row["count_texto"]) if pd.notna(row.get("count_texto")) else 0,
                int(row["count_reacciones"]) if pd.notna(row.get("count_reacciones")) else 0,
                int(row["count_total"]) if pd.notna(row.get("count_total")) else 0,
                float(row["pct_anuncio"]) if pd.notna(row.get("pct_anuncio")) else 0.0,
                float(row["pct_inicio_linea"]) if pd.notna(row.get("pct_inicio_linea")) else 0.0,
                float(row["pct_solo_emoji"]) if pd.notna(row.get("pct_solo_emoji")) else 0.0,
                float(row["pct_en_pregunta"]) if pd.notna(row.get("pct_en_pregunta")) else 0.0,
                bool(es_pendiente),
                ejemplo
            ))

        insert_emojis_sql = """
            INSERT INTO diccionario_emojis (
                emoji, rango, nombre, significado_es, funcion, registro, categoria_emocional,
                polaridad, ironia, count_texto, count_reacciones, count_total,
                pct_anuncio, pct_inicio_linea, pct_solo_emoji, pct_en_pregunta,
                pendiente_definicion, ejemplo_en_chat
            )
            VALUES %s
            ON CONFLICT (emoji) DO UPDATE SET
                rango = EXCLUDED.rango,
                nombre = EXCLUDED.nombre,
                significado_es = EXCLUDED.significado_es,
                funcion = EXCLUDED.funcion,
                registro = EXCLUDED.registro,
                categoria_emocional = EXCLUDED.categoria_emocional,
                polaridad = EXCLUDED.polaridad,
                ironia = EXCLUDED.ironia,
                count_texto = EXCLUDED.count_texto,
                count_reacciones = EXCLUDED.count_reacciones,
                count_total = EXCLUDED.count_total,
                pct_anuncio = EXCLUDED.pct_anuncio,
                pct_inicio_linea = EXCLUDED.pct_inicio_linea,
                pct_solo_emoji = EXCLUDED.pct_solo_emoji,
                pct_en_pregunta = EXCLUDED.pct_en_pregunta,
                pendiente_definicion = EXCLUDED.pendiente_definicion,
                ejemplo_en_chat = EXCLUDED.ejemplo_en_chat,
                actualizado_en = clock_timestamp();
        """
        execute_values(cur, insert_emojis_sql, records_emojis, page_size=500)
        conn.commit()
        print(f"      * {len(records_emojis):,} emojis contextuales con perfil semiotico ingestados.")

        # Finalizar registro en bitacora_procesos_mineria
        elapsed_ms = int((time.time() - start_time) * 1000)
        cur.execute("""
            UPDATE bitacora_procesos_mineria
            SET estado = 'EXITOSO',
                duracion_ms = %s,
                finalizado_en = clock_timestamp(),
                metricas_json = %s
            WHERE proceso_id = %s;
        """, (
            elapsed_ms,
            psycopg2.extras.Json({
                "tokens_frecuencia_total": len(records_tokens),
                "shadow_linguistics_total": len(records_shadow),
                "emojis_total": len(records_emojis),
                "emojis_pendientes": len(pend_dict)
            }),
            proceso_id
        ))
        conn.commit()

        print("\n" + "="*70)
        print(f"  SINCRONIZACION EXITOSA EN {elapsed_ms} ms (Proceso #{proceso_id})")
        print("="*70 + "\n")

    except Exception as e:
        conn.rollback()
        print(f"\nError durante la sincronizacion: {e}")
        raise e
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    run_sync()
