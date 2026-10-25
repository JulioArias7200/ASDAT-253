# -*- coding: utf-8 -*-
from flask import Blueprint

web_bp = Blueprint("web", __name__)

# Importar rutas después de instanciar web_bp para evitar importaciones circulares
from app.routes.web import dashboard
