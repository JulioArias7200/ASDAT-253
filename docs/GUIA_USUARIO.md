# Guía de usuario

## Arrancar el dashboard

```bash
Rscript dashboard/run.R          # http://127.0.0.1:3838
Rscript dashboard/run.R 8080     # puerto personalizado
```

El dashboard lee los artefactos generados por el pipeline (`data/results/*.rds`,
`data/processed/*.rds`). **Ejecuta primero las etapas 01–09** para que haya datos.

Si al abrir aparece "Falta sentiment.rds", significa que el pipeline aún no se ha
ejecutado. Los avisos de artefactos ausentes se muestran en el objeto `data$warnings`.

## Secciones

| Pestaña | Para qué sirve |
|---|---|
| **Resumen** | métricas globales, distribución de polaridad y emociones, última ejecución |
| **Cargar corpus** | subir un `result.json`, validarlo en vista previa e importarlo |
| **Sentimientos** | filtrar por emoción, período, polaridad y evidencia; exportar CSV |
| **Temporal** | polaridad y volumen por día/semana/mes, con media móvil |
| **Temas** | términos más probables por tópico (LDA) |
| **Transiciones** | matriz de Markov, distribución estacionaria y métricas |
| **Avatar emocional** | emoción predominante del período, como expresión SVG |
| **Diccionario** | buscar y añadir términos; cada cambio crea una versión |
| **Bitácora** | eventos y ejecuciones registradas en SQLite |
| **Informe** | regenerar figuras/tablas y compilar el PDF |

## Cargar un corpus

1. Pestaña **Cargar corpus** → selecciona un `result.json` de Telegram Desktop.
2. Pulsa **Analizar archivo**: verás un resumen, la vista previa y la validación.
3. Pulsa **Confirmar e importar**: se copia a `data/raw/` y se registra en la bitácora.

## Avatar emocional

- Elige un período o fuerza una emoción con el selector.
- El avatar resume la emoción **predominante** del período; la tabla muestra las
  proporciones.
- Respeta `prefers-reduced-motion` (sin animación si el sistema lo pide).

> El avatar es una visualización agregada del modelo. No representa el estado de ninguna
> persona.

## Añadir términos al diccionario

En **Diccionario**, completa término, categoría, polaridad y peso, y pulsa **Añadir**. El
cambio queda registrado en `dictionary_changes` y genera una nueva versión. Para que el
nuevo término afecte al análisis, vuelve a ejecutar `04_sentiment.R` en adelante.

## Problemas frecuentes

- **`topicmodels` no carga / falta `libgsl`**: exporta
  `LD_LIBRARY_PATH=$HOME/opt/gsl/usr/lib/x86_64-linux-gnu` antes de lanzar R.
- **No compila el PDF**: instala un motor LaTeX (`pdflatex`) o usa TinyTeX
  (`Rscript -e 'tinytex::install_tinytex()'`), y añade `$HOME/bin` al `PATH`.
- **Sin resultados**: ejecuta el pipeline (01–09) y recarga el dashboard.
