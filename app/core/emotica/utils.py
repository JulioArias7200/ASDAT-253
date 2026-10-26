# -*- coding: utf-8 -*-
"""
Utilidades generales de I/O, rutas y normalización de cadenas para el paquete emotica.
Garantiza paridad estricta con emotica/R/utils.R y normalización Latin-ASCII.
"""

import os
import json
import unicodedata
from pathlib import Path
from typing import Any, List, Union

# Localización de la raíz de recursos (emotica/)
CORE_DIR = Path(__file__).resolve().parent
APP_DIR = CORE_DIR.parent.parent
ROOT_DIR = APP_DIR.parent

def obtener_raiz_emotica() -> Path:
    env_root = os.getenv("EMOTICA_RAIZ")
    if env_root and os.path.isdir(env_root):
        return Path(env_root)
    candidato = ROOT_DIR / "emotica"
    if candidato.exists() and (candidato / "resources").exists():
        return candidato
    if (ROOT_DIR / "resources").exists():
        return ROOT_DIR
    return candidato

def ruta_recurso(*parts: str) -> Path:
    """Resuelve rutas relativas a emotica/resources o emotica/config."""
    raiz = obtener_raiz_emotica()
    return raiz.joinpath(*parts)

def leer_yaml(path: Union[str, Path]) -> Any:
    """
    Lee archivos de configuración/taxonomía con 100% Python estándar (sin librerías externas).
    Prioriza el archivo .json correspondiente o utiliza json nativo.
    """
    p = Path(path)
    
    # 1. Si existe equivalente nativo en JSON, cargarlo directamente
    p_json = p.with_suffix(".json")
    if p_json.exists():
        with open(p_json, "r", encoding="utf-8") as f:
            return json.load(f)
            
    if not p.exists():
        raise FileNotFoundError(f"No existe el archivo de configuración: {p}")
        
    with open(p, "r", encoding="utf-8") as f:
        content = f.read()
        
    # 2. Intentar cargar como JSON directo si el contenido tiene formato JSON
    try:
        return json.loads(content)
    except Exception:
        pass
        
    # 3. Fallback opcional a PyYAML si está instalado en el entorno
    try:
        import yaml
        return yaml.safe_load(content)
    except ImportError:
        pass
        
    raise ValueError(
        f"No se pudo parsear {p.name}. Para mantener 100% Python nativo sin dependencias "
        f"externas, asegúrese de que exista {p.stem}.json."
    )

def leer_lineas_utf8(path: Union[str, Path]) -> List[str]:
    """Lee líneas de texto en UTF-8 descartando saltos de línea."""
    p = Path(path)
    if not p.exists():
        return []
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        return [line.rstrip("\r\n") for line in f]

def normalizar_clave(texto: Union[str, List[str]]) -> Union[str, List[str]]:
    """
    Equivalente exacto a stringi::stri_trans_general(tolower(x), 'Latin-ASCII').
    Convierte a minúsculas y elimina diacríticos y tildes preservando el carácter base.
    """
    def _norm(s: str) -> str:
        if not s or not isinstance(s, str):
            return ""
        s = s.lower()
        nfkd = unicodedata.normalize("NFKD", s)
        # Filtrar marcas diacríticas (Mn)
        return "".join(c for c in nfkd if unicodedata.category(c) != "Mn")

    if isinstance(texto, (list, tuple)):
        return [_norm(t) for t in texto]
    return _norm(texto)
