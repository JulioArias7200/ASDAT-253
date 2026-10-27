# -*- coding: utf-8 -*-
from pathlib import Path

queries_path = Path("database/queries.py")
content = queries_path.read_text(encoding="utf-8")

# Localizar el bloque a reemplazar
marker = "# =============================================================================\n#  MÓDULO DE 15 EMOCIONES"
idx = content.find(marker)
if idx == -1:
    marker_alt = "# =============================================================================\r\n#  MÓDULO DE 15 EMOCIONES"
    idx = content.find(marker_alt)

if idx == -1:
    print("ERROR: No se encontro el marcador del modulo de 15 emociones")
    exit(1)

base_content = content[:idx]

new_block = '''# =============================================================================
#  MÓDULO DE 15 EMOCIONES — Neon PostgreSQL (Primaria) + SQLite (Respaldo)
# =============================================================================

import sqlite3 as _sqlite3
from pathlib import Path as _Path

_SQLITE_PATH = _Path(__file__).resolve().parent / "as_telegram.sqlite"

_EMOCIONES_15 = [
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
]


def _get_sqlite_conn():
    """Retorna una conexión SQLite al archivo local as_telegram.sqlite."""
    conn = _sqlite3.connect(str(_SQLITE_PATH))
    conn.row_factory = _sqlite3.Row
    return conn


def get_emociones_15_barras():
    """
    Consulta SQL de conteo total de mensajes por emoción dominante:
    1. Intenta consultar Neon Serverless PostgreSQL (Tabla: mensajes).
    2. Si Neon no está disponible (ej. sin conexión), conmuta transparentemente a SQLite local.
    """
    rows = []
    total_msgs = 0
    motor_origen = "Neon Serverless PostgreSQL (TGBase)"

    # Intento 1: Neon PostgreSQL (Primaria)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        dominant_emotion                     AS emocion_id,
                        COUNT(*)                             AS total,
                        AVG(COALESCE(intensity, 1.0))        AS avg_intensity
                    FROM mensajes
                    WHERE dominant_emotion IS NOT NULL
                      AND dominant_emotion != ''
                    GROUP BY dominant_emotion
                    ORDER BY total DESC;
                """)
                rows = cur.fetchall()
                cur.execute("SELECT COUNT(*) AS total FROM mensajes;")
                total_msgs = cur.fetchone()["total"]
    except Exception as e_neon:
        # Intento 2: Fallback a SQLite local (Respaldo offline)
        print(f"[Aviso] Neon no disponible ({e_neon}). Usando SQLite local para barras.")
        try:
            with _get_sqlite_conn() as conn:
                cur = conn.cursor()
                cur.execute("""
                    SELECT
                        dominant_emotion                     AS emocion_id,
                        COUNT(*)                             AS total,
                        AVG(COALESCE(intensity, 1.0))        AS avg_intensity
                    FROM sentiment_results
                    WHERE dominant_emotion IS NOT NULL
                      AND dominant_emotion != ''
                    GROUP BY dominant_emotion
                    ORDER BY total DESC;
                """)
                rows = cur.fetchall()
                cur.execute("SELECT COUNT(*) AS total FROM messages;")
                total_msgs = cur.fetchone()["total"]
                motor_origen = "SQLite Local (Respaldo Offline)"
        except Exception as e_sql:
            print(f"[Error crítico] Fallback SQLite falló: {e_sql}")
            return {"emociones": [], "total_con_emocion": 0, "total_mensajes": 0, "pct_cobertura": 0, "motor_origen": "Error"}

    meta = {e["id"]: e for e in _EMOCIONES_15}
    total_con_emocion = sum(r["total"] for r in rows)

    result = []
    for r in rows:
        eid = r["emocion_id"]
        m = meta.get(eid, {"label": eid.capitalize(), "valence": "desconocida", "color": "#6b7280"})
        result.append({
            "emocion_id": eid,
            "label": m["label"],
            "valence": m["valence"],
            "color": m["color"],
            "total": int(r["total"]),
            "pct": round(100.0 * r["total"] / max(total_con_emocion, 1), 1),
            "avg_intensity": round(float(r["avg_intensity"] or 1.0), 3),
        })

    ids_en_db = {r["emocion_id"] for r in result}
    for e in _EMOCIONES_15:
        if e["id"] not in ids_en_db:
            result.append({
                "emocion_id": e["id"],
                "label": e["label"],
                "valence": e["valence"],
                "color": e["color"],
                "total": 0,
                "pct": 0.0,
                "avg_intensity": 0.0,
            })

    return {
        "emociones": result,
        "total_con_emocion": int(total_con_emocion),
        "total_mensajes": int(total_msgs),
        "pct_cobertura": round(100.0 * total_con_emocion / max(total_msgs, 1), 1),
        "motor_origen": motor_origen,
    }


def get_emociones_15_serie_temporal(fecha_inicio=None, fecha_fin=None, emociones_filtro=None):
    """
    Consulta SQL de evolución temporal mensual de emociones:
    1. Intenta consultar Neon Serverless PostgreSQL (TO_CHAR(timestamp_utc, 'YYYY-MM')).
    2. Si Neon no está disponible, conmuta a SQLite (strftime('%Y-%m', timestamp_utc)).
    """
    emociones_activas = emociones_filtro if emociones_filtro else [e["id"] for e in _EMOCIONES_15]
    rows = []
    fecha_min_db = "2022-01-01"
    fecha_max_db = "2026-12-31"
    motor_origen = "Neon Serverless PostgreSQL (TGBase)"

    # Intento 1: Neon PostgreSQL (Primaria)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                where_clauses = [
                    "dominant_emotion IS NOT NULL",
                    "dominant_emotion != ''",
                    "timestamp_utc IS NOT NULL"
                ]
                params = []
                if fecha_inicio:
                    where_clauses.append("timestamp_utc >= %s")
                    params.append(fecha_inicio)
                if fecha_fin:
                    where_clauses.append("timestamp_utc <= %s")
                    params.append(fecha_fin + " 23:59:59")

                placeholders = ",".join(["%s"] * len(emociones_activas))
                where_clauses.append(f"dominant_emotion IN ({placeholders})")
                params.extend(emociones_activas)

                cur.execute(f"""
                    SELECT
                        TO_CHAR(timestamp_utc, 'YYYY-MM')   AS periodo,
                        dominant_emotion                    AS emocion_id,
                        COUNT(*)                            AS total
                    FROM mensajes
                    WHERE {" AND ".join(where_clauses)}
                    GROUP BY periodo, dominant_emotion
                    ORDER BY periodo ASC;
                """, params)
                rows = cur.fetchall()

                cur.execute("""
                    SELECT MIN(timestamp_utc) AS fecha_min,
                           MAX(timestamp_utc) AS fecha_max
                    FROM mensajes
                    WHERE timestamp_utc IS NOT NULL;
                """)
                rng = cur.fetchone()
                if rng and rng["fecha_min"]:
                    fmin = rng["fecha_min"]
                    fecha_min_db = fmin.strftime("%Y-%m-%d") if hasattr(fmin, "strftime") else str(fmin)[:10]
                if rng and rng["fecha_max"]:
                    fmax = rng["fecha_max"]
                    fecha_max_db = fmax.strftime("%Y-%m-%d") if hasattr(fmax, "strftime") else str(fmax)[:10]
    except Exception as e_neon:
        # Intento 2: Fallback a SQLite local
        print(f"[Aviso] Neon no disponible ({e_neon}). Usando SQLite local para serie temporal.")
        try:
            where_clauses = [
                "sr.dominant_emotion IS NOT NULL",
                "sr.dominant_emotion != ''",
                "m.timestamp_utc IS NOT NULL",
            ]
            params = []
            if fecha_inicio:
                where_clauses.append("m.timestamp_utc >= ?")
                params.append(fecha_inicio)
            if fecha_fin:
                where_clauses.append("m.timestamp_utc <= ?")
                params.append(fecha_fin + "T23:59:59Z")

            placeholders = ",".join("?" * len(emociones_activas))
            where_clauses.append(f"sr.dominant_emotion IN ({placeholders})")
            params.extend(emociones_activas)

            with _get_sqlite_conn() as conn:
                cur = conn.cursor()
                cur.execute(f"""
                    SELECT
                        strftime('%Y-%m', m.timestamp_utc)  AS periodo,
                        sr.dominant_emotion                  AS emocion_id,
                        COUNT(*)                             AS total
                    FROM sentiment_results sr
                    JOIN messages m ON sr.message_id = m.message_id
                    WHERE {" AND ".join(where_clauses)}
                    GROUP BY periodo, sr.dominant_emotion
                    ORDER BY periodo ASC;
                """, params)
                rows = cur.fetchall()

                cur.execute("""
                    SELECT MIN(timestamp_utc) AS fecha_min,
                           MAX(timestamp_utc) AS fecha_max
                    FROM messages
                    WHERE timestamp_utc IS NOT NULL;
                """)
                rng = cur.fetchone()
                fecha_min_db = rng["fecha_min"][:10] if rng["fecha_min"] else "2022-01-01"
                fecha_max_db = rng["fecha_max"][:10] if rng["fecha_max"] else "2026-12-31"
                motor_origen = "SQLite Local (Respaldo Offline)"
        except Exception as e_sql:
            print(f"[Error crítico] Fallback SQLite falló: {e_sql}")
            return {
                "labels": [], "datasets": [],
                "emociones_disponibles": _EMOCIONES_15,
                "fecha_min": "2022-01-01", "fecha_max": "2026-12-31",
                "motor_origen": "Error"
            }

    if not rows:
        return {
            "labels": [], "datasets": [],
            "emociones_disponibles": _EMOCIONES_15,
            "fecha_min": fecha_min_db, "fecha_max": fecha_max_db,
            "motor_origen": motor_origen,
        }

    periodos = sorted(set(r["periodo"] for r in rows))
    meta = {e["id"]: e for e in _EMOCIONES_15}

    datos_por_emocion = {}
    for r in rows:
        eid = r["emocion_id"]
        if eid not in datos_por_emocion:
            datos_por_emocion[eid] = {}
        datos_por_emocion[eid][r["periodo"]] = int(r["total"])

    datasets = []
    for eid, datos in sorted(datos_por_emocion.items(), key=lambda x: -sum(x[1].values())):
        m = meta.get(eid, {"label": eid.capitalize(), "color": "#6b7280", "valence": "desconocida"})
        datasets.append({
            "emocion_id": eid,
            "label": m["label"],
            "color": m["color"],
            "valence": m.get("valence", "desconocida"),
            "data": [datos.get(p, 0) for p in periodos],
            "total": sum(datos.values()),
        })

    return {
        "labels": periodos,
        "datasets": datasets,
        "emociones_disponibles": _EMOCIONES_15,
        "fecha_min": fecha_min_db,
        "fecha_max": fecha_max_db,
        "motor_origen": motor_origen,
    }


def get_emociones_15_polar():
    """
    Consulta SQL de intensidad promedio y frecuencia para coordenadas polares (radar):
    1. Intenta consultar Neon Serverless PostgreSQL (mensajes).
    2. Si Neon no está disponible, conmuta a SQLite (sentiment_results).
    """
    rows = []
    motor_origen = "Neon Serverless PostgreSQL (TGBase)"

    # Intento 1: Neon PostgreSQL (Primaria)
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        dominant_emotion                   AS emocion_id,
                        COUNT(*)                           AS total,
                        AVG(COALESCE(intensity, 1.0))      AS avg_intensity,
                        MAX(COALESCE(intensity, 1.0))      AS max_intensity
                    FROM mensajes
                    WHERE dominant_emotion IS NOT NULL
                      AND dominant_emotion != ''
                    GROUP BY dominant_emotion;
                """)
                rows = cur.fetchall()
    except Exception as e_neon:
        # Intento 2: Fallback a SQLite local
        print(f"[Aviso] Neon no disponible ({e_neon}). Usando SQLite local para radar polar.")
        try:
            with _get_sqlite_conn() as conn:
                cur = conn.cursor()
                cur.execute("""
                    SELECT
                        dominant_emotion                   AS emocion_id,
                        COUNT(*)                           AS total,
                        AVG(COALESCE(intensity, 1.0))      AS avg_intensity,
                        MAX(COALESCE(intensity, 1.0))      AS max_intensity
                    FROM sentiment_results
                    WHERE dominant_emotion IS NOT NULL
                      AND dominant_emotion != ''
                    GROUP BY dominant_emotion;
                """)
                rows = cur.fetchall()
                motor_origen = "SQLite Local (Respaldo Offline)"
        except Exception as e_sql:
            print(f"[Error crítico] Fallback SQLite falló: {e_sql}")
            return {"emociones": [], "motor_origen": "Error"}

    meta = {e["id"]: e for e in _EMOCIONES_15}
    max_total = max((r["total"] for r in rows), default=1)
    max_avg_int = max((float(r["avg_intensity"] or 1.0) for r in rows), default=1.0)

    result_map = {}
    for r in rows:
        eid = r["emocion_id"]
        m = meta.get(eid, {"label": eid.capitalize(), "valence": "desconocida", "color": "#6b7280"})
        freq_norm = 100.0 * r["total"] / max(max_total, 1)
        intens_norm = 100.0 * float(r["avg_intensity"] or 1.0) / max(max_avg_int, 1)
        score_polar = round(0.60 * freq_norm + 0.40 * intens_norm, 1)
        result_map[eid] = {
            "emocion_id": eid,
            "label": m["label"],
            "valence": m["valence"],
            "color": m["color"],
            "total": int(r["total"]),
            "avg_intensity": round(float(r["avg_intensity"] or 1.0), 3),
            "score_polar": score_polar,
        }

    ordered = []
    for e in _EMOCIONES_15:
        ordered.append(result_map.get(e["id"], {
            "emocion_id": e["id"],
            "label": e["label"],
            "valence": e["valence"],
            "color": e["color"],
            "total": 0,
            "avg_intensity": 0.0,
            "score_polar": 0.0,
        }))

    return {"emociones": ordered, "motor_origen": motor_origen}
'''

queries_path.write_text(base_content + new_block, encoding="utf-8")
print("OK: queries.py actualizado exitosamente con Neon como BD primaria!")
