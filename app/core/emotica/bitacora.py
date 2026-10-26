# -*- coding: utf-8 -*-
"""
Módulo de auditoría y bitácora de ejecución automática (Data Lineage & CDC).
Garantiza paridad estricta con emotica/R/bitacora.R.
"""

import os
import json
import time
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable, Union
import pandas as pd

class BitacoraAuditoria:
    _instance = None
    
    def __init__(self):
        self.filas: List[Dict[str, Any]] = []
        self.usuario: str = "sistema"
        self.huella: Optional[str] = None
        
    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = BitacoraAuditoria()
        return cls._instance

_bit = BitacoraAuditoria.get_instance()

def bitacora_iniciar(archivo: Optional[Union[str, Path]] = None, usuario: Optional[str] = None) -> Optional[str]:
    """Inicia una nueva sesión de bitácora calculando la huella SHA-256 del archivo de entrada."""
    _bit.filas = []
    _bit.usuario = usuario or os.getenv("USERNAME", os.getenv("USER", "sistema"))
    _bit.huella = None
    
    if archivo:
        p = Path(archivo)
        if p.exists() and p.is_file():
            hasher = hashlib.sha256()
            with open(p, "rb") as f:
                while chunk := f.read(65536):
                    hasher.update(chunk)
            _bit.huella = hasher.hexdigest()
    return _bit.huella

def bitacora_registrar(
    paso: str,
    parametros: Optional[Dict[str, Any]] = None,
    filas_entrada: Optional[int] = None,
    filas_salida: Optional[int] = None,
    detalle: str = "",
    duracion_s: Optional[float] = None
) -> Dict[str, Any]:
    """Registra una operación en la bitácora con marcas temporales y parámetros JSON."""
    p_json = json.dumps(parametros or {}, ensure_ascii=False)
    fila = {
        "paso": paso,
        "parametros": p_json,
        "filas_entrada": filas_entrada,
        "filas_salida": filas_salida,
        "huella_archivo": _bit.huella,
        "fecha_hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "usuario": _bit.usuario,
        "detalle": str(detalle or ""),
        "duracion_s": round(duracion_s, 3) if duracion_s is not None else None
    }
    _bit.filas.append(fila)
    return fila

def bitacora_leer() -> pd.DataFrame:
    """Retorna la bitácora acumulada en memoria como DataFrame."""
    if not _bit.filas:
        return pd.DataFrame(columns=[
            "paso", "parametros", "filas_entrada", "filas_salida",
            "huella_archivo", "fecha_hora", "usuario", "detalle", "duracion_s"
        ])
    return pd.DataFrame(_bit.filas)

def bitacora_guardar(path: Union[str, Path]) -> str:
    """Exporta la bitácora a formato CSV UTF-8."""
    df = bitacora_leer()
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(p, index=False, encoding="utf-8")
    return str(p)

def ejecutar_paso(
    paso: str,
    df: pd.DataFrame,
    f: Callable[[pd.DataFrame], pd.DataFrame],
    parametros: Optional[Dict[str, Any]] = None
) -> pd.DataFrame:
    """
    Ejecuta un paso de transformación cronometrándolo y registrándolo en la bitácora.
    Extrae df.attrs['detalle'] si fue configurado por la función.
    """
    t0 = time.perf_counter()
    n_in = len(df)
    
    out = f(df)
    
    n_out = len(out)
    duracion = time.perf_counter() - t0
    detalle = out.attrs.get("detalle", "")
    
    bitacora_registrar(
        paso=paso,
        parametros=parametros or {},
        filas_entrada=n_in,
        filas_salida=n_out,
        detalle=detalle,
        duracion_s=duracion
    )
    return out
