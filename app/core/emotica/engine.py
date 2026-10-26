# -*- coding: utf-8 -*-
"""
Motor analítico de 15 emociones.
Garantiza paridad estricta y matemática con emotica/R/engine.R.
Regla clave: NUNCA nombra una emoción en el código; todo proviene de la taxonomía externa y del léxico.
"""

import math
import re
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_yaml, normalizar_clave
from app.core.emotica.taxonomy import cargar_taxonomia, cargar_lexicon
from app.core.emotica.anuncios import mensajes_analizables

def cargar_params_motor(path: Optional[str] = None) -> Dict[str, Any]:
    """Carga los parámetros numéricos y umbrales desde config/engine.yml."""
    f = ruta_recurso("config", "engine.yml") if not path else path
    if Path(f).exists():
        return leer_yaml(f)
    return {
        "ventana_modificadores": 3,
        "factor_negacion_opuesta": 0.5,
        "escala_intensidad": 2.0,
        "niveles": {"leve": 0.30, "moderada": 0.60, "alta": 0.85},
        "senales": {
            "exclamacion": 0.15,
            "exclamacion_max": 3,
            "mayusculas": 0.20,
            "alargamiento": 0.15,
            "tope": 0.60
        },
        "excluir_anuncios": True
    }

def cargar_modificadores(idioma: str = "es") -> pd.DataFrame:
    """Carga el diccionario de modificadores (intensificadores, atenuadores, negadores)."""
    f = ruta_recurso("resources", "modifiers", f"{idioma}.csv")
    vacio = pd.DataFrame(columns=["termino", "tipo", "factor", "clave"])
    if not f.exists():
        return vacio
    try:
        m = pd.read_csv(f, dtype=str, encoding="utf-8").fillna("")
        m["factor"] = pd.to_numeric(m["factor"], errors="coerce").fillna(1.0)
        m["clave"] = normalizar_clave(m["termino"].tolist())
        return m
    except Exception:
        return vacio

