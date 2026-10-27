# -*- coding: utf-8 -*-
from pathlib import Path

tmpl_path = Path("app/templates/dashboard/emociones_15.html")
content = tmpl_path.read_text(encoding="utf-8")

old_str = """                        <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-primary/20 text-primary border border-primary/30">
                            <span class="material-symbols-outlined text-[13px]">emoji_emotions</span>
                            Motor Emotica Python — SQLite Local
                        </span>"""

new_str = """                        <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-primary/20 text-primary border border-primary/30">
                            <span class="material-symbols-outlined text-[13px]">database</span>
                            <span id="motor-badge">{{ barras.motor_origen | default('Neon PostgreSQL') }}</span>
                        </span>"""

old_desc = """                    <p class="font-body-sm text-xs sm:text-body-sm text-outline max-w-4xl">
                        Distribución, evolución temporal e intensidad de las 15 emociones inferidas por el motor Emotica.
                        Todos los datos provienen de consultas SQL directas a la base de datos SQLite local
                        (<code class="font-mono text-primary font-semibold">sentiment_results</code> × <code class="font-mono text-primary font-semibold">messages</code>).
                    </p>"""

new_desc = """                    <p class="font-body-sm text-xs sm:text-body-sm text-outline max-w-4xl">
                        Distribución, evolución temporal e intensidad de las 15 emociones inferidas por el motor Emotica.
                        Consultas SQL ejecutadas primariamente sobre <strong>Neon Serverless PostgreSQL (TGBase)</strong>
                        con fallback automático a SQLite local (<code class="font-mono text-primary font-semibold">mensajes</code>).
                    </p>"""

content = content.replace(old_str, new_str).replace(old_desc, new_desc)

# También actualizar la descripción de la consulta SQL en la tarjeta de barras
content = content.replace(
    'SQL: <code class="text-primary font-mono">SELECT dominant_emotion, COUNT(*) FROM sentiment_results GROUP BY dominant_emotion</code>',
    'SQL: <code class="text-primary font-mono">SELECT dominant_emotion, COUNT(*) FROM mensajes GROUP BY dominant_emotion</code>'
)

tmpl_path.write_text(content, encoding="utf-8")
print("OK: Template emociones_15.html actualizado.")
