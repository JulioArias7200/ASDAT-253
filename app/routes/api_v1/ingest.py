# -*- coding: utf-8 -*-
"""
Controlador de API v1 para la ingesta de datos, subida de paquetes Telegram (ZIP o carpeta)
y ejecución del pipeline analítico emotica en Python.
"""

import os
import shutil
import tempfile
import zipfile
from pathlib import Path
from typing import Dict, Any, List, Optional
import pandas as pd
from flask import request, jsonify
from app.routes.api_v1 import api_v1_bp
from app.core.emotica import (
    preprocess_chat,
    score_emotions,
    cobertura_emociones,
    resumen_por_periodo
)
from database.emotica_neon import comparar_chat_con_baseline_neon


def calcular_timeline_chat(mensajes_df: pd.DataFrame) -> Dict[str, Any]:
    """
    Calcula la serie temporal de actividad del chat en memoria:
    granularidades mensual, semanal y horaria (24h) con detección de picos y caídas.
    Operación 100% en memoria en Python (cero escrituras en Neon).
    """
    if mensajes_df.empty or "fecha" not in mensajes_df.columns:
        return {"status": "empty", "granularidades": {}}

    try:
        fechas = pd.to_datetime(mensajes_df["fecha"], errors="coerce")
        validas = fechas.notna()
        if not validas.any():
            return {"status": "empty", "granularidades": {}}

        df_t = mensajes_df[validas].copy()
        df_t["_dt"] = fechas[validas]

        # Detección de preguntas académicas
        if "n_questions" in df_t.columns:
            es_pregunta = df_t["n_questions"] > 0
        else:
            text_col = "texto" if "texto" in df_t.columns else "texto_limpio"
            es_pregunta = df_t[text_col].astype(str).str.contains(r"\?", regex=True)
        df_t["_es_pregunta"] = es_pregunta

        min_fecha = df_t["_dt"].min()
        max_fecha = df_t["_dt"].max()
        duracion_dias = max(1, (max_fecha - min_fecha).days)

        def _construir_puntos(serie_periodos, formato_label):
            df_grp = df_t.groupby(serie_periodos).agg(
                total=("_dt", "count"),
                preguntas=("_es_pregunta", "sum")
            ).reset_index()

            points = []
            for _, row in df_grp.iterrows():
                key = row.iloc[0]
                lbl = formato_label(key)
                tot = int(row["total"])
                preg = int(row["preguntas"])
                points.append({
                    "label": lbl,
                    "total": tot,
                    "preguntas": preg,
                    "pct_preguntas": round(100.0 * preg / max(tot, 1), 1)
                })

            if not points:
                return None

            tot_periodo = sum(p["total"] for p in points)
            tot_preg = sum(p["preguntas"] for p in points)
            pico = max(points, key=lambda x: x["total"])
            caida = min(points, key=lambda x: x["total"])
            promedio = round(tot_periodo / max(len(points), 1), 1)

            return {
                "kpis": {
                    "total_periodo": tot_periodo,
                    "total_preguntas": tot_preg,
                    "pct_preguntas": round(100.0 * tot_preg / max(tot_periodo, 1), 1),
                    "pico_maximo": {"label": pico["label"], "total": pico["total"]},
                    "caida_minima": {"label": caida["label"], "total": caida["total"]},
                    "promedio": promedio,
                    "num_puntos": len(points)
                },
                "points": points
            }

        # Remover zona horaria para operaciones de período limpias sin advertencias
        dt_naive = df_t["_dt"].dt.tz_localize(None) if hasattr(df_t["_dt"].dt, "tz") and df_t["_dt"].dt.tz is not None else df_t["_dt"]

        # 1. Mensual (YYYY-MM)
        monthly_res = _construir_puntos(
            dt_naive.dt.to_period("M"),
            lambda p: str(p)
        )

        # 2. Semanal (Sem XX/YY)
        weekly_res = _construir_puntos(
            dt_naive.dt.to_period("W"),
            lambda p: f"Sem {p.strftime('%W/%y')}"
        )

        # 3. Horario 24 Horas (00:00 - 23:00)
        hourly_res = _construir_puntos(
            df_t["_dt"].dt.hour,
            lambda h: f"{int(h):02d}:00"
        )
        if hourly_res:
            map_hourly = {p["label"]: p for p in hourly_res["points"]}
            puntos_completos = []
            for h in range(24):
                lbl = f"{h:02d}:00"
                if lbl in map_hourly:
                    puntos_completos.append(map_hourly[lbl])
                else:
                    puntos_completos.append({"label": lbl, "total": 0, "preguntas": 0, "pct_preguntas": 0.0})
            hourly_res["points"] = puntos_completos

        default_gran = "monthly" if (monthly_res and len(monthly_res["points"]) >= 3) else ("weekly" if (weekly_res and len(weekly_res["points"]) >= 3) else "hourly")

        return {
            "status": "success",
            "fecha_inicio": min_fecha.strftime("%Y-%m-%d"),
            "fecha_fin": max_fecha.strftime("%Y-%m-%d"),
            "duracion_dias": duracion_dias,
            "default_granularity": default_gran,
            "granularidades": {
                "monthly": monthly_res,
                "weekly": weekly_res,
                "hourly": hourly_res
            }
        }
    except Exception as e:
        return {
            "status": "warning",
            "message": f"No se pudo calcular la serie temporal: {str(e)}",
            "granularidades": {}
        }

