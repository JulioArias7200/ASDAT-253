# -*- coding: utf-8 -*-
"""Actualizar sentiment_dictionary.csv y .json con las 15 emociones oficiales."""
import pandas as pd
import json
import unicodedata

def normalize(text):
    if not text: return ""
    text = text.lower()
    text = unicodedata.normalize('NFKD', text).encode('ASCII', 'ignore').decode('utf-8')
    return text

from apply_15_emotions_to_db import EMOCIONES_DEF

rows = []
for emo_id, data in EMOCIONES_DEF.items():
    pol = data["polarity"]
    # Palabras
    for w in set(data["palabras"]):
        rows.append({
            "term": w,
            "normalized_term": normalize(w),
            "category": emo_id,
            "polarity": pol,
            "weight": 1.0,
            "term_type": "palabra" if " " not in w else "frase",
            "language_variant": "es",
            "negation_sensitive": True if pol != "neutro" else False,
            "source": "manual_15_emociones",
            "notes": "",
            "dictionary_version": "v2.0"
        })
    # Raíces
    for r in set(data["raices"]):
        if r not in [x["term"] for x in rows]:
            rows.append({
                "term": r,
                "normalized_term": normalize(r),
                "category": emo_id,
                "polarity": pol,
                "weight": 0.8,
                "term_type": "raiz",
                "language_variant": "es",
                "negation_sensitive": True if pol != "neutro" else False,
                "source": "manual_15_emociones",
                "notes": "raiz_morfologica",
                "dictionary_version": "v2.0"
            })

df = pd.DataFrame(rows).drop_duplicates(subset=["term", "category"])
csv_path = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\data\dictionary\sentiment_dictionary.csv"
json_path = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\data\dictionary\sentiment_dictionary.json"

df.to_csv(csv_path, index=False, encoding="utf-8")
print(f"Guardado {csv_path} con {len(df)} términos en {df['category'].nunique()} categorías.")

with open(json_path, "w", encoding="utf-8") as f:
    json.dump(df.to_dict(orient="records"), f, ensure_ascii=False, indent=2)
print(f"Guardado {json_path}.")
