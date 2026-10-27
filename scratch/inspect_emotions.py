import sqlite3
import json

conn = sqlite3.connect('database/as_telegram.sqlite')
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# Ver columnas de sentiment_results
cur.execute("PRAGMA table_info(sentiment_results)")
cols = cur.fetchall()
print("Columnas sentiment_results:")
for c in cols:
    print(f"  {c['name']} ({c['type']})")

# Ver columnas de messages
cur.execute("PRAGMA table_info(messages)")
cols_m = cur.fetchall()
print("\nColumnas messages:")
for c in cols_m:
    print(f"  {c['name']} ({c['type']})")

# Ver muestra de sentiment_results
print("\nMuestra sentiment_results (5 filas con emociones):") 
cur.execute("""
    SELECT sr.message_id, sr.dominant_emotion, sr.polarity_label, 
           sr.intensity, sr.emotion_scores, m.timestamp_utc
    FROM sentiment_results sr
    JOIN messages m ON sr.message_id = m.message_id
    WHERE sr.dominant_emotion IS NOT NULL
    LIMIT 5
""")
for r in cur.fetchall():
    scores = r['emotion_scores']
    print(f"  msg={r['message_id']} emo={r['dominant_emotion']} pol={r['polarity_label']} intensidad={r['intensity']}")
    print(f"    fecha={r['timestamp_utc']}")
    if scores:
        try:
            s = json.loads(scores)
            print(f"    scores keys: {list(s.keys())[:5]}")
        except:
            print(f"    scores (raw): {scores[:100]}")

# Listar emociones disponibles en la DB
cur.execute("""
    SELECT dominant_emotion, COUNT(*) as cnt, 
           AVG(intensity) as avg_int,
           AVG(polarity) as avg_pol
    FROM sentiment_results 
    WHERE dominant_emotion IS NOT NULL
    GROUP BY dominant_emotion
    ORDER BY cnt DESC
""")
print("\nEmociones en la DB (dominant_emotion):")
for r in cur.fetchall():
    print(f"  {r['dominant_emotion']}: {r['cnt']} msgs, avg_intensity={r['avg_int']:.3f if r['avg_int'] else 'N/A'}")

conn.close()
