"""Inserta el link de 15 emociones en el sidebar justo antes del link de Comparativa."""
from pathlib import Path

sidebar = Path('app/templates/components/sidebar.html')
content = sidebar.read_text(encoding='utf-8')

nuevo_link = '''
                <!-- 15 Emociones Motor Emotica -->
                <a class="flex items-center gap-space-sm px-space-sm py-2 rounded-xl transition-colors {% if request.path == '/emociones-15' %}bg-surface-container-high text-primary font-medium border border-primary/20 shadow-sm{% else %}text-on-surface-variant hover:text-on-surface hover:bg-surface-container{% endif %}"
                    href="/emociones-15">
                    <span class="material-symbols-outlined text-[18px] {% if request.path == '/emociones-15' %}text-primary{% endif %}">emoji_emotions</span>
                    <span class="text-body-sm text-[13px] flex-1">15 Emociones — Análisis Temporal</span>
                    <span class="font-code-sm text-[9px] bg-emerald-500/20 text-emerald-400 px-1.5 py-0.5 rounded font-semibold">SQLite</span>
                </a>

'''

# Buscar el marcador del link de Comparativa (usando texto ASCII seguro)
marcador = '<!-- Comparativa Librer'
idx = content.find(marcador)
if idx == -1:
    # Intentar con el texto corrupto que hay ahora
    marcador = '<!-- Comparativa Librer\u00c3\u00adas vs DS propio -->'
    idx = content.find(marcador)

if idx == -1:
    print("ERROR: No se encontro el marcador. Buscando texto alternativo...")
    # Buscar por la URL de comparativa
    marcador = '/comparativa-librerias-ds'
    idx2 = content.find(marcador)
    if idx2 != -1:
        # Retroceder hasta el inicio de la linea de comentario
        inicio_linea = content.rfind('\n', 0, idx2) + 1
        # Retroceder una linea mas (el comentario)
        inicio_comentario = content.rfind('\n', 0, inicio_linea - 1) + 1
        content = content[:inicio_comentario] + nuevo_link + content[inicio_comentario:]
        sidebar.write_text(content, encoding='utf-8')
        print("OK: Link insertado (modo alternativo).")
    else:
        print("ERROR: No se pudo insertar el link.")
else:
    content = content[:idx] + nuevo_link + content[idx:]
    sidebar.write_text(content, encoding='utf-8')
    print("OK: Link insertado correctamente.")

# Verificar
if '/emociones-15' in Path('app/templates/components/sidebar.html').read_text(encoding='utf-8'):
    print("Verificacion: Link de emociones-15 presente en sidebar.")
else:
    print("ERROR: Link NO encontrado.")
