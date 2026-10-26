/**
 * sankey_engine.js - SentiDataUMSA
 * Motor de visualización analítica del Pipeline ETL & NLP.
 * Gestiona el Diagrama de Sankey interactivo (Apache ECharts) y el Histograma de Distribución de Longitud.
 */

class PreprocessingAnalyticsEngine {
    constructor() {
        this.sankeyContainer = document.getElementById('sankey-chart-container');
        this.sankeyChart = null;
        this.currentMode = 'volumen'; // 'volumen' | 'tipologia'
        this.sankeyData = window.__PREP_SANKEY_DATA__ || null;
        this.histogramData = window.__PREP_HISTOGRAM_DATA__ || null;

        this.init();
    }

    init() {
        if (this.sankeyContainer && typeof echarts !== 'undefined' && this.sankeyData) {
            this.initSankey();
            this.initModeControls();
            this.initThemeWatcher();
            this.initResizeListener();
        }

        if (this.histogramData) {
            this.renderHistogram();
        }
    }

    isDarkMode() {
        return document.documentElement.classList.contains('dark');
    }

    getThemeColors() {
        const dark = this.isDarkMode();
        return {
            textColor: dark ? '#cbd5e1' : '#334155',
            tooltipBg: dark ? 'rgba(15, 23, 42, 0.92)' : 'rgba(255, 255, 255, 0.95)',
            tooltipBorder: dark ? 'rgba(99, 102, 241, 0.35)' : 'rgba(99, 102, 241, 0.2)',
            tooltipText: dark ? '#f8fafc' : '#0f172a',
            linkOpacity: dark ? 0.38 : 0.32,
            linkHoverOpacity: 0.75
        };
    }

    initSankey() {
        if (!this.sankeyContainer) return;

        if (this.sankeyChart) {
            this.sankeyChart.dispose();
        }

        this.sankeyChart = echarts.init(this.sankeyContainer, null, {
            renderer: 'svg'
        });

        this.updateSankeyOption();
    }

    updateSankeyOption() {
        if (!this.sankeyChart || !this.sankeyData) return;

        const colors = this.getThemeColors();
        const modeData = this.currentMode === 'volumen' 
            ? this.sankeyData.modo_volumen 
            : this.sankeyData.modo_tipologia;

        if (!modeData || !modeData.nodes || !modeData.links) return;

        const isVolumen = this.currentMode === 'volumen';
        const unitLabel = isVolumen ? 'caracteres' : 'mensajes';

        const option = {
            backgroundColor: 'transparent',
            tooltip: {
                trigger: 'item',
                triggerOn: 'mousemove',
                backgroundColor: colors.tooltipBg,
                borderColor: colors.tooltipBorder,
                borderWidth: 1,
                padding: [10, 14],
                textStyle: {
                    color: colors.tooltipText,
                    fontFamily: 'Inter, system-ui, sans-serif',
                    fontSize: 12
                },
                extraCssText: 'backdrop-filter: blur(8px); border-radius: 12px; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);',
                formatter: (params) => {
                    if (params.dataType === 'edge') {
                        const valFormatted = Number(params.value).toLocaleString();
                        return `
                            <div class="flex flex-col gap-1">
                                <div class="text-[11px] font-mono text-indigo-400 font-semibold uppercase tracking-wider flex items-center gap-1.5">
                                    <span>${params.data.source}</span>
                                    <span class="text-slate-400">➔</span>
                                    <span>${params.data.target}</span>
                                </div>
                                <div class="flex items-baseline gap-2 mt-0.5">
                                    <span class="text-base font-bold font-mono text-white">${valFormatted}</span>
                                    <span class="text-xs text-slate-400">${unitLabel}</span>
                                </div>
                            </div>
                        `;
                    } else {
                        const valFormatted = params.value ? Number(params.value).toLocaleString() : '';
                        return `
                            <div class="flex flex-col gap-1">
                                <span class="text-xs font-semibold text-slate-200">${params.name}</span>
                                ${valFormatted ? `
                                <div class="flex items-baseline gap-2">
                                    <span class="text-sm font-bold font-mono text-indigo-300">${valFormatted}</span>
                                    <span class="text-[11px] text-slate-400">${unitLabel}</span>
                                </div>` : ''}
                            </div>
                        `;
                    }
                }
            },
            series: [
                {
                    type: 'sankey',
                    layout: 'none',
                    emphasis: {
                        focus: 'adjacency'
                    },
                    nodeAlign: 'justify',
                    orient: 'horizontal',
                    draggable: true,
                    nodeWidth: 18,
                    nodeGap: 18,
                    data: modeData.nodes.map(n => ({
                        ...n,
                        itemStyle: {
                            ...n.itemStyle,
                            borderRadius: 4
                        }
                    })),
                    links: modeData.links,
                    lineStyle: {
                        color: 'gradient',
                        curveness: 0.5,
                        opacity: colors.linkOpacity
                    },
                    label: {
                        color: colors.textColor,
                        fontFamily: 'Inter, system-ui, sans-serif',
                        fontSize: 12,
                        fontWeight: 500,
                        padding: [0, 8]
                    }
                }
            ]
        };

        this.sankeyChart.setOption(option, true);
    }

