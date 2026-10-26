# -*- coding: utf-8 -*-
"""
Módulo de ingesta agnóstica para Telegram (JSON), WhatsApp (TXT), CSV y archivos ZIP.
Garantiza paridad con emotica/R/ingest.R y añade soporte completo para exportaciones multimedia.
"""

import os
import re
import json
import zipfile
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Any, Union, Tuple
import pandas as pd
from app.core.emotica.schema import detectar_esquema
from app.core.emotica.bitacora import bitacora_registrar

def detectar_adaptador(path: Union[str, Path]) -> str:
    """Detecta el tipo de archivo según extensión."""
    ext = Path(path).suffix.lower().lstrip(".")
    if ext == "json":
        return "telegram"
    if ext in ["csv", "tsv"]:
        return "csv"
    if ext == "txt":
        return "whatsapp"
    if ext == "zip":
        return "zip"
    raise ValueError(f"Formato no reconocido: .{ext}. Use json (Telegram), txt (WhatsApp), csv o zip.")

def aplanar_texto_telegram(t: Any) -> str:
    """Aplana el campo text de Telegram (que puede ser string o lista de strings/objetos enriquecidos)."""
    if t is None:
        return ""
    if isinstance(t, str):
        return t
    if isinstance(t, list):
        partes = []
        for p in t:
            if isinstance(p, str):
                partes.append(p)
            elif isinstance(p, dict):
                partes.append(str(p.get("text", "") or ""))
            else:
                partes.append(str(p or ""))
        return "".join(partes)
    return str(t)

def leer_telegram(path: Union[str, Path], base_dir: Optional[Union[str, Path]] = None) -> pd.DataFrame:
    """Lee y transforma el archivo result.json de Telegram al esquema canónico."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        data = json.load(f)
        
    messages = data.get("messages")
    if messages is None:
        raise ValueError("El JSON no tiene el campo 'messages': no parece una exportacion de Telegram Desktop.")
        
    directorio_base = Path(base_dir) if base_dir else Path(path).parent
    
    filas = []
    for m in messages:
        # Reacciones
        reac = m.get("reactions")
        total_reac = sum(int(z.get("count", 0)) for z in reac) if isinstance(reac, list) else 0
        
        # Fotos y multimedia
        foto_ref = m.get("photo")
        file_ref = m.get("file")
        media_type = m.get("media_type") or m.get("mime_type")
        
        # Sticker
        es_sticker = bool(media_type == "sticker" or (isinstance(file_ref, str) and "sticker" in file_ref))
        
        filas.append({
            "msg_id": str(m.get("id", "")),
            "fecha": str(m.get("date", "")),
            "autor_id": str(m.get("from_id", "")) if m.get("from_id") else None,
            "autor": str(m.get("from", "")) if m.get("from") else None,
            "texto": aplanar_texto_telegram(m.get("text")),
            "responde_a": str(m.get("reply_to_message_id", "")) if m.get("reply_to_message_id") else None,
            "tipo": str(m.get("type", "message")),
            "tiene_foto": bool(foto_ref is not None),
            "tipo_media": media_type,
            "reenviado": bool(m.get("forwarded_from") is not None),
            "editado": bool(m.get("edited") is not None),
            "reacciones_total": total_reac,
            "ruta_foto": str(directorio_base / foto_ref) if foto_ref else None,
            "es_sticker": es_sticker
        })
        
    df = pd.DataFrame(filas)
    df.attrs["detalle"] = f"mensajes={len(df)}; fotos={df['tiene_foto'].sum()}; stickers={df['es_sticker'].sum()}"
    return df

def leer_whatsapp(path: Union[str, Path]) -> pd.DataFrame:
    """Lee y parsea un chat exportado de WhatsApp (.txt)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lineas = [l.rstrip("\r\n") for l in f]
        
    # Limpiar caracteres invisibles de dirección LTR/RTL
    lineas = [re.sub(r"[\u200E\u200F\u202F]", " ", l) for l in lineas]
    
    # Patrón estándar de mensaje de WhatsApp
    patron = re.compile(
        r"^\[?(\d{1,4}[/.-]\d{1,2}[/.-]\d{1,4}),?\s+(\d{1,2}:\d{2}(?::\d{2})?(?:\s?[AaPp]\.?\s?[Mm]\.?)?)\]?\s*[-–]?\s*([^:]{1,60}?):\s(.*)$"
    )
    
    mensajes = []
    fecha_actual = None
    autor_actual = None
    texto_actual = []
    msg_counter = 1
    
    for l in lineas:
        m = patron.match(l)
        if m:
            if fecha_actual is not None:
                mensajes.append({
                    "msg_id": str(msg_counter),
                    "fecha": fecha_actual,
                    "autor_id": None,
                    "autor": autor_actual,
                    "texto": "\n".join(texto_actual),
                    "responde_a": None,
                    "tipo": "message"
                })
                msg_counter += 1
            f_str, h_str, aut, txt = m.groups()
            fecha_actual = f"{f_str.replace('.', '/').replace('-', '/')} {h_str}"
            autor_actual = aut.strip()
            texto_actual = [txt]
        else:
            if fecha_actual is not None:
                texto_actual.append(l)
                
    if fecha_actual is not None:
        mensajes.append({
            "msg_id": str(msg_counter),
            "fecha": fecha_actual,
            "autor_id": None,
            "autor": autor_actual,
            "texto": "\n".join(texto_actual),
            "responde_a": None,
            "tipo": "message"
        })
        
    df = pd.DataFrame(mensajes)
    df.attrs["detalle"] = f"mensajes={len(df)}; autores={df['autor'].nunique() if len(df) else 0}"
    return df

