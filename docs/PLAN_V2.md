# PLAN_V2 — AS_Telegram V2 (seguimiento de fases)

> Archivo de continuidad exigido por `PROMPTMAESTROV2.md` §17. Se actualiza al final
> de cada fase. No depende del historial de conversación.

## Estado
- Fase actual: **FASE 6 completada** (V2 finalizada; ejecución continua F0–F6).
- Última actualización: 2026-10-22.

## Diagnóstico FASE 0 (auditoría, solo lectura)

Arquitectura real (no se fuerza la numeración 00–15 de §4 del prompt maestro;
el proyecto ya usa `R/<módulo>.R` + `scripts/NN_<etapa>.R` + `dashboard/modules/mod_<x>.R`):

- Pipeline R: `R/{config,bootstrap,helpers,import_corpus,validate_corpus,clean_text,
  sentiment_dictionary,detect_negation,process_emojis,analyze_sentiment,analyze_topics,
  analyze_temporal,analyze_markov,evaluate_models,plotting,audit_log,database,
  report_figures,report_generation,dashboard_data}.R`; etapas ejecutables en
  `scripts/01_import … 10_test` con `bootstrap()` que fija rutas y fuentea `R/`.
- Datos: `data/raw/result.json` (corpus real, NO modificar), `data/processed`,
  `data/results` (RDS), `data/dictionary/sentiment_dictionary.csv`, SQLite `database/`.
- Diccionario propio: **18 categorías** (`EMOTION_CATEGORIES`, ≥ 15 exigidas), versionado
  (`dictionary_version`), términos + polaridad + peso + procedencia.
- Bitácora SQLite: tabla `audit_events` con run_id, dictionary_version, status,
  duration_s, warnings, errors, artifacts; `audit_start/audit_event`.
- Dashboard: Shiny + bslib + **ECharts local** (`www/echarts.min.js`), 10 módulos,
  avatar emocional SVG ya implementado (objetivo K cumplido), tema claro/oscuro.
- Informe LaTeX listo para Overleaf (33 págs) + `README_OVERLEAF.md`.
- Pruebas testthat: `OK 10_test`. renv en sync.

### Brechas frente a los objetivos V2 (§3)
| Objetivo | Estado actual | Acción planificada (fase) |
|---|---|---|
| A/B pipeline + tokenización + stopwords | OK (quanteda) | — (docs) |
| C n-gramas configurables + límites entre mensajes | No existe | F1 `R/ngrams.R` |
| D características lingüísticas superficiales | Parcial | F1 `R/ling_features.R` |
| E frecuencias/exploración léxica por periodo | Parcial (report) | F1–F2 módulo |
| F TF/IDF/TF-IDF documentados + cotejo manual | No existe | F2 `R/tfidf.R` |
| G modelado de tópicos | OK (LDA, conteos) | — (docs) |
| H diccionario propio ≥15 categorías | OK (18) | — |
| I importación de diccionarios externos | No existe | F3 `R/dictionary_io.R` |
| J análisis por mensaje/periodo/categoría | OK | filtro por diccionario (F3) |
| K avatar emocional | OK | re-verificar en F4 |
| L dashboard V1/V2 navegable | Faltan pestañas V2 | F4 |
| M bitácora de ejecuciones/importaciones | OK base | F5 comparación |
| N documentación actualizada | OK (informe + guías) | — (F6) |
| Versionado analítico (§11) | OK (run_id + dictionary_version) | — |

### Riesgos e incompatibilidades
1. Entorno Windows+WSL: usar `wsl -e`; R requiere
   `LD_LIBRARY_PATH=$HOME/opt/gsl/usr/lib/x86_64-linux-gnu`.
2. `quanteda` ya provee `tokens_ngrams`, `stopwords("es")` → sin dependencias nuevas.
3. Los resultados de V1 (`data/results/*.rds`) **no se deben alterar**: V2 escribe
   en `data/results/v2/` con prefijo `v2_`.
4. No usar `renv::snapshot` sin respaldo (ya sincronizado 2026-10-22).
5. Datos privados: verificar `.gitignore` (F6); no copiar mensajes reales a `reports/`.

## Tareas por fase (archivos)
- **F0**: `docs/PLAN_V2.md` (este archivo). *(completada)*
- **F1**: crear `R/ngrams.R`, `R/ling_features.R`, `scripts/05n_ngrams.R`,
  `scripts/05f_features.R`; ampliar `config/config.example.yml`; tests
  `test-ngrams.R`, `test-ling_features.R`.
- **F2**: crear `R/tfidf.R`, `scripts/06t_tfidf.R`; test `test-tfidf.R` con ejemplo
  manual; export CSV en `data/results/v2/`.