    initModeControls() {
        const btnVolumen = document.getElementById('btn-sankey-volumen');
        const btnTipologia = document.getElementById('btn-sankey-tipologia');
        const modeBadge = document.getElementById('sankey-mode-badge');
        const modeDesc = document.getElementById('sankey-mode-desc');

        if (!btnVolumen || !btnTipologia) return;

        const updateStyles = (activeMode) => {
            this.currentMode = activeMode;

            if (activeMode === 'volumen') {
                btnVolumen.classList.add('bg-primary', 'text-on-primary', 'font-semibold', 'shadow-sm');
                btnVolumen.classList.remove('text-outline', 'hover:text-on-surface');

                btnTipologia.classList.remove('bg-primary', 'text-on-primary', 'font-semibold', 'shadow-sm');
                btnTipologia.classList.add('text-outline', 'hover:text-on-surface');

                if (modeBadge) modeBadge.textContent = 'Métrica: Volumen de Caracteres & Tokens';
                if (modeDesc) modeDesc.textContent = 'Flujo de compresión desde los 1,469,733 caracteres crudos hacia los tokens canónicos refinados.';
            } else {
                btnTipologia.classList.add('bg-primary', 'text-on-primary', 'font-semibold', 'shadow-sm');
                btnTipologia.classList.remove('text-outline', 'hover:text-on-surface');

                btnVolumen.classList.remove('bg-primary', 'text-on-primary', 'font-semibold', 'shadow-sm');
                btnVolumen.classList.add('text-outline', 'hover:text-on-surface');

                if (modeBadge) modeBadge.textContent = 'Métrica: Tipología de Mensajes (23,371 Filas)';
                if (modeDesc) modeDesc.textContent = 'Distribución de los 23,371 mensajes del corpus según presencia de preguntas, emojis, stickers o texto estándar.';
            }

            this.updateSankeyOption();
        };

        btnVolumen.addEventListener('click', () => updateStyles('volumen'));
        btnTipologia.addEventListener('click', () => updateStyles('tipologia'));
    }

