# -*- coding: utf-8 -*-
"""Test funcional completo de la página /emociones-15 y su API."""
import sys, os, re, json

sys.path.insert(0, r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver")
os.chdir(r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver")

from app import create_app
app = create_app()

errors = []

with app.test_client() as client:
    # ── Test 1: Ruta principal /emociones-15 ──
    r = client.get("/emociones-15")
    print(f"GET /emociones-15 -> {r.status_code}")
    html = r.data.decode("utf-8")
    print(f"  HTML length: {len(html)} chars")

    if r.status_code != 200:
        errors.append("Ruta /emociones-15 no retorna 200!")

    # Verificar datos JSON inyectados
    barras_match = re.search(r"const barrasData\s*=\s*(\{.*?\});", html, re.DOTALL)
    serie_match = re.search(r"const serieData\s*=\s*(\{.*?\});", html, re.DOTALL)
    polar_match = re.search(r"const polarData\s*=\s*(\{.*?\});", html, re.DOTALL)

    if barras_match:
        bd = json.loads(barras_match.group(1))
        print(f"  barrasData: {len(bd['emociones'])} emociones, total_con_emocion={bd['total_con_emocion']}, motor={bd['motor_origen']}")
        top3 = [(e["label"], e["total"]) for e in bd["emociones"][:3]]
        print(f"    Top 3: {top3}")
        if bd["total_con_emocion"] == 0:
            errors.append("barrasData tiene 0 mensajes clasificados!")
        # Verificar que cada emoción tiene campos necesarios
        for e in bd["emociones"]:
            for field in ["label", "color", "total", "pct", "avg_intensity"]:
                if field not in e:
                    errors.append(f"barrasData emocion {e.get('emocion_id','?')} falta campo '{field}'")
    else:
        errors.append("barrasData no encontrado en el HTML!")

    if serie_match:
        sd = json.loads(serie_match.group(1))
        print(f"  serieData: {len(sd['labels'])} periodos, {len(sd['datasets'])} datasets, motor={sd['motor_origen']}")
        print(f"    Periodos: {sd['labels']}")
        print(f"    fecha_min={sd['fecha_min']}, fecha_max={sd['fecha_max']}")
        print(f"    Emociones disponibles: {len(sd['emociones_disponibles'])}")
        if len(sd["labels"]) == 0:
            errors.append("serieData no tiene periodos!")
        if len(sd["datasets"]) == 0:
            errors.append("serieData no tiene datasets!")
        # Verificar que datasets tienen los campos correctos para Chart.js
        for ds in sd["datasets"]:
            for field in ["label", "color", "data"]:
                if field not in ds:
                    errors.append(f"serieData dataset '{ds.get('label','?')}' falta campo '{field}'")
            if len(ds.get("data", [])) != len(sd["labels"]):
                errors.append(f"serieData dataset '{ds.get('label','?')}' data length ({len(ds.get('data',[]))}) != labels length ({len(sd['labels'])})")
        # Verificar emociones_disponibles para checkboxes
        for emo in sd["emociones_disponibles"]:
            for field in ["id", "label", "color"]:
                if field not in emo:
                    errors.append(f"emociones_disponibles falta campo '{field}' en {emo}")
    else:
        errors.append("serieData no encontrado en el HTML!")

    if polar_match:
        pd_data = json.loads(polar_match.group(1))
        print(f"  polarData: {len(pd_data['emociones'])} emociones, motor={pd_data['motor_origen']}")
        activos = [e for e in pd_data["emociones"] if e["total"] > 0]
        print(f"    Con datos: {len(activos)} emociones activas")
        top3_polar = [(e["label"], e["score_polar"]) for e in sorted(activos, key=lambda x: -x["score_polar"])[:3]]
        print(f"    Top 3 score polar: {top3_polar}")
        if len(activos) < 3:
            errors.append(f"polarData solo tiene {len(activos)} emociones con datos (mínimo esperado: 3)")
        # Verificar campos para radar chart
        for e in pd_data["emociones"]:
            for field in ["label", "color", "total", "avg_intensity", "score_polar"]:
                if field not in e:
                    errors.append(f"polarData emocion {e.get('emocion_id','?')} falta campo '{field}'")
    else:
        errors.append("polarData no encontrado en el HTML!")

    # Verificar canvas elements
    canvases = re.findall(r'id="(chart[A-Za-z]+)"', html)
    print(f"  Canvas elements encontrados: {canvases}")
    expected_canvases = ["chartBarras", "chartSerie", "chartRadar"]
    for c in expected_canvases:
        if c not in canvases:
            errors.append(f"Canvas '{c}' no encontrado en HTML!")

    # Verificar Chart.js CDN
    if "chart.umd.min.js" in html:
        print("  Chart.js CDN: presente [OK]")
    else:
        errors.append("Chart.js CDN script no encontrado!")

    # Verificar funciones JS
    js_funcs = ["switchBarrasMode", "buildSerieChart", "actualizarSerie", "resetSerie",
                "seleccionarTodas", "deseleccionarTodas", "actualizarCheckboxChip"]
    for fn in js_funcs:
        if fn in html:
            pass  # OK
        else:
            errors.append(f"Función JS '{fn}' no encontrada en HTML!")

    # ── Test 2: API serie temporal con filtros ──
    r2 = client.get("/api/emociones-15/serie?fecha_inicio=2022-01-01&fecha_fin=2026-12-31&emociones=gratitud,alegria,frustracion")
    print(f"\nGET /api/emociones-15/serie (3 emociones) -> {r2.status_code}")
    if r2.status_code == 200:
        api_data = r2.get_json()
        print(f"  Periodos: {len(api_data['labels'])}")
        for ds in api_data["datasets"]:
            print(f"    {ds['label']}: total={ds['total']}, puntos={len(ds['data'])}")
        if len(api_data["datasets"]) == 0:
            errors.append("API serie: 0 datasets con 3 emociones filtradas!")
    else:
        errors.append(f"API serie retorna {r2.status_code}!")

    # ── Test 3: API serie con filtro estrecho ──
    r3 = client.get("/api/emociones-15/serie?fecha_inicio=2024-01-01&fecha_fin=2024-12-31&emociones=alegria")
    print(f"\nGET /api/emociones-15/serie (2024, solo alegria) -> {r3.status_code}")
    if r3.status_code == 200:
        api3 = r3.get_json()
        print(f"  Periodos: {api3['labels']}")
        for ds in api3["datasets"]:
            print(f"    {ds['label']}: data={ds['data']}")

    # ── Test 4: API sin emociones (edge case) ──
    r4 = client.get("/api/emociones-15/serie?emociones=")
    print(f"\nGET /api/emociones-15/serie (sin filtro) -> {r4.status_code}")
    if r4.status_code == 200:
        api4 = r4.get_json()
        print(f"  Datasets: {len(api4['datasets'])}")
    else:
        errors.append(f"API serie sin filtro retorna {r4.status_code}!")

# -- Resumen --
print("\n" + "=" * 60)
if errors:
    print(f"[X] ERRORES ENCONTRADOS: {len(errors)}")
    for e in errors:
        print(f"  * {e}")
else:
    print("[OK] TODO CORRECTO - Las 3 graficas y la API estan correctas")
print("=" * 60)
