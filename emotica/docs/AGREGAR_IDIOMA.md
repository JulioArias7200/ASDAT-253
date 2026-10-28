# Agregar un idioma (no se toca código)
Con estos archivos, el pipeline detecta el idioma solo y el motor lo analiza:
1. `resources/stopwords/<id>.txt`: una palabra por línea. **No** incluya negaciones ni intensificadores.
2. `resources/lexicons/<id>/base.csv`: `termino,emocion_id,peso,tipo,fuente,contexto` (tipos: palabra, frase, regex; pesos 0.5 a 2.0). Los emojis ya valen para todos los idiomas (`resources/lexicons/_universal/`).
3. `resources/modifiers/<id>.csv`: `termino,tipo,factor` con intensificadores, atenuadores y negadores (sin apóstrofes: `dont`, no `don't`).
4. Opcional: `resources/anuncios/<id>.txt` (palabras de aviso; `!palabra` = spam fuerte).
Sin léxico para un idioma, el motor lo avisa y no inventa resultados. Para medir calidad: etiquetas humanas (propias o un conjunto público) y `scripts/02_evaluar.R`; ejemplo en inglés: `scripts/04_evaluar_goemotions.R`.