@api_v1_bp.route("/ingest/upload", methods=["POST"])
def upload_chat_dataset():
    """
    Recibe la exportación de chat (archivo .ZIP o conjunto de archivos de carpeta).
    Valida la estructura (result.json + photos/ + stickers/ + video_files/),
    ejecuta el preprocesamiento y el motor de 15 emociones en Python nativo,
    y retorna la telemetría completa para la interfaz web.
    """
    archivos = request.files.getlist("files")
    if not archivos:
        # Intentar con campo singular 'file'
        f_single = request.files.get("file")
        if f_single:
            archivos = [f_single]
            
    if not archivos:
        return jsonify({"status": "error", "message": "No se recibieron archivos en la solicitud."}), 400
        
    temp_dir = Path(tempfile.mkdtemp(prefix="sentidata_upload_"))
    
    try:
        # 1. Caso A: Archivo ZIP único
        if len(archivos) == 1 and archivos[0].filename.lower().endswith(".zip"):
            zip_target = temp_dir / "paquete.zip"
            archivos[0].save(zip_target)
            
            with zipfile.ZipFile(zip_target, "r") as z:
                z.extractall(temp_dir)
            zip_target.unlink()
        else:
            # 2. Caso B: Múltiples archivos preservando estructura relativa de carpetas
            for arch in archivos:
                rel_path = arch.filename.replace("\\", "/").lstrip("/")
                dest_path = temp_dir / rel_path
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                arch.save(dest_path)
                
        # 3. Localizar archivo de corpus central
        result_json_candidatos = list(temp_dir.rglob("result.json"))
        csv_candidatos = list(temp_dir.rglob("*.csv"))
        txt_candidatos = list(temp_dir.rglob("*.txt"))
        
        if result_json_candidatos:
            target_chat_file = result_json_candidatos[0]
            adapter = "telegram"
        elif csv_candidatos:
            target_chat_file = csv_candidatos[0]
            adapter = "csv"
        elif txt_candidatos:
            target_chat_file = txt_candidatos[0]
            adapter = "whatsapp"
        else:
            return jsonify({
                "status": "error",
                "message": (
                    "Estructura inválida: No se encontró 'result.json' ni ningún archivo "
                    "CSV o TXT compatible en el paquete subido."
                )
            }), 400
            
        # 4. Inventario de carpetas y archivos multimedia
        base_folder = target_chat_file.parent
        dir_photos = base_folder / "photos"
        dir_stickers = base_folder / "stickers"
        dir_videos = base_folder / "video_files"
        
        n_fotos = len(list(dir_photos.glob("*"))) if dir_photos.exists() else 0
        n_stickers = len(list(dir_stickers.glob("*"))) if dir_stickers.exists() else 0
        n_videos = len(list(dir_videos.glob("*"))) if dir_videos.exists() else 0
        
        # 5. Ejecutar pipeline de emotica en Python
        res_prep = preprocess_chat(target_chat_file, adapter=adapter, usuario="web_dashboard")
        mensajes_df = res_prep["mensajes"]
        tokens_df = res_prep["tokens"]
        bitacora_df = res_prep["bitacora"]
        idioma_info = res_prep["idioma"]
        
        # 6. Ejecutar motor de 15 emociones en Python
        scores_df = score_emotions(mensajes_df)
        cob = cobertura_emociones(scores_df, mensajes_df)
        
        # 7. Estadísticas agregadas
        total_msgs = len(mensajes_df)
        n_con_texto = cob["mensajes_con_texto"]
        cobertura_pct = round(100.0 * cob["cobertura"], 1)
        
        # Top emociones dominantes
        top_emociones = []
        if len(scores_df) > 0:
            dom = scores_df.sort_values(by=["msg_id", "puntaje"], ascending=[True, False]).drop_duplicates(subset=["msg_id"])
            conteo_dom = dom["emocion_id"].value_counts()
            for emo, cnt in conteo_dom.head(6).items():
                top_emociones.append({
                    "emocion": emo,
                    "conteo": int(cnt),
                    "pct": round(100.0 * cnt / max(1, len(dom)), 1)
                })
                
        # 8. Muestras antes vs después
        muestras = []
        sub_sample = mensajes_df[mensajes_df["texto_limpio"].str.len() >= 10].head(8)
        
        # Mapear evidencia de emoción si existe
        mapa_evid = {}
        if len(scores_df) > 0:
            dom_scores = scores_df.sort_values(by=["msg_id", "puntaje"], ascending=[True, False]).drop_duplicates(subset=["msg_id"])
            for _, r in dom_scores.iterrows():
                mapa_evid[r["msg_id"]] = {
                    "emocion": r["emocion_id"],
                    "intensidad": r["intensidad"],
                    "nivel": r["nivel"],
                    "evidencia": r["evidencia"]
                }
                
        for _, r in sub_sample.iterrows():
            mid = str(r["msg_id"])
            orig = str(r.get("texto", "") or "")
            norm = str(r.get("texto_limpio", "") or "")
            info_emo = mapa_evid.get(mid, {"emocion": "neutro/sin_emocion", "nivel": "neutro", "evidencia": "sin_evidencia"})
            
            muestras.append({
                "msg_id": mid,
                "texto_original": orig[:120] + ("..." if len(orig) > 120 else ""),
                "texto_limpio": norm[:120] + ("..." if len(norm) > 120 else ""),
                "len_orig": len(orig),
                "len_norm": len(norm),
                "reduccion": max(0, len(orig) - len(norm)),
                "emocion": info_emo["emocion"],
                "nivel": info_emo["nivel"],
                "evidencia": info_emo["evidencia"]
            })
            
        # 9. Bitácora de pasos en formato estructurado
        bitacora_pasos = []
        for _, b in bitacora_df.iterrows():
            bitacora_pasos.append({
                "paso": b["paso"],
                "filas_entrada": int(b["filas_entrada"]) if pd.notna(b["filas_entrada"]) else "-",
                "filas_salida": int(b["filas_salida"]) if pd.notna(b["filas_salida"]) else "-",
                "duracion_s": float(b["duracion_s"]) if pd.notna(b["duracion_s"]) else 0.0,
                "detalle": str(b.get("detalle", ""))
            })
            
        # 10. Diagnóstico Comparativo Read-Only vs Corpus Histórico Neon
        try:
            comparativa_neon = comparar_chat_con_baseline_neon(mensajes_df, scores_df)
        except Exception as e_cmp:
            comparativa_neon = {
                "status": "warning",
                "message": f"No se pudo consultar el baseline de Neon: {str(e_cmp)}"
            }

        # 11. Serie Temporal del Chat en Memoria (Opción 1: Spline idéntico a Periodos)
        timeline_chat = calcular_timeline_chat(mensajes_df)

        return jsonify({
            "status": "success",
            "archivo": target_chat_file.name,
            "tipo_adaptador": adapter,
            "total_mensajes": total_msgs,
            "mensajes_con_texto": n_con_texto,
            "idioma_detectado": idioma_info["idioma"],
            "multimedia": {
                "fotos": n_fotos,
                "stickers": n_stickers,
                "videos": n_videos
            },
            "cobertura_emocional_pct": cobertura_pct,
            "top_emociones": top_emociones,
            "muestras": muestras,
            "bitacora_pasos": bitacora_pasos,
            "comparativa_neon": comparativa_neon,
            "timeline": timeline_chat
        })
        
    except Exception as e:
        return jsonify({"status": "error", "message": f"Error al procesar el chat: {str(e)}"}), 500
    finally:
        # Limpiar carpeta temporal
        shutil.rmtree(temp_dir, ignore_errors=True)

