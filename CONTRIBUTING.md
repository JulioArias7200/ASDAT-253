# Contribuir

Gracias por tu interés. Este proyecto prioriza reproducibilidad, trazabilidad y uso ético
de los datos.

## Flujo de trabajo

1. Crea una rama: `git checkout -b feature/mi-cambio`.
2. Haz cambios pequeños y enfocados.
3. Ejecuta las pruebas: `Rscript scripts/10_test.R`.
4. Si cambias el análisis, re-ejecuta el pipeline y actualiza el informe.
5. Abre un Pull Request describiendo el cambio y su justificación.

## Estilo de código R

- Sin comentarios innecesarios; el código debe ser autoexplicativo.
- Funciones documentadas con comentarios `#'` cuando son reutilizables.
- No mezclar señales (léxico, emojis, reacciones) sin justificar.
- Mantener la regla de evidencia: sin evidencia ⇒ `indeterminado`.
- Añadir una prueba `testthat` por cada comportamiento nuevo.

## Cambios en el diccionario

- Añade términos vía `add_term()`/dashboard para conservar el versionado.
- Justifica cada término nuevo y su polaridad.
- No elimines términos existentes sin registrar el cambio.

## Datos

- Nunca subas el corpus (`data/raw/`), bases `.sqlite` ni registros de ejecución.
- Usa el corpus sintético (`tests/testthat/fixtures/`) en las pruebas.

## Ética

Cualquier contribución debe respetar `docs/PRIVACIDAD.md`. Los PR que permitan identificar
personas o usar los resultados para evaluar individuos serán rechazados.
