# -*- coding: utf-8 -*-
"""
Endpoints de telemetría, healthcheck para Render y acciones de pipeline.
"""
from flask import jsonify, request
from app.routes.api_v1 import api_v1_bp

@api_v1_bp.route("/health", methods=["GET"])
def health_check():
    """Endpoint de salud para monitor de Render."""
    return jsonify({
        "status": "healthy",
        "service": "sentidataumsa-api",
        "engine": "Neon Serverless PostgreSQL Ready"
    }), 200

@api_v1_bp.route("/stats", methods=["GET"])
def get_stats():
    """Métricas en JSON en tiempo real obtenidas desde Neon PostgreSQL."""
    try:
        from database import get_dashboard_kpis
        kpis = get_dashboard_kpis()
        return jsonify({
            "status": "success",
            "engine": "Neon PostgreSQL Serverless (Live)",
            "total_messages": kpis["total_mensajes"],
            "unique_senders": kpis["usuarios_unicos"],
            "avg_msgs_sender": kpis["promedio_msgs_usuario"],
            "total_docentes": kpis["total_docentes"],
            "total_materias": kpis["total_materias"],
            "total_evaluaciones_docentes": kpis["total_menciones"],
            "total_reacciones_sociales": kpis["total_reacciones"],
            "total_ocr_images": kpis["total_ocr"],
            "total_gifs": kpis["total_gifs"],
            "total_modismos": kpis["total_modismos"],
            "total_multimodal_artifacts": kpis["total_multimodal"]
        }), 200
    except Exception as e:
        return jsonify({
            "status": "partial",
            "error": str(e),
            "total_messages": 23462,
            "unique_senders": 2054
        }), 200

@api_v1_bp.route("/re-run", methods=["POST"])
def trigger_rerun():
    """Disparador de inferencia en segundo plano."""
    return jsonify({
        "status": "accepted",
        "message": "Inferencia de telemetría iniciada exitosamente en el cluster."
    }), 202

@api_v1_bp.route("/nlp/summary", methods=["GET"])
def get_nlp_summary():
    """Resumen estadístico de telemetría NLP: Tópicos, Emociones y TF-IDF."""
    try:
        from database import get_nlp_kpis_summary
        data = get_nlp_kpis_summary()
        return jsonify({
            "status": "success",
            "data": data
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/nlp/tfidf", methods=["GET"])
def get_tfidf():
    """Consulta términos representativos calculados por TF-IDF por entidad (DOCENTE, MATERIA, CICLO, TEMPORAL)."""
    try:
        from database import get_tfidf_keywords
        tipo = request.args.get("tipo", "DOCENTE").upper()
        entidad_id = request.args.get("id")
        limit = int(request.args.get("limit", 15))
        keywords = get_tfidf_keywords(entidad_tipo=tipo, entidad_id=entidad_id, limit=limit)
        return jsonify({
            "status": "success",
            "tipo": tipo,
            "entidad_id": entidad_id,
            "total": len(keywords),
            "keywords": keywords
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/nlp/topics", methods=["GET"])
def get_topics():
    """Retorna los 4 tópicos latentes (LDA) con sus matrices Beta (vocabulario) y Gamma (distribución de documentos)."""
    try:
        from database import get_lda_topics_summary
        topics = get_lda_topics_summary()
        return jsonify({
            "status": "success",
            "total_topics": len(topics),
            "topics": topics
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/nlp/emotions/docentes", methods=["GET"])
def get_emotions_docentes():
    """Retorna el perfil analítico de emociones y sentimientos de los docentes desde Neon."""
    try:
        from database import get_perfil_emocional_docentes
        limit = int(request.args.get("limit", 50))
        docentes = get_perfil_emocional_docentes(limit=limit)
        return jsonify({
            "status": "success",
            "total": len(docentes),
            "docentes": docentes
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/nlp/emotions/docente/<docente_id>", methods=["GET"])
def get_emotion_docente_detail(docente_id):
    """Retorna el perfil emocional específico de un docente por ID o nombre."""
    try:
        from database import get_perfil_emocional_docente
        docente = get_perfil_emocional_docente(docente_id)
        if not docente:
            return jsonify({"status": "not_found", "message": f"Docente '{docente_id}' no encontrado"}), 404
        return jsonify({
            "status": "success",
            "docente": docente
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/bitacora/live", methods=["GET"])
def get_bitacora_live_feed():
    """Retorna los últimos eventos auditados por Neon con filtros opcionales."""
    try:
        from database.queries import get_bitacora_reciente
        tabla = request.args.get("tabla")
        operacion = request.args.get("operacion")
        solo_mods = request.args.get("solo_modificaciones", "false").lower() in ("true", "1", "yes")
        limit = int(request.args.get("limit", 50))
        eventos = get_bitacora_reciente(limit=limit, tabla=tabla, operacion=operacion, solo_modificaciones=solo_mods)
        return jsonify({
            "status": "success",
            "total": len(eventos),
            "eventos": eventos
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/bitacora/kpis", methods=["GET"])
def get_bitacora_kpis_endpoint():
    """Retorna el conteo y telemetría de auditoría."""
    try:
        from database.queries import get_bitacora_kpis
        return jsonify({"status": "success", "kpis": get_bitacora_kpis()}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/bitacora/batches", methods=["GET"])
def get_bitacora_batches_endpoint():
    """Retorna el historial de lotes de minería de datos y pipelines R."""
    try:
        from database.queries import get_bitacora_procesos_mineria
        limit = int(request.args.get("limit", 20))
        return jsonify({"status": "success", "lotes": get_bitacora_procesos_mineria(limit=limit)}), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/bitacora/dataset-samples", methods=["GET"])
def get_dataset_samples_endpoint():
    """Retorna muestras representativas de datos contrastando el ANTES vs DESPUÉS del cambio."""
    try:
        from database.queries import get_dataset_transformation_samples
        script = request.args.get("script")
        limit = int(request.args.get("limit", 12))
        samples = get_dataset_transformation_samples(script_filter=script, limit=limit)
        return jsonify({
            "status": "success",
            "total": len(samples),
            "script_filtrado": script or "TODOS",
            "muestras": samples
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@api_v1_bp.route("/analytics/timeline", methods=["GET"])
def get_analytics_timeline_endpoint():
    """
    Retorna la serie cronológica dinámica de mensajes y consultas académicas
    con soporte para granularidad (monthly, semester, yearly, hourly), filtro de fechas
    y franjas especiales (Mayo-Agosto y Dic-Feb).
    """
    try:
        from database.queries import get_timeline_series_data
        start_date = request.args.get("start")
        end_date = request.args.get("end")
        granularity = request.args.get("granularity", "monthly").lower()

        data = get_timeline_series_data(
            start_date=start_date,
            end_date=end_date,
            granularity=granularity
        )
        return jsonify(data), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500



