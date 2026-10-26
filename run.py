# -*- coding: utf-8 -*-
"""
Script de ejecución local para Sentix Intelligence Dashboard.
Inicia el servidor Flask en modo de desarrollo con recarga en caliente y conexión a Neon.
"""
import os
import sys

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

# Asegurar que el directorio raíz del proyecto esté en el PYTHONPATH
project_root = os.path.dirname(os.path.abspath(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from dotenv import load_dotenv
load_dotenv(os.path.join(project_root, ".env"))

from app import create_app

app = create_app("development")

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    host = os.getenv("HOST", "127.0.0.1")
    
    print("\n" + "="*65)
    print("  🚀 SENTIX INTELLIGENCE - SERVIDOR LOCAL EN EJECUCIÓN")
    print("="*65)
    print(f"  • Motor BD:       Neon Serverless PostgreSQL (TGBase)")
    print(f"  • Overview C-Level: http://{host}:{port}/")
    print(f"  • Control Bitácora: http://{host}:{port}/bitacora")
    print(f"  • Telemetría API:   http://{host}:{port}/api/v1/health")
    print("="*65)
    print("  Presiona CTRL+C para detener el servidor.\n")
    
    app.run(host=host, port=port, debug=True)
