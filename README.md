# Proyecto - Analisis de Sentimientos
# Mineria de Datos - Dat-253

Análisis de sentimiento y emociones aplicado al grupo de temporada en Telegram,
El proyecto importa una exportación JSON de Telegram, limpia y valida los mensajes,
asigna polaridad y emociones con un método léxico multietiqueta en español, realiza
análisis temporal, temático (LDA) y de transiciones (Markov), y presenta los resultados
en un dashboard.



## Características

- **Método léxico multietiqueta** con 18 categorías emocionales y señales separadas
  (léxico, emojis, reacciones).
- **Negación contextual** (ventana de tokens) y frases de doble negación.
- **Nivel de evidencia** por mensaje: `suficiente`, `insuficiente`, `sin_evidencia`
  (sin evidencia ⇒ etiqueta `indeterminado`, nunca `neutral` por defecto).
- **Trazabilidad** en SQLite: versiones de código y diccionario, parámetros y artefactos
  por ejecución.
- **Dashboard Shiny** modular con avatar emocional accesible.
- **Informe LaTeX** reproducible y **suite de pruebas** `testthat`.

## Requisitos

- R ≥ 4.2 (probado con R 4.5) y `renv` para el entorno.
- Linux (WSL compatible). En Windows nativo, ajustar rutas.
- `topicmodels` requiere GSL (`libgsl.so.28`). El ayudante `.Rprofile` añade
  `~/opt/gsl/usr/lib/x86_64-linux-gnu` a `LD_LIBRARY_PATH` si existe.
- Para compilar el informe: un motor LaTeX (`pdflatex`). TinyTeX se instala sin `sudo`
  (ver más abajo).

## Instalación

```bash
# 1) Restaurar dependencias R (binarios PPM si están configurados)
Rscript -e 'renv::restore()'

# 2) Configuración (opcional): copiar y editar
cp config/config.example.yml config/config.yml

# 3) Colocar el corpus en data/raw/result.json (no se versiona)
```

Motor LaTeX opcional (sin privilegios de administrador):

```bash
Rscript -e 'tinytex::install_tinytex()'
export PATH="$HOME/bin:$PATH"
tlmgr install babel-spanish lm booktabs caption enumitem
```

## Uso

### Pipeline completo

```bash
Rscript scripts/01_import.R          # importa y persiste el corpus
Rscript scripts/02_validate.R        # validación estructural
Rscript scripts/03_clean.R           # normalización (conserva original y emojis)
Rscript scripts/04_sentiment.R       # polaridad + emociones
Rscript scripts/05_topics.R          # temas (LDA)
Rscript scripts/06_temporal.R        # agregados diario/semanal/mensual
Rscript scripts/07_markov.R          # transiciones de estado
Rscript scripts/08_evaluate.R        # cobertura y evaluación
Rscript scripts/09_generate_report.R # figuras, tablas y PDF
Rscript scripts/10_test.R            # suite de pruebas
```

Si `topicmodels` no encuentra GSL, exportar antes de ejecutar:

```bash
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"
```

### Dashboard

```bash
Rscript dashboard/run.R            # http://127.0.0.1:3838
Rscript dashboard/run.R 8080       # puerto personalizado
```

### Pruebas

```bash
Rscript tests/testthat.R
# o
Rscript scripts/10_test.R
```

## Estructura del proyecto

```
R/                     módulos del pipeline (import, limpieza, sentimiento, topics, ...)
scripts/               ejecutables por etapas (01..10)
dashboard/             app Shiny modular + www/ (avatar JS/CSS)
database/schema.sql    esquema SQLite (trazabilidad)
data/dictionary/       diccionario emocional versionado (CSV)
data/raw|interim|...   datos (no versionados)
reports/               informe LaTeX (main.tex + sections + figures + tables)
tests/testthat/        pruebas y fixtures
docs/                  auditoría, esquema, metodología, privacidad, guías
config/                configuración (config.yml no se versiona)
logs/                  bitácoras de ejecución
```

## Estado del análisis (última ejecución)

| Métrica | Valor |
|---|---|
| Mensajes importados/analizados | 21 981 |
| Cobertura del diccionario | 18.6 % |
| Indeterminados | 81.4 % |
| Positivos / Negativos / Neutros | 2 520 / 1 190 / 368 |

Las cifras se regeneran automáticamente en `reports/generated/values.tex` y en las tablas
de `reports/tables/`.

## Documentación

- [`EJECUCION.md`](EJECUCION.md) — guía paso a paso para ejecutar el proyecto.
- [`docs/AUDITORIA_INICIAL.md`](docs/AUDITORIA_INICIAL.md) — auditoría del proyecto original.
- [`docs/ESQUEMA_DATOS.md`](docs/ESQUEMA_DATOS.md) — esquema canónico de datos.
- [`docs/METODOLOGIA.md`](docs/METODOLOGIA.md) — método de análisis.
- [`docs/GUIA_USUARIO.md`](docs/GUIA_USUARIO.md) — uso del dashboard.
- [`docs/PRIVACIDAD.md`](docs/PRIVACIDAD.md) — privacidad y uso ético.
- [`docs/CHECKLIST_PUBLICACION.md`](docs/CHECKLIST_PUBLICACION.md) — antes de publicar.

## Licencia y cita

MIT (ver [`LICENSE`](LICENSE)). Para citar, ver [`CITATION.cff`](CITATION.cff).
