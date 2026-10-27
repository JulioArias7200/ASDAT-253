# -*- coding: utf-8 -*-
"""
Aplica la clasificación de las 15 emociones oficiales al corpus de SQLite (sentiment_results).
Basado en los términos y raíces definidos por el usuario + búsquedas de seguridad e ironía en result.json.
"""
import sqlite3
import re
import unicodedata
import json

def normalize(text):
    if not text: return ""
    text = text.lower()
    text = unicodedata.normalize('NFKD', text).encode('ASCII', 'ignore').decode('utf-8')
    return text

EMOCIONES_DEF = {
    "alegria": {
        "valencia": "positiva",
        "polarity": "positivo",
        "palabras": ["alegre","alegria","feliz","felices","felicidad","contento","contenta","jaja","jeje","xd","genial","buenisimo","buenisima","bacan","chevere","divertido","divertida","festejar","celebrar"],
        "raices": ["jaja","jeje","aleg"]
    },
    "gratitud": {
        "valencia": "positiva",
        "polarity": "positivo",
        "palabras": ["gracias","grax","agradezco","agradecido","agradecida","mil gracias","muchas gracias","bendiciones","dios le pague"],
        "raices": ["agradec"]
    },
    "esperanza": {
        "valencia": "positiva",
        "polarity": "positivo",
        "palabras": ["ojala","espero","esperemos","esperanza","confio","confiamos","suerte","exito","exitos","animo","animos","lograremos","podemos lograrlo","vamos a poder"],
        "raices": ["esperanz"]
    },
    "seguridad": {
        "valencia": "positiva",
        "polarity": "positivo",
        "palabras": ["seguro","segura","seguridad","seguros","seguras","oficial","confirmado","confirmada","confirmo","confiable","certeza","garantizado","garantizada","verificado","verificada","fijo","fija","cierto","sin duda","aseguro","asegura"],
        "raices": ["segur","confirm","oficial","verific","garant"]
    },
    "admiracion": {
        "valencia": "positiva",
        "polarity": "positivo",
        "palabras": ["admiro","admiracion","excelente","crack","capo","genio","increible","bravo","felicitaciones","felicidades","respeto","recomendado","recomendada","recomiendo","recomendable"],
        "raices": ["admir","felicit"]
    },
    "tranquilidad": {
        "valencia": "positiva",
        "polarity": "positivo",
        "palabras": ["tranquilo","tranquila","tranquilidad","calma","calmado","relajado","paz","descuida","tranqui","sin problema","no hay problema","aliviado","alivio","menos mal"],
        "raices": ["tranqui","relaj","relax"]
    },
    "sorpresa": {
        "valencia": "ambigua",
        "polarity": "neutro",
        "palabras": ["wow","guau","sorpresa","sorprendido","sorprendida","imposible","uf","ufff","dios mio","no puede ser","no lo puedo creer","de repente","inesperado","insolito","raro","rara"],
        "raices": ["sorpren","inesper"]
    },
    "confusion": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["confundido","confundida","confusion","confuso","confusa","no entiendo","no entendi","nose","ni idea","duda","dudas","dudo","perdido","perdida","me perdi","como asi"],
        "raices": ["confu"]
    },
    "preocupacion": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["preocupado","preocupada","preocupacion","inquieto","nervioso","nerviosa","nervios","ansiedad","ansioso","ansiosa","miedo","temo","urgente","apurate","apurense","riesgo","peligro","angustia"],
        "raices": ["preocup","nervi","angust"]
    },
    "tristeza": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["triste","tristeza","lamento","lamentable","que pena","penita","lastima","llorar","lloro","duele","sufrir","sufro","deprimido","deprimida","desanimado","descontento"],
        "raices": ["trist","llor","lament","deprim"]
    },
    "enojo": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["enojado","enojada","enojo","molesto","molesta","bronca","rabia","furioso","furiosa","harto","harta","ira","fastidio","odio","pesimo","pesima","horrible","asco","maldito","maldita","mierda","carajo","chucha","puta","pucha","joder","estupido","idiota","inutil","basura","mal","malo","mala","peor","reclamo","queja","injusto","abuso","envidia"],
        "raices": ["enoj","moles","pesim","reclam","injust"]
    },
    "decepcion": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["decepcion","decepcionado","decepcionada","decepciono","desilusion","desilusionado","fraude","engano","mentira","mintieron","falso","falsa","no sirve","para nada","fracaso","fracase","reprobe","reprobado","reprobaron","aplazado","jale","jalaron"],
        "raices": ["decep","desilus","\\bf\\b"]
    },
    "cansancio": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["cansado","cansada","cansancio","agotado","agotada","agotador","fatiga","estres","estresado","estresada","estresante","pesado","pesada","tedioso","aburrido","aburrida","aburre","aburrimiento","flojera"],
        "raices": ["cansa","agota","estres","aburr"]
    },
    "ironia": {
        "valencia": "negativa",
        "polarity": "negativo",
        "palabras": ["obvio","obviamente","/s","sisi","sisisi","si claro","claro que si","como no","uy si","ay si","para variar","no me digas","gran ayuda","que novedad","que maravilla","sarcasmo","ironia","ironico","ironica","segurisimo"],
        "raices": ["ironi","sarcas","obvi"]
    },
    "curiosidad": {
        "valencia": "ambigua",
        "polarity": "neutro",
        "palabras": ["curioso","curiosa","curiosidad","interesante","me interesa","quisiera saber","quiero saber","me gustaria saber","cuentame mas"],
        "raices": ["curios"]
    }
}

