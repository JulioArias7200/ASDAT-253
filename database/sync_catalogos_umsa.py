# -*- coding: utf-8 -*-
"""
database/sync_catalogos_umsa.py
Sincroniza los catalogos institucionales de la UMSA en Neon PostgreSQL:
  - data/results/catalogo_docentes_umsa.csv  -> Tabla 'docentes'
  - data/results/catalogo_materias_umsa.csv  -> Tabla 'materias'
  - data/results/oferta_horarios_umsa.csv    -> Tabla 'oferta_academica_semestral'
Asegura columnas semestrales en 'menciones_docentes' y registra la auditoria en 'bitacora_procesos_mineria'.
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

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

load_dotenv(os.path.join(project_root, ".env"))
neon_conn_str = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")
if not neon_conn_str:
    raise ValueError("No se encontro NEON_CONECTION ni DATABASE_URL en el entorno o .env")

def sync_catalogos():
    print("\n" + "="*70)
    print("  SINCRONIZACION DE CATALOGOS INSTITUCIONALES UMSA EN NEON (TGBase)")
    print("="*70)
    
    start_time = time.time()
    conn = psycopg2.connect(neon_conn_str)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Contexto de sesion para auditoria
        cur.execute("SELECT set_config('app.current_user', 'admin_sync_catalogos', true);")
        cur.execute("SELECT set_config('app.current_ip', '127.0.0.1', true);")
        cur.execute("SELECT set_config('app.current_endpoint', '/database/sync_catalogos_umsa.py', true);")

        # ---------------------------------------------------------------------
        # 1. Asegurar Estructuras DDL y Nuevas Columnas Semestrales
        # ---------------------------------------------------------------------
        print("\n  [1/4] Verificando estructuras DDL...")

        cur.execute("""
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

        -- Tabla de Oferta Académica Semestral con soporte para Co-docencia y Permutabilidad
        DROP TABLE IF EXISTS oferta_academica_semestral CASCADE;
        CREATE TABLE oferta_academica_semestral (
            id               BIGSERIAL PRIMARY KEY,
            gestion_semestre VARCHAR(20) NOT NULL,
            codigo_materia   VARCHAR(50) NOT NULL REFERENCES materias(codigo_materia),
            paralelo         VARCHAR(10) NOT NULL,
            docente_id       VARCHAR(100) REFERENCES docentes(docente_id),
            horarios_texto   TEXT,
            creado_en        TIMESTAMPTZ DEFAULT clock_timestamp(),
            CONSTRAINT uq_oferta_semestral UNIQUE (gestion_semestre, codigo_materia, paralelo, docente_id)
        );

        CREATE INDEX IF NOT EXISTS idx_oferta_sem_mat ON oferta_academica_semestral(gestion_semestre, codigo_materia);
        CREATE INDEX IF NOT EXISTS idx_oferta_sem_doc ON oferta_academica_semestral(gestion_semestre, docente_id);
        CREATE INDEX IF NOT EXISTS idx_oferta_sem_completo ON oferta_academica_semestral(gestion_semestre, docente_id, codigo_materia);

        -- Columnas semestrales en menciones_docentes si no existen
        ALTER TABLE menciones_docentes 
            ADD COLUMN IF NOT EXISTS gestion_semestre VARCHAR(20),
            ADD COLUMN IF NOT EXISTS paralelo VARCHAR(10);

        CREATE INDEX IF NOT EXISTS idx_menc_semestre ON menciones_docentes(gestion_semestre);
        """)
        conn.commit()
        print("        Estructuras DDL y columnas semestrales verificadas exitosamente.")

        # ---------------------------------------------------------------------
        # 2. Ingesta de Catálogo Docentes (catalogo_docentes_umsa.csv)
        # ---------------------------------------------------------------------
        print("\n  [2/4] Sincronizando Catálogo de Docentes...")
        doc_csv_path = os.path.join(project_root, "data", "results", "catalogo_docentes_umsa.csv")
        df_doc = pd.read_csv(doc_csv_path).fillna("")

        # Agregar docente comodín para materias sin docente asignado
        docentes_data = [
            (
                "DOC_SIN_DOCENTE",
                "Sin Docente Asignado",
                "Materias vacantes o en designacion",
                r"\b(?:sin\s+docente|por\s+designar|sin\s+asignar)\b"
            )
        ]

        for _, row in df_doc.iterrows():
            docentes_data.append((
                str(row["docente_id"]).strip(),
                str(row["nombre_completo"]).strip(),
                str(row.get("materias_que_dicta", "")).strip(),
                str(row.get("alias_regex", "")).strip()
            ))

        sql_doc = """
        INSERT INTO docentes (docente_id, nombre_completo, materias_que_dicta, alias_regex)
        VALUES %s
        ON CONFLICT (docente_id) DO UPDATE SET
            nombre_completo = EXCLUDED.nombre_completo,
            materias_que_dicta = EXCLUDED.materias_que_dicta,
            alias_regex = EXCLUDED.alias_regex;
        """
        execute_values(cur, sql_doc, docentes_data, page_size=100)
        conn.commit()
        print(f"        {len(docentes_data)} registros sincronizados en 'docentes'.")

        # ---------------------------------------------------------------------
        # 3. Ingesta de Catálogo Materias (catalogo_materias_umsa.csv)
        # ---------------------------------------------------------------------
        print("\n  [3/4] Sincronizando Catálogo de Materias...")
        mat_csv_path = os.path.join(project_root, "data", "results", "catalogo_materias_umsa.csv")
        df_mat = pd.read_csv(mat_csv_path).fillna("")

        materias_data = []
        for _, row in df_mat.iterrows():
            materias_data.append((
                str(row["codigo_materia"]).strip(),
                str(row["nombre_materia"]).strip(),
                str(row.get("paralelos_disponibles", "")).strip(),
                str(row.get("docentes_asignados", "")).strip(),
                str(row.get("alias_regex", "")).strip()
            ))

        sql_mat = """
        INSERT INTO materias (codigo_materia, nombre_materia, paralelos_disponibles, docentes_asignados, alias_regex)
        VALUES %s
        ON CONFLICT (codigo_materia) DO UPDATE SET
            nombre_materia = EXCLUDED.nombre_materia,
            paralelos_disponibles = EXCLUDED.paralelos_disponibles,
            docentes_asignados = EXCLUDED.docentes_asignados,
            alias_regex = EXCLUDED.alias_regex;
        """
        execute_values(cur, sql_mat, materias_data, page_size=100)
        conn.commit()
        print(f"        {len(materias_data)} registros sincronizados en 'materias'.")

        # ---------------------------------------------------------------------
        # 4. Ingesta de Oferta Académica Semestral (oferta_horarios_umsa.csv)
        # ---------------------------------------------------------------------
        print("\n  [4/4] Sincronizando Oferta Académica Semestral con Versionamiento...")
        hor_csv_path = os.path.join(project_root, "data", "results", "oferta_horarios_umsa.csv")
        df_hor = pd.read_csv(hor_csv_path).fillna("")
        df_hor = df_hor.drop_duplicates(subset=['codigo_materia', 'paralelo', 'docente'])

        # Crear diccionario de mapeo nombre_completo -> docente_id
        cur.execute("SELECT docente_id, nombre_completo FROM docentes;")
        doc_map = {r["nombre_completo"].strip().upper(): r["docente_id"] for r in cur.fetchall()}

        gestiones_activas = [
            '2022-II', '2023-I', '2023-II', 
            '2024-I', '2024-II', '2025-I', 
            '2025-II', '2026-I', '2026-II'
        ]

        oferta_rows = []
        for gestion in gestiones_activas:
            for _, row in df_hor.iterrows():
                cod_mat = str(row["codigo_materia"]).strip()
                paralelo = str(row["paralelo"]).strip()
                nom_doc = str(row["docente"]).strip().upper()
                horarios = str(row.get("horarios", "")).strip()

                doc_id = doc_map.get(nom_doc)
                if not doc_id:
                    doc_id = "DOC_SIN_DOCENTE"

                oferta_rows.append((
                    gestion,
                    cod_mat,
                    paralelo,
                    doc_id,
                    horarios
                ))

        sql_oferta = """
        INSERT INTO oferta_academica_semestral (gestion_semestre, codigo_materia, paralelo, docente_id, horarios_texto)
        VALUES %s
        ON CONFLICT (gestion_semestre, codigo_materia, paralelo, docente_id) DO UPDATE SET
            horarios_texto = EXCLUDED.horarios_texto;
        """
        execute_values(cur, sql_oferta, oferta_rows, page_size=200)
        conn.commit()
        print(f"        {len(oferta_rows)} asignaciones semestrales sincronizadas ({len(gestiones_activas)} gestiones x {len(df_hor)} registros).")

        # ---------------------------------------------------------------------
        # 5. Registro de Auditoría en bitacora_procesos_mineria
        # ---------------------------------------------------------------------
        duracion_ms = int((time.time() - start_time) * 1000)
        metricas = {
            "total_docentes_sincronizados": len(docentes_data),
            "total_materias_sincronizadas": len(materias_data),
            "total_asignaciones_semestrales": len(oferta_rows),
            "gestiones_semestrales": gestiones_activas
        }

        cur.execute("""
        INSERT INTO bitacora_procesos_mineria (
            nombre_pipeline, fase, estado, metricas_json, duracion_ms
        ) VALUES (
            'sync_catalogos_umsa.py', 
            'INGESTA_CATALOGOS_Y_OFERTA_SEMESTRAL', 
            'EXITOSO', 
            %s::jsonb,
            %s
        );
        """, (psycopg2.extras.Json(metricas), duracion_ms))
        conn.commit()
        print("        Evento formal registrado en 'bitacora_procesos_mineria'.")

        print("\n" + "="*70)
        print("  SINCRONIZACION COMPLETADA EXITOSAMENTE")
        print("="*70 + "\n")

    except Exception as e:
        conn.rollback()
        print(f"\n  [ERROR] Fallo en la sincronizacion de catalogos: {e}")
        raise
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    sync_catalogos()
