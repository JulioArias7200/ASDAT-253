# -*- coding: utf-8 -*-
"""Explorar palabras en result.json para seguridad e ironia con salida limpia."""
import json
import re
from collections import Counter

result_path = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\data\raw\result.json"

with open(result_path, "r", encoding="utf-8") as f:
    data = json.load(f)

messages = data.get("messages", [])

textos = []
for m in messages:
    txt = m.get("text", "")
    if isinstance(txt, list):
        parts = []
        for p in txt:
            if isinstance(p, str):
                parts.append(p)
            elif isinstance(p, dict) and "text" in p:
                parts.append(p["text"])
        txt = "".join(parts)
    if isinstance(txt, str) and txt.strip():
        textos.append(txt)

print(f"Total mensajes con texto: {len(textos)}")

# 1. Búsqueda para SEGURIDAD
patrones_seguridad = [
    r"\bsegur[oa]s?\b", r"\bseguridad\b", r"\bconfiable\b", r"\bgarantizad[oa]\b",
    r"\bfij[oa]\b", r"\bconfirmad[oa]\b", r"\bcerteza\b", r"\bclar[oa]\b",
    r"\bsin duda\b", r"\bverificad[oa]\b", r"\boficial\b", r"\b100%\b",
    r"\basegur[oa]\b", r"\bgarantia\b", r"\bconfirmo\b", r"\bcierto\b",
    r"\bsegurisimo\b", r"\bgarantizo\b", r"\bproteccion\b", r"\bprotegido\b"
]

print("\n--- PALABRAS ENCONTRADAS PARA SEGURIDAD ---")
seguridad_matches = Counter()
for t in textos:
    t_lower = t.lower()
    for p in patrones_seguridad:
        for match in re.findall(p, t_lower):
            seguridad_matches[match] += 1

for w, c in seguridad_matches.most_common(25):
    print(f"  {w}: {c}")

# 2. Búsqueda para IRONÍA / SARCASMO
patrones_ironia = [
    r"\bclaro que si\b", r"\bsi claro\b", r"\buy si\b", r"\bay si\b",
    r"\bsegurisimo\b", r"\bque util\b", r"\bgran ayuda\b", r"\bque maravilla\b",
    r"\bque capo\b", r"\bque genio\b", r"\bun genio\b", r"\bcomo no\b",
    r"\bobvio\b", r"\bobviamente\b", r"\bque sorpresa\b", r"\b/s\b",
    r"\bsarcasmo\b", r"\bironia\b", r"\bironico\b", r"\bironica\b",
    r"\bsi pues\b", r"\bque bien\b", r"\bque lindo\b", r"\bpara variar\b",
    r"\bno me digas\b", r"\bmira vos\b", r"\bsisi\b", r"\bsisisi\b",
    r"\bah claro\b", r"\bclaro claro\b", r"\bque novedad\b", r"\btipico\b"
]

print("\n--- PALABRAS / FRASES ENCONTRADAS PARA IRONIA ---")
ironia_matches = Counter()
for t in textos:
    t_lower = t.lower()
    for p in patrones_ironia:
        for match in re.findall(p, t_lower):
            ironia_matches[match] += 1

for w, c in ironia_matches.most_common(25):
    print(f"  {w}: {c}")

# Búsqueda adicional de frases comunes en chats universitarios que denotan ironía
frases_chat = [
    r"\bque crack\b", r"\bque pro\b", r"\bque viva\b", r"\bya fuiste\b",
    r"\bbuena suerte con eso\b", r"\bni modo\b", r"\bque novedad\b",
    r"\btan rapido\b", r"\btan temprano\b"
]
print("\n--- OTRAS FRASES ESTUDIANTILES (posible ironía) ---")
chat_matches = Counter()
for t in textos:
    t_lower = t.lower()
    for p in frases_chat:
        for match in re.findall(p, t_lower):
            chat_matches[match] += 1

for w, c in chat_matches.most_common(20):
    print(f"  {w}: {c}")
