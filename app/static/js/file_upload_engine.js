/**
 * file_upload_engine.js
 * Motor cliente en Vanilla JavaScript (100% nativo) para la carga y validación
 * de exportaciones de Telegram Desktop (result.json, photos/, stickers/, video_files/) y archivos ZIP.
 * Recrea fielmente la UX del componente React sin dependencias externas.
 */

document.addEventListener("DOMContentLoaded", () => {
    const dropzone = document.getElementById("upload-dropzone");
    const inputFiles = document.getElementById("input-files-upload");
    const inputFolder = document.getElementById("input-folder-upload");
    const btnSelectFiles = document.getElementById("btn-select-files");
    const btnSelectFolder = document.getElementById("btn-select-folder");
    const btnClearAll = document.getElementById("btn-clear-all");
    const btnStartProcess = document.getElementById("btn-start-process");
    
    const statsContainer = document.getElementById("upload-stats-container");
    const badgeCompleted = document.getElementById("badge-completed");
    const badgeFailed = document.getElementById("badge-failed");
    const badgeUploading = document.getElementById("badge-uploading");
    
    const fileListContainer = document.getElementById("file-list-container");
    const errorAlertContainer = document.getElementById("error-alert-container");
    const resultsContainer = document.getElementById("ingestion-results-container");

    if (!dropzone) return;

    // Estado interno de archivos
    let fileQueue = []; // { id, file, relativePath, size, type, progress, status, error, preview }
    let isProcessing = false;
    let latestDiagnosticResult = null;
    let chatTimeline = null;

    // -------------------------------------------------------------------------
    // Utilidades
    // -------------------------------------------------------------------------
    function formatBytes(bytes, decimals = 1) {
        if (!bytes || bytes === 0) return "0 B";
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ["B", "KB", "MB", "GB", "TB"];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i];
    }

    function getFileIconName(file, relPath) {
        const pathLower = (relPath || file.name).toLowerCase();
        const type = file.type || "";
        
        if (pathLower.endsWith("result.json")) return "description";
        if (pathLower.includes("sticker") || pathLower.endsWith(".webp") || pathLower.endsWith(".tgs")) return "sentiment_satisfied";
        if (type.startsWith("image/") || pathLower.includes("photos") || /\.(jpg|jpeg|png|webp|gif)$/.test(pathLower)) return "image";
        if (type.startsWith("video/") || pathLower.includes("video_files") || /\.(mp4|mov|avi|webm)$/.test(pathLower)) return "movie";
        if (pathLower.endsWith(".zip") || pathLower.endsWith(".tar") || pathLower.endsWith(".gz")) return "folder_zip";
        if (pathLower.endsWith(".csv") || pathLower.endsWith(".tsv")) return "table_chart";
        if (type.includes("pdf")) return "picture_as_pdf";
        return "article";
    }

    function generateId() {
        return "f_" + Math.random().toString(36).substr(2, 9);
    }

    // -------------------------------------------------------------------------
    // Manejo de Cola de Archivos y Renderizado
    // -------------------------------------------------------------------------
    function updateStats() {
        const total = fileQueue.length;
        if (total === 0) {
            statsContainer.classList.add("hidden");
            btnStartProcess.classList.add("hidden");
            errorAlertContainer.classList.add("hidden");
            return;
        }

        statsContainer.classList.remove("hidden");
        btnStartProcess.classList.remove("hidden");

        const completed = fileQueue.filter(f => f.status === "completed").length;
        const failed = fileQueue.filter(f => f.status === "error").length;
        const uploading = fileQueue.filter(f => f.status === "uploading").length;

        // Badge Completados
        if (completed > 0) {
            badgeCompleted.classList.remove("hidden");
            badgeCompleted.textContent = `Completed: ${completed}`;
        } else {
            badgeCompleted.classList.add("hidden");
        }

        // Badge Fallidos
        if (failed > 0) {
            badgeFailed.classList.remove("hidden");
            badgeFailed.textContent = `Failed: ${failed}`;
        } else {
            badgeFailed.classList.add("hidden");
        }

        // Badge Subiendo
        if (uploading > 0) {
            badgeUploading.classList.remove("hidden");
            badgeUploading.textContent = `Uploading: ${uploading}`;
        } else {
            badgeUploading.classList.add("hidden");
        }
    }

    function renderFileList() {
        fileListContainer.innerHTML = "";
        if (fileQueue.length === 0) {
            fileListContainer.classList.add("hidden");
            return;
        }

        fileListContainer.classList.remove("hidden");

        fileQueue.forEach(item => {
            const card = document.createElement("div");
            card.className = "bg-surface-container rounded-xl p-3 border border-surface-container-high flex flex-col gap-2 transition-all shadow-sm";
            card.id = `card-${item.id}`;

            const iconName = getFileIconName(item.file, item.relativePath);
            const isImage = item.preview && (item.file.type.startsWith("image/") || /\.(jpg|jpeg|png|webp)$/i.test(item.file.name));

            card.innerHTML = `
                <div class="flex items-start gap-3">
                    <!-- Icono o Thumbnail -->
                    <div class="w-12 h-12 rounded-lg bg-surface-container-high border border-outline/10 flex items-center justify-center shrink-0 overflow-hidden text-outline">
                        ${isImage ? 
                            `<img src="${item.preview}" alt="${item.file.name}" class="w-full h-full object-cover">` : 
                            `<span class="material-symbols-outlined text-[24px] ${iconName === 'description' ? 'text-primary' : (iconName === 'sentiment_satisfied' ? 'text-amber-400' : 'text-outline')}">${iconName}</span>`
                        }
                    </div>

                    <!-- Info y Acciones -->
                    <div class="min-w-0 flex-1 flex flex-col justify-center">
                        <div class="flex items-center justify-between gap-2">
                            <div class="flex flex-col truncate min-w-0">
                                <span class="text-xs font-semibold text-on-surface truncate" title="${item.relativePath || item.file.name}">
                                    ${item.relativePath || item.file.name}
                                </span>
                                <span class="text-[11px] text-outline font-mono">
                                    ${formatBytes(item.file.size)}
                                </span>
                            </div>

                            <div class="flex items-center gap-1.5 shrink-0">
                                ${item.status === 'completed' ? 
                                    `<span class="material-symbols-outlined text-emerald-400 text-[18px]" title="Completado">check_circle</span>` : ''}
                                ${item.status === 'error' ? 
                                    `<button type="button" class="btn-retry text-outline hover:text-primary transition-colors" data-id="${item.id}" title="Reintentar">
                                        <span class="material-symbols-outlined text-[18px]">sync</span>
                                    </button>` : ''}
                                <button type="button" class="btn-remove text-outline hover:text-rose-400 transition-colors" data-id="${item.id}" title="Remover">
                                    <span class="material-symbols-outlined text-[18px]">close</span>
                                </button>
                            </div>
                        </div>

                        <!-- Barra de Progreso -->
                        ${item.status === 'uploading' ? `
                            <div class="w-full bg-surface-container-highest rounded-full h-1.5 mt-2 overflow-hidden">
                                <div class="bg-primary h-1.5 rounded-full transition-all duration-300" style="width: ${item.progress}%"></div>
                            </div>
                        ` : ''}

                        <!-- Alerta de Error Individual -->
                        ${item.status === 'error' && item.error ? `
                            <div class="mt-2 text-[11px] text-rose-400 bg-rose-500/10 border border-rose-500/20 px-2 py-1 rounded flex items-center gap-1">
                                <span class="material-symbols-outlined text-[14px]">error</span>
                                <span>${item.error}</span>
                            </div>
                        ` : ''}
                    </div>
                </div>
            `;
            fileListContainer.appendChild(card);
        });

        // Event listeners para botones remover y reintentar
        fileListContainer.querySelectorAll(".btn-remove").forEach(btn => {
            btn.addEventListener("click", () => {
                const id = btn.getAttribute("data-id");
                removeFile(id);
            });
        });

        fileListContainer.querySelectorAll(".btn-retry").forEach(btn => {
            btn.addEventListener("click", () => {
                const id = btn.getAttribute("data-id");
                retryFile(id);
            });
        });
    }

    function addFiles(newFiles) {
        Array.from(newFiles).forEach(file => {
            const relPath = file.webkitRelativePath || file.name;
            const isImg = file.type.startsWith("image/") || /\.(jpg|jpeg|png|webp)$/i.test(file.name);
            const previewUrl = isImg ? URL.createObjectURL(file) : null;

            fileQueue.push({
                id: generateId(),
                file: file,
                relativePath: relPath,
                size: file.size,
                type: file.type,
                progress: 100,
                status: "completed",
                error: null,
                preview: previewUrl
            });
        });

        // Validar si entre los archivos existe result.json o paquete zip/csv
        validarEstructuraTelegram();
        updateStats();
        renderFileList();
    }

    function validarEstructuraTelegram() {
        if (fileQueue.length === 0) return true;

        const tieneResultJson = fileQueue.some(f => f.relativePath.toLowerCase().endsWith("result.json"));
        const tieneZip = fileQueue.some(f => f.file.name.toLowerCase().endsWith(".zip"));
        const tieneCsvTxt = fileQueue.some(f => /\.(csv|tsv|txt)$/i.test(f.file.name));

        if (!tieneResultJson && !tieneZip && !tieneCsvTxt) {
            errorAlertContainer.classList.remove("hidden");
            errorAlertContainer.innerHTML = `
                <div class="p-3 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-300 text-xs flex items-center gap-2">
                    <span class="material-symbols-outlined text-[20px] shrink-0 text-amber-400">warning</span>
                    <div>
                        <strong>Aviso de estructura:</strong> Se cargaron archivos pero no se detectó el archivo principal 
                        <code class="font-mono bg-surface-container px-1 rounded text-amber-200">result.json</code> 
                        (o paquete .zip). Asegúrate de incluir la exportación completa de Telegram.
                    </div>
                </div>
            `;
            return false;
        } else {
            errorAlertContainer.classList.add("hidden");
            return true;
        }
    }

    function removeFile(fileId) {
        fileQueue = fileQueue.filter(f => f.id !== fileId);
        validarEstructuraTelegram();
        updateStats();
        renderFileList();
    }

    function retryFile(fileId) {
        const item = fileQueue.find(f => f.id === fileId);
        if (item) {
            item.status = "completed";
            item.progress = 100;
            item.error = null;
            updateStats();
            renderFileList();
        }
    }

    function clearAllFiles() {
        fileQueue.forEach(item => {
            if (item.preview) URL.revokeObjectURL(item.preview);
        });
        fileQueue = [];
        updateStats();
        renderFileList();
        if (resultsContainer) resultsContainer.classList.add("hidden");
    }

    // -------------------------------------------------------------------------
    // Eventos de Botones de Selección
    // -------------------------------------------------------------------------
    if (btnSelectFiles && inputFiles) {
        btnSelectFiles.addEventListener("click", () => inputFiles.click());
        inputFiles.addEventListener("change", (e) => {
            if (e.target.files.length > 0) addFiles(e.target.files);
            inputFiles.value = "";
        });
    }

    if (btnSelectFolder && inputFolder) {
        btnSelectFolder.addEventListener("click", () => inputFolder.click());
        inputFolder.addEventListener("change", (e) => {
            if (e.target.files.length > 0) addFiles(e.target.files);
            inputFolder.value = "";
        });
    }

    if (btnClearAll) {
        btnClearAll.addEventListener("click", clearAllFiles);
    }

    // -------------------------------------------------------------------------
    // Drag and Drop Recursivo
    // -------------------------------------------------------------------------
    ["dragenter", "dragover"].forEach(eventName => {
        dropzone.addEventListener(eventName, (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropzone.classList.add("border-primary", "bg-primary/5");
        });
    });

    ["dragleave", "drop"].forEach(eventName => {
        dropzone.addEventListener(eventName, (e) => {
            e.preventDefault();
            e.stopPropagation();
            dropzone.classList.remove("border-primary", "bg-primary/5");
        });
    });

    dropzone.addEventListener("drop", async (e) => {
        const items = e.dataTransfer.items;
        if (!items || items.length === 0) return;

        const filesToProcess = [];

        // Función recursiva para escanear directorios con webkitGetAsEntry
        async function scanEntry(entry, path = "") {
            if (entry.isFile) {
                return new Promise((resolve) => {
                    entry.file((file) => {
                        // Asignar relativePath simulado para que coincida con webkitRelativePath
                        file.simulatedRelativePath = path ? `${path}/${file.name}` : file.name;
                        filesToProcess.push(file);
                        resolve();
                    });
                });
            } else if (entry.isDirectory) {
                const dirReader = entry.createReader();
                return new Promise((resolve) => {
                    dirReader.readEntries(async (entries) => {
                        for (const child of entries) {
                            await scanEntry(child, path ? `${path}/${entry.name}` : entry.name);
                        }
                        resolve();
                    });
                });
            }
        }

        // Procesar todos los items arrastrados
        const scanPromises = [];
        for (let i = 0; i < items.length; i++) {
            const entry = items[i].webkitGetAsEntry ? items[i].webkitGetAsEntry() : null;
            if (entry) {
                scanPromises.push(scanEntry(entry));
            } else if (items[i].kind === "file") {
                const f = items[i].getAsFile();
                if (f) filesToProcess.push(f);
            }
        }

        await Promise.all(scanPromises);

        // Adaptar propiedades de ruta relativa
        filesToProcess.forEach(f => {
            if (!f.webkitRelativePath && f.simulatedRelativePath) {
                f.webkitRelativePath = f.simulatedRelativePath;
            }
        });

        addFiles(filesToProcess);
    });

    // -------------------------------------------------------------------------
    // Procesamiento en Backend Python (POST /api/v1/ingest/upload)
    // -------------------------------------------------------------------------
    if (btnStartProcess) {
        btnStartProcess.addEventListener("click", async () => {
            if (fileQueue.length === 0 || isProcessing) return;

            isProcessing = true;
            btnStartProcess.disabled = true;
            btnStartProcess.innerHTML = `
                <span class="material-symbols-outlined text-[18px] animate-spin">sync</span>
                <span>Procesando con Emotica Python...</span>
            `;

            // Marcar todos en subida
            fileQueue.forEach(f => {
                f.status = "uploading";
                f.progress = 50;
            });
            updateStats();
            renderFileList();

            const formData = new FormData();
            fileQueue.forEach(item => {
                // Preservar la ruta relativa si existe
                formData.append("files", item.file, item.relativePath || item.file.name);
            });

            try {
                const response = await fetch("/api/v1/ingest/upload", {
                    method: "POST",
                    body: formData
                });

                const data = await response.json();

                if (!response.ok || data.status === "error") {
                    throw new Error(data.message || "Error al procesar el chat en el servidor.");
                }

                // Carga exitosa
                fileQueue.forEach(f => {
                    f.status = "completed";
                    f.progress = 100;
                });
                updateStats();
                renderFileList();

                // Mostrar panel de resultados en vivo
                renderResultados(data);

            } catch (err) {
                fileQueue.forEach(f => {
                    f.status = "error";
                    f.error = err.message;
                });
                updateStats();
                renderFileList();

                errorAlertContainer.classList.remove("hidden");
                errorAlertContainer.innerHTML = `
                    <div class="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-start gap-2.5">
                        <span class="material-symbols-outlined text-[20px] text-rose-400 shrink-0">error</span>
                        <div class="flex flex-col gap-1">
                            <strong class="text-rose-200">Error durante la ejecución del pipeline:</strong>
                            <p>${err.message}</p>
                        </div>
                    </div>
                `;
            } finally {
                isProcessing = false;
                btnStartProcess.disabled = false;
                btnStartProcess.innerHTML = `
                    <span class="material-symbols-outlined text-[18px]">bolt</span>
                    <span>Procesar con Motor Python (Emotica)</span>
                `;
            }
        });
    }

    // -------------------------------------------------------------------------
    // Renderizado del Panel de Resultados
    // -------------------------------------------------------------------------
    function renderResultados(data) {
        if (!resultsContainer) return;
        latestDiagnosticResult = data;
        resultsContainer.classList.remove("hidden");

        document.getElementById("res-total-mensajes").textContent = Number(data.total_mensajes || 0).toLocaleString();
        document.getElementById("res-mensajes-texto").textContent = Number(data.mensajes_con_texto || 0).toLocaleString();
        document.getElementById("res-idioma").textContent = (data.idioma_detectado || "und").toUpperCase();
        document.getElementById("res-cobertura").textContent = `${data.cobertura_emocional_pct || 0}%`;

        document.getElementById("res-multimedia-fotos").textContent = data.multimedia?.fotos || 0;
        document.getElementById("res-multimedia-stickers").textContent = data.multimedia?.stickers || 0;
        document.getElementById("res-multimedia-videos").textContent = data.multimedia?.videos || 0;

        // Renderizar Top Emociones
        const emoContainer = document.getElementById("res-top-emociones-container");
        if (emoContainer) {
            emoContainer.innerHTML = "";
            (data.top_emociones || []).forEach(e => {
                const badge = document.createElement("div");
                badge.className = "p-2 rounded-xl bg-surface-container-high border border-outline/10 flex items-center justify-between text-xs";
                badge.innerHTML = `
                    <div class="flex items-center gap-1.5 font-semibold text-on-surface capitalize">
                        <span class="w-2 h-2 rounded-full bg-primary"></span>
                        <span>${e.emocion}</span>
                    </div>
                    <div class="font-mono text-outline">
                        <strong>${e.conteo}</strong> (${e.pct}%)
                    </div>
                `;
                emoContainer.appendChild(badge);
            });
        }

        // Renderizar Muestras Antes vs Después
        const muestrasBody = document.getElementById("res-muestras-table-body");
        if (muestrasBody) {
            muestrasBody.innerHTML = "";
            (data.muestras || []).forEach(m => {
                const tr = document.createElement("tr");
                tr.className = "border-b border-surface-container-high/40 text-xs hover:bg-surface-container/30 transition-colors";
                tr.innerHTML = `
                    <td class="p-2.5 font-mono text-outline font-semibold">#${m.msg_id}</td>
                    <td class="p-2.5 text-on-surface-variant max-w-[200px] truncate" title="${m.texto_original}">${m.texto_original}</td>
                    <td class="p-2.5 text-on-surface max-w-[200px] truncate font-medium" title="${m.texto_limpio}">${m.texto_limpio}</td>
                    <td class="p-2.5">
                        <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-primary/20 text-primary border border-primary/30 capitalize">
                            ${m.emocion}
                        </span>
                    </td>
                    <td class="p-2.5 font-mono text-[11px] text-tertiary max-w-[180px] truncate" title="${m.evidencia}">${m.evidencia}</td>
                `;
                muestrasBody.appendChild(tr);
            });
        }

        // Renderizar Pasos de Bitácora
        const bitacoraBody = document.getElementById("res-bitacora-table-body");
        if (bitacoraBody) {
            bitacoraBody.innerHTML = "";
            (data.bitacora_pasos || []).forEach(b => {
                const tr = document.createElement("tr");
                tr.className = "border-b border-surface-container-high/40 text-xs";
                tr.innerHTML = `
                    <td class="p-2 font-mono text-primary font-semibold">${b.paso}</td>
                    <td class="p-2 font-mono text-outline">${b.filas_entrada}</td>
                    <td class="p-2 font-mono text-on-surface font-medium">${b.filas_salida}</td>
                    <td class="p-2 font-mono text-secondary">${b.duracion_s}s</td>
                    <td class="p-2 text-outline text-[11px] truncate max-w-[220px]" title="${b.detalle}">${b.detalle}</td>
                `;
                bitacoraBody.appendChild(tr);
            });
        }

        // Renderizar Comparativa vs Baseline Histórico de Neon (Read-Only)
        if (data.comparativa_neon) {
            const cmp = data.comparativa_neon;
            const elChatPos = document.getElementById("cmp-chat-pos");
            const elCorpusPos = document.getElementById("cmp-corpus-pos");
            const elChatNeg = document.getElementById("cmp-chat-neg");
            const elCorpusNeg = document.getElementById("cmp-corpus-neg");
            const elDeltaBadge = document.getElementById("cmp-delta-badge");

            if (elChatPos) elChatPos.textContent = `${cmp.chat_metricas?.pct_positivo || 0}%`;
            if (elCorpusPos) elCorpusPos.textContent = `${cmp.baseline_neon?.pct_positivo || 61.8}%`;
            if (elChatNeg) elChatNeg.textContent = `${cmp.chat_metricas?.pct_negativo || 0}%`;
            if (elCorpusNeg) elCorpusNeg.textContent = `${cmp.baseline_neon?.pct_negativo || 29.2}%`;
            if (elDeltaBadge) elDeltaBadge.textContent = cmp.diferencial_polaridad?.interpretacion || "Comparativa calculada";

            // Renderizar Docentes de Neon identificados en el chat
            const docContainer = document.getElementById("cmp-docentes-container");
            const docTotal = document.getElementById("cmp-docentes-total");
            const docs = cmp.docentes_mencionados || [];

            if (docTotal) docTotal.textContent = docs.length;
            if (docContainer) {
                docContainer.innerHTML = "";
                if (docs.length === 0) {
                    docContainer.innerHTML = '<span class="text-[11px] text-outline">Sin menciones docentes detectadas</span>';
                } else {
                    docs.forEach(d => {
                        const sp = document.createElement("span");
                        sp.className = "px-2 py-0.5 rounded-md bg-secondary/15 text-secondary border border-secondary/30 text-[10px] font-mono font-semibold flex items-center gap-1";
                        sp.innerHTML = `<span class="material-symbols-outlined text-[12px]">school</span>${d.nombre} (${d.menciones})`;
                        docContainer.appendChild(sp);
                    });
                }
            }
        }

        // Renderizar Evolución Temporal del Chat Analizado (Spline en Memoria)
        if (data.timeline && chatTimeline) {
            chatTimeline.loadData(data.timeline);
        }

        // Desplazar vista a los resultados
        resultsContainer.scrollIntoView({ behavior: "smooth" });
    }

    // -------------------------------------------------------------------------
    // Motor de Visualización Spline Cúbico del Chat (ChatTimelineEngine)
    // -------------------------------------------------------------------------
    class ChatTimelineEngine {
        constructor() {
            this.card = document.getElementById("chat-timeline-card");
            this.svg = document.getElementById("chat-timeline-svg");
            this.crosshair = document.getElementById("chat-timeline-crosshair");
            this.tooltip = document.getElementById("chat-timeline-tooltip");
            this.granButtons = document.querySelectorAll(".chat-timeline-gran-btn");
            this.spanBadge = document.getElementById("chat-timeline-span-badge");

            this.timelineData = null;
            this.currentGranularity = "monthly";
            this.currentPoints = [];

            this.initEvents();
        }

        initEvents() {
            this.granButtons.forEach(btn => {
                btn.addEventListener("click", () => {
                    const gran = btn.dataset.chatGran;
                    if (!gran || !this.timelineData) return;
                    this.setGranularity(gran);
                });
            });

            if (this.svg) {
                this.svg.addEventListener("mousemove", (e) => this.handleMouseMove(e));
                this.svg.addEventListener("mouseleave", () => this.handleMouseLeave());

                this.svg.addEventListener("touchstart", (e) => {
                    if (e.touches && e.touches[0]) this.handleMouseMove(e.touches[0]);
                }, { passive: true });

                this.svg.addEventListener("touchmove", (e) => {
                    if (e.touches && e.touches[0]) this.handleMouseMove(e.touches[0]);
                }, { passive: true });

                this.svg.addEventListener("touchend", () => this.handleMouseLeave());
            }

            window.addEventListener("resize", () => {
                if (this.timelineData) this.render();
            });
        }

        loadData(timeline) {
            if (!timeline || timeline.status !== "success" || !timeline.granularidades) {
                if (this.card) this.card.classList.add("hidden");
                return;
            }

            this.timelineData = timeline;
            if (this.card) this.card.classList.remove("hidden");

            if (this.spanBadge && timeline.fecha_inicio && timeline.fecha_fin) {
                this.spanBadge.textContent = `Período evaluado: ${timeline.fecha_inicio} al ${timeline.fecha_fin} (${timeline.duracion_dias} días)`;
            }

            // Elegir granularidad por defecto
            const def = timeline.default_granularity || "monthly";
            this.setGranularity(def);
        }

        setGranularity(gran) {
            this.currentGranularity = gran;

            // Actualizar botones UI
            this.granButtons.forEach(b => {
                if (b.dataset.chatGran === gran) {
                    b.classList.add("bg-primary", "text-on-primary", "font-semibold");
                    b.classList.remove("text-outline", "hover:text-on-surface");
                } else {
                    b.classList.remove("bg-primary", "text-on-primary", "font-semibold");
                    b.classList.add("text-outline", "hover:text-on-surface");
                }
            });

            const dataGran = this.timelineData?.granularidades?.[gran];
            if (!dataGran) {
                const fallbackKey = Object.keys(this.timelineData.granularidades).find(k => this.timelineData.granularidades[k] !== null);
                if (fallbackKey && fallbackKey !== gran) {
                    this.setGranularity(fallbackKey);
                    return;
                }
            }

            this.updateKPIs(dataGran?.kpis);
            this.render();
        }

        updateKPIs(kpis) {
            const elTotal = document.getElementById("chat-kpi-total");
            const elPico = document.getElementById("chat-kpi-pico");
            const elCaida = document.getElementById("chat-kpi-caida");
            const elPreg = document.getElementById("chat-kpi-preguntas");
            const elProm = document.getElementById("chat-kpi-promedio");

            if (!kpis) {
                if (elTotal) elTotal.textContent = "--";
                if (elPico) elPico.textContent = "--";
                if (elCaida) elCaida.textContent = "--";
                if (elPreg) elPreg.textContent = "--";
                if (elProm) elProm.textContent = "--";
                return;
            }

            if (elTotal) elTotal.textContent = Number(kpis.total_periodo || 0).toLocaleString();
            if (elPico && kpis.pico_maximo) {
                elPico.textContent = `${kpis.pico_maximo.label} (${Number(kpis.pico_maximo.total).toLocaleString()} msgs)`;
            }
            if (elCaida && kpis.caida_minima) {
                elCaida.textContent = `${kpis.caida_minima.label} (${Number(kpis.caida_minima.total).toLocaleString()} msgs)`;
            }
            if (elPreg) {
                elPreg.textContent = `${Number(kpis.total_preguntas || 0).toLocaleString()} (${kpis.pct_preguntas || 0}%)`;
            }
            if (elProm) {
                const suf = this.currentGranularity === 'hourly' ? 'hora' : (this.currentGranularity === 'weekly' ? 'sem' : 'mes');
                elProm.textContent = `${Number(kpis.promedio || 0).toLocaleString()} / ${suf}`;
            }
        }

        generateSpline(pts) {
            if (!pts || pts.length === 0) return '';
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
            if (!pts || pts.length === 0) return '';
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

        render() {
            if (!this.svg || !this.timelineData) return;
            const dataGran = this.timelineData.granularidades?.[this.currentGranularity];
            const points = dataGran?.points || [];
            if (points.length === 0) return;

            const width = 740;
            const height = 240;
            const padLeft = 50;
            const padRight = 30;
            const padTop = 35;
            const padBottom = 35;

            const graphW = width - padLeft - padRight;
            const graphH = height - padTop - padBottom;

            const maxVal = Math.max(...points.map(p => p.total), 10);
            const yMax = Math.ceil((maxVal * 1.25) / 10) * 10 || 10;

            // Limpiar lienzo excepto defs
            const defs = this.svg.querySelector("defs");
            this.svg.innerHTML = "";
            if (defs) this.svg.appendChild(defs);

            // 1. Grid horizontal de referencia y ticks Y
            const yTicks = 4;
            for (let i = 0; i <= yTicks; i++) {
                const val = Math.round((yMax / yTicks) * i);
                const yPos = padTop + graphH - (val / yMax) * graphH;

                const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
                line.setAttribute("x1", padLeft);
                line.setAttribute("x2", width - padRight);
                line.setAttribute("y1", yPos);
                line.setAttribute("y2", yPos);
                line.setAttribute("stroke", "currentColor");
                line.setAttribute("class", i === 0 ? "text-outline-variant/60" : "text-surface-container-highest/60");
                if (i > 0) line.setAttribute("stroke-dasharray", "3 3");
                this.svg.appendChild(line);

                const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
                text.setAttribute("x", padLeft - 8);
                text.setAttribute("y", yPos + 3.5);
                text.setAttribute("text-anchor", "end");
                text.setAttribute("fill", "#908fa0");
                text.setAttribute("class", "font-mono text-[10px]");
                text.textContent = val >= 1000 ? (val / 1000).toFixed(1) + "k" : val;
                this.svg.appendChild(text);
            }

            // 2. Coordenadas de puntos
            const stepX = points.length > 1 ? graphW / (points.length - 1) : 0;
            this.currentPoints = points.map((p, idx) => {
                const x = points.length > 1 ? padLeft + idx * stepX : padLeft + graphW / 2;
                const yTotal = padTop + graphH - (p.total / yMax) * graphH;
                const yPreg = padTop + graphH - (p.preguntas / yMax) * graphH;
                return { ...p, x, yTotal, yPreg, index: idx };
            });

            // 3. Área y Curva de Volumen Total (#chatVolumeArea, #4cd7f6)
            const totalAreaPath = this.generateAreaPath(this.currentPoints.map(p => ({ x: p.x, y: p.yTotal })), padTop + graphH);
            if (totalAreaPath) {
                const pathAreaTotal = document.createElementNS("http://www.w3.org/2000/svg", "path");
                pathAreaTotal.setAttribute("d", totalAreaPath);
                pathAreaTotal.setAttribute("fill", "url(#chatVolumeArea)");
                this.svg.appendChild(pathAreaTotal);
            }

            // 4. Área y Curva de Preguntas (#chatPosArea, #4edea3)
            const pregAreaPath = this.generateAreaPath(this.currentPoints.map(p => ({ x: p.x, y: p.yPreg })), padTop + graphH);
            if (pregAreaPath) {
                const pathAreaPreg = document.createElementNS("http://www.w3.org/2000/svg", "path");
                pathAreaPreg.setAttribute("d", pregAreaPath);
                pathAreaPreg.setAttribute("fill", "url(#chatPosArea)");
                this.svg.appendChild(pathAreaPreg);
            }

            // Curva Total Spline
            const totalLinePath = this.generateSpline(this.currentPoints.map(p => ({ x: p.x, y: p.yTotal })));
            if (totalLinePath) {
                const pLine = document.createElementNS("http://www.w3.org/2000/svg", "path");
                pLine.setAttribute("d", totalLinePath);
                pLine.setAttribute("fill", "none");
                pLine.setAttribute("stroke", "#4cd7f6");
                pLine.setAttribute("stroke-width", "2.5");
                pLine.setAttribute("stroke-linecap", "round");
                this.svg.appendChild(pLine);
            }

            // Curva Preguntas Spline
            const pregLinePath = this.generateSpline(this.currentPoints.map(p => ({ x: p.x, y: p.yPreg })));
            if (pregLinePath) {
                const pPregLine = document.createElementNS("http://www.w3.org/2000/svg", "path");
                pPregLine.setAttribute("d", pregLinePath);
                pPregLine.setAttribute("fill", "none");
                pPregLine.setAttribute("stroke", "#4edea3");
                pPregLine.setAttribute("stroke-width", "2");
                pPregLine.setAttribute("stroke-linecap", "round");
                pPregLine.setAttribute("stroke-dasharray", "4 3");
                this.svg.appendChild(pPregLine);
            }

            // 5. Etiquetas en Eje X
            const skipFactor = Math.ceil(this.currentPoints.length / 12);
            this.currentPoints.forEach((p, idx) => {
                if (idx % skipFactor === 0 || idx === this.currentPoints.length - 1) {
                    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
                    text.setAttribute("x", p.x);
                    text.setAttribute("y", height - 12);
                    text.setAttribute("text-anchor", "middle");
                    text.setAttribute("class", "font-mono text-[10px]");
                    text.setAttribute("fill", "#908fa0");
                    text.textContent = p.label;
                    this.svg.appendChild(text);
                }
            });

            // 6. Círculos de Puntos y Picos
            const picoPunto = this.currentPoints.reduce((max, p) => p.total > max.total ? p : max, this.currentPoints[0]);
            const vallePunto = this.currentPoints.reduce((min, p) => p.total < min.total ? p : min, this.currentPoints[0]);

            this.currentPoints.forEach(p => {
                const isPico = (p === picoPunto && p.total > 0 && this.currentPoints.length > 2);
                const isValle = (p === vallePunto && this.currentPoints.length > 2);

                const halo = document.createElementNS("http://www.w3.org/2000/svg", "circle");
                halo.setAttribute("cx", p.x);
                halo.setAttribute("cy", p.yTotal);
                halo.setAttribute("r", isPico || isValle ? "7" : "4.5");
                halo.setAttribute("fill", isPico ? "rgba(78, 222, 163, 0.35)" : (isValle ? "rgba(244, 114, 182, 0.35)" : "rgba(76, 215, 246, 0.25)"));
                this.svg.appendChild(halo);

                const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
                circle.setAttribute("cx", p.x);
                circle.setAttribute("cy", p.yTotal);
                circle.setAttribute("r", isPico || isValle ? "4.5" : "2.5");
                circle.setAttribute("fill", isPico ? "#4edea3" : (isValle ? "#f472b6" : "#4cd7f6"));
                circle.setAttribute("stroke", "#13141f");
                circle.setAttribute("stroke-width", "1.5");
                this.svg.appendChild(circle);
            });
        }

        handleMouseMove(e) {
            if (!this.currentPoints || this.currentPoints.length === 0 || !this.svg) return;

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

            if (this.crosshair) {
                this.crosshair.classList.remove("hidden");
                const svgLeftPct = (closest.x / 740) * 100;
                this.crosshair.style.left = `${svgLeftPct}%`;
            }

            if (this.tooltip && this.card) {
                this.tooltip.classList.remove("hidden");
                this.tooltip.innerHTML = `
                    <div class="flex items-center justify-between gap-3 border-b border-outline/20 pb-1 mb-1.5">
                        <span class="font-mono text-xs font-bold text-primary">${closest.label}</span>
                        <span class="text-[10px] text-outline font-mono">Chat Evaluado</span>
                    </div>
                    <div class="flex flex-col gap-1 text-xs font-mono">
                        <div class="flex items-center justify-between gap-4">
                            <span class="text-[#4cd7f6] flex items-center gap-1">
                                <span class="w-2 h-2 rounded-full bg-[#4cd7f6]"></span> Total Mensajes:
                            </span>
                            <strong class="text-on-surface font-bold">${Number(closest.total).toLocaleString()}</strong>
                        </div>
                        <div class="flex items-center justify-between gap-4">
                            <span class="text-[#4edea3] flex items-center gap-1">
                                <span class="w-2 h-2 rounded-full bg-[#4edea3]"></span> Preguntas Académicas:
                            </span>
                            <strong class="text-on-surface font-bold">${Number(closest.preguntas).toLocaleString()} (${closest.pct_preguntas}%)</strong>
                        </div>
                    </div>
                `;

                const cardRect = this.card.getBoundingClientRect();
                const posX = clientX - cardRect.left;
                const posY = (e.clientY !== undefined ? e.clientY : (e.touches && e.touches[0] ? e.touches[0].clientY : 0)) - cardRect.top;

                const tooltipW = 210;
                const tooltipH = 75;
                let finalLeft = posX + 15;
                let finalTop = posY - tooltipH - 10;

                if (finalLeft + tooltipW > cardRect.width - 20) {
                    finalLeft = posX - tooltipW - 15;
                }
                if (finalTop < 10) {
                    finalTop = posY + 15;
                }

                this.tooltip.style.left = `${finalLeft}px`;
                this.tooltip.style.top = `${finalTop}px`;
            }
        }

        handleMouseLeave() {
            if (this.crosshair) this.crosshair.classList.add("hidden");
            if (this.tooltip) this.tooltip.classList.add("hidden");
        }
    }

    // Instanciar motor de evolución temporal
    chatTimeline = new ChatTimelineEngine();

    // Exportar Reporte Diagnóstico en JSON
    const btnExportJson = document.getElementById("btn-export-diagnostic-json");
    if (btnExportJson) {
        btnExportJson.addEventListener("click", () => {
            if (!latestDiagnosticResult) {
                showError("No hay reporte de diagnóstico disponible para exportar.");
                return;
            }
            try {
                const jsonStr = JSON.stringify(latestDiagnosticResult, null, 2);
                const blob = new Blob([jsonStr], { type: "application/json;charset=utf-8" });
                const url = URL.createObjectURL(blob);
                const a = document.createElement("a");
                const safeName = (latestDiagnosticResult.archivo || "chat").replace(/[^a-zA-Z0-9_\-]/g, "_");
                const dateStr = new Date().toISOString().slice(0, 10);
                a.href = url;
                a.download = `sentidata_diagnostico_${safeName}_${dateStr}.json`;
                document.body.appendChild(a);
                a.click();
                setTimeout(() => {
                    document.body.removeChild(a);
                    URL.revokeObjectURL(url);
                }, 100);
            } catch (err) {
                showError(`Error al exportar reporte: ${err.message}`);
            }
        });
    }
});
