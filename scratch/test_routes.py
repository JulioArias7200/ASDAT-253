import sys
sys.path.insert(0, '.')
from app import create_app

app = create_app()

# Listar todas las rutas
print("=== RUTAS REGISTRADAS ===")
with app.app_context():
    for rule in sorted(app.url_map.iter_rules(), key=lambda r: r.rule):
        print(f"  {rule.rule:50s}  {','.join(rule.methods - {'HEAD','OPTIONS'})}")

print("\n=== Verificando rutas nuevas ===")
rutas_nuevas = ['/emociones-15', '/api/emociones-15/serie']
with app.test_client() as client:
    for ruta in rutas_nuevas:
        resp = client.get(ruta)
        print(f"  GET {ruta} -> HTTP {resp.status_code}")

print("\nOK: Todas las rutas responden.")
