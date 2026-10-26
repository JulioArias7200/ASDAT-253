# -*- coding: utf-8 -*-
"""
Módulo de gestión de taxonomía emocional y léxicos dinámicos.
Garantiza paridad estricta con emotica/R/taxonomy.R (100% dinámico, cero hardcoding).
"""

import math
import re
from pathlib import Path
import json
from typing import Dict, List, Optional, Any, Union
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_yaml, normalizar_clave
from app.core.emotica.clean import cargar_stopwords

def cargar_taxonomia(path: Optional[Union[str, Path]] = None) -> pd.DataFrame:
    """Carga la taxonomía declarativa desde resources/taxonomy/emotions.json (o .yml)."""
    p = Path(path) if path else ruta_recurso("resources", "taxonomy", "emotions.yml")
    datos = leer_yaml(p)
    
    filas = []
    for item in datos:
        filas.append({
            "id": str(item.get("id", "")).strip(),
            "nombre": str(item.get("nombre", item.get("id", ""))).strip(),
            "valencia": str(item.get("valencia", "ambigua")).strip(),
            "activacion": str(item.get("activacion", "media")).strip(),
            "opuesta": str(item["opuesta"]).strip() if item.get("opuesta") else None,
            "activa": bool(item.get("activa", True))
        })
    return pd.DataFrame(filas)

def guardar_taxonomia(tax: pd.DataFrame, path: Optional[Union[str, Path]] = None) -> None:
    """Guarda la taxonomía en formato JSON nativo y YAML opcional si está instalado."""
    p = Path(path) if path else ruta_recurso("resources", "taxonomy", "emotions.yml")
    lista = []
    for _, r in tax.iterrows():
        elem = {
            "id": r["id"],
            "nombre": r["nombre"],
            "valencia": r["valencia"],
            "activacion": r["activacion"],
            "activa": bool(r["activa"])
        }
        if pd.notna(r.get("opuesta")) and r.get("opuesta"):
            elem["opuesta"] = r["opuesta"]
        lista.append(elem)
        
    p_json = p.with_suffix(".json")
    with open(p_json, "w", encoding="utf-8") as f:
        json.dump(lista, f, ensure_ascii=False, indent=2)
        
    try:
        import yaml
        with open(p, "w", encoding="utf-8") as f:
            yaml.safe_dump(lista, f, allow_unicode=True, sort_keys=False)
    except ImportError:
        pass

def cargar_lexicon(idioma: str = "es") -> pd.DataFrame:
    """Carga todos los archivos CSV de léxicos en resources/lexicons/<idioma>/."""
    dir_lex = ruta_recurso("resources", "lexicons", idioma)
    vacio = pd.DataFrame(columns=["termino", "emocion_id", "peso", "tipo", "fuente", "contexto", "clave"])
    if not dir_lex.exists() or not dir_lex.is_dir():
        return vacio
        
    dfs = []
    for f in dir_lex.glob("*.csv"):
        try:
            d = pd.read_csv(f, dtype=str, encoding="utf-8").fillna("")
            if "fuente" not in d.columns:
                d["fuente"] = f.name
            if "contexto" not in d.columns:
                d["contexto"] = ""
            dfs.append(d[["termino", "emocion_id", "peso", "tipo", "fuente", "contexto"]])
        except Exception:
            pass
            
    if not dfs:
        return vacio
        
    lex = pd.concat(dfs, ignore_index=True)
    lex["peso"] = pd.to_numeric(lex["peso"], errors="coerce").fillna(1.0)
    lex["clave"] = normalizar_clave(lex["termino"].tolist())
    return lex

def validar_lexicon(lex: pd.DataFrame, tax: pd.DataFrame) -> pd.DataFrame:
    """Valida integridad del léxico contra la taxonomía."""
    problemas = []
    tax_ids = set(tax["id"].tolist())
    
    for idx, r in lex.iterrows():
        t = r["termino"]
        emo = r["emocion_id"]
        if emo not in tax_ids:
            problemas.append({"problema": "emocion_id no existe en la taxonomia", "termino": t, "emocion_id": emo})
        if r["peso"] <= 0 or r["peso"] > 3:
            problemas.append({"problema": "peso fuera de (0, 3]", "termino": t, "emocion_id": emo})
        if r["tipo"] not in ["palabra", "frase", "regex", "emoji"]:
            problemas.append({"problema": "tipo invalido", "termino": t, "emocion_id": emo})
            
    # Chequeo de duplicados
    dup_mask = lex.duplicated(subset=["clave", "emocion_id"])
    for _, r in lex[dup_mask].iterrows():
        problemas.append({"problema": "duplicado (termino + emocion)", "termino": r["termino"], "emocion_id": r["emocion_id"]})
        
    return pd.DataFrame(problemas)

def set_active(tax: pd.DataFrame, ids: List[str]) -> pd.DataFrame:
    """Activa o desactiva emociones según la lista de IDs provista."""
    tax = tax.copy()
    tax["activa"] = tax["id"].isin(ids)
    return tax

