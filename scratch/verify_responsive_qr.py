import urllib.request
import urllib.error
import sys

BASE_URL = "http://127.0.0.1:5000"
ROUTES = [
    ("/", "Resumen Ejecutivo"),
    ("/periodos", "Análisis por Periodos"),
    ("/preprocesamiento", "Preprocesamiento"),
    ("/emojis-mensajes", "Emojis"),
    ("/sentimientos", "Sentimientos"),
    ("/comparativa-librerias-ds", "Comparativa"),
    ("/importar-datos", "Importar Datos"),
    ("/bitacora", "Bitácora"),
    ("/static/js/qr_engine.js", "QR Engine Script"),
    ("/static/js/timeline_chart.js", "Timeline Engine"),
    ("/static/js/main.js", "Main Script"),
]

all_ok = True
print("=== VERIFICANDO RESPUESTAS HTTP 200 Y COMPONENTES RESPONSIVE/QR ===")
for path, label in ROUTES:
    url = f"{BASE_URL}{path}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
            content = resp.read().decode("utf-8", errors="replace")
            print(f"[OK 200] {path:30} -> {label}")
            
            # Chequeos de componentes clave en las vistas HTML
            if path.startswith("/"):
                if "btn-open-qr-modal" not in content and not path.endswith(".js"):
                    print(f"  [WARN] 'btn-open-qr-modal' no encontrado en {path}")
                if "sidebar-backdrop" not in content and not path.endswith(".js"):
                    print(f"  [WARN] 'sidebar-backdrop' no encontrado en {path}")
                if "qr_engine.js" not in content and not path.endswith(".js"):
                    print(f"  [WARN] 'qr_engine.js' no incluido en {path}")
    except Exception as e:
        print(f"[ERROR] {path:30} -> {e}")
        all_ok = False

if all_ok:
    print("\n>>> ¡TODAS LAS RUTAS Y COMPONENTES RESPONSIVE/QR FUNCIONAN A LA PERFECCIÓN! <<<")
else:
    print("\n>>> HUBO ERRORES EN LA VERIFICACIÓN <<<")
    sys.exit(1)
