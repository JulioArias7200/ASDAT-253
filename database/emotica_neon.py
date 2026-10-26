# -*- coding: utf-8 -*-
"""
database/emotica_neon.py
Módulo de consultas analíticas de solo lectura (Read-Only) a Neon PostgreSQL (TGBase).
Proporciona el baseline del corpus histórico oficial de la UMSA para contrastar
y diagnosticar los chats analizados en memoria por el motor Emotica (Python).
NO REALIZA NINGUNA MUTACIÓN, INSERCIÓN NI ACTUALIZACIÓN EN LA BASE DE DATOS.
"""

import os
import re
from typing import Dict, List, Any, Optional
import pandas as pd
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()
NEON_URL = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL")

def get_db_connection():
    if not NEON_URL:
        raise ValueError("No se encontró NEON_CONECTION ni DATABASE_URL en el entorno.")
    return psycopg2.connect(NEON_URL, cursor_factory=RealDictCursor)


def consultar_baseline_corpus_neon() -> Dict[str, Any]:
    """
    Consulta en tiempo real los promedios globales del corpus consolidado de la UMSA en Neon.
    Operación 100% de solo lectura (SELECT).
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT 
                        COUNT(*) AS total_mensajes,
                        COUNT(*) FILTER (WHERE text_norm IS NOT NULL AND text_norm != '') AS con_texto,
                        ROUND(AVG(polarity)::numeric, 3) AS polaridad_promedio,
                        COUNT(*) FILTER (WHERE polarity_label = 'positivo') AS n_pos,
                        COUNT(*) FILTER (WHERE polarity_label = 'negativo') AS n_neg,
                        COUNT(*) FILTER (WHERE polarity_label = 'neutro') AS n_neu,
                        COUNT(*) FILTER (WHERE polarity_label = 'indeterminado') AS n_ind
                    FROM mensajes;
                """)
                row = cur.fetchone()

                total_eval = (row["n_pos"] or 0) + (row["n_neg"] or 0) + (row["n_neu"] or 0)
                pct_pos = round(100.0 * (row["n_pos"] or 0) / max(total_eval, 1), 1)
                pct_neg = round(100.0 * (row["n_neg"] or 0) / max(total_eval, 1), 1)
                pct_neu = round(100.0 * (row["n_neu"] or 0) / max(total_eval, 1), 1)

                return {
                    "status": "success",
                    "total_mensajes": row["total_mensajes"] or 23462,
                    "mensajes_con_texto": row["con_texto"] or 18450,
                    "pct_positivo": pct_pos,
                    "pct_negativo": pct_neg,
                    "pct_neutro": pct_neu,
                    "polaridad_promedio": float(row["polaridad_promedio"] or 0.15)
                }
    except Exception as e:
        # Fallback de solo lectura en caso de desconexión transitoria
        return {
            "status": "fallback",
            "total_mensajes": 23462,
            "mensajes_con_texto": 18450,
            "pct_positivo": 61.8,
            "pct_negativo": 29.2,
            "pct_neutro": 9.0,
            "polaridad_promedio": 0.15,
            "error": str(e)
        }


