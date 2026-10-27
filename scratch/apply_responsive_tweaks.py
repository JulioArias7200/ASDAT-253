# -*- coding: utf-8 -*-
"""Optimización de responsividad fina en emociones_15.html."""
p = r"c:\Users\YOSHUA\Documents\PDF_MATERIAL_MATERIAS\MINERIA DE DATOS\PROYECTO_LIMPIEZA_TELEGRAM\proyecto_iver\app\templates\dashboard\emociones_15.html"

with open(p, "r", encoding="utf-8") as f:
    c = f.read()

# 1. Header pills flex-wrap
c = c.replace(
    '<div class="flex items-center gap-2">\n                        <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-primary/20 text-primary border border-primary/30">',
    '<div class="flex items-center gap-2 flex-wrap">\n                        <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-primary/20 text-primary border border-primary/30">'
)

# 2. Header right buttons flex-wrap
c = c.replace(
    '<div class="flex items-center gap-2 self-start md:self-auto shrink-0">',
    '<div class="flex items-center gap-2 flex-wrap self-start md:self-auto shrink-0">'
)

# 3. Gráfica 1 switch buttons flex-wrap
c = c.replace(
    '<div class="flex items-center gap-2">\n                        <button id="btn-barras-freq"',
    '<div class="flex items-center gap-2 flex-wrap">\n                        <button id="btn-barras-freq"'
)

# 4. Gráfica 2 inputs responsive flex
old_inputs = '''                        <div class="flex flex-wrap gap-3 items-end">
                            <div class="flex flex-col gap-1">
                                <label class="text-xs font-semibold text-outline uppercase tracking-wider">Fecha inicio</label>
                                <input type="date" id="fechaInicio" value="{{ serie.fecha_min }}"
                                    min="{{ serie.fecha_min }}" max="{{ serie.fecha_max }}"
                                    class="bg-surface-container-high text-on-surface border border-outline/20 rounded-lg px-3 py-1.5 text-xs font-mono focus:outline-none focus:border-primary">
                            </div>
                            <div class="flex flex-col gap-1">
                                <label class="text-xs font-semibold text-outline uppercase tracking-wider">Fecha fin</label>
                                <input type="date" id="fechaFin" value="{{ serie.fecha_max }}"
                                    min="{{ serie.fecha_min }}" max="{{ serie.fecha_max }}"
                                    class="bg-surface-container-high text-on-surface border border-outline/20 rounded-lg px-3 py-1.5 text-xs font-mono focus:outline-none focus:border-primary">
                            </div>
                            <button onclick="actualizarSerie()"
                                class="bg-primary hover:bg-primary/90 text-on-primary px-4 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-colors">
                                <span class="material-symbols-outlined text-[16px]">refresh</span>
                                Actualizar
                            </button>
                            <button onclick="resetSerie()"
                                class="bg-surface-container-high hover:bg-surface-container-highest text-on-surface px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors">
                                Resetear
                            </button>
                        </div>'''

new_inputs = '''                        <div class="flex flex-wrap gap-3 items-end">
                            <div class="flex flex-col gap-1 flex-1 min-w-[130px]">
                                <label class="text-xs font-semibold text-outline uppercase tracking-wider">Fecha inicio</label>
                                <input type="date" id="fechaInicio" value="{{ serie.fecha_min }}"
                                    min="{{ serie.fecha_min }}" max="{{ serie.fecha_max }}"
                                    class="bg-surface-container-high text-on-surface border border-outline/20 rounded-lg px-3 py-1.5 text-xs font-mono focus:outline-none focus:border-primary w-full">
                            </div>
                            <div class="flex flex-col gap-1 flex-1 min-w-[130px]">
                                <label class="text-xs font-semibold text-outline uppercase tracking-wider">Fecha fin</label>
                                <input type="date" id="fechaFin" value="{{ serie.fecha_max }}"
                                    min="{{ serie.fecha_min }}" max="{{ serie.fecha_max }}"
                                    class="bg-surface-container-high text-on-surface border border-outline/20 rounded-lg px-3 py-1.5 text-xs font-mono focus:outline-none focus:border-primary w-full">
                            </div>
                            <div class="flex items-center gap-2 w-full sm:w-auto">
                                <button onclick="actualizarSerie()"
                                    class="flex-1 sm:flex-none justify-center bg-primary hover:bg-primary/90 text-on-primary px-4 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-colors">
                                    <span class="material-symbols-outlined text-[16px]">refresh</span>
                                    Actualizar
                                </button>
                                <button onclick="resetSerie()"
                                    class="flex-1 sm:flex-none justify-center bg-surface-container-high hover:bg-surface-container-highest text-on-surface px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors">
                                    Resetear
                                </button>
                            </div>
                        </div>'''

c = c.replace(old_inputs.replace('\r\n', '\n'), new_inputs.replace('\r\n', '\n'))
c = c.replace(old_inputs, new_inputs)

# 5. Tabla con min-w-[340px]
c = c.replace('<table class="w-full text-xs">', '<table class="w-full text-xs min-w-[340px]">')

with open(p, "w", encoding="utf-8") as f:
    f.write(c)

print("[OK] Optimizaciones responsive aplicadas a emociones_15.html!")
