# -*- coding: utf-8 -*-
"""
Controlador de vistas web para el dashboard de analítica y telemetría.
"""
from flask import render_template, request, jsonify
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
    get_dataset_transformation_samples,
    get_sentiment_comparison_data,
    get_preprocessing_pipeline_data,
    get_emojis_messages_data,
    get_sentimientos_overview_data,
    get_timeline_series_data,
    get_topicos_frecuencia_page_data,
    get_mensajes_por_topico_y_emocion,
    get_mensajes_docente_paginados
)

@web_bp.route("/")
@web_bp.route("/dashboard")
def dashboard_view():
    """
    Renderiza el monitor ejecutivo de analítica y telemetría conectado en vivo
    a Neon Serverless PostgreSQL (TGBase) con procesamiento de PLN avanzado.
    Permite el filtrado dinámico por semestre académico.
    """
    semestre_param = request.args.get("semestre", "").strip()
    gestion_filtro = semestre_param if semestre_param and semestre_param.lower() != "todos" else None

    try:
        kpis = get_dashboard_kpis()
        ranking_docentes = get_top_docentes_ranking(limit=7, gestion_semestre=gestion_filtro)
        directorio_docentes = get_docentes_directory(limit=50, gestion_semestre=gestion_filtro)
        reacciones = get_top_reacciones_telegram(limit=8)
        modalidad = get_modalidad_chat_distribution()
        tendencia = get_tendencia_temporal_resumen()
        neon_status = get_neon_health_telemetry()
        lda_topics = get_lda_topics_summary()
        perfil_emocional = get_perfil_emocional_docentes(limit=8, gestion_semestre=gestion_filtro)
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
        top_tfidf_ciclos=top_tfidf_ciclos,
        semestre_activo=gestion_filtro or "todos",
        gestiones_disponibles=[
            "todos", "2022-II", "2023-I", "2023-II", 
            "2024-I", "2024-II", "2025-I", "2025-II", 
            "2026-I", "2026-II"
        ]
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


@web_bp.route("/periodos")
def periodos_view():
    """
    Renderiza la vista dedicada de Análisis por Periodos e Hitos Académicos
    con gráfico interactivo spline, selector anual/mensual/horario y detección de valles y picos.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    return render_template(
        "dashboard/periodos.html",
        kpis=kpis,
        neon_status=neon_status
    )


@web_bp.route("/preprocesamiento")
def preprocesamiento_view():
    """
    Renderiza el pipeline de preprocesamiento, tokenización, stopwords y shadow linguistic
    con visor interactivo antes/después del dataset.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    prep_data = get_preprocessing_pipeline_data(limit=15)
    return render_template(
        "dashboard/preprocesamiento.html",
        kpis=kpis,
        neon_status=neon_status,
        prep=prep_data
    )


@web_bp.route("/emojis-mensajes")
def emojis_mensajes_view():
    """
    Renderiza el catálogo analítico de emojis, concordancia semántica con el texto
    y diccionario de jergas/modismos estudiantiles de la UMSA con selector dinámico de Top.
    """
    top_param = request.args.get("top", "10").strip().lower()
    if top_param in ["all", "todos", "0"]:
        limit = None
        top_display = "all"
    else:
        try:
            limit = int(top_param)
            top_display = str(limit)
        except ValueError:
            limit = 10
            top_display = "10"

    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    emojis_data = get_emojis_messages_data(limit=limit)
    return render_template(
        "dashboard/emojis_mensajes.html",
        kpis=kpis,
        neon_status=neon_status,
        emojis_info=emojis_data,
        top_seleccionado=top_display
    )


@web_bp.route("/sentimientos")
def sentimientos_view():
    """
    Renderiza el monitor de análisis de sentimientos nativo SentiDataUMSA:
    distribución de polaridad, radar de emociones, señales de intensidad y negaciones.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    sent_data = get_sentimientos_overview_data()
    perfil_emocional = get_perfil_emocional_docentes(limit=8)
    return render_template(
        "dashboard/sentimientos.html",
        kpis=kpis,
        neon_status=neon_status,
        sent=sent_data,
        perfil_emocional=perfil_emocional
    )


@web_bp.route("/comparativa-librerias-ds")
def comparativa_librerias_ds_view():
    """
    Renderiza el benchmark científico: Comparativa Librerías vs DS propio.
    Matriz de confusión 3x3, índice Cohen's Kappa, métricas F1 y explorador de discrepancias.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    benchmark = get_sentiment_comparison_data()
    return render_template(
        "dashboard/comparativa_librerias_ds.html",
        kpis=kpis,
        neon_status=neon_status,
        benchmark=benchmark
    )


