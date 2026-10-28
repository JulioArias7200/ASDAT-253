# Jerga y modismos
Archivos: `resources/lexicons/es/jerga_modismos.csv` (635 entradas, fuente `jerga_modismos_v1`) y `resources/lexicons/en/slang_idioms.csv` (214, fuente `slang_idioms_v1`). Cualquier CSV nuevo en la carpeta del idioma se carga solo.
**Cobertura (español):** Bolivia/UMSA (barco, zafé, chato, reventado, me jalaron...), México (no manches, qué padre, híjole), España (me mola, flipante, cabreo), Argentina/Chile/Perú (bronca, bajón, roche, copado), Colombia y abreviaturas de chat (tqm, ntp, jsjs, qepd).
**Cobertura (inglés):** slang de internet, británico y modismos (over the moon, knackered, gutted, last straw, butterflies in my stomach).
## Cómo agregar jerga nueva
Una fila por término: `termino,emocion_id,peso,tipo,fuente,contexto` (peso 0.5 a 2.0; tipo `palabra` o `frase`; sin apóstrofes en inglés). Un mismo término puede ir en varias emociones. Usen una `fuente` con "jerga" o "slang" en el nombre para poder medir su aporte con los scripts 04 y 05 (comparan con y sin ese archivo).
## Cómo saber si un término ayuda
`auditar_terminos(scores, hoja)` (R/eval.R) cuenta aciertos y falsos positivos por término contra etiquetas humanas. Regla usada para podar: más de 6 falsos positivos y precisión menor a 25 %.
## Evidencia (medida con etiquetas humanas, conjuntos reservados)
- **Español, EmoEvent (tuits), conjunto de desarrollo:** F1 0.349 -> 0.436 (+0.087); recall 0.24 -> 0.35; precisión 0.63 -> 0.58. En entrenamiento: 0.342 -> 0.428.
- **Chat universitario (etiquetas de referencia de una IA, n=50):** F1 0.38 -> 0.41; cobertura del corpus 17.2 % -> 18.7 %.
- **Inglés, GoEmotions y EmoEvent-en (desarrollo):** sin cambio medible (F1 +-0.002). El slang en inglés es neutro en estos corpus: mantener como recurso opcional, no como mejora demostrada.
- `splits/es/test.tsv` de EmoEvent no se usó: sus etiquetas no corresponden bien a los tuits (la diferencia entre palabras emocionales y etiquetas casi desaparece, 1.1 a 1.7 veces contra 3 a 6 veces en entrenamiento y desarrollo).
Datos: GoEmotions (Google, Apache-2.0); EmoEvent (Plaza-del-Arco et al., LREC 2020; Apache-2.0 en GitHub, CC BY-NC-SA 4.0 en HuggingFace: usar solo para investigación). Ninguno va en el repo.
