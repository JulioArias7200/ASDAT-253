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

## 10. Minería de texto (V2)

V2 añade cuatro módulos independientes que **no modifican** los resultados de V1 y escriben
sus artefactos en `data/results/v2/`.

### 10.1 N-gramas

`ngram_tokenize()` y `ngram_frequencies()` (`R/ngrams.R`) tokenizan cada mensaje por
separado con `quanteda`, de modo que ningún n-grama cruza el límite entre mensajes. Se
eliminan las stopwords del español **conservando los negadores** configurados (`no`,
`nunca`, `jamás`, `tampoco`, …) y se descartan los tokens de emoji, que se analizan como
señal aparte. Se reportan frecuencia absoluta y relativa por tamaño (1--3 por defecto).
`compare_stopword_effect()` documenta el efecto de quitar stopwords.

### 10.2 Características superficiales

`linguistic_features()` (`R/ling_features.R`) calcula 17 indicadores por mensaje sobre el
texto original: caracteres, tokens, palabras, palabras únicas y su proporción, longitud
media de palabra, interrogaciones, exclamaciones, palabras en mayúsculas y su proporción,
emojis, hashtags, menciones, URLs, repeticiones de caracteres y de puntuación, e
intensidad. Son medidas descriptivas, **no** un análisis sintáctico.

### 10.3 TF--IDF

`compute_tfidf()` (`R/tfidf.R`) trata cada mensaje como documento y aplica
`IDF(t) = ln(N / df_t)`, con `TF` en conteo bruto, frecuencia relativa o escala
logarítmica. Un término presente en todos los documentos obtiene `IDF = 0`. Los términos
con `df` menor que `min_df` se descartan. La implementación se contrasta con un corpus
manual en las pruebas.

### 10.4 Diccionarios externos y versionado

`R/dictionary_io.R` importa CSV, JSON o TXT con esquema canónico
(`term, category, polarity, weight, language, notes, source`), detecta y permite mapear
columnas, valida filas y crea **siempre una versión nueva** en
`data/dictionary/versions/`; la activación es explícita y respalda la versión anterior.
El diccionario activo nunca se sobrescribe durante la importación.

### 10.5 Bitácora y dashboard

Cada ejecución registra `run_id`, versión del diccionario y versión del código en la
bitácora SQLite, con filtros por acción, estado y fechas y comparación campo a campo de
dos ejecuciones. El dashboard expone los resultados V2 en el menú
**V2 · Minería de texto** y mantiene el avatar emocional agregado, que no constituye un
diagnóstico individual.
n