@web_bp.route("/importar-datos")
def importar_datos_view():
    """
    Renderiza el laboratorio de ingestión e importación de nuevos exports de Telegram (JSON/CSV)
    con validación sintáctica y ejecución en modo sandbox.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    return render_template(
        "dashboard/importar_datos.html",
        kpis=kpis,
        neon_status=neon_status
    )


@web_bp.route("/topicos-frecuencia")
def topicos_frecuencia_view():
    """
    Renderiza la vista analítica dedicada de Tópicos de Frecuencia (LDA & Term-Prevalence)
    con selector dinámico de tópicos, barras de términos beta/TF-IDF, serie temporal y cruce emocional.
    """
    topic_param = request.args.get("topic", "1").strip()
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()
    data = get_topicos_frecuencia_page_data(selected_topic_id=topic_param)
    return render_template(
        "dashboard/topicos_frecuencia.html",
        kpis=kpis,
        neon_status=neon_status,
        data=data,
        topic_seleccionado=topic_param
    )


@web_bp.route("/api/topicos/mensajes")
def api_topicos_mensajes():
    """
    Endpoint JSON de alto rendimiento para paginación y filtrado dinámico
    de mensajes por tópico y tipo de emoción con botón 'Cargar Más'.
    """
    topico_id = request.args.get("topico_id", "1")
    emocion = request.args.get("emocion", "todos")
    offset = request.args.get("offset", "0")
    limit = request.args.get("limit", "6")

    res = get_mensajes_por_topico_y_emocion(
        topico_id=topico_id,
        emocion=emocion,
        offset=offset,
        limit=limit
    )
    return jsonify(res)


@web_bp.route("/api/docentes/<docente_id>/mensajes")
def api_docente_mensajes(docente_id):
    """
    Endpoint JSON paginado para recuperar mensajes reales y reacciones de Telegram
    asociadas a un docente específico para la ventana modal interactiva.
    """
    offset = request.args.get("offset", "0")
    limit = request.args.get("limit", "6")
    res = get_mensajes_docente_paginados(
        docente_id=docente_id,
        offset=offset,
        limit=limit
    )
    return jsonify(res)# =============================================================================
#  RUTAS — Módulo de 15 Emociones (SQLite local)
# =============================================================================

from database.queries import (
    get_emociones_15_barras,
    get_emociones_15_serie_temporal,
    get_emociones_15_polar,
)
import json as _json
from flask import jsonify as _jsonify


@web_bp.route("/emociones-15")
def emociones_15_view():
    """
    Renderiza el análisis de las 15 emociones del corpus estudiantil.
    Gráficas: barras comparativas, serie temporal filtrable y coordenadas polares.
    Todos los datos provienen de consultas SQL a la base SQLite local.
    """
    kpis = get_dashboard_kpis()
    neon_status = get_neon_health_telemetry()

    # Datos para las 3 gráficas — consultas SQL a SQLite
    barras_data = get_emociones_15_barras()
    polar_data = get_emociones_15_polar()
    # Serie temporal: carga inicial sin filtros (todo el rango)
    serie_data = get_emociones_15_serie_temporal()

    return render_template(
        "dashboard/emociones_15.html",
        kpis=kpis,
        neon_status=neon_status,
        barras=barras_data,
        polar=polar_data,
        serie=serie_data,
        serie_json=_json.dumps(serie_data, ensure_ascii=False),
        barras_json=_json.dumps(barras_data, ensure_ascii=False),
        polar_json=_json.dumps(polar_data, ensure_ascii=False),
    )


@web_bp.route("/api/emociones-15/serie")
def api_emociones_15_serie():
    """
    API JSON para actualizar la serie temporal de emociones con filtros dinámicos.
    Parámetros GET: fecha_inicio, fecha_fin, emociones (separadas por coma).
    """
    fecha_inicio = request.args.get("fecha_inicio", "").strip() or None
    fecha_fin = request.args.get("fecha_fin", "").strip() or None
    emociones_raw = request.args.get("emociones", "").strip()
    emociones_filtro = [e.strip() for e in emociones_raw.split(",") if e.strip()] or None

    data = get_emociones_15_serie_temporal(
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        emociones_filtro=emociones_filtro,
    )
    return _jsonify(data)
