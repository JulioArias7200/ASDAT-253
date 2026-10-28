# -*- coding: utf-8 -*-
"""
database/export_corpus_for_r.py
Exporta los 23.371 mensajes desde Neon Serverless PostgreSQL hacia data/interim/mensajes_corpus_neon.csv
para permitir que el script en R (R/14_topicos_frecuencia.R) procese toda la información de la base de datos.
"""
import os
import sys
import pandas as pd
import psycopg2
from dotenv import load_dotenv

project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(project_root, ".env"))

neon_url = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")
if not neon_url:
    raise ValueError("No se encontro NEON_CONECTION ni DATABASE_URL")

os.makedirs(os.path.join(project_root, "data", "interim"), exist_ok=True)
output_csv = os.path.join(project_root, "data", "interim", "mensajes_corpus_neon.csv")

print(f"Conectando a Neon PostgreSQL...")
conn = psycopg2.connect(neon_url)
query = """
SELECT 
    message_id,
    timestamp_local::text AS fecha,
    COALESCE(text_norm, text_original, '') AS texto,
    polarity,
    polarity_label,
    COALESCE(dominant_emotion, 'indeterminado') AS emocion_dominante,
    intensity AS intensidad,
    tiene_imagen,
    es_sticker,
    es_gif
FROM mensajes
ORDER BY message_id ASC;
"""
print("Extrayendo los 23.371 mensajes del corpus...")
df = pd.read_sql_query(query, conn)
conn.close()

print(f"Total filas extraídas: {len(df)}")
df.to_csv(output_csv, index=False, encoding="utf-8")
print(f"Exportado exitosamente a: {output_csv} ({os.path.getsize(output_csv)} bytes)")
