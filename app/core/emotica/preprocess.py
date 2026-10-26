# -*- coding: utf-8 -*-
"""
Orquestador maestro del pipeline de preprocesamiento, anonimización y tokenización.
Garantiza paridad estricta con emotica/R/preprocess.R (todos los pasos auditados en bitácora).
"""

import time
from pathlib import Path
from typing import Dict, Any, Optional, Union
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_yaml
from app.core.emotica.bitacora import bitacora_iniciar, bitacora_registrar, bitacora_leer, bitacora_guardar, ejecutar_paso
from app.core.emotica.ingest import ingest_chat
from app.core.emotica.schema import parse_fecha
from app.core.emotica.pii import anonimizar_autores, enmascarar_pii
from app.core.emotica.clean import limpiar_texto, detectar_idioma
from app.core.emotica.anuncios import marcar_anuncios
from app.core.emotica.periods import asignar_periodo, cargar_seasons
from app.core.emotica.tokens import tokenizar_mensajes, cargar_conservar_siempre

def cargar_config() -> Dict[str, Any]:
    """Carga config/preprocess.yml y config/seasons.yml."""
    f_prep = ruta_recurso("config", "preprocess.yml")
    p_dict = leer_yaml(f_prep) if f_prep.exists() else {}
    return {
        "params": p_dict.get("params", p_dict),
        "seasons": cargar_seasons()
    }

