# -*- coding: utf-8 -*-
"""
Módulo de evaluación científica, muestreo para etiquetado ciego y métricas de concordancia.
Garantiza paridad estricta con emotica/R/eval.R (Kappa de Cohen, F1 y correlación Spearman).
"""

import re
import itertools
from typing import Dict, List, Optional, Any, Tuple
import numpy as np
import pandas as pd
from app.core.emotica.taxonomy import cargar_taxonomia

def muestra_para_etiquetar(
    mensajes: pd.DataFrame,
    scores: pd.DataFrame,
    n: int = 100,
    min_palabras: int = 4,
    prop_sin_emocion: float = 0.3,
    semilla: int = 2026
) -> Dict[str, pd.DataFrame]:
    """
    Genera una muestra estratificada balanceada para etiquetado ciego por evaluadores humanos:
    - Retorna 'hoja' (para los evaluadores, sin revelar las predicciones del motor).
    - Retorna 'clave' (registro de control interno del motor para calcular métricas posteriores).
    """
    np.random.seed(semilla)
    nw = pd.to_numeric(mensajes.get("n_palabras", 0), errors="coerce").fillna(0)
    valid_text = mensajes["texto_limpio"].fillna("").str.strip().str.len() > 0
    ok_mensajes = mensajes[valid_text & (nw >= min_palabras)].copy()
    
    if len(scores) > 0:
        # Emoción dominante por mensaje
        dom = scores.sort_values(by=["msg_id", "puntaje"], ascending=[True, False]).drop_duplicates(subset=["msg_id"])
        con_ids = set(ok_mensajes["msg_id"].astype(str)).intersection(set(dom["msg_id"].astype(str)))
    else:
        dom = pd.DataFrame(columns=["msg_id", "emocion_id"])
        con_ids = set()
        
    con_df = ok_mensajes[ok_mensajes["msg_id"].astype(str).isin(con_ids)]
    sin_df = ok_mensajes[~ok_mensajes["msg_id"].astype(str).isin(con_ids)]
    
    n_con = int(round(n * (1.0 - prop_sin_emocion)))
    emos = dom["emocion_id"].unique() if len(dom) > 0 else []
    
    elegidos = []
    if len(emos) > 0 and len(con_df) > 0:
        por_emocion = int(np.ceil(n_con / len(emos)))
        for e in emos:
            e_ids = list(dom[dom["emocion_id"] == e]["msg_id"].astype(str))
            cand = [i for i in e_ids if i in con_ids]
            if len(cand) <= por_emocion:
                elegidos.extend(cand)
            else:
                elegidos.extend(np.random.choice(cand, por_emocion, replace=False).tolist())
                
        if len(elegidos) > n_con:
            elegidos = np.random.choice(elegidos, n_con, replace=False).tolist()
            
    n_restante = n - len(elegidos)
    sin_ids = sin_df["msg_id"].astype(str).tolist()
    if len(sin_ids) > 0 and n_restante > 0:
        n_sin = min(len(sin_ids), n_restante)
        sin_elegidos = np.random.choice(sin_ids, n_sin, replace=False).tolist()
    else:
        sin_elegidos = []
        
    todos_ids = elegidos + sin_elegidos
    np.random.shuffle(todos_ids)
    
    msg_map_texto = dict(zip(mensajes["msg_id"].astype(str), mensajes["texto"]))
    dom_map_emo = dict(zip(dom["msg_id"].astype(str), dom["emocion_id"]))
    sin_set = set(sin_elegidos)
    
    hoja = pd.DataFrame({
        "msg_id": todos_ids,
        "texto": [msg_map_texto.get(i, "") for i in todos_ids],
        "emociones": "",
        "intensidad": "",
        "etiquetador": ""
    })
    
    clave = pd.DataFrame({
        "msg_id": todos_ids,
        "estrato": ["sin_emocion_motor" if i in sin_set else "con_emocion_motor" for i in todos_ids],
        "emocion_dominante_motor": [dom_map_emo.get(i, None) for i in todos_ids]
    })
    
    return {"hoja": hoja, "clave": clave}

def kappa_cohen(a: np.ndarray, b: np.ndarray) -> float:
    """Cálculo analítico del Kappa de Cohen para presencia binaria."""
    if len(a) == 0 or len(a) != len(b):
        return 0.0
    po = np.mean(a == b)
    pe = np.mean(a) * np.mean(b) + np.mean(~a) * np.mean(~b)
    if pe >= 1.0:
        return 1.0
    return round(float((po - pe) / (1.0 - pe)), 3)

