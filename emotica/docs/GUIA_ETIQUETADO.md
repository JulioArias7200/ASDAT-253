# Guía de etiquetado (30-40 min por persona)
1. Una persona corre `Rscript scripts/01_generar_muestra.R` y comparte `etiquetado/para_etiquetar.csv` por canal privado.
2. Cada integrante copia el archivo como `etiquetado/hoja_<su_nombre>.csv` y llena, **sin mirar la clave del motor**:
   - `emociones`: ids separados por `;` (ej. `gratitud;alegria`) o `ninguna`. Ids válidos: los de `resources/taxonomy/emotions.yml`.
   - `intensidad`: 1 a 5 para la emoción más fuerte (vacío si `ninguna`).
3. Criterio: etiqueten lo que **expresa el autor**, no el tema. "¿Alguien sabe cuándo abren?" suele ser `curiosidad` leve o `ninguna`.
4. Cuando estén las cuatro hojas: `Rscript scripts/02_evaluar.R` entrega precisión, recall y F1 por emoción, kappa entre etiquetadores
   y la correlación entre el peso del motor y la intensidad humana (para calibrar `peso` en los léxicos).
5. Si el kappa entre ustedes es bajo (< 0.4), primero se afinan los criterios; el motor no puede ser mejor que el acuerdo humano.
