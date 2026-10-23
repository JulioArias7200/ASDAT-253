# -*- coding: utf-8 -*-
"""
Configuración de la aplicación Flask para entornos Local y Render con Neon PostgreSQL.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
env_file = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(dotenv_path=env_file)

class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "sentix-intelligence-secret-production-key-2026")
    
    # Normalización de URL para Neon PostgreSQL
    raw_db_url = os.getenv("NEON_CONECTION") or os.getenv("DATABASE_URL") or "sqlite:///sentix_local.db"
    if raw_db_url.startswith("postgres://"):
        raw_db_url = raw_db_url.replace("postgres://", "postgresql+psycopg2://", 1)
    elif raw_db_url.startswith("postgresql://") and not raw_db_url.startswith("postgresql+"):
        raw_db_url = raw_db_url.replace("postgresql://", "postgresql+psycopg2://", 1)
    
    SQLALCHEMY_DATABASE_URI = raw_db_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Opciones de conexión optimizadas para Neon Serverless PostgreSQL
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "pool_size": 5,
        "max_overflow": 10
    }

class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False

config_by_name = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "default": ProductionConfig if os.getenv("RENDER") else DevelopmentConfig
}