def evaluar_motor(
    scores: pd.DataFrame,
    hoja: pd.DataFrame,
    taxonomy: Optional[pd.DataFrame] = None,
    umbral_confianza: float = 0.0
) -> Dict[str, Any]:
    """
    Evalúa las predicciones del motor contra las etiquetas manuales provistas en una hoja.
    Calcula TP, FP, FN, Precisión, Recall y F1 por emoción y globales.
    """
    valid_hoja = hoja[hoja["emociones"].fillna("").astype(str).str.strip().str.len() > 0].copy()
    if len(valid_hoja) == 0:
        return {"por_emocion": pd.DataFrame(), "global": {"precision": 0, "recall": 0, "f1": 0}}
        
    human_pairs = set()
    for _, r in valid_hoja.iterrows():
        mid = str(r["msg_id"])
        em_list = [e.strip().lower() for e in re.split(r"[,;]\s*", str(r["emociones"])) if e.strip() and e.strip() != "ninguna"]
        for e in em_list:
            human_pairs.add(f"{mid}|{e}")
            
    valid_ids = set(valid_hoja["msg_id"].astype(str))
    sub_scores = scores[scores["msg_id"].astype(str).isin(valid_ids) & (scores["confianza"] >= umbral_confianza)]
    
    motor_pairs = set(f"{r['msg_id']}|{r['emocion_id']}" for _, r in sub_scores.iterrows())
    
    todas_emociones = sorted(set([p.split("|")[1] for p in human_pairs.union(motor_pairs)]))
    
    filas = []
    total_tp = 0
    total_fp = 0
    total_fn = 0
    
    for e in todas_emociones:
        h_e = set(p for p in human_pairs if p.endswith(f"|{e}"))
        m_e = set(p for p in motor_pairs if p.endswith(f"|{e}"))
        
        tp = len(h_e.intersection(m_e))
        fp = len(m_e - h_e)
        fn = len(h_e - m_e)
        
        total_tp += tp
        total_fp += fp
        total_fn += fn
        
        prec = round(tp / (tp + fp), 2) if (tp + fp) > 0 else 0.0
        rec = round(tp / (tp + fn), 2) if (tp + fn) > 0 else 0.0
        f1 = round(2 * prec * rec / (prec + rec), 2) if (prec + rec) > 0 else 0.0
        
        filas.append({
            "emocion_id": e,
            "humano": len(h_e),
            "motor": len(m_e),
            "tp": tp,
            "fp": fp,
            "fn": fn,
            "precision": prec,
            "recall": rec,
            "f1": f1
        })
        
    p_glob = total_tp / max(1, total_tp + total_fp)
    r_glob = total_tp / max(1, total_tp + total_fn)
    f1_glob = (2 * p_glob * r_glob / (p_glob + r_glob)) if (p_glob + r_glob) > 0 else 0.0
    
    return {
        "por_emocion": pd.DataFrame(filas),
        "n_mensajes": len(valid_ids),
        "global": {
            "precision": round(p_glob, 3),
            "recall": round(r_glob, 3),
            "f1": round(f1_glob, 3)
        }
    }

def acuerdo_etiquetadores(hojas: Dict[str, pd.DataFrame], emociones: Optional[List[str]] = None) -> pd.DataFrame:
    """Calcula el acuerdo Kappa de Cohen por pares entre diferentes evaluadores humanos."""
    tax_emos = emociones or cargar_taxonomia()["id"].tolist()
    pares = list(itertools.combinations(hojas.keys(), 2))
    
    filas = []
    for p1, p2 in pares:
        h1 = hojas[p1]
        h2 = hojas[p2]
        
        comun_ids = sorted(set(h1["msg_id"].astype(str)).intersection(set(h2["msg_id"].astype(str))))
        if not comun_ids:
            continue
            
        def _get_bin_vec(h_df):
            mapping = {}
            for _, r in h_df.iterrows():
                mid = str(r["msg_id"])
                mapping[mid] = set(re.split(r"[,;]\s*", str(r.get("emociones", "")).lower()))
            vec = []
            for e in tax_emos:
                for mid in comun_ids:
                    vec.append(e in mapping.get(mid, set()))
            return np.array(vec)
            
        v1 = _get_bin_vec(h1)
        v2 = _get_bin_vec(h2)
        k = kappa_cohen(v1, v2)
        
        filas.append({
            "par": f"{p1} vs {p2}",
            "kappa": k,
            "n_frases": len(comun_ids)
        })
        
    return pd.DataFrame(filas)

def correlacion_intensidad(scores: pd.DataFrame, hoja: pd.DataFrame) -> Dict[str, Any]:
    """Calcula la correlación Spearman entre el puntaje continuo del motor y la intensidad humana (1 a 5)."""
    if len(scores) == 0 or len(hoja) == 0:
        return {"n": 0, "spearman": None}
        
    dom = scores.sort_values(by=["msg_id", "puntaje"], ascending=[True, False]).drop_duplicates(subset=["msg_id"])
    h_valid = hoja[hoja["intensidad"].fillna("").astype(str).str.strip().str.isdigit()].copy()
    if len(h_valid) == 0:
        return {"n": 0, "spearman": None}
        
    merged = pd.merge(
        dom[["msg_id", "puntaje"]],
        h_valid[["msg_id", "intensidad"]],
        on="msg_id"
    )
    merged["humana"] = pd.to_numeric(merged["intensidad"], errors="coerce")
    merged = merged.dropna(subset=["puntaje", "humana"])
    
    if len(merged) < 5:
        return {"n": len(merged), "spearman": None}
        
    corr, _ = spearmanr(merged["puntaje"], merged["humana"])
    return {
        "n": len(merged),
        "spearman": round(float(corr), 3) if not np.isnan(corr) else None
    }
