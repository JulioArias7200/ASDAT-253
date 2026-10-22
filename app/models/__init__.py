# -*- coding: utf-8 -*-
"""
Módulo de modelos SQLAlchemy para Neon PostgreSQL.
"""
from app.models.schema import (
    Docente,
    Materia,
    OfertaHorario,
    Mensaje,
    MencionDocente,
    ReaccionGranular,
    Modismo,
    DiccionarioJerga,
    EventoServicio,
    ModismoMensaje,
    GifAnimacion,
    OcrCache
)

__all__ = [
    "Docente",
    "Materia",
    "OfertaHorario",
    "Mensaje",
    "MencionDocente",
    "ReaccionGranular",
    "Modismo",
    "DiccionarioJerga",
    "EventoServicio",
    "ModismoMensaje",
    "GifAnimacion",
    "OcrCache"
]
