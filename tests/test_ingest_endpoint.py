# -*- coding: utf-8 -*-
"""
tests/test_ingest_endpoint.py
Test unitario y de integración para la ruta /api/v1/ingest/upload.
Verifica la ingesta de JSON individual y paquetes ZIP de Telegram Desktop.
"""

import io
import json
import zipfile
import pytest
from app import create_app

@pytest.fixture
def client():
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c

def test_ingest_upload_json(client):
    """Prueba subida directa de un archivo result.json."""
    data = {
        "messages": [
            {"id": 1, "type": "message", "date": "2024-02-10T10:00:00", "from": "Carlos", "from_id": "u1", "text": "Excelente explicación de la materia, muchas gracias!!"},
            {"id": 2, "type": "message", "date": "2024-02-11T11:00:00", "from": "Maria", "from_id": "u2", "text": "No me gustó nada el examen, qué rabia y frustración"}
        ]
    }
    json_bytes = json.dumps(data).encode("utf-8")
    
    response = client.post(
        "/api/v1/ingest/upload",
        data={"files": (io.BytesIO(json_bytes), "result.json")},
        content_type="multipart/form-data"
    )
    
    assert response.status_code == 200
    res = response.get_json()
    assert res["status"] == "success"
    assert res["total_mensajes"] == 2
    assert res["tipo_adaptador"] == "telegram"
    assert "top_emociones" in res
    assert "muestras" in res
    assert "bitacora_pasos" in res
    assert len(res["bitacora_pasos"]) > 0
    assert "comparativa_neon" in res
    assert "chat_metricas" in res["comparativa_neon"]
    assert "timeline" in res
    assert res["timeline"]["status"] == "success"
    assert "granularidades" in res["timeline"]
    assert "hourly" in res["timeline"]["granularidades"]

def test_ingest_upload_zip(client):
    """Prueba subida de un archivo .zip que contiene result.json y carpetas multimedia."""
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        data = {
            "messages": [
                {"id": 1, "type": "message", "date": "2024-02-10T10:00:00", "from": "Juan", "from_id": "u1", "text": "Muy buen material compartido"},
                {"id": 2, "type": "message", "date": "2024-02-11T12:00:00", "from": "Pedro", "from_id": "u2", "text": "Esperemos que todo salga bien en la entrega"}
            ]
        }
        zf.writestr("ChatExport/result.json", json.dumps(data))
        zf.writestr("ChatExport/photos/photo_1.jpg", b"fake_photo_data")
        zf.writestr("ChatExport/stickers/sticker_1.webp", b"fake_sticker_data")
        
    zip_buffer.seek(0)
    
    response = client.post(
        "/api/v1/ingest/upload",
        data={"files": (zip_buffer, "export_telegram.zip")},
        content_type="multipart/form-data"
    )
    
    assert response.status_code == 200
    res = response.get_json()
    assert res["status"] == "success"
    assert res["total_mensajes"] == 2
    assert res["multimedia"]["fotos"] == 1
    assert res["multimedia"]["stickers"] == 1