def leer_csv_generico(path: Union[str, Path], mapping: Optional[Dict[str, str]] = None) -> pd.DataFrame:
    """Lee un CSV genérico con detección automática de delimitador y codificación."""
    p = Path(path)
    
    # Detección de delimitador por línea 1
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        l1 = f.readline()
    conteos = {sep: l1.count(sep) for sep in [",", ";", "\t", "|"]}
    delim = max(conteos, key=conteos.get) if any(conteos.values()) else ","
    
    df = pd.read_csv(p, sep=delim, dtype=str, encoding="utf-8", errors="replace").fillna("")
    
    esq = detectar_esquema(df)
    mp = dict(esq["mapping"])
    if mapping:
        mp.update(mapping)
        
    faltan = [c for c in ["texto", "fecha"] if c not in mp]
    if faltan:
        disponibles = ", ".join(df.columns)
        raise ValueError(
            f"No pude identificar la(s) columna(s): {', '.join(faltan)}. "
            f"Columnas disponibles: {disponibles}. "
            "Indique el mapeo con mapping={'texto': '...', 'fecha': '...'}"
        )
        
    col_id = mp.get("id")
    id_series = df[col_id] if col_id and col_id in df.columns else pd.Series(range(1, len(df) + 1), dtype=str)
    
    out = pd.DataFrame({
        "msg_id": id_series.astype(str),
        "fecha": df[mp["fecha"]],
        "autor_id": None,
        "autor": df[mp["autor"]] if "autor" in mp and mp["autor"] in df.columns else None,
        "texto": df[mp["texto"]],
        "responde_a": df[mp["responde_a"]] if "responde_a" in mp and mp["responde_a"] in df.columns else None,
        "tipo": "message"
    })
    
    det = f"separador={repr(delim)}; mapeo={mp}; confianza={esq['confianza']}"
    out.attrs["detalle"] = det
    return out

def extraer_paquete_zip(zip_path: Union[str, Path]) -> Tuple[Path, str]:
    """Extrae un archivo ZIP en un directorio temporal y localiza el archivo principal."""
    p = Path(zip_path)
    temp_dir = Path(tempfile.mkdtemp(prefix="emotica_zip_"))
    
    with zipfile.ZipFile(p, "r") as z:
        z.extractall(temp_dir)
        
    # Buscar result.json o similar en la raíz o subdirectorios
    jsons = list(temp_dir.rglob("result.json"))
    if jsons:
        return jsons[0], "telegram"
    csvs = list(temp_dir.rglob("*.csv"))
    if csvs:
        return csvs[0], "csv"
    txts = list(temp_dir.rglob("*.txt"))
    if txts:
        return txts[0], "whatsapp"
        
    raise ValueError("El archivo .ZIP no contiene result.json, ni ningún CSV o TXT válido.")

def ingest_chat(
    path: Union[str, Path],
    adapter: str = "auto",
    mapping: Optional[Dict[str, str]] = None
) -> pd.DataFrame:
    """Punto de entrada principal para la ingesta agnóstica de chats."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"No existe el archivo: {p}")
        
    if adapter == "auto":
        adapter = detectar_adaptador(p)
        
    t0 = time.perf_counter()
    
    if adapter == "zip":
        real_path, sub_adapter = extraer_paquete_zip(p)
        base_dir = real_path.parent
        df = leer_telegram(real_path, base_dir=base_dir) if sub_adapter == "telegram" else (
            leer_whatsapp(real_path) if sub_adapter == "whatsapp" else leer_csv_generico(real_path, mapping)
        )
    elif adapter == "telegram":
        df = leer_telegram(p)
    elif adapter == "whatsapp":
        df = leer_whatsapp(p)
    elif adapter == "csv":
        df = leer_csv_generico(p, mapping)
    else:
        raise ValueError(f"Adaptador desconocido: {adapter}")
        
    duracion = time.perf_counter() - t0
    detalle = df.attrs.get("detalle", "")
    
    bitacora_registrar(
        paso="lectura_archivo",
        parametros={"adaptador": adapter, "archivo": p.name, "bytes": p.stat().st_size},
        filas_entrada=None,
        filas_salida=len(df),
        detalle=detalle,
        duracion_s=duracion
    )
    df.attrs["adaptador"] = adapter
    return df
