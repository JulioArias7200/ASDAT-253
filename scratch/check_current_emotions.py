# -*- coding: utf-8 -*-
import sqlite3

p = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\database\as_telegram.sqlite"
conn = sqlite3.connect(p)
cur = conn.cursor()
cur.execute("""
    SELECT dominant_emotion, COUNT(*)
    FROM sentiment_results
    WHERE dominant_emotion IS NOT NULL AND dominant_emotion != ''
    GROUP BY dominant_emotion
    ORDER BY COUNT(*) DESC
""")
print("Emociones actuales en sentiment_results (SQLite):")
for r in cur.fetchall():
    print(f"  {r[0]}: {r[1]}")
conn.close()
