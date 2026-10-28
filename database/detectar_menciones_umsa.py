# -*- coding: utf-8 -*-
"""
database/detectar_menciones_umsa.py
Escanea los 23,371 mensajes del corpus en Neon PostgreSQL:
  1. Detecta menciones de docentes usando expresiones regulares (alias_regex).
  2. Detecta menciones de materias y paralelos/horarios.
  3. Resuelve el contexto semestral contra 'oferta_academica_semestral' (dinámica SCD Tipo 2).
  4. Inserta las menciones enriquecidas en 'menciones_docentes'.
  5. Registra la auditoria en 'bitacora_procesos_mineria'.
"""
import os
import sys
import re
import time
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor
from dotenv import load_dotenv

project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

load_dotenv(os.path.join(project_root, ".env"))
neon_conn_str = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")
if not neon_conn_str:
    raise ValueError("No se encontro NEON_CONECTION ni DATABASE_URL en el entorno o .env")

def run_detection():
    print("\n" + "="*70)
    print("  DETECCION Y EXTRACCION DE MENCIONES DOCENTES CON RESOLUCION SEMESTRAL")
    print("="*70)

    start_time = time.time()
    conn = psycopg2.connect(neon_conn_str)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Contexto de auditoria
        cur.execute("SELECT set_config('app.current_user', 'nlp_menciones_scanner', true);")
        cur.execute("SELECT set_config('app.current_ip', '127.0.0.1', true);")
        cur.execute("SELECT set_config('app.current_endpoint', '/database/detectar_menciones_umsa.py', true);")

        # ---------------------------------------------------------------------
        # ---------------------------------------------------------------------
        # 1. Cargar Catálogos y Compilar Regex en Memoria
        # ---------------------------------------------------------------------
        print("\n  [1/4] Cargando docentes, materias y oferta semestral en memoria...")

        # Docentes
        cur.execute("SELECT docente_id, nombre_completo, alias_regex, materias_que_dicta FROM docentes WHERE docente_id != 'DOC_SIN_DOCENTE';")
        docentes_raw = cur.fetchall()

        # Oferta Académica Semestral
        cur.execute("""
            SELECT gestion_semestre, codigo_materia, paralelo, docente_id, horarios_texto 
            FROM oferta_academica_semestral;
        """)
        oferta_list = cur.fetchall()
        
        # Mapeo rápido: (gestion_semestre, docente_id) -> lista de ofertas asignadas
        oferta_map = {}
        docente_materias_map = {}
        for of in oferta_list:
            key = (of["gestion_semestre"], of["docente_id"])
            if key not in oferta_map:
                oferta_map[key] = []
            oferta_map[key].append(of)
            
            did = of["docente_id"]
            if did not in docente_materias_map:
                docente_materias_map[did] = set()
            docente_materias_map[did].add(of["codigo_materia"].upper())

        print(f"        {len(oferta_list)} asignaciones semestrales indexadas para resolución temporal.")

        docentes_compiled = []
        for d in docentes_raw:
            did = d["docente_id"]
            nom = d["nombre_completo"]
            pattern = d["alias_regex"]
            mats = d.get("materias_que_dicta") or ""
            
            if did not in docente_materias_map:
                docente_materias_map[did] = set()
            if mats:
                for m in mats.split(';'):
                    m_clean = m.strip().split('-')[0].strip() if '-' in m else m.strip()
                    if m_clean:
                        docente_materias_map[did].add(m_clean.upper())

            if pattern and pattern.strip():
                try:
                    compiled = re.compile(pattern, re.IGNORECASE)
                    partes = nom.upper().split()
                    paterno = partes[-2] if len(partes) >= 2 else partes[0]
                    materno = partes[-1] if len(partes) >= 2 else ""
                    nombres = partes[:-2] if len(partes) > 2 else [partes[0]]

                    docentes_compiled.append({
                        "docente_id": did,
                        "nombre_completo": nom,
                        "paterno": paterno,
                        "materno": materno,
                        "nombres": nombres,
                        "regex": compiled,
                        "materias": docente_materias_map[did]
                    })
                except Exception as ex:
                    print(f"      [WARN] Regex invalida para docente {did}: {ex}")

        print(f"        {len(docentes_compiled)} expresiones regulares de docentes compiladas.")

        # Materias
        cur.execute("SELECT codigo_materia, nombre_materia, alias_regex FROM materias;")
        materias_raw = cur.fetchall()
        materias_compiled = []
        for m in materias_raw:
            pattern = m["alias_regex"]
            if pattern and pattern.strip():
                try:
                    compiled = re.compile(pattern, re.IGNORECASE)
                    materias_compiled.append((m["codigo_materia"], m["nombre_materia"], compiled))
                except Exception as ex:
                    print(f"      [WARN] Regex invalida para materia {m['codigo_materia']}: {ex}")

        print(f"        {len(materias_compiled)} expresiones regulares de materias compiladas.")

        # Diccionario léxico de materias clave para desambiguación contextual
        KEYWORDS_MATERIA = {
            'base de datos': ['INF-132', 'INF-244', 'INF-252', 'COM-322', 'DAT-251'],
            'base de datos i': ['INF-132'],
            'base de datos ii': ['INF-244', 'INF-252', 'COM-322'],
            'bd': ['INF-132', 'INF-244', 'INF-252', 'COM-322'],
            'bd1': ['INF-132'],
            'bd2': ['INF-244', 'INF-252', 'COM-322'],
            'diseño': ['INF-246'],
            'animacion': ['INF-246'],
            'diseño y animacion': ['INF-246'],
            'multimedia': ['INF-246'],
            'programacion i': ['INF-111'],
            'programacion ii': ['INF-121'],
            'programacion iii': ['INF-131'],
            'progra 1': ['INF-111'],
            'progra 2': ['INF-121'],
            'progra 3': ['INF-131'],
            'progra': ['INF-111', 'INF-121', 'INF-131'],
            'java': ['INF-111', 'INF-121'],
            'criptografia': ['COM-253', 'SEG-246', 'SEG-254'],
            'cripto': ['COM-253', 'SEG-246', 'SEG-254'],
            'seguridad': ['INF-265', 'SEG-244', 'SEG-262', 'DAT-321'],
            'software': ['INF-261', 'INF-382'],
            'ingenieria de software': ['INF-261', 'INF-382'],
            'inteligencia artificial': ['COM-252', 'DAT-245', 'INF-335', 'INF-372'],
            'ia': ['COM-252', 'DAT-245', 'INF-335', 'INF-372'],
            'computacion paralela': ['COM-263'],
            'algebra': ['INF-114', 'INF-125'],
            'calculo': ['INF-115', 'DAT-135', 'INF-247', 'INF-321'],
            'estadistica': ['INF-124', 'INF-134', 'DAT-246'],
            'redes': ['INF-242', 'INF-333', 'SEG-252', 'TIC-254', 'TIC-247'],
            'fisica': ['INF-116'],
            'sistemas operativos': ['INF-241', 'COM-251'],
            'taller de proyecto': ['INF-266'],
            'taller de graduacion': ['INF-384'],
        }

        # ---------------------------------------------------------------------
        # 2. Leer Mensajes del Corpus
        # ---------------------------------------------------------------------
        print("\n  [2/4] Leyendo mensajes del corpus de Telegram...")
        cur.execute("""
            SELECT 
                message_id, 
                text_original, 
                text_norm, 
                timestamp_local, 
                dominant_emotion, 
                polarity_label, 
                polarity
            FROM mensajes
            WHERE text_original IS NOT NULL AND length(text_original) >= 5
            ORDER BY timestamp_local ASC;
        """)
        mensajes = cur.fetchall()
        print(f"        {len(mensajes)} mensajes aptos cargados para análisis.")

        # ---------------------------------------------------------------------
        # 3. Escaneo y Extracción con Resolución Semestral y Desambiguación
        # ---------------------------------------------------------------------
        print("\n  [3/4] Escaneando menciones docentes con desambiguación contextual por materia...")
        menciones_to_insert = []
        docentes_mencionados_set = set()
        distribucion_semestral = {}

        for msg in mensajes:
            mid = msg["message_id"]
            text_orig = msg["text_original"]
            text_norm = msg["text_norm"] or ""
            search_text = f"{text_orig} {text_norm}"
            search_lower = search_text.lower()
            
            ts = msg["timestamp_local"]
            if ts:
                sem_str = "I" if ts.month <= 6 else "II"
                gestion = f"{ts.year}-{sem_str}"
            else:
                gestion = "2024-I"

            # 3.1. Detectar materias presentes en el mensaje
            materias_en_mensaje = []
            for cod_mat, nom_mat, mat_rx in materias_compiled:
                if mat_rx.search(search_text):
                    materias_en_mensaje.append((cod_mat, nom_mat))

            # Códigos sugeridos por keywords léxicos
            cods_por_keyword = set()
            for kw, cods in KEYWORDS_MATERIA.items():
                if re.search(rf"\b{re.escape(kw)}\b", search_lower):
                    for c in cods:
                        cods_por_keyword.add(c)

            # 3.2. Encontrar docentes candidatos y calcular score de certeza
            candidatos = []
            for doc in docentes_compiled:
                if doc["regex"].search(search_text):
                    score = 10  # Base match por regex
                    
                    # Bonus si el mensaje incluye el nombre de pila
                    for nom in doc["nombres"]:
                        if len(nom) >= 3 and re.search(rf"\b{re.escape(nom.lower())}\b", search_lower):
                            score += 80
                            break

                    # Bonus si incluye el segundo apellido
                    if doc["materno"] and len(doc["materno"]) >= 3 and re.search(rf"\b{re.escape(doc['materno'].lower())}\b", search_lower):
                        score += 50

                    # Bonus si el mensaje menciona una materia dictada por este docente
                    codigos_docente = doc["materias"]
                    for cod_m, _ in materias_en_mensaje:
                        if any(cod_m.upper() in d_mat for d_mat in codigos_docente):
                            score += 70

                    for cod_kw in cods_por_keyword:
                        if any(cod_kw in d_mat for d_mat in codigos_docente):
                            score += 45

                    # Bonus si está activo en la oferta académica de esta gestión específica
                    if (gestion, doc["docente_id"]) in oferta_map:
                        score += 15

                    candidatos.append((doc, score))

            if not candidatos:
                continue

            # 3.3. Desambiguación de homónimos (agrupación por apellido paterno)
            # Evita que 'lic Zeballos', 'lic Huanca' o 'lic Silva' inserte filas duplicadas
            from collections import defaultdict
            candidatos_por_paterno = defaultdict(list)
            for doc, score in candidatos:
                candidatos_por_paterno[doc["paterno"]].append((doc, score))

            docentes_ganadores = []
            for pat, grupo in candidatos_por_paterno.items():
                # El docente con mayor score contextual gana la mención
                grupo.sort(key=lambda x: x[1], reverse=True)
                ganador, gan_score = grupo[0]
                docentes_ganadores.append((ganador, gan_score))

            # 3.4. Atribución final de materia y paralelo
            for doc, score in docentes_ganadores:
                doc_id = doc["docente_id"]
                nom_doc = doc["nombre_completo"]
                docentes_mencionados_set.add(doc_id)
                distribucion_semestral[gestion] = distribucion_semestral.get(gestion, 0) + 1

                materias_dictadas_semestre = oferta_map.get((gestion, doc_id), [])
                cod_materia_final = None
                nom_materia_final = None
                paralelo_final = None

                # Prioridad 1: Materia explícita del mensaje que el docente dicta en ese semestre
                if materias_en_mensaje and materias_dictadas_semestre:
                    for cod_m, nom_m in materias_en_mensaje:
                        for of in materias_dictadas_semestre:
                            if of["codigo_materia"] == cod_m:
                                cod_materia_final = cod_m
                                nom_materia_final = nom_m
                                paralelo_final = of["paralelo"]
                                break
                        if cod_materia_final:
                            break

                # Prioridad 2: Materia detectada por keywords que el docente dicta
                if not cod_materia_final and cods_por_keyword:
                    for cod_kw in cods_por_keyword:
                        for of in materias_dictadas_semestre:
                            if of["codigo_materia"] == cod_kw:
                                cod_materia_final = cod_kw
                                nom_materia_final = of.get("nombre_materia") or cod_kw
                                paralelo_final = of["paralelo"]
                                break
                        if cod_materia_final:
                            break

                # Prioridad 3: Materia general mencionada en el mensaje
                if not cod_materia_final and materias_en_mensaje:
                    cod_materia_final = materias_en_mensaje[0][0]
                    nom_materia_final = materias_en_mensaje[0][1]

                # Prioridad 4: Atribuir materia semestral asignada al docente
                if not cod_materia_final and materias_dictadas_semestre:
                    cod_materia_final = materias_dictadas_semestre[0]["codigo_materia"]
                    paralelo_final = materias_dictadas_semestre[0]["paralelo"]
                    # Buscar nombre de la materia si es posible
                    for cod_m, nom_m, _ in materias_compiled:
                        if cod_m == cod_materia_final:
                            nom_materia_final = nom_m
                            break

                # Fallback nombre de materia si se tiene código
                if cod_materia_final and not nom_materia_final:
                    for cod_m, nom_m, _ in materias_compiled:
                        if cod_m == cod_materia_final:
                            nom_materia_final = nom_m
                            break

                menciones_to_insert.append((
                    mid,
                    gestion,
                    paralelo_final,
                    doc_id,
                    nom_doc,
                    cod_materia_final,
                    nom_materia_final,
                    ts,
                    "Estudiante UMSA",
                    text_orig[:500],
                    msg["polarity_label"] or "neutral",
                    float(msg["polarity"] or 0.0),
                    msg["dominant_emotion"] or "neutral"
                ))

        print(f"        Total de menciones identificadas: {len(menciones_to_insert)}")
        print(f"        Docentes únicos referenciados: {len(docentes_mencionados_set)}")
        print("        Distribución por semestre detectada:")
        for g, count in sorted(distribucion_semestral.items()):
            print(f"          - {g}: {count} menciones")

        # ---------------------------------------------------------------------
        # 4. Inserción Masiva en 'menciones_docentes'
        # ---------------------------------------------------------------------
        print("\n  [4/4] Limpiando e insertando menciones en 'menciones_docentes'...")
        cur.execute("TRUNCATE TABLE menciones_docentes RESTART IDENTITY CASCADE;")

        sql_insert_menc = """
        INSERT INTO menciones_docentes (
            mensaje_id, gestion_semestre, paralelo,
            docente_id, docente_mencionado,
            codigo_materia, materia_mencionada,
            fecha, usuario_nombre, texto_limpio,
            sentimiento_propio, sentimiento_score, emocion_propia
        ) VALUES %s;
        """
        execute_values(cur, sql_insert_menc, menciones_to_insert, page_size=500)
        conn.commit()
        print(f"        {len(menciones_to_insert)} registros guardados en 'menciones_docentes'.")

        # ---------------------------------------------------------------------
        # 5. Auditoría Formal en bitacora_procesos_mineria
        # ---------------------------------------------------------------------
        duracion_ms = int((time.time() - start_time) * 1000)
        metricas = {
            "total_menciones": len(menciones_to_insert),
            "docentes_unicos": len(docentes_mencionados_set),
            "distribucion_semestral": distribucion_semestral
        }

        cur.execute("""
        INSERT INTO bitacora_procesos_mineria (
            nombre_pipeline, fase, estado, metricas_json, duracion_ms
        ) VALUES (
            'detectar_menciones_umsa.py', 
            'EXTRACCION_MENCIONES_DOCENTES_SEMESTRAL', 
            'EXITOSO', 
            %s::jsonb, 
            %s
        );
        """, (psycopg2.extras.Json(metricas), duracion_ms))
        conn.commit()
        print("        Evento formal registrado en 'bitacora_procesos_mineria'.")

        print("\n" + "="*70)
        print("  DETECCION Y POBLADO DE MENCIONES COMPLETADO CON EXITO")
        print("="*70 + "\n")

    except Exception as e:
        conn.rollback()
        print(f"\n  [ERROR] Fallo en la deteccion de menciones: {e}")
        raise
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    run_detection()
