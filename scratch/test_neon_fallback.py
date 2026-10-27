import sys
sys.path.insert(0, '.')

from database.queries import (
    _EMOCIONES_15,
    _get_sqlite_conn,
    get_connection,
)

# Probar la lógica Neon con fallback SQLite
def test_barras_neon_fallback():
    motor_origen = None
    rows = []
    total_msgs = 0
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        dominant_emotion AS emocion_id,
                        COUNT(*) AS total,
                        AVG(COALESCE(intensity, 1.0)) AS avg_intensity
                    FROM mensajes
                    WHERE dominant_emotion IS NOT NULL AND dominant_emotion != ''
                    GROUP BY dominant_emotion
                    ORDER BY total DESC;
                """)
                rows = cur.fetchall()
                cur.execute("SELECT COUNT(*) AS total FROM mensajes;")
                total_msgs = cur.fetchone()["total"]
                motor_origen = "Neon Serverless PostgreSQL (TGBase)"
    except Exception as e:
        print(f"Neon fallo ({e}). Activando fallback SQLite...")
        with _get_sqlite_conn() as conn:
            cur = conn.cursor()
            cur.execute("""
                SELECT
                    dominant_emotion AS emocion_id,
                    COUNT(*) AS total,
                    AVG(COALESCE(intensity, 1.0)) AS avg_intensity
                FROM sentiment_results
                WHERE dominant_emotion IS NOT NULL AND dominant_emotion != ''
                GROUP BY dominant_emotion
                ORDER BY total DESC;
            """)
            rows = cur.fetchall()
            cur.execute("SELECT COUNT(*) AS total FROM messages;")
            total_msgs = cur.fetchone()["total"]
            motor_origen = "SQLite Local (Respaldo Offline)"

    print(f"Origen motor: {motor_origen}")
    print(f"Total mensajes: {total_msgs}")
    print(f"Filas encontradas: {len(rows)}")

test_barras_neon_fallback()