def preprocess_chat(
    path: Union[str, Path],
    adapter: str = "auto",
    mapping: Optional[Dict[str, str]] = None,
    config: Optional[Dict[str, Any]] = None,
    sal: Optional[str] = None,
    salida: Optional[Union[str, Path]] = None,
    usuario: Optional[str] = None
) -> Dict[str, Any]:
    """
    Pipeline de preprocesamiento completo:
    1. Ingesta agnóstica
    2. Filtrado de eventos de servicio
    3. Normalización temporal multiformato
    4. Desduplicación por clave única
    5. Anonimización de autores con sal (SHA-256)
    6. Enmascaramiento PII
    7. Limpieza textual y extracción de emojis
    8. Detección automática de idioma
    9. Marcado de anuncios/spam
    10. Asignación de periodos y temporadas
    11. Tokenización posicional
    """
    cfg = config or cargar_config()
    tz = cfg.get("params", {}).get("zona_horaria", "UTC")
    
    # Iniciar bitácora
    bitacora_iniciar(path, usuario=usuario)
    
    # 1. Ingesta
    df = ingest_chat(path, adapter=adapter, mapping=mapping)
    adapter_detectado = df.attrs.get("adaptador", adapter)
    
    # 2. Filtrar eventos de servicio
    def _paso_servicio(d: pd.DataFrame) -> pd.DataFrame:
        if "tipo" not in d.columns:
            return d
        mask_valida = d["tipo"].isna() | (d["tipo"] == "message")
        out = d[mask_valida].copy()
        out.attrs["detalle"] = f"eliminados {len(d) - len(out)} eventos que no son mensajes"
        return out
    df = ejecutar_paso("filtrar_eventos_de_servicio", df, _paso_servicio)
    
    # 3. Normalizar fechas
    def _paso_fechas(d: pd.DataFrame) -> pd.DataFrame:
        pf = parse_fecha(d["fecha"], tz=tz)
        d_out = d.copy()
        d_out["fecha"] = pf["fecha"]
        validas = d_out["fecha"].notna()
        out = d_out[validas].copy()
        aviso_amb = "; AVISO: dia/mes ambiguo, se asumio dia primero" if pf.get("ambiguo") else ""
        out.attrs["detalle"] = f"formato={pf.get('formato')}; tasa={pf.get('tasa', 0.0):.3f}; sin fecha valida={len(d) - len(out)}{aviso_amb}"
        return out
    df = ejecutar_paso("normalizar_fechas", df, _paso_fechas, {"zona": tz})
    
    # 4. Eliminar duplicados
    def _paso_duplicados(d: pd.DataFrame) -> pd.DataFrame:
        if adapter_detectado == "telegram" and "msg_id" in d.columns:
            clave = d["msg_id"].astype(str)
            clave_tipo = "msg_id"
        else:
            autor_col = d["autor"].fillna("") if "autor" in d.columns else pd.Series([""] * len(d))
            clave = d["fecha"].astype(str) + "|" + autor_col.astype(str) + "|" + d["texto"].fillna("").astype(str)
            clave_tipo = "fecha+autor+texto"
            
        dup_mask = clave.duplicated()
        out = d[~dup_mask].copy()
        out.attrs["detalle"] = f"duplicados={int(dup_mask.sum())} (clave={clave_tipo})"
        return out
    df = ejecutar_paso("eliminar_duplicados", df, _paso_duplicados)
    
    # 5. Anonimizar autores (SHA-256 + sal)
    df = ejecutar_paso("anonimizar_autores", df, lambda d: anonimizar_autores(d, sal=sal), {"algoritmo": "sha256+sal"})
    
    # 6. Enmascarar PII
    df = ejecutar_paso("enmascarar_pii", df, enmascarar_pii, {"patrones": ["URL", "EMAIL", "USUARIO", "NUM_ID"]})
    
    # 7. Limpieza textual
    df = ejecutar_paso("limpiar_texto", df, limpiar_texto)
    
    # 8. Detectar idioma
    umbral_id = float(cfg.get("params", {}).get("umbral_idioma", 0.10))
    id_res = detectar_idioma(df["texto_limpio"], umbral=umbral_id)
    df["idioma"] = id_res["idioma"]
    frac_str = ", ".join(f"{k}={v}" for k, v in id_res["fracciones"].items())
    bitacora_registrar(
        paso="detectar_idioma",
        parametros={"umbral": umbral_id},
        filas_entrada=len(df),
        filas_salida=len(df),
        detalle=f"idioma={id_res['idioma']}; fracciones de stopwords: {frac_str}"
    )
    
    # 9. Marcar anuncios
    df = ejecutar_paso(
        "marcar_anuncios",
        df,
        lambda d: marcar_anuncios(d, config=cfg, idioma=id_res["idioma"]),
        {"umbral": cfg.get("params", {}).get("anuncios", {}).get("umbral", 2)}
    )
    
    # 10. Asignar periodos
    def _paso_periodos(d: pd.DataFrame) -> pd.DataFrame:
        p_df = asignar_periodo(d["fecha"], seasons=cfg.get("seasons"))
        d_out = d.copy()
        d_out["temporada"] = p_df["temporada"].values
        d_out["ciclo"] = p_df["ciclo"].values
        d_out["periodo_id"] = p_df["periodo_id"].values
        tb = d_out["periodo_id"].value_counts().to_dict()
        d_out.attrs["detalle"] = "; ".join(f"{k}={v}" for k, v in tb.items())
        return d_out
    temporadas_ids = [s.get("id") for s in cfg.get("seasons", [])]
    df = ejecutar_paso("asignar_periodos", df, _paso_periodos, {"temporadas": temporadas_ids})
    
    # Reordenar columnas canónicas
    cols_can = ["msg_id", "fecha", "autor_hash", "texto", "texto_limpio", "idioma", "responde_a", "periodo_id"]
    cols_existentes = [c for c in cols_can if c in df.columns]
    cols_resto = [c for c in df.columns if c not in cols_existentes and c != "tipo"]
    df = df[cols_existentes + cols_resto].copy()
    
    # 11. Tokenización
    t0_tok = time.perf_counter()
    conservar_sw = cfg.get("params", {}).get("conservar_siempre", cargar_conservar_siempre())
    tok = tokenizar_mensajes(df, col="texto_limpio", idioma=id_res["idioma"], conservar=conservar_sw)
    dur_tok = time.perf_counter() - t0_tok
    
    sw_cnt = int(tok["es_stopword"].sum()) if len(tok) else 0
    em_cnt = int(tok["es_emoji"].sum()) if len(tok) else 0
    bitacora_registrar(
        paso="tokenizar",
        parametros={"columna": "texto_limpio"},
        filas_entrada=int(df["tiene_texto"].sum()),
        filas_salida=len(tok),
        detalle=f"filas_salida = tokens; stopwords marcadas={sw_cnt}; emojis={em_cnt}",
        duracion_s=dur_tok
    )
    
    resultado = {
        "mensajes": df,
        "tokens": tok,
        "bitacora": bitacora_leer(),
        "idioma": id_res
    }
    
    # Guardar en disco si se solicitó ruta de salida
    if salida:
        dir_out = Path(salida)
        dir_out.mkdir(parents=True, exist_ok=True)
        df.to_csv(dir_out / "mensajes.csv", index=False, encoding="utf-8")
        tok.to_csv(dir_out / "tokens.csv", index=False, encoding="utf-8")
        bitacora_guardar(dir_out / "bitacora_auto.csv")
        
    return resultado
