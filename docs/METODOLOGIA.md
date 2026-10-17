# Metodología

Este documento describe el método implementado en `R/analyze_sentiment.R` y módulos
relacionados. Es la referencia técnica del informe (`reports/main.tex`).

## 1. Normalización

`normalize_text()` (en `R/clean_text.R`):

- Unificación Unicode **NFC** (garantiza comparaciones fiables).
- Minúsculas (configurable).
- Eliminación opcional de URLs y menciones (configurable).
- Colapso de espacios.
- **Nunca elimina emojis, negaciones ni palabras cortas.**
- El texto original se conserva en `text_original`; la versión procesada en `text_norm`.

## 2. Señales separadas

El diseño evita mezclar fuentes heterogéneas sin calibración:

| Señal | Fuente | Uso por defecto |
|---|---|---|
| Léxico | diccionario CSV | polaridad y emociones |
| Emojis | emojis del mensaje | polaridad (`emoji_weight=1`) y emociones |
| Reacciones | reacciones de Telegram | registradas aparte (`reaction_weight=0`) |

## 3. Negación contextual

`detect_negation()` (en `R/detect_negation.R`):

- Un negador (`no, ni, nunca, jamás, tampoco, sin, nada, nadie`) invierte la polaridad de
  los términos sensibles en los siguientes `window` tokens (por defecto 3).
- Un nuevo negador dentro de la ventana **no** se marca a sí mismo (evita dobles conteos).
- Frases de doble negación (`"no está nada mal"`, `"no puedo estar más feliz"`) se tratan
  como excepciones positivas explícitas.

## 4. Puntuación y etiquetado

`score_message()`:

```
score_texto = Σ (peso_i con signo)   [léxico, con negación aplicada]
            + emoji_weight · señal_emoji
```

- `polarity` = puntuación **léxica** continua (sin emojis).
- `polarity_label` ∈ {`positivo`, `negativo`, `neutro`, `indeterminado`} según el signo de
  `score_texto`.

## 5. Nivel de evidencia

```
n_evidence = n_terms + n_emoji
```

- `n_evidence = 0` ⇒ `evidence_level = "sin_evidencia"` ⇒ etiqueta `indeterminado`.
- `n_evidence < min_evidence_terms` ⇒ `insuficiente`.
- En otro caso ⇒ `suficiente`.

Regla clave: **sin evidencia no se emite conclusión**; nunca se asigna `neutral` por
defecto.

## 6. Emociones

18 categorías: alegría, tristeza, ira, miedo, sorpresa, asco, amor, gratitud, confianza,
anticipación, frustración, ansiedad, esperanza, orgullo, vergüenza, diversión, aburrimiento
y alivio. Un mensaje puede tener varias emociones; `dominant_emotion` es la de mayor
puntuación.

## 7. Temas (LDA)

`build_dfm()` / `fit_topics()` (`R/analyze_topics.R`) usan `quanteda` para construir la
matriz documento-término y `topicmodels` (Gibbs, semilla fija) para el modelo. Los tópicos
son **exploratorios**, no categorías objetivas.

## 8. Transiciones (Markov)

`markov_analysis()` (`R/analyze_markov.R`) modela la secuencia temporal de estados
(`positivo`, `negativo`, `neutro`). Reporta matriz de transición, distribución estacionaria,
tiempo medio de permanencia y recuperación desde lo negativo. Las filas sin origen observado
quedan `NA`: no se inventan transiciones.

## 9. Evaluación

`R/evaluate_models.R` reporta cobertura del diccionario, proporción de indeterminados y, si
hay etiquetas manuales, concordancia con el modelo. Sin etiquetas humanas, la validación
supervisada se declara **no disponible**.
