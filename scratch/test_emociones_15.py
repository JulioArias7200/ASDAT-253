import sys
sys.path.insert(0, '.')
from database.queries import (
    get_emociones_15_barras,
    get_emociones_15_serie_temporal,
    get_emociones_15_polar,
)

print("=== BARRAS ===")
d = get_emociones_15_barras()
print(f"Total mensajes: {d['total_mensajes']}")
print(f"Total con emocion: {d['total_con_emocion']}")
print(f"Cobertura: {d['pct_cobertura']}%")
print(f"Top 5 emociones:")
for e in d['emociones'][:5]:
    print(f"  {e['label']}: {e['total']} msgs ({e['pct']}%) intens={e['avg_intensity']}")

print()
print("=== SERIE TEMPORAL ===")
s = get_emociones_15_serie_temporal()
print(f"Labels (periodos): {s['labels'][:5]}...")
print(f"Datasets: {len(s['datasets'])}")
print(f"Rango: {s['fecha_min']} -> {s['fecha_max']}")

print()
print("=== SERIE CON FILTRO ===")
sf = get_emociones_15_serie_temporal(fecha_inicio='2023-01-01', fecha_fin='2024-12-31', emociones_filtro=['gratitud', 'alegria', 'tristeza'])
print(f"Labels: {sf['labels'][:5]}")
print(f"Datasets: {len(sf['datasets'])}")

print()
print("=== POLAR ===")
p = get_emociones_15_polar()
print("Top 5 por score_polar:")
tops = sorted(p['emociones'], key=lambda x: -x['score_polar'])[:5]
for e in tops:
    print(f"  {e['label']}: score={e['score_polar']} total={e['total']} intens={e['avg_intensity']}")

print()
print("✅ Todo OK!")
