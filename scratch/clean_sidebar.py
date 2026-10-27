# -*- coding: utf-8 -*-
import os

p = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\app\templates\components\sidebar.html"
with open(p, "r", encoding="utf-8-sig") as f:
    text = f.read()

replacements = {
    "Ã¡": "á",
    "Ã©": "é",
    "Ã\xad": "í",
    "Ã³": "ó",
    "Ãº": "ú",
    "Ã±": "ñ",
    "Ã\x81": "Á",
    "Ã\x89": "É",
    "Ã\x8d": "Í",
    "Ã\x93": "Ó",
    "Ã\x9a": "Ú",
    "Ã\x91": "Ñ",
}

for k, v in replacements.items():
    text = text.replace(k, v)

with open(p, "w", encoding="utf-8") as f:
    f.write(text)

print("[OK] Sidebar accents cleaned up successfully!")
