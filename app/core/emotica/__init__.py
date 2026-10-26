# -*- coding: utf-8 -*-
"""
Paquete emotica (Python Nativo):
Procesamiento de lenguaje natural, anonimización con sal, motor de 15 emociones,
modelado de tópicos LDA y auditoría de transformaciones en chats estudiantiles.
"""

from app.core.emotica.preprocess import preprocess_chat
from app.core.emotica.engine import score_emotions, cargar_params_motor
from app.core.emotica.taxonomy import (
    cargar_taxonomia,
    guardar_taxonomia,
    cargar_lexicon,
    validar_lexicon,
    set_active,
    add_emotion,
    suggest_terms
)
from app.core.emotica.bitacora import (
    bitacora_iniciar,
    bitacora_registrar,
    bitacora_leer,
    bitacora_guardar,
    ejecutar_paso
)
from app.core.emotica.summary import cobertura_emociones, resumen_por_periodo
from app.core.emotica.topics import (
    agrupar_documentos,
    matriz_doc_term,
    ajustar_temas,
    terminos_por_tema,
    temas_por_periodo
)
from app.core.emotica.evaluation import (
    muestra_para_etiquetar,
    evaluar_motor,
    acuerdo_etiquetadores,
    correlacion_intensidad,
    kappa_cohen
)
from app.core.emotica.clean import normalizar_texto, extraer_emojis, detectar_idioma
from app.core.emotica.periods import asignar_periodo

__all__ = [
    "preprocess_chat",
    "score_emotions",
    "cargar_params_motor",
    "cargar_taxonomia",
    "guardar_taxonomia",
    "cargar_lexicon",
    "validar_lexicon",
    "set_active",
    "add_emotion",
    "suggest_terms",
    "bitacora_iniciar",
    "bitacora_registrar",
    "bitacora_leer",
    "bitacora_guardar",
    "ejecutar_paso",
    "cobertura_emociones",
    "resumen_por_periodo",
    "agrupar_documentos",
    "matriz_doc_term",
    "ajustar_temas",
    "terminos_por_tema",
    "temas_por_periodo",
    "muestra_para_etiquetar",
    "evaluar_motor",
    "acuerdo_etiquetadores",
    "correlacion_intensidad",
    "kappa_cohen",
    "normalizar_texto",
    "extraer_emojis",
    "detectar_idioma",
    "asignar_periodo"
]