def score_emotions(
    mensajes: pd.DataFrame,
    taxonomy: Optional[pd.DataFrame] = None,
    lexicon: Optional[pd.DataFrame] = None,
    active: Optional[List[str]] = None,
    idioma: Optional[str] = None,
    params: Optional[Dict[str, Any]] = None
) -> pd.DataFrame:
    """
    Motor central de inferencia afectiva:
    1. Frases y Regex con prioridad y enmascaramiento.
    2. Palabras y emojis con ventana retrospectiva de modificadores (3 tokens).
    3. Inversión semántica por negación hacia la emoción opuesta (50% de peso).
    4. Bonificación tipográfica por signos !, MAYÚSCULAS y elongación.
    5. Curva de saturación exponencial de intensidad y confianza calibrada.
    """
    col_salida = ["msg_id", "emocion_id", "puntaje", "confianza", "evidencia", "intensidad", "nivel"]
    vacio = pd.DataFrame(columns=col_salida)
    
    if len(mensajes) == 0:
        return vacio
        
    tax = taxonomy if taxonomy is not None else cargar_taxonomia()
    p_motor = params if params is not None else cargar_params_motor()
    
    id_activo = idioma or (mensajes["idioma"].iloc[0] if "idioma" in mensajes.columns and len(mensajes) > 0 else "es")
    lex = lexicon if lexicon is not None else cargar_lexicon(id_activo)
    
    if len(lex) == 0:
        import warnings
        warnings.warn(f"Sin lexico para el idioma '{id_activo}': se devuelve tabla vacia.")
        return vacio
        
    # Filtrar emociones activas
    activas_set = set(tax[tax["activa"]]["id"].tolist())
    if active is not None:
        activas_set = activas_set.intersection(set(active))
        
    lex = lex[lex["emocion_id"].isin(activas_set)].copy()
    if len(lex) == 0:
        return vacio
        
    mods = cargar_modificadores(id_activo)
    map_mod_tipo = dict(zip(mods["clave"], mods["tipo"]))
    map_mod_factor = dict(zip(mods["clave"], mods["factor"]))
    
    # 0. Filtrar mensajes analizables
    mask_analizables = mensajes_analizables(mensajes, p_motor)
    sub_df = mensajes[mask_analizables].copy()
    if len(sub_df) == 0:
        return vacio
        
    sub_indices = list(range(len(sub_df)))
    msg_ids = sub_df["msg_id"].astype(str).tolist()
    
    textos_limpios = sub_df["texto_limpio"].fillna("").tolist()
    textos_raw = sub_df["texto"].fillna("").astype(str).tolist()
    
    k_list = [normalizar_clave(t) for t in textos_limpios]
    kk_list = [f" {k} " for k in k_list]
    raw_clean_list = [re.sub(r"<[A-Z_]+>", " ", r) for r in textos_raw]
    es_pregunta_list = [bool(re.search(r"[?\u00bf]", r)) for r in textos_raw]
    
    hits = []  # Tuplas: (idx, emocion_id, contrib, evidencia, neg)
    
    # 1. Frases y Regex (Las más largas primero)
    frases_df = lex[lex["tipo"].isin(["frase", "regex"])].copy()
    if len(frases_df) > 0:
        # Ordenar por longitud de clave descendente
        frases_df["len_clave"] = frases_df["clave"].str.len()
        frases_df = frases_df.sort_values(by="len_clave", ascending=False)
        
        for cl in frases_df["clave"].unique():
            sub_f = frases_df[frases_df["clave"] == cl]
            es_rx = sub_f["tipo"].iloc[0] == "regex"
            
            for i in sub_indices:
                kk = kk_list[i]
                if not kk:
                    continue
                if es_rx:
                    matches = len(re.findall(cl, kk))
                else:
                    pat_fijo = f" {cl} "
                    matches = kk.count(pat_fijo)
                    
                if matches > 0:
                    esp = es_pregunta_list[i]
                    for _, r in sub_f.iterrows():
                        ctx = r.get("contexto", "")
                        if ctx == "no_pregunta" and esp:
                            continue
                        if ctx == "pregunta" and not esp:
                            continue
                            
                        peso = float(r["peso"])
                        hits.append({
                            "i": i,
                            "emocion_id": r["emocion_id"],
                            "contrib": peso * matches,
                            "evidencia": r["termino"],
                            "neg": False
                        })
                    # Enmascarar la frase para evitar doble conteo
                    if es_rx:
                        kk_list[i] = re.sub(cl, " ¦ ", kk)
                    else:
                        kk_list[i] = kk.replace(f" {cl} ", " ¦ ")
                        
    # 2. Palabras y Emojis con Ventana de Modificadores hacia atrás
    palabras_df = lex[lex["tipo"].isin(["palabra", "emoji"])].copy()
    map_palabras: Dict[str, List[Dict[str, Any]]] = {}
    for _, r in palabras_df.iterrows():
        map_palabras.setdefault(r["clave"], []).append({
            "emocion_id": r["emocion_id"],
            "peso": float(r["peso"]),
            "termino": r["termino"],
            "contexto": r.get("contexto", "")
        })
        
    map_opuesta = dict(zip(tax["id"], tax["opuesta"]))
    ventana = int(p_motor.get("ventana_modificadores", 3))
    factor_neg_op = float(p_motor.get("factor_negacion_opuesta", 0.5))
    
    for i in sub_indices:
        kk = kk_list[i]
        tokens = [tok for tok in kk.split() if tok and tok != "¦"]
        nt = len(tokens)
        if nt == 0:
            continue
            
        esp = es_pregunta_list[i]
        
        for pos, tok in enumerate(tokens):
            if tok not in map_palabras:
                continue
                
            entries = map_palabras[tok]
            
            # Buscar modificadores en ventana hacia atrás (pos - 1, pos - 2, pos - 3)
            neg = False
            negtok = None
            fac = 1.0
            
            for L in range(1, ventana + 1):
                prev_pos = pos - L
                if prev_pos < 0:
                    break
                prev_tok = tokens[prev_pos]
                t_mod = map_mod_tipo.get(prev_tok)
                f_mod = map_mod_factor.get(prev_tok, 1.0)
                
                if t_mod == "negador":
                    if not neg:
                        negtok = prev_tok
                    neg = True
                elif t_mod in ["intensificador", "atenuador"]:
                    fac *= f_mod
                    
            fac = min(max(fac, 0.3), 2.0)
            
            for e in entries:
                ctx = e["contexto"]
                if ctx == "no_pregunta" and esp:
                    continue
                if ctx == "pregunta" and not esp:
                    continue
                    
                contrib = e["peso"] * fac
                evid = f"{e['termino']} x{round(fac, 2)}" if fac != 1.0 else e["termino"]
                
                if not neg:
                    hits.append({
                        "i": i,
                        "emocion_id": e["emocion_id"],
                        "contrib": contrib,
                        "evidencia": evid,
                        "neg": False
                    })
                else:
                    # Negación: no suma a su propia emoción; pasa a la opuesta
                    opuesta = map_opuesta.get(e["emocion_id"])
                    if opuesta and opuesta in activas_set:
                        hits.append({
                            "i": i,
                            "emocion_id": opuesta,
                            "contrib": factor_neg_op * contrib,
                            "evidencia": f"NEG({negtok})+{e['termino']}",
                            "neg": True
                        })
                        
    if not hits:
        vacio.attrs["cobertura"] = {"mensajes_con_texto": len(sub_df), "con_emocion": 0}
        return vacio
        
    hits_df = pd.DataFrame(hits)
    
    # 3. Agregación por mensaje (i) y por emocion_id
    grouped = hits_df.groupby(["i", "emocion_id"]).agg(
        base=("contrib", "sum"),
        n_evid=("contrib", "count"),
        neg=("neg", "any"),
        evidencia=("evidencia", lambda s: " | ".join(dict.fromkeys(s)))
    ).reset_index()
    
    # 4. Señales Paralingüísticas sobre el texto original
    s_params = p_motor.get("senales", {})
    s_excl = float(s_params.get("exclamacion", 0.15))
    s_excl_max = int(s_params.get("exclamacion_max", 3))
    s_mayus = float(s_params.get("mayusculas", 0.20))
    s_alarg = float(s_params.get("alargamiento", 0.15))
    s_tope = float(s_params.get("tope", 0.60))
    
    multiplicadores = []
    pat_caps = re.compile(r"\b[A-ZÁÉÍÓÚÑ]{3,}\b")
    pat_alarg = re.compile(r"([a-záéíóúñ])\1{2,}", re.IGNORECASE)
    
    for i in sub_indices:
        raw = raw_clean_list[i]
        n_excl = raw.count("!")
        n_caps = len(pat_caps.findall(raw))
        tiene_alarg = bool(pat_alarg.search(raw))
        
        bonus = (
            s_excl * min(n_excl, s_excl_max) +
            (s_mayus if n_caps >= 2 else 0.0) +
            (s_alarg if tiene_alarg else 0.0)
        )
        mult = 1.0 + min(s_tope, bonus)
        multiplicadores.append(mult)
        
    escala = float(p_motor.get("escala_intensidad", 2.0))
    nv = p_motor.get("niveles", {"leve": 0.30, "moderada": 0.60, "alta": 0.85})
    
    filas_finales = []
    for _, r in grouped.iterrows():
        idx_msg = int(r["i"])
        base_val = float(r["base"])
        mult_val = multiplicadores[idx_msg]
        
        puntaje = round(base_val * mult_val, 3)
        intensidad = round(1.0 - math.exp(-puntaje / escala), 3)
        
        if intensidad < nv.get("leve", 0.30):
            nivel = "leve"
        elif intensidad < nv.get("moderada", 0.60):
            nivel = "moderada"
        elif intensidad < nv.get("alta", 0.85):
            nivel = "alta"
        else:
            nivel = "muy_alta"
            
        n_ev = int(r["n_evid"])
        is_neg = bool(r["neg"])
        conf_base = 0.35 + 0.25 * min(n_ev, 2) + (0.15 if n_ev >= 3 else 0.0)
        confianza = round(min(1.0, max(0.1, conf_base * (0.7 if is_neg else 1.0))), 2)
        
        item = {
            "msg_id": msg_ids[idx_msg],
            "emocion_id": r["emocion_id"],
            "puntaje": puntaje,
            "confianza": confianza,
            "evidencia": r["evidencia"],
            "intensidad": intensidad,
            "nivel": nivel
        }
        if "periodo_id" in sub_df.columns:
            item["periodo_id"] = sub_df["periodo_id"].iloc[idx_msg]
        if "temporada" in sub_df.columns:
            item["temporada"] = sub_df["temporada"].iloc[idx_msg]
            
        filas_finales.append(item)
        
    out = pd.DataFrame(filas_finales)
    out = out.sort_values(by=["msg_id", "puntaje"], ascending=[True, False]).reset_index(drop=True)
    
    mensajes_con_emocion = len(grouped["i"].unique())
    out.attrs["cobertura"] = {
        "mensajes_con_texto": len(sub_df),
        "con_emocion": mensajes_con_emocion,
        "cobertura": (mensajes_con_emocion / len(sub_df)) if len(sub_df) > 0 else 0.0
    }
    return out
