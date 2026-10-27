"""
Test completo del endpoint de ingest: simula el upload del result.json
y reporta el error exacto.
"""
import sys
sys.path.insert(0, '.')

from app import create_app
import json

app = create_app()

with app.test_client() as client:
    # Simular upload de result.json como si fuera el navegador
    ruta_json = 'data/raw/result.json'
    
    print(f"Abriendo {ruta_json}...")
    with open(ruta_json, 'rb') as f:
        contenido = f.read()
    print(f"  Tamano: {len(contenido):,} bytes ({len(contenido)/1024/1024:.1f} MB)")
    
    print("Enviando POST a /api/v1/ingest/upload...")
    from io import BytesIO
    response = client.post(
        '/api/v1/ingest/upload',
        data={'files': (BytesIO(contenido), 'result.json')},
        content_type='multipart/form-data'
    )
    
    print(f"HTTP Status: {response.status_code}")
    try:
        data = response.get_json()
        if data:
            print(f"Status: {data.get('status')}")
            if data.get('status') == 'error':
                print(f"ERROR: {data.get('message')}")
            else:
                print(f"Total mensajes: {data.get('total_mensajes')}")
                print(f"Mensajes con texto: {data.get('mensajes_con_texto')}")
                print(f"Idioma detectado: {data.get('idioma_detectado')}")
                print(f"Cobertura emocional: {data.get('cobertura_emocional_pct')}%")
                print(f"Top emociones: {data.get('top_emociones', [])[:3]}")
                print(f"Bitacora pasos: {len(data.get('bitacora_pasos', []))}")
                print("\nOK: Upload funciona correctamente!")
    except Exception as e:
        print(f"Error al parsear respuesta: {e}")
        print(f"Body raw: {response.data[:500]}")