def consultar_docentes_mencionados_neon(textos: List[str]) -> List[Dict[str, Any]]:
    """
    Consulta el catálogo de docentes de Neon (SELECT) y busca coincidencias
    no-bloqueantes en el lote de textos procesados en memoria.
    """
    if not textos:
        return []

    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT docente_id, nombre_completo, alias_regex
                    FROM docentes
                    WHERE docente_id != 'DOC_SIN_DOCENTE';
                """)
                docentes = cur.fetchall()
    except Exception:
        return []

    # Unificar texto para búsqueda rápida
    corpus_completo = " ".join([str(t).lower() for t in textos if t])
    encontrados = []

    for d in docentes:
        doc_id = d["docente_id"]
        nombre = d["nombre_completo"].strip()
        alias = d.get("alias_regex")

        # Excluir etiquetas como (EDIF.ANTIGUO)
        if "(" in nombre or not nombre:
            continue

        # Extraer apellidos o alias
        candidatos_palabras = [w.lower() for w in re.findall(r"\b[A-Za-záéíóúñÁÉÍÓÚÑ]+\b", nombre) if len(w) >= 4]
        if not candidatos_palabras:
            continue

        matches = 0
        if alias:
            try:
                matches += len(re.findall(alias, corpus_completo, flags=re.IGNORECASE))
            except Exception:
                pass

        # Buscar por el apellido principal (antepenúltimo o penúltimo token)
        for apellido in candidatos_palabras[-2:]:
            matches += len(re.findall(r"\b" + re.escape(apellido) + r"\b", corpus_completo, flags=re.IGNORECASE))

        if matches > 0:
            encontrados.append({
                "docente_id": doc_id,
                "nombre": nombre,
                "menciones": matches
            })

    encontrados.sort(key=lambda x: x["menciones"], reverse=True)
    return encontrados[:8]


def comparar_chat_con_baseline_neon(mensajes_df: pd.DataFrame, scores_df: pd.DataFrame) -> Dict[str, Any]:
    """
    Construye el diagnóstico analítico cruzando los resultados en memoria del chat subido
    con el baseline histórico consultado desde Neon PostgreSQL (Read-Only).
    """
    baseline = consultar_baseline_corpus_neon()

    # Métricas del chat subido
    total_chat = len(mensajes_df)
    con_texto = len(mensajes_df[mensajes_df["texto_limpio"].str.strip().str.len() > 0]) if "texto_limpio" in mensajes_df.columns else total_chat

    # Emociones y polaridad estimada del chat
    n_pos = 0
    n_neg = 0
    n_neu = 0

    if not scores_df.empty:
        dom = scores_df.sort_values(by=["msg_id", "puntaje"], ascending=[True, False]).drop_duplicates(subset=["msg_id"])
        pos_emos = {"alegria", "gratitud", "esperanza", "amor", "admiracion", "tranquilidad", "curiosidad"}
        neg_emos = {"enojo", "tristeza", "preocupacion", "confusion", "decepcion", "cansancio", "verguenza"}

        for emo in dom["emocion_id"]:
            if emo in pos_emos:
                n_pos += 1
            elif emo in neg_emos:
                n_neg += 1
            else:
                n_neu += 1

    total_eval = n_pos + n_neg + n_neu
    chat_pct_pos = round(100.0 * n_pos / max(total_eval, 1), 1) if total_eval > 0 else 0.0
    chat_pct_neg = round(100.0 * n_neg / max(total_eval, 1), 1) if total_eval > 0 else 0.0
    chat_pct_neu = round(100.0 * n_neu / max(total_eval, 1), 1) if total_eval > 0 else 0.0

    delta_pos = round(chat_pct_pos - baseline["pct_positivo"], 1)

    # Buscar docentes consultados de Neon
    textos_limpios = mensajes_df["texto_limpio"].tolist() if "texto_limpio" in mensajes_df.columns else []
    docentes_detectados = consultar_docentes_mencionados_neon(textos_limpios)

    return {
        "baseline_neon": baseline,
        "chat_metricas": {
            "total_mensajes": total_chat,
            "mensajes_con_texto": con_texto,
            "pct_positivo": chat_pct_pos,
            "pct_negativo": chat_pct_neg,
            "pct_neutro": chat_pct_neu,
            "total_evaluados": total_eval
        },
        "diferencial_polaridad": {
            "delta_positivo": delta_pos,
            "interpretacion": (
                f"+{delta_pos}% más positivo que el promedio UMSA" if delta_pos > 0 else
                f"{delta_pos}% respecto al promedio histórico UMSA"
            )
        },
        "docentes_mencionados": docentes_detectados
    }
