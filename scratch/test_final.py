"""
Verificacion final: Prueba todas las rutas del dashboard incluyendo emociones-15
"""
import sys
sys.path.insert(0, '.')
from app import create_app

app = create_app()

rutas_a_probar = [
    ('GET', '/'),
    ('GET', '/sentimientos'),
    ('GET', '/emociones-15'),
    ('GET', '/api/emociones-15/serie'),
    ('GET', '/api/emociones-15/serie?fecha_inicio=2023-01-01&fecha_fin=2024-12-31&emociones=gratitud,alegria,tristeza'),
    ('GET', '/periodos'),
    ('GET', '/preprocesamiento'),
    ('GET', '/emojis-mensajes'),
    ('GET', '/importar-datos'),
    ('GET', '/bitacora'),
]

print("=== TEST FINAL DE RUTAS ===")
with app.test_client() as client:
    errores = []
    for metodo, ruta in rutas_a_probar:
        resp = client.get(ruta) if metodo == 'GET' else client.post(ruta)
        status = resp.status_code
        ok = "OK" if status == 200 else "ERROR"
        print(f"  {ok} [{status}] {metodo} {ruta}")
        if status != 200:
            errores.append(f"{metodo} {ruta} -> {status}")

print()
if errores:
    print(f"ERRORES ({len(errores)}):")
    for e in errores:
        print(f"  - {e}")
else:
    print("Todas las rutas responden HTTP 200.")

# Verificar datos de emociones-15
print()
print("=== VERIFICACION DATOS EMOCIONES-15 ===")
import json
resp = client.get('/api/emociones-15/serie?emociones=gratitud,alegria,tristeza')
data = resp.get_json()
print(f"  Periodos: {len(data['labels'])}")
print(f"  Datasets (emociones): {len(data['datasets'])}")
print(f"  Rango: {data['fecha_min']} -> {data['fecha_max']}")
for ds in data['datasets']:
    total = sum(ds['data'])
    print(f"  - {ds['label']}: {total} msgs en {len(ds['data'])} periodos")
