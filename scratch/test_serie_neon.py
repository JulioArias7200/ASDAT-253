import sys
sys.path.insert(0, '.')

from database.queries import (
    _EMOCIONES_15,
    _get_sqlite_conn,
    get_connection,
)

def test_serie_neon_fallback():
    emociones_activas = [e["id"] for e in _EMOCIONES_15]
    rows = []
    fecha_min_db = "2022-01-01"
    fecha_max_db = "2026-12-31"
    motor_origen = None

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                where_clauses = [
                    "dominant_emotion IS NOT NULL",
                    "dominant_emotion != ''",
                    "timestamp_utc IS NOT NULL"
                ]
                params = []
                placeholders = ",".join(["%s"] * len(emociones_activas))
                where_clauses.append(f"dominant_emotion IN ({placeholders})")
                params.extend(emociones_activas)

                cur.execute(f"""
                    SELECT
                        TO_CHAR(timestamp_utc, 'YYYY-MM') AS periodo,
                        dominant_emotion AS emocion_id,
                        COUNT(*) AS total
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
                motor_origen = "Neon Serverless PostgreSQL (TGBase)"
    except Exception as e:
        print(f"Neon fallo ({e}). Activando fallback SQLite...")
        where_clauses = [
            "sr.dominant_emotion IS NOT NULL",
            "sr.dominant_emotion != ''",
            "m.timestamp_utc IS NOT NULL",
        ]
        params = []
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

    print(f"Motor: {motor_origen}")
    print(f"Periodos encontrados en filas: {len(rows)}")
    print(f"Rango: {fecha_min_db} -> {fecha_max_db}")

test_serie_neon_fallback()
