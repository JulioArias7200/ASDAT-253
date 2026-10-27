import sqlite3
conn = sqlite3.connect('database/as_telegram.sqlite')
cur = conn.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
print('TABLAS:', [r[0] for r in cur.fetchall()])
cur.execute("SELECT COUNT(*) FROM messages")
print('Mensajes:', cur.fetchone()[0])
try:
    cur.execute("SELECT COUNT(*) FROM sentiment_results")
    print('Sentiment results:', cur.fetchone()[0])
    cur.execute("SELECT dominant_emotion, COUNT(*) as cnt FROM sentiment_results GROUP BY dominant_emotion ORDER BY cnt DESC LIMIT 20")
    print('Emociones dominantes:')
    for r in cur.fetchall():
        print(' ', r)
except Exception as e:
    print('Error sentiment_results:', e)
try:
    cur.execute("SELECT COUNT(*) FROM audit_events")
    print('Audit events:', cur.fetchone()[0])
except Exception as e:
    print('Error audit_events:', e)
conn.close()
