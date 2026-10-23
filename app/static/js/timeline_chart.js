/**
 * timeline_chart.js - Sentix Intelligence
 * Motor de visualización interactiva para la Evolución Histórica de Conversaciones.
 * Soporta granularidad (anual, semestral, mensual, horario), selección de rangos de fecha,
 * interpolación spline suave, crosshair con tooltip glassmorphic y franjas especiales (Mayo-Agosto y Dic-Feb).
 */

class TimelineChartEngine {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        if (!this.container) return;

        this.svg = this.container.querySelector('svg.timeline-svg');
        this.tooltip = document.getElementById('timeline-tooltip');
        this.crosshair = document.getElementById('timeline-crosshair');
        
        // Estado inicial
        this.granularity = 'monthly';
        this.startDate = '';
        this.endDate = '';
        this.data = null;
        this.currentPoints = [];

        this.initControls();
        this.fetchData();
    }

    initControls() {
        const granButtons = document.querySelectorAll('.timeline-gran-btn');
        const presetButtons = document.querySelectorAll('.timeline-preset-btn');
        const dateInputs = document.getElementById('timeline-custom-dates');

        // Función auxiliar para actualizar estilos de botones de granularidad
        this.updateGranularityButtons = (activeGran) => {
            granButtons.forEach(b => {
                if (b.dataset.granularity === activeGran) {
                    b.classList.add('bg-primary', 'text-on-primary', 'font-semibold');
                    b.classList.remove('text-outline', 'hover:text-on-surface');
                } else {
                    b.classList.remove('bg-primary', 'text-on-primary', 'font-semibold');
                    b.classList.add('text-outline', 'hover:text-on-surface');
                }
            });
        };

        // Función auxiliar para actualizar estilos de botones de preset
        this.updatePresetButtons = (activePreset) => {
            presetButtons.forEach(b => {
                if (b.dataset.preset === activePreset) {
                    b.classList.add('border-primary', 'text-primary', 'bg-primary/10');
                    b.classList.remove('border-outline/20', 'text-outline');
                } else {
                    b.classList.remove('border-primary', 'text-primary', 'bg-primary/10');
                    b.classList.add('border-outline/20', 'text-outline');
                }
            });
        };

        // 1. Botones de granularidad (Mensual, Semestral, Anual, Horario)
        granButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const targetGran = btn.dataset.granularity;
                this.granularity = targetGran;
                this.updateGranularityButtons(targetGran);

                // Si elige vista "Anual", limpiamos filtros de año único para mostrar todos los años históricos
                if (targetGran === 'yearly') {
                    this.startDate = '';
                    this.endDate = '';
                    this.updatePresetButtons('all');
                    if (dateInputs) dateInputs.classList.add('hidden');
                }

                this.fetchData();
            });
        });

        // 2. Presets de rango (Histórico, 2023, 2024, 2025, 2026, Personalizado)
        presetButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const val = btn.dataset.preset;
                this.updatePresetButtons(val);

                if (val === 'all') {
                    this.startDate = '';
                    this.endDate = '';
                    if (dateInputs) dateInputs.classList.add('hidden');
                } else if (val === 'custom') {
                    if (dateInputs) dateInputs.classList.remove('hidden');
                    return; // Esperar a que el usuario presione "Aplicar Rango"
                } else {
                    // Año específico seleccionado (ej: 2024)
                    this.startDate = `${val}-01-01`;
                    this.endDate = `${val}-12-31`;
                    if (dateInputs) dateInputs.classList.add('hidden');

                    // Al seleccionar un año específico, forzar granularidad 'monthly'
                    // para mostrar el desglose de los 12 meses de ese año y visualizar caídas y picos
                    this.granularity = 'monthly';
                    this.updateGranularityButtons('monthly');
                }
                this.fetchData();
            });
        });

        // 3. Inputs de rango personalizado
        const applyCustomBtn = document.getElementById('btn-apply-custom-dates');
        if (applyCustomBtn) {
            applyCustomBtn.addEventListener('click', () => {
                const startInput = document.getElementById('input-start-date');
                const endInput = document.getElementById('input-end-date');
                if (startInput && endInput && startInput.value && endInput.value) {
                    this.startDate = startInput.value;
                    this.endDate = endInput.value;
                    this.fetchData();
                }
            });
        }

        // 4. Eventos de ratón para Tooltip, Crosshair y Clic Drill-down
        if (this.svg) {
            this.svg.addEventListener('mousemove', (e) => this.handleMouseMove(e));
            this.svg.addEventListener('mouseleave', () => this.handleMouseLeave());
            this.svg.addEventListener('touchmove', (e) => {
                if (e.touches.length > 0) {
                    this.handleMouseMove(e.touches[0]);
                }
            });
            this.svg.addEventListener('touchend', () => this.handleMouseLeave());
            this.svg.addEventListener('click', (e) => this.handleClick(e));
        }

        window.addEventListener('resize', () => {
            if (this.data) this.render();
        });
    }

    handleClick(e) {
        if (!this.currentPoints || this.currentPoints.length === 0) return;

        const rect = this.svg.getBoundingClientRect();
        const clientX = e.clientX !== undefined ? e.clientX : (e.touches && e.touches[0] ? e.touches[0].clientX : 0);
        const relX = ((clientX - rect.left) / rect.width) * 740;

        let closest = this.currentPoints[0];
        let minDist = Math.abs(relX - closest.x);

        for (let i = 1; i < this.currentPoints.length; i++) {
            const dist = Math.abs(relX - this.currentPoints[i].x);
            if (dist < minDist) {
                minDist = dist;
                closest = this.currentPoints[i];
            }
        }

        // Si estamos en granularidad anual, hacer drill-down directo al año clickeado
        if (this.granularity === 'yearly' && closest.periodo) {
            this.drillDownYear(closest.periodo);
        }
    }

    drillDownYear(year) {
        this.startDate = `${year}-01-01`;
        this.endDate = `${year}-12-31`;
        this.granularity = 'monthly';
        this.updateGranularityButtons('monthly');
        this.updatePresetButtons(year);
        const dateInputs = document.getElementById('timeline-custom-dates');
        if (dateInputs) dateInputs.classList.add('hidden');
        this.fetchData();
    }

    async fetchData() {
        const loadingIndicator = document.getElementById('timeline-loading');
        if (loadingIndicator) loadingIndicator.classList.remove('hidden');

        try {
            let url = `/api/v1/analytics/timeline?granularity=${encodeURIComponent(this.granularity)}`;
            if (this.startDate) url += `&start=${encodeURIComponent(this.startDate)}`;
            if (this.endDate) url += `&end=${encodeURIComponent(this.endDate)}`;

            const res = await fetch(url);
            const json = await res.json();
            if (json.status === 'success') {
                this.data = json;
                this.updateKPIs(json.kpis);
                this.render();
            }
        } catch (err) {
            console.error('Error cargando serie temporal:', err);
        } finally {
            if (loadingIndicator) loadingIndicator.classList.add('hidden');
        }
    }

    updateKPIs(kpis) {
        if (!kpis) return;
        const totalEl = document.getElementById('timeline-kpi-total');
        if (totalEl) totalEl.textContent = Number(kpis.total_periodo || 0).toLocaleString();

        const preguntasEl = document.getElementById('timeline-kpi-preguntas');
        if (preguntasEl) {
            const pct = kpis.pct_preguntas || (kpis.total_periodo > 0 ? Math.round((kpis.total_preguntas / kpis.total_periodo) * 100) : 0);
            preguntasEl.textContent = `${Number(kpis.total_preguntas || 0).toLocaleString()} (${pct}%)`;
        }

        const picoEl = document.getElementById('timeline-kpi-pico');
        if (picoEl) {
            if (kpis.pico_maximo && kpis.pico_maximo.label) {
                picoEl.textContent = `${kpis.pico_maximo.label} (${Number(kpis.pico_maximo.total).toLocaleString()} msgs)`;
            } else {
                picoEl.textContent = '--';
            }
        }

        const caidaEl = document.getElementById('timeline-kpi-caida');
        if (caidaEl) {
            if (kpis.caida_minima && kpis.caida_minima.label) {
                caidaEl.textContent = `${kpis.caida_minima.label} (${Number(kpis.caida_minima.total).toLocaleString()} msgs)`;
            } else {
                caidaEl.textContent = '--';
            }
        }

        const promEl = document.getElementById('timeline-kpi-promedio');
        if (promEl) promEl.textContent = `${Number(kpis.promedio || 0).toLocaleString()} / período`;

        // Context Badge y Drill-down Hint
        const contextText = document.getElementById('timeline-context-text');
        const drilldownHint = document.getElementById('timeline-drilldown-hint');
        if (contextText) {
            if (this.granularity === 'yearly') {
                contextText.innerHTML = `<span class="w-2 h-2 rounded-full bg-amber-400"></span> <span><strong>Vista Macro Interanual (2022-2026):</strong> Suma acumulada de mensajes por año.</span>`;
                if (drilldownHint) drilldownHint.classList.remove('hidden');
            } else if (this.startDate && this.endDate && this.startDate.slice(0, 4) === this.endDate.slice(0, 4)) {
                const yr = this.startDate.slice(0, 4);
                contextText.innerHTML = `<span class="w-2 h-2 rounded-full bg-primary animate-pulse"></span> <span><strong>Desglose Mensual Año ${yr}:</strong> Caídas y picos estacionales visibles a lo largo de las 12 cohortes.</span>`;
                if (drilldownHint) drilldownHint.classList.add('hidden');
            } else {
                contextText.innerHTML = `<span class="w-2 h-2 rounded-full bg-tertiary"></span> <span><strong>Evolución Cronológica Completa:</strong> Fluctuaciones de actividad académica, parciales y recesos.</span>`;
                if (drilldownHint) drilldownHint.classList.add('hidden');
            }
        }
    }

    render() {
        if (!this.svg || !this.data || !this.data.data_points || this.data.data_points.length === 0) return;

        const points = this.data.data_points;
        const franjas = this.data.franjas_definidas || [];
        const width = 740;
        const height = 240;
        const padLeft = 55;
        const padRight = 30;
        const padTop = 38;
        const padBottom = 35;

        const graphW = width - padLeft - padRight;
        const graphH = height - padTop - padBottom;

        // Máximo Y con margen de 20%
        const maxVal = Math.max(...points.map(p => p.total), 10);
        const yMax = Math.ceil((maxVal * 1.20) / 100) * 100;

        // Limpiar contenido previo del SVG excepto defs
        const defs = this.svg.querySelector('defs');
        this.svg.innerHTML = '';
        if (defs) this.svg.appendChild(defs);

        // 1. Grid horizontal de referencia y etiquetas Y
        const yTicks = 4;
        for (let i = 0; i <= yTicks; i++) {
            const val = Math.round((yMax / yTicks) * i);
            const yPos = padTop + graphH - (val / yMax) * graphH;

            const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
            line.setAttribute('x1', padLeft);
            line.setAttribute('x2', width - padRight);
            line.setAttribute('y1', yPos);
            line.setAttribute('y2', yPos);
            line.setAttribute('stroke', 'currentColor');
            line.setAttribute('class', i === 0 ? 'text-outline-variant/60' : 'text-surface-container-highest/60');
            if (i > 0) line.setAttribute('stroke-dasharray', '3 3');
            this.svg.appendChild(line);

            const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            text.setAttribute('x', padLeft - 10);
            text.setAttribute('y', yPos + 3.5);
            text.setAttribute('text-anchor', 'end');
            text.setAttribute('fill', '#908fa0');
            text.setAttribute('class', 'font-mono text-[10px]');
            text.textContent = val >= 1000 ? (val / 1000).toFixed(1) + 'k' : val;
            this.svg.appendChild(text);
        }

        // Calcular coordenadas X de cada punto
        const stepX = points.length > 1 ? graphW / (points.length - 1) : 0;
        this.currentPoints = points.map((p, idx) => {
            const x = points.length > 1 ? padLeft + idx * stepX : padLeft + graphW / 2;
            const yTotal = padTop + graphH - (p.total / yMax) * graphH;
            const yPreg = padTop + graphH - (p.preguntas / yMax) * graphH;
            return { ...p, x, yTotal, yPreg, index: idx };
        });

        // 2. Renderizar Franjas Sombreadas Especiales (Mayo-Agosto y Dic-Feb)
        if (this.granularity === 'monthly' || this.granularity === 'daily') {
            this.renderSpecialBands(padTop, graphH, franjas);
        }

        // 3. Renderizar Área Rellena (Gradientes)
        const totalAreaPath = this.generateAreaPath(this.currentPoints.map(p => ({ x: p.x, y: p.yTotal })), padTop + graphH);
        if (totalAreaPath) {
            const pathAreaTotal = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            pathAreaTotal.setAttribute('d', totalAreaPath);
            pathAreaTotal.setAttribute('fill', 'url(#volumeArea)');
            this.svg.appendChild(pathAreaTotal);
        }

        const pregAreaPath = this.generateAreaPath(this.currentPoints.map(p => ({ x: p.x, y: p.yPreg })), padTop + graphH);
        if (pregAreaPath) {
            const pathAreaPreg = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            pathAreaPreg.setAttribute('d', pregAreaPath);
            pathAreaPreg.setAttribute('fill', 'url(#posArea)');
            this.svg.appendChild(pathAreaPreg);
        }

        // 4. Renderizar Curvas Spline
        const totalLinePath = this.generateSpline(this.currentPoints.map(p => ({ x: p.x, y: p.yTotal })));
        if (totalLinePath) {
            const pathLineTotal = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            pathLineTotal.setAttribute('d', totalLinePath);
            pathLineTotal.setAttribute('fill', 'none');
            pathLineTotal.setAttribute('stroke', '#4cd7f6');
            pathLineTotal.setAttribute('stroke-width', '2.5');
            pathLineTotal.setAttribute('stroke-linecap', 'round');
            this.svg.appendChild(pathLineTotal);
        }

        const pregLinePath = this.generateSpline(this.currentPoints.map(p => ({ x: p.x, y: p.yPreg })));
        if (pregLinePath) {
            const pathLinePreg = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            pathLinePreg.setAttribute('d', pregLinePath);
            pathLinePreg.setAttribute('fill', 'none');
            pathLinePreg.setAttribute('stroke', '#4edea3');
            pathLinePreg.setAttribute('stroke-width', '2');
            pathLinePreg.setAttribute('stroke-linecap', 'round');
            this.svg.appendChild(pathLinePreg);
        }

        // 5. Renderizar Etiquetas del Eje X
        const skipFactor = this.currentPoints.length <= 12 ? 1 : Math.ceil(this.currentPoints.length / 10);
        this.currentPoints.forEach((p, idx) => {
            if (idx % skipFactor === 0 || idx === this.currentPoints.length - 1) {
                const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                text.setAttribute('x', p.x);
                text.setAttribute('y', height - 8);
                text.setAttribute('text-anchor', 'middle');
                text.setAttribute('class', 'font-mono text-[11px]');
                
                if (p.en_franja === 'invierno') {
                    text.setAttribute('fill', '#4cd7f6');
                    text.setAttribute('font-weight', '700');
                } else if (p.en_franja === 'verano') {
                    text.setAttribute('fill', '#f472b6');
                    text.setAttribute('font-weight', '700');
                } else {
                    text.setAttribute('fill', '#908fa0');
                }
                text.textContent = p.label;
                this.svg.appendChild(text);
            }
        });

        // 6. Renderizar Puntos Interactivos (Circles) y Badges de Picos y Caídas
        this.currentPoints.forEach(p => {
            // Círculo exterior (Halo)
            const halo = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
            halo.setAttribute('cx', p.x);
            halo.setAttribute('cy', p.yTotal);
            halo.setAttribute('r', this.granularity === 'yearly' ? '8' : (p.en_franja ? '6' : '4.5'));
            halo.setAttribute('fill', p.en_franja === 'verano' ? 'rgba(244, 114, 182, 0.25)' : (p.es_valle ? 'rgba(244, 114, 182, 0.35)' : 'rgba(76, 215, 246, 0.25)'));
            this.svg.appendChild(halo);

            // Círculo principal
            const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
            circle.setAttribute('cx', p.x);
            circle.setAttribute('cy', p.yTotal);
            circle.setAttribute('r', this.granularity === 'yearly' ? '5.5' : (p.es_pico || p.es_valle ? '4.5' : (p.en_franja ? '3.5' : '2.5')));
            circle.setAttribute('fill', p.es_valle ? '#f472b6' : (p.es_pico ? '#4edea3' : (p.en_franja === 'verano' ? '#f472b6' : '#4cd7f6')));
            circle.setAttribute('stroke', '#13141f');
            circle.setAttribute('stroke-width', '1.5');
            if (this.granularity === 'yearly') {
                circle.style.cursor = 'pointer';
            }
            this.svg.appendChild(circle);

            // Renderizado de Badges Explicativos para Picos y Caídas
            if (p.es_pico) {
                this.drawPointBadge(p, 'pico');
            } else if (p.es_valle && this.currentPoints.length > 2) {
                this.drawPointBadge(p, 'valle');
            } else if (this.granularity === 'yearly') {
                const valText = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                valText.setAttribute('x', p.x);
                valText.setAttribute('y', p.yTotal - 13);
                valText.setAttribute('text-anchor', 'middle');
                valText.setAttribute('class', 'font-mono text-[11px] font-bold cursor-pointer');
                valText.setAttribute('fill', '#4cd7f6');
                valText.textContent = Number(p.total).toLocaleString();
                this.svg.appendChild(valText);
            }
        });
    }

    drawPointBadge(p, type) {
        const isPico = type === 'pico';
        const badgeW = isPico ? 92 : 96;
        const badgeH = 17;
        const badgeX = Math.max(10, Math.min(740 - badgeW - 10, p.x - badgeW / 2));
        
        let badgeY = isPico ? (p.yTotal - 23) : (p.yTotal + 13);
        if (badgeY < 18) badgeY = p.yTotal + 13;
        if (badgeY > 205) badgeY = p.yTotal - 23;

        const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        g.setAttribute('class', 'point-badge select-none pointer-events-none');

        const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        rect.setAttribute('x', badgeX);
        rect.setAttribute('y', badgeY);
        rect.setAttribute('width', badgeW);
        rect.setAttribute('height', badgeH);
        rect.setAttribute('rx', '4');
        rect.setAttribute('fill', isPico ? '#05232a' : '#2d091a');
        rect.setAttribute('stroke', isPico ? '#4edea3' : '#f472b6');
        rect.setAttribute('stroke-width', '1');
        rect.setAttribute('opacity', '0.96');
        g.appendChild(rect);

        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('x', badgeX + badgeW / 2);
        text.setAttribute('y', badgeY + 11.5);
        text.setAttribute('text-anchor', 'middle');
        text.setAttribute('fill', isPico ? '#4edea3' : '#f472b6');
        text.setAttribute('class', 'font-mono text-[9px] font-bold');
        text.textContent = isPico 
            ? `▲ Pico: ${Number(p.total).toLocaleString()}` 
            : `▼ Caída: ${Number(p.total).toLocaleString()}`;
        g.appendChild(text);

        this.svg.appendChild(g);
    }

    renderSpecialBands(padTop, graphH, franjas) {
        let currentBand = null;

        this.currentPoints.forEach((p, idx) => {
            if (p.en_franja) {
                if (!currentBand || currentBand.tipo !== p.en_franja) {
                    if (currentBand) {
                        this.drawBand(currentBand, padTop, graphH);
                    }
                    currentBand = {
                        tipo: p.en_franja,
                        nombre: p.franja_nombre || (p.en_franja === 'invierno' ? 'Mayo - Agosto' : 'Dic - Feb'),
                        badge: p.franja_badge,
                        startX: p.x - (idx > 0 ? (p.x - this.currentPoints[idx-1].x)/2 : 15),
                        endX: p.x,
                        color: p.en_franja === 'invierno' ? '#4cd7f6' : '#f472b6',
                        bgColor: p.en_franja === 'invierno' ? 'rgba(76, 215, 246, 0.12)' : 'rgba(244, 114, 182, 0.14)'
                    };
                } else {
                    currentBand.endX = p.x + (idx < this.currentPoints.length - 1 ? (this.currentPoints[idx+1].x - p.x)/2 : 15);
                }
            } else {
                if (currentBand) {
                    this.drawBand(currentBand, padTop, graphH);
                    currentBand = null;
                }
            }
        });

        if (currentBand) {
            this.drawBand(currentBand, padTop, graphH);
        }
    }

    drawBand(band, padTop, graphH) {
        const bandW = Math.max(band.endX - band.startX, 24);

        const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        rect.setAttribute('x', band.startX);
        rect.setAttribute('y', padTop);
        rect.setAttribute('width', bandW);
        rect.setAttribute('height', graphH);
        rect.setAttribute('fill', band.bgColor);
        rect.setAttribute('rx', '4');
        this.svg.appendChild(rect);

        const lineL = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        lineL.setAttribute('x1', band.startX);
        lineL.setAttribute('x2', band.startX);
        lineL.setAttribute('y1', padTop);
        lineL.setAttribute('y2', padTop + graphH);
        lineL.setAttribute('stroke', band.color);
        lineL.setAttribute('stroke-dasharray', '2 2');
        lineL.setAttribute('opacity', '0.5');
        this.svg.appendChild(lineL);

        const lineR = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        lineR.setAttribute('x1', band.startX + bandW);
        lineR.setAttribute('x2', band.startX + bandW);
        lineR.setAttribute('y1', padTop);
        lineR.setAttribute('y2', padTop + graphH);
        lineR.setAttribute('stroke', band.color);
        lineR.setAttribute('stroke-dasharray', '2 2');
        lineR.setAttribute('opacity', '0.5');
        this.svg.appendChild(lineR);

        const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        const badgeW = 76;
        const badgeH = 16;
        const badgeX = band.startX + (bandW - badgeW) / 2;
        const badgeY = padTop - 20;

        const badgeRect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        badgeRect.setAttribute('x', badgeX);
        badgeRect.setAttribute('y', badgeY);
        badgeRect.setAttribute('width', badgeW);
        badgeRect.setAttribute('height', badgeH);
        badgeRect.setAttribute('rx', '4');
        badgeRect.setAttribute('fill', band.tipo === 'invierno' ? '#0c2836' : '#330a1c');
        badgeRect.setAttribute('stroke', band.color);
        badgeRect.setAttribute('stroke-width', '1');
        badgeRect.setAttribute('opacity', '0.9');
        g.appendChild(badgeRect);

        const badgeText = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        badgeText.setAttribute('x', badgeX + badgeW / 2);
        badgeText.setAttribute('y', badgeY + 11.5);
        badgeText.setAttribute('text-anchor', 'middle');
        badgeText.setAttribute('fill', band.color);
        badgeText.setAttribute('class', 'font-mono text-[8.5px] font-bold');
        badgeText.textContent = band.tipo === 'invierno' ? 'May-Ago' : 'Dic-Feb';
        g.appendChild(badgeText);

        this.svg.appendChild(g);
    }

    generateSpline(pts) {
        if (pts.length === 0) return '';
        if (pts.length === 1) return `M ${pts[0].x - 45},${pts[0].y} L ${pts[0].x + 45},${pts[0].y}`;
        if (pts.length === 2) return `M ${pts[0].x},${pts[0].y} L ${pts[1].x},${pts[1].y}`;

        let d = `M ${pts[0].x},${pts[0].y}`;
        for (let i = 0; i < pts.length - 1; i++) {
            const p0 = pts[Math.max(0, i - 1)];
            const p1 = pts[i];
            const p2 = pts[i + 1];
            const p3 = pts[Math.min(pts.length - 1, i + 2)];

            const cp1x = p1.x + (p2.x - p0.x) / 6;
            const cp1y = p1.y + (p2.y - p0.y) / 6;
            const cp2x = p2.x - (p3.x - p1.x) / 6;
            const cp2y = p2.y - (p3.y - p1.y) / 6;

            d += ` C ${cp1x.toFixed(1)},${cp1y.toFixed(1)} ${cp2x.toFixed(1)},${cp2y.toFixed(1)} ${p2.x.toFixed(1)},${p2.y.toFixed(1)}`;
        }
        return d;
    }

    generateAreaPath(pts, baselineY) {
        if (pts.length === 0) return '';
        if (pts.length === 1) {
            const x = pts[0].x;
            const y = pts[0].y;
            return `M ${x - 45},${y} L ${x + 45},${y} L ${x + 45},${baselineY} L ${x - 45},${baselineY} Z`;
        }
        const spline = this.generateSpline(pts);
        const first = pts[0];
        const last = pts[pts.length - 1];
        return `${spline} L ${last.x},${baselineY} L ${first.x},${baselineY} Z`;
    }

    handleMouseMove(e) {
        if (!this.currentPoints || this.currentPoints.length === 0) return;

        const rect = this.svg.getBoundingClientRect();
        const clientX = e.clientX !== undefined ? e.clientX : e.pageX;
        const relX = ((clientX - rect.left) / rect.width) * 740;

        let closest = this.currentPoints[0];
        let minDist = Math.abs(relX - closest.x);

        for (let i = 1; i < this.currentPoints.length; i++) {
            const dist = Math.abs(relX - this.currentPoints[i].x);
            if (dist < minDist) {
                minDist = dist;
                closest = this.currentPoints[i];
            }
        }

        if (this.crosshair) {
            this.crosshair.classList.remove('hidden');
            const svgLeftPct = (closest.x / 740) * 100;
            this.crosshair.style.left = `${svgLeftPct}%`;
        }

        if (this.tooltip) {
            this.tooltip.classList.remove('hidden');
            const pctPreguntas = closest.total > 0 ? Math.round((closest.preguntas / closest.total) * 100) : 0;
            
            let franjaBadge = '';
            if (closest.en_franja === 'invierno') {
                franjaBadge = `<div class="mt-1.5 px-2 py-0.5 rounded bg-cyan-950/80 border border-cyan-500/40 text-[#4cd7f6] text-[10px] font-semibold flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-[#4cd7f6] animate-pulse"></span>
                    ${closest.franja_nombre || 'Mayo - Agosto (Parciales)'}
                </div>`;
            } else if (closest.en_franja === 'verano') {
                franjaBadge = `<div class="mt-1.5 px-2 py-0.5 rounded bg-pink-950/80 border border-pink-500/40 text-[#f472b6] text-[10px] font-semibold flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-[#f472b6] animate-pulse"></span>
                    ${closest.franja_nombre || 'Diciembre - Febrero (Verano)'}
                </div>`;
            }

            let picoValleBadge = '';
            if (closest.es_pico) {
                picoValleBadge = `<div class="mt-1 px-1.5 py-0.5 rounded bg-emerald-950/90 border border-emerald-500/40 text-[#4edea3] text-[9.5px] font-bold flex items-center gap-1">
                    <span>▲</span> Pico Máximo de Actividad
                </div>`;
            } else if (closest.es_valle && this.currentPoints.length > 2) {
                picoValleBadge = `<div class="mt-1 px-1.5 py-0.5 rounded bg-pink-950/90 border border-pink-500/40 text-[#f472b6] text-[9.5px] font-bold flex items-center gap-1">
                    <span>▼</span> Caída Mínima (Receso Académico)
                </div>`;
            }

            let drillHint = '';
            if (this.granularity === 'yearly') {
                drillHint = `<div class="mt-1.5 text-primary text-[10px] font-medium border-t border-outline/10 pt-1 flex items-center gap-1">
                    <span class="material-symbols-outlined text-[12px]">zoom_in</span>
                    <span>Clic para ver las caídas y picos de ${closest.label}</span>
                </div>`;
            }

            this.tooltip.innerHTML = `
                <div class="font-mono text-[11px] text-outline font-semibold border-b border-outline/10 pb-1 flex items-center justify-between">
                    <span>${closest.periodo}</span>
                    <span class="text-on-surface font-bold">${closest.label}</span>
                </div>
                <div class="mt-1.5 flex flex-col gap-1 text-[12px]">
                    <div class="flex items-center justify-between gap-3">
                        <span class="flex items-center gap-1.5 text-tertiary">
                            <span class="w-2 h-2 rounded-full bg-tertiary"></span> Total Mensajes:
                        </span>
                        <span class="font-bold font-mono text-on-surface">${Number(closest.total).toLocaleString()}</span>
                    </div>
                    <div class="flex items-center justify-between gap-3">
                        <span class="flex items-center gap-1.5 text-secondary">
                            <span class="w-2 h-2 rounded-full bg-secondary"></span> Preguntas:
                        </span>
                        <span class="font-bold font-mono text-on-surface">${Number(closest.preguntas).toLocaleString()} <span class="text-outline text-[10px]">(${pctPreguntas}%)</span></span>
                    </div>
                </div>
                ${picoValleBadge}
                ${franjaBadge}
                ${drillHint}
            `;

            const containerRect = this.container.getBoundingClientRect();
            const posX = ((closest.x / 740) * rect.width);
            const posY = ((closest.yTotal / 240) * rect.height);

            this.tooltip.style.left = `${Math.min(Math.max(posX, 90), containerRect.width - 140)}px`;
            this.tooltip.style.top = `${Math.max(posY - 20, 30)}px`;
        }
    }

    handleMouseLeave() {
        if (this.crosshair) this.crosshair.classList.add('hidden');
        if (this.tooltip) this.tooltip.classList.add('hidden');
    }
}

document.addEventListener('DOMContentLoaded', () => {
    window.timelineEngine = new TimelineChartEngine('evolucion-temporal');
});