- **F3**: crear `R/dictionary_io.R`; ampliar `dashboard/modules/mod_dictionary.R`;
  tests `test-dictionary_io.R`.
- **F4**: ampliar `dashboard/app.R`; crear `mod_ngrams.R`, `mod_frequencies.R`,
  `mod_features.R`, `mod_tfidf.R`; verificación HTTP 200 + testServer.
- **F5**: ampliar `mod_audit.R` (comparación de ejecuciones); verificar V1 intacta.
- **F6**: suite completa; actualizar `reports/sections/*`, `preamble.tex`,
  `README_OVERLEAF.md`, `EJECUCION.md`, `docs/METODOLOGIA.md`; revisar `.gitignore`.
  *(completada: suite OK; PDF 37 págs sin overfull; `.gitignore` revisado)*

## Decisiones técnicas
1. **No renumerar** a `R/00…15`: se conserva la arquitectura existente (§4 permite
   adaptarla; reutiliza funciones y evita duplicación).
2. TF-IDF se calcula con implementación R explícita para fórmulas y cotejo manual;
   `quanteda` se usa para tokenizar/n-gramas.
3. Documento = mensaje (defecto); agregación por periodo solo como modo explícito.
4. Datos sintéticos solo en tests (`fixtures/`); resultados presentados = corpus real.
5. Ejecución continua F0→F6 autorizada por el usuario (2026-10-22).

## Cuaderno de fases
### FASE 0 — Auditoría · COMPLETADA
- Diagnóstico entregado y `docs/PLAN_V2.md` creado. Pruebas: no aplicables (solo lectura).

### FASE 1 — N-gramas y características superficiales · COMPLETADA
- Creados: `R/ngrams.R`, `R/ling_features.R`, `scripts/05n_ngrams.R`,
  `scripts/05f_features.R`, `tests/testthat/test-ngrams.R`,
  `tests/testthat/test-ling_features.R`.
- Config nueva: bloques `ngrams` y `features` (`R/config.R`, `config.example.yml`).
- Salidas reales: `data/results/v2/ngrams.rds` (21 464 docs; top unigrama «no»,
  4 124), `data/results/v2/linguistic_features.rds` (21 981 filas, 17 métricas).
- Decisiones: negadores preservados en stopwords; n-gramas por documento (sin
  concatenar mensajes); características sobre `text_original` (mayúsculas/signos);
  emojis contados con `\p{Extended_Pictographic}`.
- Pruebas: 19 (ngrams) + 24 (features) OK.

### FASE 2 — TF/IDF/TF-IDF · COMPLETADA
- Creados: `R/tfidf.R`, `scripts/06t_tfidf.R`, `tests/testthat/test-tfidf.R`.
- Fórmulas documentadas en cabecera: IDF = ln(N/df_t); TF raw|prop|log;
  documento = mensaje; `min_df` configurable. Cotejo manual en test (N=3, df=2).
- Config nueva: bloque `tfidf` (`raw`, `min_df: 2`, `top`, `export`).
- Salidas reales: `data/results/v2/tfidf.rds` y `tfidf.csv` (6.7 MB);
  top global: no, si, alguien, materia, grupo.
- Pruebas: 18 OK.

### FASE 3 — Diccionario propio e importación externa · COMPLETADA
- Creado: `R/dictionary_io.R` (esquema canónico, lectura CSV/JSON/TXT,
  detección/mapeo de columnas, validación, importación como nueva versión,
  activación con respaldo, listado de versiones).
- Ampliado: `dashboard/modules/mod_dictionary.R` (vista previa, mapeo, validación,
  importar, etiqueta de versión, activar; tabla de versiones).
- Pruebas: `tests/testthat/test-dictionary_io.R` (30 OK).
- Nota: importar NO sobrescribe el diccionario activo; activar copia la versión al
  archivo vigente guardando un `backup_*` en `data/dictionary/versions/`.

### FASE 4 — Dashboard y avatar · COMPLETADA
- Nuevos módulos: `mod_ngrams.R`, `mod_frequencies.R`, `mod_features.R`,
  `mod_tfidf.R`; menú «V2 · Minería de texto» en `dashboard/app.R`.
- `R/dashboard_data.R` carga artefactos V2 y versiones del diccionario.
- Verificación: 6 recursos estáticos `200`, `nav_menu` presente, UIs construidas
  y `testServer` OK para los 6 módulos (incluido diccionario y auditoría).
- El avatar emocional V1 sigue operativo (sin cambios de contrato).

