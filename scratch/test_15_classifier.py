# -*- coding: utf-8 -*-
"""Probar clasificación de las 15 emociones en los mensajes de SQLite."""
import sqlite3
import re
import unicodedata

def normalize(text):
    if not text: return ""
    text = text.lower()
    text = unicodedata.normalize('NFKD', text).encode('ASCII', 'ignore').decode('utf-8')
    return text

# Definición de las 15 emociones
EMOCIONES_DEF = {
    "alegria": {
        "valencia": "positiva",
        "palabras": ["alegre","alegria","feliz","felices","felicidad","contento","contenta","jaja","jeje","xd","genial","buenisimo","buenisima","bacan","chevere","divertido","divertida","festejar","celebrar"],
        "raices": ["jaja","jeje","aleg"]
    },
    "gratitud": {
        "valencia": "positiva",
        "palabras": ["gracias","grax","agradezco","agradecido","agradecida","mil gracias","muchas gracias","bendiciones","dios le pague"],
        "raices": ["agradec"]
    },
    "esperanza": {
        "valencia": "positiva",
        "palabras": ["ojala","espero","esperemos","esperanza","confio","confiamos","suerte","exito","exitos","animo","animos","lograremos","podemos lograrlo","vamos a poder"],
        "raices": ["esperanz"]
    },
    "seguridad": {
        "valencia": "positiva",
        "palabras": ["seguro","segura","seguridad","seguros","seguras","oficial","confirmado","confirmada","confirmo","confiable","certeza","garantizado","garantizada","verificado","verificada","fijo","fija","cierto","sin duda","aseguro","asegura"],
        "raices": ["segur","confirm","oficial","verific","garant"]
    },
    "admiracion": {
        "valencia": "positiva",
        "palabras": ["admiro","admiracion","excelente","crack","capo","genio","increible","bravo","felicitaciones","felicidades","respeto","recomendado","recomendada","recomiendo","recomendable"],
        "raices": ["admir","felicit"]
    },
    "tranquilidad": {
        "valencia": "positiva",
        "palabras": ["tranquilo","tranquila","tranquilidad","calma","calmado","relajado","paz","descuida","tranqui","sin problema","no hay problema","aliviado","alivio","menos mal"],
        "raices": ["tranqui","relaj","relax"]
    },
    "sorpresa": {
        "valencia": "ambigua",
        "palabras": ["wow","guau","sorpresa","sorprendido","sorprendida","imposible","uf","ufff","dios mio","no puede ser","no lo puedo creer","de repente","inesperado","insolito","raro","rara"],
        "raices": ["sorpren","inesper"]
    },
    "confusion": {
        "valencia": "negativa",
        "palabras": ["confundido","confundida","confusion","confuso","confusa","no entiendo","no entendi","nose","ni idea","duda","dudas","dudo","perdido","perdida","me perdi","como asi"],
        "raices": ["confu"]
    },
    "preocupacion": {
        "valencia": "negativa",
        "palabras": ["preocupado","preocupada","preocupacion","inquieto","nervioso","nerviosa","nervios","ansiedad","ansioso","ansiosa","miedo","temo","urgente","apurate","apurense","riesgo","peligro","angustia"],
        "raices": ["preocup","nervi","angust"]
    },
    "tristeza": {
        "valencia": "negativa",
        "palabras": ["triste","tristeza","lamento","lamentable","que pena","penita","lastima","llorar","lloro","duele","sufrir","sufro","deprimido","deprimida","desanimado","descontento"],
        "raices": ["trist","llor","lament","deprim"]
    },
    "enojo": {
        "valencia": "negativa",
        "palabras": ["enojado","enojada","enojo","molesto","molesta","bronca","rabia","furioso","furiosa","harto","harta","ira","fastidio","odio","pesimo","pesima","horrible","asco","maldito","maldita","mierda","carajo","chucha","puta","pucha","joder","estupido","idiota","inutil","basura","mal","malo","mala","peor","reclamo","queja","injusto","abuso","envidia"],
        "raices": ["enoj","moles","pesim","reclam","injust"]
    },
    "decepcion": {
        "valencia": "negativa",
        "palabras": ["decepcion","decepcionado","decepcionada","decepciono","desilusion","desilusionado","fraude","engano","mentira","mintieron","falso","falsa","no sirve","para nada","fracaso","fracase","reprobe","reprobado","reprobaron","aplazado","jale","jalaron"],
        "raices": ["decep","desilus","\\bf\\b"]
    },
    "cansancio": {
        "valencia": "negativa",
        "palabras": ["cansado","cansada","cansancio","agotado","agotada","agotador","fatiga","estres","estresado","estresada","estresante","pesado","pesada","tedioso","aburrido","aburrida","aburre","aburrimiento","flojera"],
        "raices": ["cansa","agota","estres","aburr"]
    },
    "ironia": {
        "valencia": "negativa",
        "palabras": ["obvio","obviamente","/s","sisi","sisisi","si claro","claro que si","como no","uy si","ay si","para variar","no me digas","gran ayuda","que novedad","que maravilla","sarcasmo","ironia","ironico","ironica","segurisimo"],
        "raices": ["ironi","sarcas","obvi"]
    },
    "curiosidad": {
        "valencia": "ambigua",
        "palabras": ["curioso","curiosa","curiosidad","interesante","me interesa","quisiera saber","quiero saber","me gustaria saber","cuentame mas"],
        "raices": ["curios"]
    }
}

# Preparar regex compilados para cada emoción
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

# Probar en SQLite
conn = sqlite3.connect(r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\database\as_telegram.sqlite")
cur = conn.cursor()
cur.execute("SELECT message_id, text_original, text_norm FROM messages WHERE text_original IS NOT NULL AND text_original != ''")
rows = cur.fetchall()

conteo = {e: 0 for e in EMOCIONES_DEF}
total_mensajes_con_emocion = 0

for mid, t_orig, t_norm in rows:
    t = normalize(t_norm or t_orig)
    if not t: continue
    matched = []
    for emo_id, pat in compiled_patterns.items():
        m = pat.findall(t)
        if m:
            matched.append((emo_id, len(m)))
    if matched:
        total_mensajes_con_emocion += 1
        # Mayor cantidad de ocurrencias es dominante
        matched.sort(key=lambda x: -x[1])
        dom = matched[0][0]
        conteo[dom] += 1

print(f"Total mensajes evaluados: {len(rows)}")
print(f"Total mensajes con al menos 1 emocion: {total_mensajes_con_emocion} ({round(100.0*total_mensajes_con_emocion/len(rows), 1)}%)\n")
print("Distribucion de las 15 emociones:")
for emo, c in sorted(conteo.items(), key=lambda x: -x[1]):
    print(f"  {emo:15s}: {c:5d} msgs")

conn.close()
