# -*- coding: utf-8 -*-
"""
Controlador de vistas web para el dashboard de analítica y telemetría.
"""
from flask import render_template
from app.routes.web import web_bp
from database.queries import (
    get_dashboard_kpis,
    get_top_docentes_ranking,
    get_docentes_directory,
    get_top_reacciones_telegram,
    get_modalidad_chat_distribution,
    get_tendencia_temporal_resumen,
    get_neon_health_telemetry,
    get_lda_topics_summary,
    get_perfil_emocional_docentes,
    get_nlp_kpis_summary,
    get_tfidf_keywords,
    get_bitacora_reciente,
    get_bitacora_kpis,
    get_bitacora_procesos_mineria,
    get_dataset_transformations_lineage,
    get_dataset_transformation_samples
)

@web_bp.route("/")
@web_bp.route("/dashboard")
def dashboard_view():
    """
    Renderiza el monitor ejecutivo de analítica y telemetría conectado en vivo
    a Neon Serverless PostgreSQL (TGBase) con procesamiento de PLN avanzado.
    """
    try:
        kpis = get_dashboard_kpis()
        ranking_docentes = get_top_docentes_ranking(limit=7)
        directorio_docentes = get_docentes_directory(limit=50)
        reacciones = get_top_reacciones_telegram(limit=8)
        modalidad = get_modalidad_chat_distribution()
        tendencia = get_tendencia_temporal_resumen()
        neon_status = get_neon_health_telemetry()
        lda_topics = get_lda_topics_summary()
        perfil_emocional = get_perfil_emocional_docentes(limit=8)
        nlp_kpis = get_nlp_kpis_summary()
        top_tfidf_docentes = get_tfidf_keywords(entidad_tipo="DOCENTE", limit=12)
        top_tfidf_ciclos = get_tfidf_keywords(entidad_tipo="CICLO", limit=12)
    except Exception as e:
        # Fallback defensivo
        kpis = {
            "total_mensajes": 23462, "usuarios_unicos": 2054, "promedio_msgs_usuario": 11.4,
            "total_docentes": 85, "total_materias": 158, "total_menciones": 3734, "total_paralelos": 267,
            "total_multimodal": 4919, "total_ocr": 1782, "total_gifs": 24, "total_reacciones": 2575,
            "total_modismos": 538
        }
        ranking_docentes = []
        directorio_docentes = []
        reacciones = []
        modalidad = {
            "total": 23462, "texto_puro": 16400, "ocr": 1782, "preguntas": 3100, "stickers": 2180,
            "pct_texto": 69.9, "pct_ocr": 7.6, "pct_preguntas": 13.2, "pct_stickers": 9.3,
            "len_texto": 439.2, "len_preguntas": 82.9, "len_ocr": 47.8, "len_stickers": 58.4,
            "off_preguntas": -439.2, "off_ocr": -522.1, "off_stickers": -569.9
        }
        tendencia = []
        neon_status = {
            "status": f"Reconectando ({e})", "engine": "Neon Serverless PostgreSQL",
            "version": "PostgreSQL 18.6", "database": "TGBase", "region": "sa-east-1",
            "size": "N/A", "tables_count": 14, "views_count": 4
        }
        lda_topics = []
        perfil_emocional = []
        nlp_kpis = {}
        top_tfidf_docentes = []
        top_tfidf_ciclos = []

    return render_template(
        "dashboard/index.html",
        kpis=kpis,
        ranking_docentes=ranking_docentes,
        directorio_docentes=directorio_docentes,
        reacciones=reacciones,
        modalidad=modalidad,
        tendencia=tendencia,
        neon_status=neon_status,
        lda_topics=lda_topics,
        perfil_emocional=perfil_emocional,
        nlp_kpis=nlp_kpis,
        top_tfidf_docentes=top_tfidf_docentes,
        top_tfidf_ciclos=top_tfidf_ciclos
    )

@web_bp.route("/bitacora")
def bitacora_view():
    """
    Renderiza el centro de comando de la bitácora y auditoría en tiempo real (CDC)
    con segmentación por cambios de valor, altas y lotes de minería sobre Neon PostgreSQL.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    kpis_bitacora = get_bitacora_kpis()
    modificaciones = get_bitacora_reciente(limit=100, solo_modificaciones=True)
    altas = get_bitacora_reciente(limit=100, operacion='INSERT')
    lotes = get_bitacora_procesos_mineria(limit=20)
    eventos = get_bitacora_reciente(limit=100)
    lineage_etapas = get_dataset_transformations_lineage()
    muestreo_dataset = get_dataset_transformation_samples(limit=12)
    
    return render_template(
        "dashboard/bitacora.html",
        kpis=kpis,
        neon_status=neon_status,
        kpis_bitacora=kpis_bitacora,
        modificaciones=modificaciones,
        altas=altas,
        lotes=lotes,
        eventos=eventos,
        lineage_etapas=lineage_etapas,
        muestreo_dataset=muestreo_dataset
    )


