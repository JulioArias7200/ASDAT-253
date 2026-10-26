# -*- coding: utf-8 -*-
"""
Módulo de detección estructural de anuncios, difusiones y spam.
Garantiza paridad estricta con emotica/R/anuncios.R.
"""

import re
from typing import Dict, List, Optional, Any
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_lineas_utf8, normalizar_clave, leer_yaml

def cargar_config_preprocess() -> Dict[str, Any]:
    """Carga config/preprocess.yml si existe."""
    f = ruta_recurso("config", "preprocess.yml")
    if f.exists():
        return leer_yaml(f)
    return {
        "params": {
            "anuncios": {"umbral": 2, "min_chars": 280, "min_lineas": 4}
        }
    }

def cargar_palabras_anuncio(idioma: str = "es") -> Dict[str, List[str]]:
    """Carga términos débiles y fuertes (con prefijo '!') de resources/anuncios/<idioma>.txt."""
    f = ruta_recurso("resources", "anuncios", f"{idioma}.txt")
    if not f.exists():
        return {"debiles": [], "fuertes": []}
    
    lineas = leer_lineas_utf8(f)
    validas = [l.strip() for l in lineas if l.strip() and not l.startswith("#")]
    
    debiles = [normalizar_clave(l) for l in validas if not l.startswith("!")]
    fuertes = [normalizar_clave(l[1:]) for l in validas if l.startswith("!")]
    return {"debiles": debiles, "fuertes": fuertes}

def marcar_anuncios(df: pd.DataFrame, config: Optional[Dict[str, Any]] = None, idioma: Optional[str] = None) -> pd.DataFrame:
    """
    Evalúa características estructurales de anuncios y difusiones:
    +1 si largo >= min_chars (280)
    +1 si líneas >= min_lineas (4)
    +1 si tiene <URL> y >= 6 palabras
    +1 si tiene >= 4 emojis
    +1 si tiene >= 2 menciones <USUARIO>
    +1 por palabra débil de anuncio (máximo 2)
    +3 si contiene palabra fuerte ('!palabra') = spam inmediato
    Marca df['es_anuncio'] = puntaje >= umbral (2).
    """
    df = df.copy()
    if config is None:
        config = cargar_config_preprocess()
        
    p_anuncios = config.get("params", {}).get("anuncios", {})
    if not isinstance(p_anuncios, dict):
        p_anuncios = config.get("anuncios", {})
        
    umbral = p_anuncios.get("umbral", 2)
    min_chars = p_anuncios.get("min_chars", 280)
    min_lineas = p_anuncios.get("min_lineas", 4)
    
    id_activo = idioma or (df["idioma"].iloc[0] if "idioma" in df.columns and len(df) > 0 else "es")
    pw = cargar_palabras_anuncio(id_activo)
    
    txt_series = df["texto"].fillna("").astype(str)
    
    puntajes = []
    es_anuncio_list = []
    total_fuertes = 0
    
    for raw in txt_series:
        k = f" {normalizar_clave(raw)} "
        n_pal = len(re.findall(r"[\w]+", raw, flags=re.UNICODE))
        
        # Conteo de débiles y fuertes
        n_deb = sum(1 for w in pw["debiles"] if f" {w} " in k or w in k)
        n_fue = sum(1 for w in pw["fuertes"] if f" {w} " in k or w in k)
        if n_fue > 0:
            total_fuertes += 1
            
        n_urls = len(re.findall(r"<URL>", raw))
        n_usuarios = len(re.findall(r"<USUARIO>", raw))
        n_emojis = len(re.findall(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]", raw))
        lineas = raw.count("\n") + 1
        
        pt = (
            int(len(raw) >= min_chars) +
            int(lineas >= min_lineas) +
            int(n_urls >= 1 and n_pal >= 6) +
            int(n_emojis >= 4) +
            int(n_usuarios >= 2) +
            min(2, n_deb) +
            (3 if n_fue > 0 else 0)
        )
        puntajes.append(pt)
        es_anuncio_list.append(bool(pt >= umbral))
        
    df["puntaje_anuncio"] = puntajes
    df["es_anuncio"] = es_anuncio_list
    
    n_anuncios = sum(es_anuncio_list)
    pct = (100.0 * n_anuncios / len(df)) if len(df) > 0 else 0.0
    df.attrs["detalle"] = f"anuncios/spam={n_anuncios} ({pct:.1f}%); spam fuerte={total_fuertes}; umbral={umbral}"
    return df

def mensajes_analizables(mensajes: pd.DataFrame, params: Optional[Dict[str, Any]] = None) -> pd.Series:
    """Retorna máscara booleana con los mensajes que entran a inferencia de emociones."""
    excluir = True
    if params and "excluir_anuncios" in params:
        excluir = bool(params["excluir_anuncios"])
        
    mask = mensajes["texto_limpio"].fillna("").astype(str).str.strip().str.len() > 0
    if excluir and "es_anuncio" in mensajes.columns:
        mask = mask & (~mensajes["es_anuncio"].fillna(False).astype(bool))
    return mask
