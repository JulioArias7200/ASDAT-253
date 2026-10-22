# Proyecto: Análisis de Sentimiento — Grupo de Telegram
# Directorio base: /home/max1/dm/AS

## Stack
- Python 3.x
- Telethon (extracción)
- nltk o regex manual (preprocesamiento)
- collections, math (stdlib para n-gramas, TF-IDF manual si aplica)
- sklearn SOLO si implementar desde cero no es pedagógico
- Streamlit (dashboard final)
- Gemini API (comparación al final, via requests, sin SDK)

## Convenciones
- Stdlib primero; librería externa solo si no es pedagógico hacerlo a mano
- Código legible y comentado sobre código compacto
- Una fase a la vez — esperar OK del usuario antes de avanzar
- Si hay decisiones de diseño (umbral, stemming vs lemma, etc.): preguntar antes de asumir
- Nunca avanzar a la siguiente fase sin confirmación explícita

## Datos del grupo
- Tipo: privado (acceso por invitación, no @username)
- Identificador: chat_id numérico (se obtiene con scripts/find_group.py)
- El usuario es miembro del grupo
- Cobertura: ~5 meses históricos + mensajes nuevos desde ese punto
- Campos a guardar: id, date, sender_id, sender_name, text, type, is_forward

## Estructura de directorios
```
AS/
├── .claude/
│   └── context.md          ← este archivo
├── data/
│   ├── raw/                ← Fase 1: raw_messages.json
│   ├── filtered/           ← Fase 2: filtered_messages.json
│   ├── processed/          ← Fase 3: processed_messages.json
│   └── results/            ← Fase 4+: sentiment_results.json, etc.
├── scripts/
│   ├── find_group.py       ← listar diálogos → obtener chat_id
│   ├── fetch.py            ← descargar mensajes (Fase 1)
│   ├── filter.py           ← filtrado (Fase 2)
│   ├── preprocess.py       ← preprocesamiento (Fase 3)
│   ├── sentiment.py        ← análisis de sentimiento (Fase 4)
│   ├── vectorize.py        ← BoW, TF-IDF, n-gramas (Fase 5)
│   ├── lda.py              ← tópicos LDA (Fase 6)
│   ├── markov.py           ← cadenas de Markov (Fase 7)
│   └── gemini_compare.py   ← comparación con Gemini (Fase 9)
├── dashboard/
│   └── app.py              ← Streamlit (Fase 8)
├── .env                    ← credenciales (NO versionar)
├── .gitignore
└── requirements.txt
```

---

## FASE 1: Extracción con Telethon

**Estado: en progreso**

### Paso 0: Credenciales
- Obtener api_id y api_hash en https://my.telegram.org → "API development tools"
- Completar .env con: TG_API_ID, TG_API_HASH, TG_PHONE, TG_SESSION=anon

### Paso 1: find_group.py
- Autenticarse con Telethon
- Listar todos los diálogos → identificar chat_id del grupo
- Guardar chat_id en .env como TG_CHAT_ID

### Paso 2: fetch.py
- Descargar mensajes con paginación (iter_messages)
- Guardar en data/raw/raw_messages.json
- Campos: id, date, sender_id, sender_name, text, type, is_forward

---

## FASE 2: Filtrado

- Eliminar mensajes de servicio (entrada/salida de miembros, etc.)
- Eliminar mensajes sin texto (stickers, fotos sin caption, GIFs)
- Eliminar mensajes muy cortos (< N palabras, umbral a definir)
- Eliminar URLs solas
- Marcar/excluir forwards si no son relevantes
- Guardar en data/filtered/filtered_messages.json
- Log: cuántos descartados y por qué categoría

---

## FASE 3: Preprocesamiento de texto

- Tokenización (manual con regex o nltk)
- Lowercase
- Eliminación de stop-words en español (lista customizable)
- Eliminación de puntuación y caracteres especiales
- Stemming o lemmatización (decidir según contexto)
- Guardar tokens por mensaje en data/processed/processed_messages.json

---

## FASE 4: Diccionario de emociones y análisis de sentimiento

- Cargar o construir lexicón en español (AFINN-ES u otro)
- Clasificar cada mensaje: positivo / negativo / neutro
- Calcular score de sentimiento por mensaje
- Guardar en data/results/sentiment_results.json
- Métricas: distribución de sentimientos, score promedio por día/semana

---

## FASE 5: Representación vectorial y términos relevantes

- Bag of Words por categoría de sentimiento
- TF-IDF para términos más representativos (desde cero o sklearn)
- N-gramas (bigramas y trigramas más frecuentes)
- Visualización básica: top palabras por sentimiento

---

## FASE 6: Tópicos con LDA

- Aplicar LDA sobre mensajes procesados
- Identificar N tópicos (N a definir explorando)
- Ver correlación tópicos ↔ sentimientos
- Opcional: LSA como alternativa/comparación

---

## FASE 7: Cadenas de Markov

- Modelar transiciones de sentimiento en el tiempo
- Calcular matriz de transición
- Identificar patrones: ¿el grupo tiende a recuperarse o a mantenerse negativo?

---

## FASE 8: Dashboard con Streamlit

- Distribución de sentimientos
- Timeline de sentimiento promedio por día
- Top palabras y n-gramas por sentimiento
- Tópicos LDA
- Cadena de Markov visualizada

---

## FASE 9 (Bonus): Comparación con Gemini

- Muestra de mensajes clasificados por el pipeline clásico
- Enviar a Gemini API via requests (sin SDK)
- Comparar clasificaciones: coincidencias y diferencias
- Reflexión: ventajas y limitaciones de cada enfoque
