# Estado de las tareas (honesto, 23-oct-2026)
| Tarea | Estado | Qué falta |
|---|---|---|
| Tokenización | **Hecha** (`R/tokens.R`, probada) | Acordar con `R/11_tokenizar_stopwords.R` (Yoshua) cuál es la versión oficial |
| Stopwords | **Hecha** (`resources/stopwords/{es,en,pt}.txt`, conserva negaciones e intensificadores) | Listas cortas propias (146 en español): ampliar y validar con el grupo |
| Topic modeling | **Parcial** (`R/topics.R`: documentos por día, k por coherencia, NMF probado) | El camino LDA (`topicmodels`) está escrito pero **no se ejecutó**; correrlo, comparar con `R/analyze_topics.R` y elegir k final |
| Librería de 15 emociones | **v0 funcional, sin validar** (`R/engine.R`, `R/taxonomy.R`) | No hay etiquetas manuales: sin precisión/recall. Calibrar pesos, decidir "alguien sabe" (curiosidad), integrar con el pipeline de Medina |
Pruebas: 75 automáticas (`Rscript tests/testthat.R` dentro de `emotica/`). Cobertura del léxico semilla: ~18 % de los mensajes con texto.
Este aporte es **aditivo**: vive en `emotica/` y no modifica ningún archivo existente del repo.

## Validación preliminar (23-oct-2026)
Muestra de 100 mensajes (70 con emoción detectada por el motor, 30 sin ella; **no es representativa de la precisión poblacional**), etiquetada por un solo etiquetador independiente (IA) como referencia, **no verdad humana**:
precisión 0.31 · recall 0.47 · F1 0.37 · correlación de intensidad 0.18 (pesos aún sin calibrar).
Mejor: gratitud (F1 0.86), decepción y sorpresa (0.67). Peor: admiración, amor, vergüenza, cansancio, esperanza, alegría (muchos falsos positivos) y confusión (recall 0.17).
Causas: 34 de 57 falsos positivos están en anuncios, spam o pedidos de información; términos débiles ("alguien sabe", "dudas", "xd", "se puede") y emojis de cortesía (🙏 😅 🥺).
**Pendiente:** que los 4 integrantes etiqueten la misma hoja, medir kappa, y corregir el léxico con una mitad de las frases y probar con la otra (para no sobreajustar).

## Filtro de anuncios y spam (23-oct-2026, `R/anuncios.R`)
Reglas estructurales (largo, líneas, URLs, emojis, menciones, palabras de aviso por idioma en `resources/anuncios/<idioma>.txt`). Marca 4.2 % del corpus (987 mensajes). Se excluyen del motor y de los temas (`excluir_anuncios` en `config/engine.yml`).
Prueba en una **muestra nueva de 50 mensajes (holdout)**, etiquetada por la misma IA de referencia: precisión 0.26 → 0.37, falsos positivos 31 → 19, recall sin cambio (0.39), F1 0.31 → 0.38. En la muestra 1 (ya vista al diseñar las reglas): F1 0.37 → 0.40.
Los 9 mensajes marcados en el holdout eran anuncios reales (se escapó 1: una convocatoria corta). En una revisión visual de 25 marcados al azar, 4 o 5 eran mensajes reales (ej. un agradecimiento largo).
Todavía: precisión 0.37 y recall 0.39 son bajos. El léxico necesita corrección con etiquetas humanas (usar la mitad para ajustar y la otra mitad para probar; el holdout de 50 queda reservado para la prueba final).

## Inglés y portabilidad (23-oct-2026)
Se agregó el idioma inglés **solo con archivos de recursos** (léxico de 431 términos, modificadores, stopwords, palabras de aviso; emojis compartidos en `_universal`), más manejo de apóstrofes (`don't` -> `dont`). El motor no cambió.
Validación independiente con **GoEmotions** (Google; 5,427 comentarios de Reddit de prueba, etiquetados por personas), mapeando sus categorías a nuestras 14 equivalentes (`cansancio` no existe allí; se excluyen los comentarios que solo tienen emociones sin equivalente, como approval o disgust):
- Primer intento, sin ajustes (desarrollo): F1 0.51.
- Tras una ronda de mejoras guiada por los errores de desarrollo: F1 0.54.
- **Prueba (medida una sola vez): precisión 0.56, recall 0.51, F1 0.53, macro-F1 0.46.**
Mejores: gratitud 0.89, amor 0.71, alegría 0.61, esperanza 0.59. Peores: tranquilidad 0.07, curiosidad 0.22, decepción 0.22 (la curiosidad de GoEmotions es casi cualquier pregunta, distinta de la nuestra).
Límites: dominio distinto al chat universitario (Reddit); el mapeo de categorías es una decisión nuestra; mensajes cortos y con sarcasmo siguen siendo difíciles para un léxico.

## Jerga y modismos (24-oct-2026)
Se agregaron 635 entradas en español (Bolivia, México, España, Cono Sur, Perú, Colombia, abreviaturas de chat) y 214 en inglés. Detalle y evidencia en `docs/JERGA_Y_MODISMOS.md`.
**Español: mejora demostrada** en tuits etiquetados por personas (EmoEvent, desarrollo): F1 0.349 -> 0.436; el motor encuentra más emociones (recall 0.24 -> 0.35) con algo menos de precisión.
**Inglés: sin mejora medible** (GoEmotions y EmoEvent-en). Se podaron 20 términos con muchos falsos positivos usando solo los datos de entrenamiento.
Tests: 98. Nueva herramienta: `auditar_terminos()` para ver qué términos fallan.
