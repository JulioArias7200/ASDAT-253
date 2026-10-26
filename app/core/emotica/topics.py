# -*- coding: utf-8 -*-
"""
Módulo de modelado de tópicos probabilísticos (LDA y NMF con divergencia Kullback-Leibler).
Garantiza paridad con emotica/R/topics.R y cálculo de distintividad de Blei.
"""

from typing import Dict, List, Optional, Any, Tuple
import numpy as np
import pandas as pd
from app.core.emotica.tokens import filtrar_tokens

def agrupar_documentos(
    tok: pd.DataFrame,
    mensajes: pd.DataFrame,
    por: str = "dia",
    ventana: int = 25,
    min_tokens: int = 15,
    quitar_emojis: bool = True,
    min_chars: int = 3,
    excluir_anuncios: bool = True
) -> pd.DataFrame:
    """
    Agrupa mensajes en pseudo-documentos temporales (por día 'YYYY-MM-DD' o ventana de N mensajes).
    """
    tk = tok.copy()
    if excluir_anuncios and "es_anuncio" in mensajes.columns:
        valid_ids = set(mensajes[~mensajes["es_anuncio"].fillna(False).astype(bool)]["msg_id"].astype(str))
        tk = tk[tk["msg_id"].astype(str).isin(valid_ids)]
        
    tk = filtrar_tokens(tk, min_chars=min_chars)
    if quitar_emojis and "es_emoji" in tk.columns:
        tk = tk[~tk["es_emoji"].astype(bool)]
        
    msg_map_fecha = dict(zip(mensajes["msg_id"].astype(str), pd.to_datetime(mensajes["fecha"]).dt.strftime("%Y-%m-%d")))
    msg_order = dict(zip(mensajes.sort_values(by="fecha")["msg_id"].astype(str), range(len(mensajes))))
    
    docs = []
    for _, r in tk.iterrows():
        mid = str(r["msg_id"])
        if por == "dia":
            docs.append(msg_map_fecha.get(mid, "desconocido"))
        else:
            rank = msg_order.get(mid, 0)
            docs.append(f"w{rank // ventana:05d}")
            
    tk["doc"] = docs
    
    # Filtrar documentos que cumplan min_tokens
    conteos = tk["doc"].value_counts()
    valid_docs = set(conteos[conteos >= min_tokens].index)
    return tk[tk["doc"].isin(valid_docs)].copy()

def matriz_doc_term(tk: pd.DataFrame, min_docs: int = 5, max_prop: float = 0.5) -> Dict[str, Any]:
    """
    Construye la matriz Documento-Término (DTM) filtrando términos raros o excesivamente comunes.
    """
    docs = sorted(tk["doc"].unique())
    nd = len(docs)
    if nd == 0:
        return {"dtm": pd.DataFrame(), "periodo": {}}
        
    # Document frequency
    df_series = tk.groupby("token")["doc"].nunique()
    vocab = sorted(df_series[(df_series >= min_docs) & (df_series <= max_prop * nd)].index)
    
    if not vocab:
        return {"dtm": pd.DataFrame(), "periodo": {}}
        
    sub_tk = tk[tk["token"].isin(set(vocab))]
    crosstab = pd.crosstab(sub_tk["doc"], sub_tk["token"]).reindex(index=docs, columns=vocab, fill_value=0)
    
    # Filtrar filas sin términos
    crosstab = crosstab[crosstab.sum(axis=1) > 0]
    
    # Mapeo de periodo dominante por documento
    periodo_map = {}
    if "periodo_id" in tk.columns:
        for d, grp in tk.groupby("doc"):
            pers = grp["periodo_id"].dropna().value_counts()
            periodo_map[d] = pers.index[0] if len(pers) > 0 else "fuera"
            
    return {"dtm": crosstab, "periodo": periodo_map}

