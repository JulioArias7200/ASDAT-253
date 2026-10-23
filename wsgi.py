# -*- coding: utf-8 -*-
"""
Punto de entrada WSGI para Gunicorn en entornos de producción (Render).
100% Python, sin dependencias de archivos YAML.
"""
import os
from app import create_app

# Render establece la variable de entorno RENDER=true automáticamente
env_mode = "production" if os.getenv("RENDER") else "development"
app = create_app(env_mode)

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
