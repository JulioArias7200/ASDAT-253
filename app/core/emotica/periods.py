# -*- coding: utf-8 -*-
"""
Módulo de asignación de periodos y temporadas académicas.
Garantiza paridad estricta con emotica/R/periods.R (soporta bisiestos y temporadas interanuales).
"""

from typing import List, Dict, Any, Union, Optional
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_yaml

def cargar_seasons() -> List[Dict[str, Any]]:
    """Carga config/seasons.yml."""
    f = ruta_recurso("config", "seasons.yml")
    if f.exists():
        return leer_yaml(f)
    return [
        {"id": "invierno", "inicio": "05-01", "fin": "08-31"},
        {"id": "verano", "inicio": "12-01", "fin": "02-29"}
    ]

def asignar_periodo(fechas: Union[pd.Series, List[Any]], seasons: Optional[List[Dict[str, Any]]] = None) -> pd.DataFrame:
    """
    Asigna temporada (ej: 'invierno', 'verano') y ciclo (año de finalización) a cada fecha.
    Retorna DataFrame con columnas: temporada, ciclo, periodo_id.
    """
    if seasons is None:
        seasons = cargar_seasons()
        
    f_series = pd.to_datetime(fechas, errors="coerce")
    n = len(f_series)
    
    temporadas = ["fuera_de_temporada"] * n
    ciclos = [None] * n
    
    md_strings = f_series.dt.strftime("%m-%d")
    anios = f_series.dt.year
    
    for s in seasons:
        s_id = s["id"]
        inicio = s["inicio"]
        fin = s["fin"]
        cruza = inicio > fin
        
        for idx in range(n):
            md = md_strings.iloc[idx]
            if pd.isna(md):
                continue
            y = anios.iloc[idx]
            
            # Chequeo de inclusión en el rango
            if not cruza:
                dentro = (md >= inicio) and (md <= fin)
            else:
                dentro = (md >= inicio) or (md <= fin)
                
            if dentro:
                # Si cruza el año y estamos en la primera parte (diciembre), el ciclo es año + 1
                anio_ciclo = (y + 1) if (cruza and md >= inicio) else y
                temporadas[idx] = s_id
                ciclos[idx] = anio_ciclo
                
    periodos_id = [
        "fuera" if t == "fuera_de_temporada" else f"{t}_{c}"
        for t, c in zip(temporadas, ciclos)
    ]
    
    return pd.DataFrame({
        "temporada": temporadas,
        "ciclo": ciclos,
        "periodo_id": periodos_id
    })