def _nmf_kl(V: np.ndarray, k: int, max_iter: int = 200, seed: int = 1) -> Dict[str, np.ndarray]:
    """
    Implementación determinista de NMF con divergencia Kullback-Leibler (equivalente a pLSA).
    """
    np.random.seed(seed)
    n, p = V.shape
    W = np.random.uniform(0.1, 1.0, (n, k))
    H = np.random.uniform(0.1, 1.0, (k, p))
    
    eps = 1e-9
    for _ in range(max_iter):
        WH = W @ H + eps
        H *= (W.T @ (V / WH)) / (W.sum(axis=0)[:, None] + eps)
        WH = W @ H + eps
        W *= ((V / WH) @ H.T) / (H.sum(axis=1)[None, :] + eps)
        
    rs = H.sum(axis=1, keepdims=True) + eps
    phi = H / rs
    theta = W * rs.T
    theta /= (theta.sum(axis=1, keepdims=True) + eps)
    
    return {"theta": theta, "phi": phi}

def ajustar_temas(
    dtm: pd.DataFrame,
    k: int = 8,
    metodo: str = "auto",
    max_iter: int = 200,
    semilla: int = 1
) -> Dict[str, Any]:
    """
    Ajusta modelo de tópicos mediante LDA o NMF-KL.
    Retorna diccionario con matrices theta (doc-topic) y phi (topic-term).
    """
    if len(dtm) == 0:
        return {"theta": pd.DataFrame(), "phi": pd.DataFrame(), "metodo": metodo}
        
    k = min(k, len(dtm.columns), len(dtm))
    if k < 2:
        k = 2
        
    V = dtm.values.astype(float)
    docs = list(dtm.index)
    vocab = list(dtm.columns)
    
    usar_lda = (metodo == "lda") or (metodo == "auto")
    if usar_lda:
        try:
            from sklearn.decomposition import LatentDirichletAllocation
            lda = LatentDirichletAllocation(
                n_components=k,
                max_iter=max_iter,
                random_state=semilla,
                learning_method="batch"
            )
            theta_arr = lda.fit_transform(V)
            phi_arr = lda.components_ / lda.components_.sum(axis=1)[:, None]
            metodo_usado = "lda"
        except Exception:
            res_nmf = _nmf_kl(V, k, max_iter, semilla)
            theta_arr, phi_arr = res_nmf["theta"], res_nmf["phi"]
            metodo_usado = "nmf"
    else:
        res_nmf = _nmf_kl(V, k, max_iter, semilla)
        theta_arr, phi_arr = res_nmf["theta"], res_nmf["phi"]
        metodo_usado = "nmf"
        
    topic_names = [f"tema_{i+1}" for i in range(k)]
    theta_df = pd.DataFrame(theta_arr, index=docs, columns=topic_names)
    phi_df = pd.DataFrame(phi_arr, index=topic_names, columns=vocab)
    
    return {"theta": theta_df, "phi": phi_df, "metodo": metodo_usado}

def terminos_por_tema(modelo: Dict[str, Any], n: int = 10) -> pd.DataFrame:
    """
    Calcula los términos más distintivos por tema utilizando la métrica term-score de Blei y Lafferty.
    term-score = phi * (log(phi) - mean(log(phi)))
    """
    phi_df = modelo.get("phi")
    if phi_df is None or len(phi_df) == 0:
        return pd.DataFrame(columns=["tema", "rank", "termino"])
        
    phi = phi_df.values + 1e-12
    mean_log_phi = np.mean(np.log(phi), axis=0, keepdims=True)
    ts = phi * (np.log(phi) - mean_log_phi)
    
    vocab = np.array(phi_df.columns)
    filas = []
    for t_idx, t_name in enumerate(phi_df.index):
        top_indices = np.argsort(-ts[t_idx])[:n]
        for rank, idx in enumerate(top_indices, start=1):
            filas.append({
                "tema": t_name,
                "rank": rank,
                "termino": vocab[idx]
            })
    return pd.DataFrame(filas)

def temas_por_periodo(modelo: Dict[str, Any], periodo_map: Dict[str, str]) -> pd.DataFrame:
    """Calcula la proporción promedio de cada tópico desglosada por periodo académico."""
    theta_df = modelo.get("theta")
    if theta_df is None or len(theta_df) == 0:
        return pd.DataFrame()
        
    df = theta_df.copy()
    df["periodo"] = [periodo_map.get(d, "fuera") for d in df.index]
    
    grouped = df.groupby("periodo").mean(numeric_only=True)
    # Normalizar para que sume 1 por fila
    row_sums = grouped.sum(axis=1)
    prop = grouped.div(row_sums, axis=0).round(3)
    return prop