compiled_patterns = {}
for emo_id, data in EMOCIONES_DEF.items():
    pats = []
    for w in data["palabras"]:
        nw = normalize(w)
        if nw:
            pats.append(r"\b" + re.escape(nw) + r"\b")
    for r_stem in data["raices"]:
        nr = normalize(r_stem)
        if nr:
            pats.append(r"\b" + re.escape(nr) + r"\w*")
    combined = re.compile("|".join(set(pats)))
    compiled_patterns[emo_id] = combined

db_path = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\database\as_telegram.sqlite"
conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Leer todos los mensajes
cur.execute("SELECT message_id, text_original, text_norm FROM messages")
rows = cur.fetchall()
print(f"Cargados {len(rows)} mensajes desde SQLite messages.")

updates = []
conteo = {e: 0 for e in EMOCIONES_DEF}
sin_emocion = 0

for mid, t_orig, t_norm in rows:
    t = normalize(t_norm or t_orig)
    if not t:
        updates.append((None, None, 0.0, None, mid))
        sin_emocion += 1
        continue
    
    matched = []
    scores = {}
    for emo_id, pat in compiled_patterns.items():
        found = pat.findall(t)
        if found:
            cnt = len(found)
            matched.append((emo_id, cnt))
            scores[emo_id] = cnt
            
    if matched:
        # Ordenar por frecuencia detectada
        matched.sort(key=lambda x: -x[1])
        dom_emo = matched[0][0]
        conteo[dom_emo] += 1
        intensity = min(3.0, 1.0 + 0.25 * (matched[0][1] - 1))
        detected_json = json.dumps([m[0] for m in matched])
        emotion_scores_json = json.dumps(scores)
        updates.append((dom_emo, detected_json, intensity, emotion_scores_json, mid))
    else:
        updates.append((None, None, 0.0, None, mid))
        sin_emocion += 1

print(f"Mensajes clasificados con alguna de las 15 emociones: {len(rows) - sin_emocion}")
print("Actualizando tabla sentiment_results en lote...")

cur.executemany("""
    UPDATE sentiment_results
    SET dominant_emotion = ?,
        detected_emotions = ?,
        intensity = ?,
        emotion_scores = ?,
        dictionary_version = 'v2.0_15_emociones'
    WHERE message_id = ?;
""", updates)

conn.commit()
print("Transacción SQLite confirmada exitosamente.")

# Verificación
cur.execute("""
    SELECT dominant_emotion, COUNT(*), ROUND(AVG(intensity), 2)
    FROM sentiment_results
    WHERE dominant_emotion IS NOT NULL AND dominant_emotion != ''
    GROUP BY dominant_emotion
    ORDER BY COUNT(*) DESC;
""")
res = cur.fetchall()
print("\n--- RESULTADOS ACTUALIZADOS EN SQLite (sentiment_results) ---")
for r in res:
    print(f"  {r[0]:15s}: {r[1]:5d} msgs (intensidad avg: {r[2]})")

conn.close()
