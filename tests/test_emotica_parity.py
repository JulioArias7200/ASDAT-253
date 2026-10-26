# -*- coding: utf-8 -*-
"""
Suite de pruebas de paridad para app.core.emotica.
Traduce y valida 1:1 los casos de prueba de emotica/tests/testthat/
(test-engine.R, test-preprocess.R, test-eval-topics.R).
"""

import os
import re
import json
import tempfile
from pathlib import Path
import pytest
import pandas as pd
import numpy as np

from app.core.emotica import (
    preprocess_chat,
    score_emotions,
    cargar_taxonomia,
    cargar_lexicon,
    validar_lexicon,
    add_emotion,
    set_active,
    suggest_terms,
    normalizar_texto,
    asignar_periodo,
    evaluar_motor,
    acuerdo_etiquetadores,
    muestra_para_etiquetar,
    correlacion_intensidad,
    agrupar_documentos,
    matriz_doc_term,
    ajustar_temas,
    terminos_por_tema,
    temas_por_periodo
)
from app.core.emotica.tokens import tokenizar_mensajes, filtrar_tokens

def mk(textos):
    df = pd.DataFrame({
        "msg_id": [str(i + 1) for i in range(len(textos))],
        "texto": textos
    })
    df["texto_limpio"] = [normalizar_texto(t) for t in textos]
    df["idioma"] = "es"
    return df

def pt(texto, emocion):
    s = score_emotions(mk([texto]))
    sub = s[s["emocion_id"] == emocion]
    return float(sub["puntaje"].iloc[0]) if len(sub) > 0 else 0.0


# -----------------------------------------------------------------------------
# 1. Pruebas del Motor de Emociones (Paridad con test-engine.R)
# -----------------------------------------------------------------------------

def test_lexico_valido_15_emociones():
    tax = cargar_taxonomia()
    lex = cargar_lexicon("es")
    prob = validar_lexicon(lex, tax)
    assert len(prob) == 0, f"Problemas encontrados en el léxico: {prob}"
    assert len(tax) == 15, "La taxonomía debe tener exactamente 15 emociones base"
    conteos = lex["emocion_id"].value_counts()
    assert (conteos >= 8).all(), "Cada una de las 15 emociones debe tener al menos 8 términos"

def test_pesos_modificadores_signos_mayusculas():
    # Intensificadores, signos y mayúsculas deben aumentar puntaje; atenuadores reducir
    p_base = pt("estoy feliz", "alegria")
    p_muy = pt("estoy muy feliz", "alegria")
    p_signos = pt("estoy feliz!!!", "alegria")
    p_mayus = pt("ESTOY MUY FELIZ", "alegria")
    p_poco = pt("estoy poco feliz", "alegria")

    assert p_muy > p_base, "muy feliz debe superar a feliz"
    assert p_signos > p_base, "feliz!!! debe superar a feliz"
    assert p_mayus > p_muy, "ESTOY MUY FELIZ debe superar a estoy muy feliz"
    assert p_poco < p_base, "estoy poco feliz debe ser menor a feliz"

def test_significado_frases_y_contexto():
    # 'aprobe con 85' != 'aprobe raspando' != 'no aprobe'
    s = score_emotions(mk(["aprobé con 85", "aprobé raspando", "no aprobé"]))
    def g(msg_id, emo):
        sub = s[(s["msg_id"] == msg_id) & (s["emocion_id"] == emo)]
        return float(sub["puntaje"].iloc[0]) if len(sub) > 0 else 0.0

    assert g("1", "alegria") > g("2", "alegria")
    assert g("2", "tranquilidad") > g("2", "alegria")
    assert g("3", "alegria") == 0.0, "no aprobé no debe puntuar alegría"
    assert g("3", "decepcion") > 0.0, "no aprobé debe puntuar decepción"

def test_negacion_traspaso_a_emocion_opuesta():
    # 'no estoy tranquila' no debe sumar a tranquilidad, sino a preocupacion con evidencia NEG
    s = score_emotions(mk(["no estoy tranquila"]))
    emos = set(s["emocion_id"].tolist())
    assert "tranquilidad" not in emos, "no estoy tranquila no debe puntuar tranquilidad"
    assert "preocupacion" in emos, "debe transferir a preocupacion (su opuesta)"
    evid = s[s["emocion_id"] == "preocupacion"]["evidencia"].iloc[0]
    assert "NEG" in evid, "La evidencia debe contener el marcador NEG"

