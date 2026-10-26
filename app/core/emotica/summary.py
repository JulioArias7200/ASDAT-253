# -*- coding: utf-8 -*-
"""
Módulo de resumen analítico y tasas agregadas por periodo.
Garantiza paridad estricta con emotica/R/summary.R.
"""

from typing import Dict, Any
import pandas as pd

def cobertura_emociones(scores: pd.DataFrame, mensajes: pd.DataFrame) -> Dict[str, Any]:
    """Calcula la cobertura afectiva global del corpus."""
    n_con_texto = int(mensajes["tiene_texto"].sum()) if "tiene_texto" in mensajes.columns else len(mensajes)
    con_emocion = len(scores["msg_id"].unique()) if len(scores) > 0 else 0
    cobertura = con_emocion / max(1, n_con_texto)
    return {
        "mensajes_con_texto": n_con_texto,
        "con_emocion": con_emocion,
        "cobertura": round(cobertura, 4)
    }

def resumen_por_periodo(scores: pd.DataFrame, mensajes: pd.DataFrame) -> pd.DataFrame:
    """Calcula la tasa de ocurrencia de cada emoción por cada 1,000 mensajes desglosada por periodo."""
    if len(scores) == 0 or len(mensajes) == 0:
        return pd.DataFrame(columns=["emocion_id", "periodo_id", "total_emocion", "total_periodo", "tasa_x1000"])
        
    totales_periodo = mensajes["periodo_id"].value_counts().to_dict() if "periodo_id" in mensajes.columns else {}
    
    conteo_emo = scores.groupby(["emocion_id", "periodo_id"]).size().reset_index(name="total_emocion")
    conteo_emo["total_periodo"] = conteo_emo["periodo_id"].map(totales_periodo).fillna(1)
    conteo_emo["tasa_x1000"] = (conteo_emo["total_emocion"] / conteo_emo["total_periodo"] * 1000.0).round(2)
    
    return conteo_emo.sort_values(by=["periodo_id", "tasa_x1000"], ascending=[True, False]).reset_index(drop=True)
