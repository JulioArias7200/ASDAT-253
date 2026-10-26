# -*- coding: utf-8 -*-
"""
Módulo de tokenización tabular posicional y filtrado de tokens.
Garantiza paridad con emotica/R/tokens.R preservando modificadores emocionales críticos.
"""

import re
from typing import List, Optional, Dict, Any
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_yaml
from app.core.emotica.clean import cargar_stopwords, es_emoji

def cargar_conservar_siempre() -> List[str]:
    """Carga la lista de palabras protegidas que nunca deben ser tratadas como stopwords."""
    f = ruta_recurso("config", "preprocess.yml")
    if f.exists():
        cfg = leer_yaml(f)
        params = cfg.get("params", {}) if isinstance(cfg.get("params"), dict) else cfg
        return [str(w).lower() for w in params.get("conservar_siempre", [])]
    return [
        "no", "nunca", "ni", "sin", "tampoco", "jamas", "jamás", "nada", "nadie",
        "ningun", "ningún", "ninguno", "ninguna", "pero", "muy", "mas", "más",
        "menos", "poco", "poca", "bastante", "demasiado", "tan", "casi"
    ]

def tokenizar_mensajes(
    df: pd.DataFrame,
    col: str = "texto_limpio",
    idioma: Optional[str] = None,
    conservar: Optional[List[str]] = None
) -> pd.DataFrame:
    """
    Genera la tabla larga de tokens con posición y banderas booleanas:
    msg_id, pos (1-indexed), token, periodo_id, temporada, es_stopword, es_emoji, es_numero.
    """
    if len(df) == 0:
        return pd.DataFrame(columns=[
            "msg_id", "pos", "token", "periodo_id", "temporada",
            "es_stopword", "es_emoji", "es_numero"
        ])
        
    id_activo = idioma or (df["idioma"].iloc[0] if "idioma" in df.columns and len(df) > 0 else "es")
    palabras_conservadas = set(conservar or cargar_conservar_siempre())
    sw_set = set(cargar_stopwords(id_activo)) - palabras_conservadas
    
    rows = []
    pat_num = re.compile(r"^\d+$")
    
    for _, row in df.iterrows():
        t = str(row.get(col, "") or "").strip()
        if not t:
            continue
        msg_id = str(row.get("msg_id", ""))
        periodo_id = row.get("periodo_id", None)
        temporada = row.get("temporada", None)
        
        partes = t.split()
        for pos, tok in enumerate(partes, start=1):
            rows.append({
                "msg_id": msg_id,
                "pos": pos,
                "token": tok,
                "periodo_id": periodo_id,
                "temporada": temporada,
                "es_stopword": tok in sw_set,
                "es_emoji": es_emoji(tok),
                "es_numero": bool(pat_num.match(tok))
            })
            
    return pd.DataFrame(rows)

def filtrar_tokens(
    tok: pd.DataFrame,
    quitar_stopwords: bool = True,
    quitar_numeros: bool = True,
    min_chars: int = 2
) -> pd.DataFrame:
    """Filtra la tabla de tokens para topic modeling o cálculo de frecuencias."""
    if len(tok) == 0:
        return tok.copy()
        
    keep = pd.Series(True, index=tok.index)
    if quitar_stopwords and "es_stopword" in tok.columns:
        keep = keep & (~tok["es_stopword"].astype(bool))
    if quitar_numeros and "es_numero" in tok.columns:
        keep = keep & (~tok["es_numero"].astype(bool))
        
    # Conservar si es emoji o cumple la longitud mínima
    es_em = tok["es_emoji"].astype(bool) if "es_emoji" in tok.columns else pd.Series(False, index=tok.index)
    keep = keep & (es_em | (tok["token"].str.len() >= min_chars))
    
    return tok[keep].copy()