def test_dinamico_active_limita_evaluacion():
    m = mk(["estoy feliz pero triste", "gracias"])
    s = score_emotions(m, active=["alegria", "tristeza"])
    assert set(s["emocion_id"].unique()) == {"alegria", "tristeza"}
    
    tax_g = set_active(cargar_taxonomia(), ["gratitud"])
    s2 = score_emotions(m, taxonomy=tax_g)
    assert set(s2["emocion_id"].unique()) == {"gratitud"}

def test_dinamico_emocion_nueva_sin_tocar_codigo():
    m = mk(["qué nostalgia de esos tiempos, extraño la época", "hola"])
    assert "nostalgia" not in score_emotions(m)["emocion_id"].values
    
    r = add_emotion(
        id_emo="nostalgia",
        nombre="Nostalgia",
        valencia="ambigua",
        semillas={
            "nostalgia": 1.5,
            "extraño la época": 1.2,
            "recuerdos": 1.0,
            "viejos tiempos": 1.0,
            "añoro": 1.2,
            "tiempos pasados": 1.0
        },
        emojis=["🕰️"],
        persistir=False
    )
    assert "nostalgia" in r["taxonomy"]["id"].values
    s = score_emotions(m, taxonomy=r["taxonomy"], lexicon=pd.concat([cargar_lexicon("es"), r["lexicon_nuevo"]]))
    assert "nostalgia" in s["emocion_id"].values

def test_dinamico_codigo_python_no_menciona_emociones_por_nombre():
    """Verifica que el código del motor no tenga emociones hardcodeadas."""
    ids = cargar_taxonomia()["id"].tolist()
    core_path = Path(__file__).resolve().parent.parent / "app" / "core" / "emotica"
    
    for f in core_path.glob("*.py"):
        if f.name in ["__init__.py", "evaluation.py", "taxonomy.py"]:
            continue
        with open(f, "r", encoding="utf-8") as archivo:
            for n_line, linea in enumerate(archivo, start=1):
                clean_l = linea.split("#")[0] # ignorar comentarios
                for emo_id in ids:
                    assert not re.search(rf"\b{emo_id}\b", clean_l), (
                        f"Violación de diseño dinámico: emoción '{emo_id}' encontrada en {f.name}:{n_line}"
                    )

def test_contexto_pregunta_esperanza():
    s = score_emotions(mk(["se puede lograr con esfuerzo", "¿se puede inscribir hoy?"]))
    assert "1" in s[s["emocion_id"] == "esperanza"]["msg_id"].values
    assert "2" not in s[s["emocion_id"] == "esperanza"]["msg_id"].values


# -----------------------------------------------------------------------------
# 2. Pruebas de Preprocesamiento y Privacidad (Paridad con test-preprocess.R)
# -----------------------------------------------------------------------------

def telegram_mini_file():
    contenido = {
        "name": "chat_test",
        "messages": [
            {"id": 1, "type": "service", "date": "2024-05-02T10:00:00", "text": "", "actor": "Ana", "action": "join"},
            {"id": 2, "type": "message", "date": "2023-12-20T10:00:00", "from": "Ana Perez", "from_id": "user1",
             "text": "No estoy nada tranquila, llamame al 70123456 o a ana@correo.com https://x.com"},
            {"id": 3, "type": "message", "date": "2024-02-29T08:00:00", "from": "Luis", "from_id": "user2",
             "reply_to_message_id": 2, "text": [{"type": "link", "text": "https://a.b"}, " holaaaa muy feliz 😊?"]},
            {"id": 4, "type": "message", "date": "2024-03-15T08:00:00", "from": "Luis", "from_id": "user2",
             "text": "fuera de temporada gracias"},
            {"id": 5, "type": "message", "date": "2024-05-01T08:00:00", "from": "Ana Perez", "from_id": "user1",
             "text": "inicio del invierno, la verdad no me gusta"}
        ]
    }
    tmp = tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode="w", encoding="utf-8")
    json.dump(contenido, tmp)
    tmp.close()
    return tmp.name

