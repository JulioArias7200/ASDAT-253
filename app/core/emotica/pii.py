# -*- coding: utf-8 -*-
"""
Módulo de privacidad y enmascaramiento de PII.
Garantiza paridad criptográfica con emotica/R/pii.R (SHA-256 con sal y prefijo u_).
"""

import os
import re
import random
import string
import hashlib
from typing import Optional, Dict
import pandas as pd
from app.core.emotica.utils import ruta_recurso

PATRONES_PII: Dict[str, str] = {
    "URL": r"(?i)(https?://|www\.)\S+",
    "EMAIL": r"[\w.+-]+@[\w-]+\.[\w.-]+",
    "USUARIO": r"(?<![\w])@\w{3,}",
    "NUM_ID": r"(?<!\d)(?:\+\d{1,3}[\s-]?)?\d{3,4}[\s-]?\d{4}(?!\d)"
}

def obtener_sal(sal: Optional[str] = None) -> str:
    """Obtiene o genera la sal pseudoaleatoria de 32 caracteres para el hashing de autores."""
    if sal:
        return sal
    env_sal = os.getenv("EMOTICA_SAL")
    if env_sal and env_sal.strip():
        return env_sal.strip()
    
    f_sal = ruta_recurso(".emotica_sal")
    if f_sal.exists():
        with open(f_sal, "r", encoding="utf-8") as f:
            line = f.readline().strip()
            if line:
                return line
    
    # Generar sal criptográfica nueva
    chars = string.ascii_lowercase + string.digits
    nueva_sal = "".join(random.choice(chars) for _ in range(32))
    try:
        with open(f_sal, "w", encoding="utf-8") as f:
            f.write(nueva_sal)
    except Exception:
        pass
    return nueva_sal

def anonimizar_autores(df: pd.DataFrame, sal: Optional[str] = None) -> pd.DataFrame:
    """
    Reemplaza autor y autor_id por un hash SHA-256 recortado con sal (prefijo u_).
    ELIMINA físicamente los nombres e identificadores originales del DataFrame.
    """
    sal_activa = obtener_sal(sal)
    df = df.copy()
    
    # Determinar la clave de autor preferente
    if "autor_id" in df.columns:
        clave = df["autor_id"].fillna("").astype(str)
        mask_vacio = clave.str.strip() == ""
        if "autor" in df.columns:
            clave[mask_vacio] = df["autor"][mask_vacio].fillna("").astype(str)
    elif "autor" in df.columns:
        clave = df["autor"].fillna("").astype(str)
    else:
        clave = pd.Series(["anonimo"] * len(df), index=df.index)
        
    clave = clave.replace({"": "anonimo", "nan": "anonimo", "None": "anonimo"})
    
    # Calcular hashes únicos
    unicos = clave.unique()
    mapa_hash = {}
    for u in unicos:
        digest = hashlib.sha256((sal_activa + u).encode("utf-8")).hexdigest()
        mapa_hash[u] = f"u_{digest[:12]}"
        
    df["autor_hash"] = clave.map(mapa_hash)
    
    # Destruir columnas con nombres reales
    if "autor" in df.columns:
        del df["autor"]
    if "autor_id" in df.columns:
        del df["autor_id"]
        
    df.attrs["detalle"] = f"autores unicos={len(unicos)}; nombres e ids originales eliminados de la tabla"
    return df

def enmascarar_pii(df: pd.DataFrame) -> pd.DataFrame:
    """
    Sustituye URLs, emails, menciones y teléfonos/IDs por etiquetas canónicas <TAG>.
    """
    df = df.copy()
    conteos = {}
    
    if "texto" not in df.columns:
        return df

    textos = df["texto"].fillna("").astype(str)
    
    for tag, pat in PATRONES_PII.items():
        compilado = re.compile(pat)
        # Contar apariciones totales
        c = sum(len(compilado.findall(t)) for t in textos)
        conteos[tag] = c
        # Reemplazar
        textos = textos.apply(lambda t: compilado.sub(f"<{tag}>", t))
        
    df["texto"] = textos
    df.attrs["detalle"] = "; ".join(f"{k}={v}" for k, v in conteos.items())
    return df
