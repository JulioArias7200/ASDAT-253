# -*- coding: utf-8 -*-
"""
Application Factory Pattern para Flask.
Inicializa configuración y Blueprints.
"""
import os
from flask import Flask
from app.config import config_by_name

def create_app(config_name=None):
    if not config_name:
        if os.getenv("RENDER") or os.getenv("FLASK_ENV") == "production":
            config_name = "production"
        else:
            config_name = os.getenv("FLASK_ENV", "development")
    
    app = Flask(__name__)
    config_obj = config_by_name.get(config_name, config_by_name["default"])
    app.config.from_object(config_obj)
    
    # Inicializar Base de Datos
    from app.extensions import db
    db.init_app(app)
    
    # Registrar Blueprints
    from app.routes.web import web_bp
    from app.routes.api_v1 import api_v1_bp
    
    app.register_blueprint(web_bp)
    app.register_blueprint(api_v1_bp)
    
    return app
