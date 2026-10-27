# -*- coding: utf-8 -*-
"""Actualizar _EMOCIONES_15 y filtrado estricto en database/queries.py."""
p = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\database\queries.py"

with open(p, "r", encoding="utf-8") as f:
    code = f.read()

old_block = """_EMOCIONES_15 = [
    {"id": "alegria",      "label": "Alegría",      "valence": "positiva",  "color": "#22c55e"},
    {"id": "gratitud",     "label": "Gratitud",     "valence": "positiva",  "color": "#10b981"},
    {"id": "esperanza",    "label": "Esperanza",    "valence": "positiva",  "color": "#34d399"},
    {"id": "amor",         "label": "Amor",         "valence": "positiva",  "color": "#f472b6"},
    {"id": "confianza",    "label": "Confianza",    "valence": "positiva",  "color": "#38bdf8"},
    {"id": "anticipacion", "label": "Anticipación", "valence": "positiva",  "color": "#a78bfa"},
    {"id": "alivio",       "label": "Alivio",       "valence": "positiva",  "color": "#86efac"},
    {"id": "orgullo",      "label": "Orgullo",      "valence": "positiva",  "color": "#fbbf24"},
    {"id": "diversion",    "label": "Diversión",    "valence": "positiva",  "color": "#facc15"},
    {"id": "sorpresa",     "label": "Sorpresa",     "valence": "ambigua",   "color": "#fb923c"},
    {"id": "tristeza",     "label": "Tristeza",     "valence": "negativa",  "color": "#60a5fa"},
    {"id": "frustracion",  "label": "Frustración",  "valence": "negativa",  "color": "#f87171"},
    {"id": "ansiedad",     "label": "Ansiedad",     "valence": "negativa",  "color": "#fb923c"},
    {"id": "verguenza",    "label": "Vergüenza",    "valence": "negativa",  "color": "#c084fc"},
    {"id": "miedo",        "label": "Miedo",        "valence": "negativa",  "color": "#94a3b8"},
    {"id": "ira",          "label": "Ira",          "valence": "negativa",  "color": "#ef4444"},
    {"id": "asco",         "label": "Asco",         "valence": "negativa",  "color": "#a3e635"},
    {"id": "aburrimiento", "label": "Aburrimiento", "valence": "negativa",  "color": "#64748b"},
]"""

new_block = """_EMOCIONES_15 = [
    {"id": "alegria",      "label": "Alegría",      "valence": "positiva",  "color": "#22c55e"},
    {"id": "gratitud",     "label": "Gratitud",     "valence": "positiva",  "color": "#10b981"},
    {"id": "esperanza",    "label": "Esperanza",    "valence": "positiva",  "color": "#34d399"},
    {"id": "seguridad",    "label": "Seguridad",    "valence": "positiva",  "color": "#06b6d4"},
    {"id": "admiracion",   "label": "Admiración",   "valence": "positiva",  "color": "#3b82f6"},
    {"id": "tranquilidad", "label": "Tranquilidad", "valence": "positiva",  "color": "#14b8a6"},
    {"id": "sorpresa",     "label": "Sorpresa",     "valence": "ambigua",   "color": "#f59e0b"},
    {"id": "confusion",    "label": "Confusión",    "valence": "negativa",  "color": "#8b5cf6"},
    {"id": "preocupacion", "label": "Preocupación", "valence": "negativa",  "color": "#ec4899"},
    {"id": "tristeza",     "label": "Tristeza",     "valence": "negativa",  "color": "#6366f1"},
    {"id": "enojo",        "label": "Enojo",        "valence": "negativa",  "color": "#ef4444"},
    {"id": "decepcion",    "label": "Decepción",    "valence": "negativa",  "color": "#f97316"},
    {"id": "cansancio",    "label": "Cansancio",    "valence": "negativa",  "color": "#64748b"},
    {"id": "ironia",       "label": "Ironía",       "valence": "negativa",  "color": "#a855f7"},
    {"id": "curiosidad",   "label": "Curiosidad",   "valence": "ambigua",   "color": "#eab308"},
]"""

code = code.replace(old_block.replace("\r\n", "\n"), new_block)
code = code.replace(old_block, new_block)

# Asegurar filtrado estricto en get_emociones_15_barras
old_filter = """    meta = {e["id"]: e for e in _EMOCIONES_15}
    total_con_emocion = sum(r["total"] for r in rows)"""

new_filter = """    meta = {e["id"]: e for e in _EMOCIONES_15}
    # Filtrar estrictamente solo las 15 emociones oficiales (descartar cualquier otra)
    rows = [r for r in rows if r["emocion_id"] in meta]
    total_con_emocion = sum(r["total"] for r in rows)"""

code = code.replace(old_filter.replace("\r\n", "\n"), new_filter)
code = code.replace(old_filter, new_filter)

# Asegurar filtrado estricto en get_emociones_15_polar
old_polar_filter = """    meta = {e["id"]: e for e in _EMOCIONES_15}
    max_total = max((r["total"] for r in rows), default=1)"""

new_polar_filter = """    meta = {e["id"]: e for e in _EMOCIONES_15}
    # Filtrar estrictamente solo las 15 emociones oficiales
    rows = [r for r in rows if r["emocion_id"] in meta]
    max_total = max((r["total"] for r in rows), default=1)"""

code = code.replace(old_polar_filter.replace("\r\n", "\n"), new_polar_filter)
code = code.replace(old_polar_filter, new_polar_filter)

with open(p, "w", encoding="utf-8") as f:
    f.write(code)

print("[OK] database/queries.py actualizado con las 15 emociones oficiales y filtrado estricto!")
