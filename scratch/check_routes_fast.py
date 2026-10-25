import urllib.request
import sys

routes = [
    "/",
    "/periodos",
    "/preprocesamiento",
    "/emojis-mensajes",
    "/sentimientos",
    "/comparativa-librerias-ds",
    "/importar-datos",
    "/bitacora",
    "/static/js/qr_engine.js"
]

for r in routes:
    url = "http://127.0.0.1:5000" + r
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            print(f"{resp.status} OK -> {r}", flush=True)
    except Exception as e:
        print(f"ERR -> {r}: {e}", flush=True)