    initThemeWatcher() {
        const observer = new MutationObserver(() => {
            if (this.sankeyChart) {
                this.updateSankeyOption();
            }
            if (this.histogramData) {
                this.renderHistogram();
            }
        });

        observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['class']
        });
    }

    initResizeListener() {
        window.addEventListener('resize', () => {
            if (this.sankeyChart) {
                this.sankeyChart.resize();
            }
            if (this.histogramData) {
                this.renderHistogram();
            }
        });
    }

    renderHistogram() {
        const svg = document.getElementById('length-distribution-svg');
        const tooltip = document.getElementById('hist-tooltip');
        if (!svg || !this.histogramData) return;

        const data = this.histogramData;
        const categories = data.categories || [];
        const orig = data.original || [];
        const norm = data.normalizado || [];

        const width = 640;
        const height = 270;
        const padLeft = 45;
        const padRight = 20;
        const padTop = 25;
        const padBottom = 35;

        const chartWidth = width - padLeft - padRight;
        const chartHeight = height - padTop - padBottom;

        const maxVal = Math.max(...orig, ...norm, 1);
        const barGroupWidth = chartWidth / categories.length;
        const barWidth = Math.max(barGroupWidth * 0.36, 10);

        let svgHtml = '';

        // Líneas de guía horizontales
        const gridSteps = 4;
        for (let i = 0; i <= gridSteps; i++) {
            const y = padTop + chartHeight - (i / gridSteps) * chartHeight;
            const val = Math.round((i / gridSteps) * maxVal);
            svgHtml += `
                <line x1="${padLeft}" y1="${y}" x2="${width - padRight}" y2="${y}" stroke="currentColor" class="text-outline/15" stroke-dasharray="3,3" stroke-width="1"/>
                <text x="${padLeft - 8}" y="${y + 3}" text-anchor="end" class="fill-outline font-mono text-[9px]">${val.toLocaleString()}</text>
            `;
        }

        // Render de barras dobles (Original vs Normalizado)
        categories.forEach((cat, idx) => {
            const groupX = padLeft + idx * barGroupWidth;
            const xOrig = groupX + (barGroupWidth / 2) - barWidth - 2;
            const xNorm = groupX + (barGroupWidth / 2) + 2;

            const hOrig = (orig[idx] / maxVal) * chartHeight;
            const yOrig = padTop + chartHeight - hOrig;

            const hNorm = (norm[idx] / maxVal) * chartHeight;
            const yNorm = padTop + chartHeight - hNorm;

            // Barra Original (Rojo/Gris/Secundario)
            svgHtml += `
                <rect x="${xOrig}" y="${yOrig}" width="${barWidth}" height="${hOrig}" rx="3"
                    fill="url(#grad-orig)" class="opacity-80 hover:opacity-100 transition-opacity cursor-pointer hist-bar"
                    data-type="Original (Telegram)" data-cat="${cat} chars" data-val="${orig[idx].toLocaleString()}" />
            `;

            // Barra Normalizada (Primario / Turquesa)
            svgHtml += `
                <rect x="${xNorm}" y="${yNorm}" width="${barWidth}" height="${hNorm}" rx="3"
                    fill="url(#grad-norm)" class="opacity-90 hover:opacity-100 transition-opacity cursor-pointer hist-bar"
                    data-type="Normalizado (Limpio)" data-cat="${cat} chars" data-val="${norm[idx].toLocaleString()}" />
            `;

            // Label eje X
            svgHtml += `
                <text x="${groupX + barGroupWidth / 2}" y="${height - 12}" text-anchor="middle" class="fill-outline font-mono text-[10px]">${cat}</text>
            `;
        });

        // Gradientes SVG
        const defs = `
            <defs>
                <linearGradient id="grad-orig" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="#f87171" stop-opacity="0.9"/>
                    <stop offset="100%" stop-color="#ef4444" stop-opacity="0.5"/>
                </linearGradient>
                <linearGradient id="grad-norm" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stop-color="#38bdf8" stop-opacity="0.95"/>
                    <stop offset="100%" stop-color="#0284c7" stop-opacity="0.6"/>
                </linearGradient>
            </defs>
        `;

        svg.innerHTML = defs + svgHtml;

        // Tooltip interactivo sobre las barras
        const bars = svg.querySelectorAll('.hist-bar');
        bars.forEach(bar => {
            bar.addEventListener('mouseenter', (e) => {
                if (!tooltip) return;
                const type = bar.dataset.type;
                const cat = bar.dataset.cat;
                const val = bar.dataset.val;

                tooltip.innerHTML = `
                    <div class="font-semibold text-white text-[11px] mb-0.5">${type}</div>
                    <div class="text-[10px] text-slate-300">Rango: <span class="font-mono text-indigo-300">${cat}</span></div>
                    <div class="text-sm font-bold font-mono text-emerald-400 mt-1">${val} <span class="text-[10px] font-normal text-slate-300">mensajes</span></div>
                `;
                tooltip.classList.remove('hidden');
            });

            bar.addEventListener('mousemove', (e) => {
                if (!tooltip) return;
                const containerRect = svg.parentElement.getBoundingClientRect();
                const x = e.clientX - containerRect.left + 15;
                const y = e.clientY - containerRect.top - 30;
                tooltip.style.left = `${x}px`;
                tooltip.style.top = `${y}px`;
            });

            bar.addEventListener('mouseleave', () => {
                if (!tooltip) return;
                tooltip.classList.add('hidden');
            });
        });
    }
}

// Inicialización automática cuando el DOM esté listo
document.addEventListener('DOMContentLoaded', () => {
    window.preprocessingEngine = new PreprocessingAnalyticsEngine();
});
