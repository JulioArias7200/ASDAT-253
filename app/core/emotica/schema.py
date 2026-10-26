# -*- coding: utf-8 -*-
"""
Módulo de inferencia de esquemas y parser secuencial de fechas multiformato.
Garantiza paridad con emotica/R/schema.R.
"""

import re
from datetime import datetime
from typing import Dict, List, Tuple, Any, Optional
import pandas as pd
from app.core.emotica.utils import normalizar_clave

PATRONES_FECHA_STRPTIME = [
    "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d",
    "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M", "%d/%m/%Y",
    "%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M", "%m/%d/%Y",
    "%d-%m-%Y %H:%M:%S", "%d-%m-%Y %H:%M", "%d-%m-%Y",
    "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M", "%Y/%m/%d",
    "%d/%m/%y %H:%M:%S", "%d/%m/%y %H:%M", "%d/%m/%y",
    "%m/%d/%y %H:%M:%S", "%m/%d/%y %H:%M", "%m/%d/%y",
    "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %I:%M:%S %p",
    "%d/%m/%Y %I:%M:%S %p", "%d/%m/%Y %I:%M %p"
]

def parse_fecha(valores: pd.Series, tz: str = "UTC") -> Dict[str, Any]:
    """
    Evalúa múltiples patrones de fecha secuencialmente y elige el que mayor tasa de éxito interprete.
    Retorna: fecha (Series pd.Timestamp), formato, tasa, ambiguo (bool).
    """
    if pd.api.types.is_datetime64_any_dtype(valores):
        return {
            "fecha": pd.to_datetime(valores, utc=True),
            "formato": "POSIXct",
            "tasa": 1.0,
            "ambiguo": False
        }
        
    s_clean = valores.dropna().astype(str).str.strip()
    s_valid = s_clean[s_clean.str.len() > 0]
    if len(s_valid) == 0:
        return {
            "fecha": pd.to_datetime(pd.Series([None] * len(valores)), utc=True),
            "formato": None,
            "tasa": 0.0,
            "ambiguo": False
        }
        
    # Verificar si son marcas Unix Epoch numéricas
    num_vals = pd.to_numeric(s_valid, errors="coerce")
    if num_vals.notna().mean() > 0.9:
        med = num_vals.median()
        if med > 1e9:
            divisor = 1000.0 if med > 1e11 else 1.0
            fechas_dt = pd.to_datetime(num_vals / divisor, unit="s", utc=True)
            return {
                "fecha": fechas_dt.reindex(valores.index),
                "formato": "epoch",
                "tasa": float(num_vals.notna().mean()),
                "ambiguo": False
            }
            
    # Muestra representativa de hasta 500 elementos
    muestra = s_valid.iloc[:min(500, len(s_valid))]
    
    mejor_fmt = None
    mejor_tasa = -1.0
    tasas = {}
    
    for fmt in PATRONES_FECHA_STRPTIME:
        exitos = 0
        for val in muestra:
            try:
                datetime.strptime(val, fmt)
                exitos += 1
            except Exception:
                pass
        tasa = exitos / len(muestra)
        tasas[fmt] = tasa
        if tasa > mejor_tasa:
            mejor_tasa = tasa
            mejor_fmt = fmt
            
    # Si ningún formato específico supera el 40%, fallback a dateutil / pd.to_datetime flexible
    if mejor_tasa < 0.4:
        fechas_flexible = pd.to_datetime(valores, errors="coerce", utc=True)
        tasa_flex = float(fechas_flexible.notna().mean())
        return {
            "fecha": fechas_flexible,
            "formato": "auto_flexible",
            "tasa": tasa_flex,
            "ambiguo": False
        }
        
    # Chequeo de ambigüedad día/mes
    ambiguo = False
    if mejor_fmt and not mejor_fmt.startswith("%Y"):
        # Ver si hay otro formato d/m vs m/d con tasa idéntica
        alt_tasas = [t for f, t in tasas.items() if t >= mejor_tasa - 1e-5 and f != mejor_fmt]
        if len(alt_tasas) > 0:
            ambiguo = True
            
    fechas_finales = pd.to_datetime(valores, format=mejor_fmt, errors="coerce", utc=True)
    return {
        "fecha": fechas_finales,
        "formato": mejor_fmt,
        "tasa": mejor_tasa,
        "ambiguo": ambiguo
    }

def detectar_esquema(df: pd.DataFrame, umbral: float = 0.45) -> Dict[str, Any]:
    """
    Detecta automáticamente las columnas semánticas en un CSV genérico:
    texto, fecha, autor, responde_a, id.
    """
    col_names = list(df.columns)
    col_norm = [normalizar_clave(c) for c in col_names]
    
    patrones = {
        "fecha": r"date|fecha|time|timestamp|datetime|hora|created|sent|^data$|^dia$",
        "autor": r"from|autor|author|user|usuario|sender|remitente|nombre|name|nick|persona|nome|^de$",
        "texto": r"text|texto|message|mensaje|mensagem|content|contenido|body|msg|comentario|comment|post",
        "responde_a": r"reply|respuesta|responde|parent|respond",
        "id": r"^id$|msg_id|message_id|^id_|_id$|mensaje_id|^n$"
    }
    
    muestra = df.iloc[:min(300, len(df))]
    scores = {}
    
    for campo, pat in patrones.items():
        comp = re.compile(pat)
        scores[campo] = []
        for i, col in enumerate(col_names):
            s_nombre = 1.0 if comp.search(col_norm[i]) else 0.0
            
            # Evaluación por contenido
            vals = muestra[col].dropna().astype(str).tolist()
            vals = [v.strip() for v in vals if v.strip()]
            if not vals:
                s_cont = 0.0
            else:
                if campo == "fecha":
                    s_cont = parse_fecha(pd.Series(vals))["tasa"]
                elif campo == "texto":
                    lens = [len(v) for v in vals]
                    med_len = pd.Series(lens).median() if lens else 0
                    s_cont = min(1.0, med_len / 40.0)
                elif campo == "autor":
                    r = len(set(vals)) / max(1, len(vals))
                    s_cont = 1.0 if (0.001 < r < 0.6) else 0.2
                elif campo == "id":
                    all_digits = all(v.isdigit() for v in vals)
                    s_cont = 1.0 if (all_digits and len(set(vals)) == len(vals)) else 0.0
                elif campo == "responde_a":
                    s_cont = 0.5 if (sum(v.isdigit() for v in vals) / len(vals) > 0.9) else 0.0
                else:
                    s_cont = 0.0
                    
            scores[campo].append(0.5 * s_nombre + 0.5 * s_cont)
            
    mapping = {}
    confianza = {}
    usadas = set()
    
    for campo in ["texto", "fecha", "autor", "id", "responde_a"]:
        sc_list = scores[campo]
        # Anular las ya asignadas
        for u in usadas:
            sc_list[u] = -1.0
        mejor_idx = int(pd.Series(sc_list).idxmax())
        if sc_list[mejor_idx] >= umbral:
            mapping[campo] = col_names[mejor_idx]
            confianza[campo] = round(sc_list[mejor_idx], 2)
            usadas.add(mejor_idx)
            
    faltan = [c for c in ["texto", "fecha"] if c not in mapping]
    return {
        "mapping": mapping,
        "confianza": confianza,
        "faltan": faltan,
        "columnas": col_names
    }