def add_emotion(
    id_emo: str,
    nombre: str,
    valencia: str,
    semillas: Union[List[str], Dict[str, float]],
    emojis: Optional[List[str]] = None,
    activacion: str = "media",
    opuesta: Optional[str] = None,
    idioma: str = "es",
    persistir: bool = True,
    taxonomy: Optional[pd.DataFrame] = None
) -> Dict[str, Any]:
    """
    Agrega una emoción nueva dinámicamente sin tocar código.
    Valida formato de ID, suficiencia de semillas (mínimo 5) y posibles conflictos.
    """
    tax = taxonomy if taxonomy is not None else cargar_taxonomia()
    id_emo = id_emo.strip().lower()
    
    if not re.match(r"^[a-z][a-z0-9_]*$", id_emo):
        raise ValueError("id invalido: use minusculas, numeros y _ (ej. 'nostalgia').")
    if id_emo in tax["id"].values:
        raise ValueError(f"La emocion '{id_emo}' ya existe.")
    if valencia not in ["positiva", "negativa", "ambigua"]:
        raise ValueError("valencia debe ser positiva, negativa o ambigua.")
    if opuesta and opuesta not in tax["id"].values:
        raise ValueError(f"La emocion opuesta '{opuesta}' no existe.")
        
    if isinstance(semillas, dict):
        terminos = list(semillas.keys())
        pesos = list(semillas.values())
    else:
        terminos = list(semillas)
        pesos = [1.0] * len(terminos)
        
    if len(terminos) < 5:
        raise ValueError(f"Se necesitan al menos 5 semillas (recomendado: 8 a 15). Recibidas: {len(terminos)}")
        
    avisos = []
    if len(terminos) < 8:
        avisos.append("Pocas semillas (<8): la confianza y la cobertura seran bajas.")
        
    nuevas_filas = []
    for term, w in zip(terminos, pesos):
        tipo = "frase" if " " in term.strip() else "palabra"
        nuevas_filas.append({
            "termino": term,
            "emocion_id": id_emo,
            "peso": float(w),
            "tipo": tipo,
            "fuente": "usuario",
            "contexto": ""
        })
        
    if emojis:
        for em in emojis:
            nuevas_filas.append({
                "termino": em,
                "emocion_id": id_emo,
                "peso": 1.0,
                "tipo": "emoji",
                "fuente": "usuario",
                "contexto": ""
            })
            
    nuevo_df = pd.DataFrame(nuevas_filas)
    nuevo_df["clave"] = normalizar_clave(nuevo_df["termino"].tolist())
    
    # Conflictos con léxico existente
    lex_existente = cargar_lexicon(idioma)
    conflictos = lex_existente[lex_existente["clave"].isin(nuevo_df["clave"])]
    if len(conflictos) > 0:
        confl_terms = ", ".join(conflictos["termino"].unique())
        avisos.append(f"{len(conflictos)} semilla(s) ya pertenecen a otra emocion (conflicto): {confl_terms}")
        
    nueva_fila_tax = pd.DataFrame([{
        "id": id_emo,
        "nombre": nombre,
        "valencia": valencia,
        "activacion": activacion,
        "opuesta": opuesta,
        "activa": True
    }])
    tax2 = pd.concat([tax, nueva_fila_tax], ignore_index=True)
    
    if persistir:
        guardar_taxonomia(tax2)
        dir_lex = ruta_recurso("resources", "lexicons", idioma)
        dir_lex.mkdir(parents=True, exist_ok=True)
        nuevo_df.to_csv(dir_lex / f"usuario_{id_emo}.csv", index=False, encoding="utf-8")
        
    return {
        "taxonomy": tax2,
        "lexicon_nuevo": nuevo_df,
        "conflictos": conflictos,
        "avisos": avisos
    }

def suggest_terms(
    mensajes: pd.DataFrame,
    semillas: List[str],
    n: int = 20,
    min_total: int = 5,
    idioma: Optional[str] = None
) -> pd.DataFrame:
    """
    Propone términos candidatos que co-ocurren con las semillas mediante PMI a nivel de mensaje.
    """
    id_activo = idioma or (mensajes["idioma"].iloc[0] if "idioma" in mensajes.columns and len(mensajes) > 0 else "es")
    sw_set = set(normalizar_clave(cargar_stopwords(id_activo)))
    
    txt_clean = normalizar_clave(mensajes["texto_limpio"].fillna("").tolist())
    sem_claves = set(normalizar_clave(semillas))
    
    # Identificar mensajes que contienen al menos una semilla
    mensajes_con_semilla = []
    mensajes_todos_tokens = []
    
    for t in txt_clean:
        toks = list(dict.fromkeys(t.split()))
        mensajes_todos_tokens.append(toks)
        if any(s in toks for s in sem_claves):
            mensajes_con_semilla.append(toks)
            
    n_con = len(mensajes_con_semilla)
    n_tot = len(mensajes_todos_tokens)
    if n_con < 3:
        raise ValueError("Las semillas aparecen en menos de 3 mensajes del corpus: no hay base para sugerir.")
        
    # Frecuencias de tokens
    from collections import Counter
    conteo_total = Counter(tok for m in mensajes_todos_tokens for tok in m)
    conteo_sem = Counter(tok for m in mensajes_con_semilla for tok in m)
    
    # Calcular PMI = log( P(w, sem) / (P(w) * P(sem)) )
    p_sem = n_con / max(1, n_tot)
    candidatos = []
    
    for tok, c_sem in conteo_sem.items():
        c_tot = conteo_total.get(tok, 0)
        if c_tot < min_total or tok in sem_claves or tok in sw_set or len(tok) < 3:
            continue
        p_tok = c_tot / n_tot
        p_conjunta = c_sem / n_tot
        pmi = math.log((p_conjunta + 1e-9) / (p_tok * p_sem + 1e-9))
        candidatos.append({
            "termino": tok,
            "pmi": round(pmi, 3),
            "freq_con_semillas": c_sem,
            "freq_total": c_tot
        })
        
    df_sug = pd.DataFrame(candidatos)
    if len(df_sug) == 0:
        return pd.DataFrame(columns=["termino", "pmi", "freq_con_semillas", "freq_total"])
    return df_sug.sort_values(by="pmi", ascending=False).head(n).reset_index(drop=True)