### FASE 5 — Bitácora y versionado · COMPLETADA
- `mod_audit.R`: filtros por acción, estado y rango de fechas; tabla de ejecuciones
  con `dictionary_version`; comparación de dos ejecuciones campo a campo (marca ≠).
- Añadido `scripts/00_run_all.R` para ejecutar el pipeline V1+V2 en orden.
- Verificado que los scripts V2 escriben sólo en `data/results/v2/`.

### FASE 6 — Documentación, pruebas y cierre · COMPLETADA
- Informe: nueva sección `reports/sections/06b_mineria_v2.tex` (n-gramas,
  características superficiales, TF--IDF, diccionarios/versionado, bitácora y
  dashboard) incluida en `reports/main.tex`; tablas V2 generadas por
  `generate_v2_tables()` (`v2_ngrams`, `v2_features`, `v2_tfidf`) y macros V2 en
  `preamble.tex` / `write_report_stats()` (`nVTwoMensajes`, `nVTwoDocs`,
  `nVTwoTerms`).
- PDF recompilado (**37 págs**, 0 overfull) con cifras reales: unigramas
  129 935 (top «no», 4 124), bigramas 64 514 (top «alguien sabe», 1 192),
  trigramas 29 453; 21 981 mensajes con características; TF--IDF 21 464 docs,
  6 246 términos (top «no», suma 7 569,9).
- Bug corregido: `emoji_shortcode()` convertía palabras acentuadas en
  `U+XX+...` al escribir tablas (afectaba a los tópicos); ahora preserva texto
  con letras y se añadió prueba de regresión en `test-emojis.R`.
- Documentación: `EJECUCION.md` (pasos V2, `00_run_all`, importación de
  diccionarios), `README.md` (pipeline V2), `docs/METODOLOGIA.md` (§10 V2).
- `.gitignore` revisado: datos privados y artefactos excluidos; añadidos
  `_*.sh`, `*.synctex.gz`, `*.fls`, `*.fdb_latexmk`, `*.bbl`, `*.blg`.
- Pruebas: `Rscript scripts/10_test.R` → **OK** (incluye ngrams, features,
  tfidf, dictionary_io y la nueva regresión de emojis).
- Temporales de verificación eliminados (`_rx.R`, `_t1.R`, `_t2.R`, `_t3.R`,
  `_dash_http2.sh`).

## Ajustes posteriores a la Fase 6 (2026-10-22, petición del usuario)
- **Resumen**: se eliminó la sección «Estado de la última ejecución» y en su lugar se
  muestra el **avatar emocional animado** (versión compacta `as-avatar-host-sm`).
  Animaciones reales (bounce/pulse/shake/droop) en `emotional_avatar.css`, objetivo por
  host en `emotional_avatar.js` (`target`), toggle «Animación» funcional.
- **Diccionarios por grupo**: la pestaña Diccionario admite subir el diccionario del
  grupo (CSV/JSON/TXT) y, al activarlo, `mod_dictionary` recalcula en caliente los
  resultados (sentimiento, temporal, transiciones, evaluación) y refresca **todo** el
  dashboard vía `reactiveValues` (`R/dashboard_recompute.R`); respaldos en
  `data/results/backups/`. Verificado round-trip con el corpus real (21981 mensajes,
  resultados idénticos con el diccionario vigente) y respaldo automático.
- Datos convertidos a `reactiveValues` en `app.R`; módulos con lecturas en
  contexto reactivo (`mod_avatar`, `mod_sentiment`, `mod_topics`, `mod_markov`).
- **Menú V2 aplanado** (2026-10-22): `nav_menu` era un dropdown oculto y solo se
  apreciaba «N-gramas»; ahora N-gramas, Frecuencias, Características y TF-IDF son
  pestañas propias visibles. A petición del usuario se retiró la pestaña
  «Transiciones» (Markov deja de mostrarse en el dashboard; el módulo R sigue
  disponible y el artefacto `markov.rds` se mantiene para el informe).
- Suite: `OK 10_test` (incluye regresión de UI del Resumen y
  `apply_dashboard_recompute`).
- **Avatar retirado del Resumen** (2026-10-22, a petición del usuario): el avatar
  emocional vive únicamente en su pestaña; el Resumen es solo KPIs y gráficas.

## Instrucciones para continuar
1. `cd ~/AS_Telegram-main`
2. `export LD_LIBRARY_PATH=$HOME/opt/gsl/usr/lib/x86_64-linux-gnu`
3. Leer la fase «EN CURSO» en este archivo y las tareas pendientes arriba.
4. Suite de referencia: `Rscript scripts/10_test.R` (debe mantener `OK`).
