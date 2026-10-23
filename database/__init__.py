# -*- coding: utf-8 -*-
"""
Package database initialization.
Exposes database query helpers.
"""
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
    get_bitacora_reciente
)