def test_pipeline_preprocess_telegram_completo():
    sal = "sal-de-prueba"
    f_path = telegram_mini_file()
    try:
        r = preprocess_chat(f_path, sal=sal)
        m = r["mensajes"]
        
        # Columnas canónicas
        for c in ["msg_id", "fecha", "autor_hash", "texto", "texto_limpio", "idioma", "responde_a", "periodo_id"]:
            assert c in m.columns
            
        # Filtró el evento de servicio (quedan 4)
        assert len(m) == 4
        
        # Anonimización: sin nombres originales
        assert "autor" not in m.columns and "autor_id" not in m.columns
        texto_unificado = " ".join(m["texto"].tolist())
        assert "Ana" not in texto_unificado and "Luis" not in texto_unificado and "Perez" not in texto_unificado
        assert m["autor_hash"].nunique() == 2
        
        # PII enmascarada
        assert "70123456" not in texto_unificado
        assert "ana@correo.com" not in texto_unificado
        assert "https://" not in texto_unificado
        assert "<NUM_ID>" in m["texto"].iloc[0] and "<EMAIL>" in m["texto"].iloc[0]
        
        # Periodos y bisiesto (29 de febrero)
        assert list(m["periodo_id"].values) == ["verano_2024", "verano_2024", "fuera", "invierno_2024"]
        
        # Tokenización: modificadores sobreviven
        tk = filtrar_tokens(r["tokens"])
        tokens_set = set(tk["token"].tolist())
        assert "no" in tokens_set and "muy" in tokens_set and "nada" in tokens_set
        assert "de" not in tokens_set
        assert "😊" in tokens_set
        
        # Bitácora registrada
        b = r["bitacora"]
        pasos = set(b["paso"].tolist())
        for p in ["lectura_archivo", "normalizar_fechas", "anonimizar_autores", "enmascarar_pii", "asignar_periodos", "tokenizar"]:
            assert p in pasos
    finally:
        if os.path.exists(f_path):
            os.remove(f_path)


# -----------------------------------------------------------------------------
# 3. Pruebas de Tópicos y Evaluación (Paridad con test-eval-topics.R)
# -----------------------------------------------------------------------------

def test_evaluacion_kappa_y_muestra():
    m = pd.DataFrame({
        "msg_id": [str(i) for i in range(1, 7)],
        "texto": [
            "feliz hoy dia", "estoy muy triste hoy", "gracias por todo amigos",
            "nada que decir aqui hoy", "estoy cansado de todo esto", "no entiendo nada de esto"
        ]
    })
    m["texto_limpio"] = [normalizar_texto(t) for t in m["texto"]]
    m["idioma"] = "es"
    m["n_palabras"] = 5
    
    s = score_emotions(m)
    hoja = pd.DataFrame({
        "msg_id": m["msg_id"],
        "emociones": ["alegria", "tristeza", "gratitud", "ninguna", "cansancio", "preocupacion"],
        "intensidad": ["3", "4", "3", "", "3", "2"]
    })
    
    ev = evaluar_motor(s, hoja)
    assert ev["n_mensajes"] == 6
    assert ev["global"]["precision"] <= 1.0
    
    ms = muestra_para_etiquetar(m, s, n=4, min_palabras=3)
    assert len(ms["hoja"]) == 4
    assert "emocion_dominante_motor" not in ms["hoja"].columns

def test_topicos_nmf_y_periodo():
    a = ["horario", "aula", "clase", "docente", "materia"]
    b = ["pago", "banco", "deposito", "comprobante", "factura"]
    dias = [f"2024-06-{i:02d}" for i in range(1, 21)]
    
    filas = []
    for i, dia in enumerate(dias):
        vocab_base = a if (i % 2 == 0) else b
        for j in range(6):
            sample_words = np.random.choice(vocab_base, 4, replace=True)
            filas.append({
                "msg_id": f"{i}_{j}",
                "fecha": dia,
                "periodo_id": "invierno_2024",
                "texto_limpio": " ".join(sample_words),
                "idioma": "es",
                "temporada": "invierno",
                "tiene_texto": True
            })
    df_msgs = pd.DataFrame(filas)
    tok = tokenizar_mensajes(df_msgs, idioma="es")
    tk = agrupar_documentos(tok, df_msgs, por="dia", min_tokens=5)
    dt = matriz_doc_term(tk, min_docs=2)
    mo = ajustar_temas(dt["dtm"], k=2, metodo="nmf", max_iter=150)
    tt = terminos_por_tema(mo, n=5)
    
    assert len(tt) == 10
    assert len(mo["theta"]) > 0
    prop_periodo = temas_por_periodo(mo, dt["periodo"])
    assert len(prop_periodo) == 1
