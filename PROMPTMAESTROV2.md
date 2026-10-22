# PROMPT MAESTRO — AS_TELEGRAM V2
## Plataforma reproducible de análisis lingüístico, minería de texto y sentimientos en conversaciones de Telegram mediante R

### 1. ROL Y OBJETIVO

Actúa como un equipo senior compuesto por:

- Ingeniero de datos especializado en R y procesamiento de lenguaje natural.
- Científico de datos con experiencia en minería de texto, TF-IDF, n-gramas y modelado de tópicos.
- Desarrollador de dashboards interactivos en R.
- Especialista en análisis de sentimientos en español.
- Ingeniero de software responsable de versionado, trazabilidad, pruebas y documentación académica.

Debes trabajar sobre el repositorio existente de AS_Telegram, que ya contiene una implementación funcional desarrollada principalmente en R.

El objetivo es implementar una nueva versión funcional denominada **AS_Telegram V2**, ampliando las capacidades analíticas, lingüísticas y visuales sin destruir ni reemplazar innecesariamente la versión anterior.

No crees un proyecto paralelo desde cero si puedes ampliar la arquitectura existente de forma segura. No supongas nombres de archivos, funciones, tablas, campos ni tecnologías sin inspeccionar primero el repositorio.

La implementación principal del procesamiento debe continuar en R. JavaScript podrá utilizarse para las interacciones visuales que lo requieran. No migres el proyecto a Python.

### 2. REGLAS DE TRABAJO

1. Inspecciona primero todo el proyecto: estructura de carpetas, scripts R, dependencias, archivos de configuración, datos, dashboard, bitácora, pruebas y documentación.
2. Identifica qué funcionalidades ya existen, cuáles funcionan, cuáles están incompletas y cuáles deben modificarse.
3. No sobrescribas ni elimines archivos originales sin justificarlo y preservar su contenido cuando corresponda.
4. Mantén compatibilidad con el corpus de Telegram ya incorporado.
5. Separa claramente el código fuente, los datos originales, los datos procesados, los resultados, los registros de ejecución y los recursos visuales.
6. No inventes resultados, frecuencias, sentimientos predominantes ni conclusiones sobre conversaciones reales.
7. Utiliza datos sintéticos únicamente para pruebas, identificándolos expresamente y manteniéndolos separados del corpus real.
8. Registra las operaciones importantes en una bitácora persistente.
9. No inicialices Git ni crees otro repositorio. El proyecto ya está alojado en un repositorio existente. No ejecutes operaciones destructivas ni hagas push sin autorización.
10. No expongas credenciales, tokens, contraseñas ni archivos de sesión.
11. No afirmes que una fase está terminada hasta ejecutar las comprobaciones correspondientes.
12. Si una decisión técnica es necesaria, adopta la alternativa más razonable, documenta el supuesto y continúa sin detenerte innecesariamente.
13. Si el contexto de trabajo está cerca de agotarse, detente en un punto estable y documenta el estado para continuar en otra sesión.

### 3. OBJETIVOS FUNCIONALES DE LA VERSIÓN V2

Implementa las siguientes capacidades integradas:

A. Pipeline secuencial de procesamiento de texto en R.

B. Tokenización y eliminación de stopwords en español.

C. Análisis de unigramas, bigramas y n-gramas configurables.

D. Extracción de características lingüísticas superficiales (*shallow linguistic features*).

E. Cálculo de frecuencias y visualización de términos y patrones lingüísticos.

F. Cálculo de TF, IDF y TF-IDF con metodología documentada.

G. Modelado de tópicos (*topic modeling*) y exploración de temas frecuentes.

H. Diccionario propio de sentimientos en español, construido y documentado a partir del corpus.

I. Importación de diccionarios de sentimientos externos desde el dashboard.

J. Análisis de sentimientos por mensaje, periodo y categoría emocional.

K. Avatar emocional interactivo con apariencia de un pequeño personaje que se cubre los ojos, similar al personaje de los antiguos juegos de inicio de sesión, con expresiones que reflejen el estado emocional agregado de los mensajes analizados.

L. Dashboard que permita navegar entre las funcionalidades de la versión anterior y las nuevas funcionalidades de V2.

M. Bitácora que registre las ejecuciones, importaciones, transformaciones, diccionarios, errores y versiones analíticas.

N. Documentación técnica y académica actualizada.

### 4. ARQUITECTURA Y ORGANIZACIÓN DEL CÓDIGO R

Después de auditar el proyecto, reorganiza los scripts de R en una secuencia lógica, manteniendo compatibilidad con los nombres y dependencias existentes cuando resulte conveniente.

Usa la siguiente organización como referencia, adaptándola a la arquitectura real:

- `R/00_configuracion.R`: rutas, parámetros y configuración común.
- `R/01_importacion.R`: carga y validación del corpus.
- `R/02_limpieza.R`: normalización y limpieza del texto.
- `R/03_tokenizacion.R`: tokenización de mensajes.
- `R/04_stopwords.R`: gestión y eliminación de stopwords.
- `R/05_ngrams.R`: unigramas, bigramas y n-gramas.
- `R/06_caracteristicas_linguisticas.R`: características lingüísticas superficiales.
- `R/07_frecuencias.R`: frecuencias de términos y patrones.
- `R/08_tfidf.R`: matrices TF, IDF y TF-IDF.
- `R/09_topicos.R`: modelado de tópicos.
- `R/10_diccionario_sentimientos.R`: creación, validación y carga de diccionarios.
- `R/11_analisis_sentimientos.R`: clasificación emocional.
- `R/12_agregacion_emocional.R`: agregación por fechas, mensajes y categorías.
- `R/13_resultados.R`: generación y persistencia de resultados.
- `R/14_bitacora.R`: registro de eventos y ejecuciones.
- `R/15_validaciones.R`: comprobaciones de calidad.

Estos nombres son una propuesta, no una orden para duplicar scripts ya existentes. Si el proyecto cuenta con funciones equivalentes, reutilízalas o refactorízalas.

Establece dependencias explícitas entre etapas. Cada script debe tener un propósito delimitado, funciones reutilizables, manejo de errores y comentarios técnicos suficientes.

Evita que la ejecución de un script dependa accidentalmente del directorio de trabajo actual. Centraliza la resolución de rutas y documenta cómo ejecutar el pipeline completo.

### 5. PIPELINE DE MINERÍA DE TEXTO

Implementa el flujo de procesamiento de manera secuencial y reproducible.

#### Etapa 1. Importación y validación

- Leer el corpus existente y los nuevos corpus importados desde el dashboard.
- Validar campos, identificadores, fechas y contenido textual.
- Detectar mensajes vacíos, duplicados y registros inválidos.
- Preservar el mensaje original y su identificador.
- Conservar, cuando existan, los metadatos necesarios para análisis temporales y respuestas.
- Registrar el archivo de origen, fecha de importación, número de registros y resultado de la validación.

No modifiques los datos originales.

#### Etapa 2. Limpieza y normalización

- Normalizar espacios y caracteres problemáticos.
- Tratar URL, menciones, hashtags, emojis y signos de puntuación mediante reglas explícitas y configurables.
- Preservar una versión del texto original y otra del texto normalizado.
- Evitar que la normalización destruya información emocional.
- Documentar cómo se tratarán las negaciones, las expresiones coloquiales y las variantes ortográficas.

No elimines automáticamente emojis ni signos expresivos antes de evaluar su utilidad para el análisis de sentimientos.

#### Etapa 3. Tokenización

- Tokenizar cada mensaje en unidades lingüísticas.
- Mantener la relación entre token, mensaje, fecha e identificador.
- Documentar las reglas aplicadas a contracciones, números, hashtags, menciones y emojis.
- Permitir la reproducción de los tokens generados.

#### Etapa 4. Eliminación de stopwords

- Utilizar una lista base de stopwords en español compatible con el entorno R.
- Permitir ampliar, editar e importar listas personalizadas.
- Mostrar las stopwords utilizadas en cada ejecución.
- No eliminar negaciones como «no», «nunca» o «jamás» cuando sean relevantes para la interpretación emocional.
- Evitar eliminar palabras frecuentes que puedan ser sustantivas para el tema estudiado.

Registrar el número de tokens antes y después del filtrado.

#### Etapa 5. Unigramas, bigramas y n-gramas

Generar:

- Unigramas: secuencias de un token.
- Bigramas: secuencias de dos tokens consecutivos.
- N-gramas configurables: secuencias de N tokens.

Calcular frecuencias absolutas y relativas, ordenar los términos más frecuentes y permitir filtrar por frecuencia mínima.

Para los bigramas y n-gramas, documentar cómo se manejan los límites entre mensajes: no formar secuencias artificiales concatenando mensajes independientes.

Permitir comparar resultados antes y después de eliminar stopwords cuando resulte útil.

#### Etapa 6. Características lingüísticas superficiales

Implementar características lingüísticas superficiales (*shallow linguistic features*), como:

- Número de palabras y tokens por mensaje.
- Longitud media de las palabras.
- Proporción de palabras únicas.
- Frecuencia de signos de interrogación y exclamación.
- Uso de mayúsculas.
- Cantidad de emojis y emoticonos.
- Uso de hashtags y menciones.
- Repetición de caracteres y signos.
- Longitud de los mensajes.
- Frecuencia de expresiones relevantes, si se definen reglas verificables.

No presentes estas características como un análisis sintáctico profundo. Explica sus limitaciones y permite visualizar su distribución.

#### Etapa 7. Frecuencias y exploración léxica

Calcular y visualizar:

- Términos más frecuentes.
- Unigramas, bigramas y n-gramas destacados.
- Frecuencias por periodo.
- Distribución de la longitud de los mensajes.
- Términos más frecuentes por segmento temporal.
- Comparaciones entre subconjuntos del corpus.

Permitir seleccionar un rango temporal, un tipo de n-grama y un umbral de frecuencia.

#### Etapa 8. TF, IDF y TF-IDF

Implementar el cálculo de TF, IDF y TF-IDF mediante una metodología estándar y documentada.

- Definir qué constituye un documento: por defecto, un mensaje individual.
- Permitir agregar mensajes por periodo únicamente como análisis alternativo explícito.
- Documentar las fórmulas y el tratamiento de términos desconocidos.
- Explicar cómo la frecuencia inversa de documentos reduce el peso de términos presentes en muchos mensajes.
- Mostrar una tabla de términos con sus valores TF, IDF y TF-IDF.
- Visualizar los términos de mayor peso por mensaje o documento agregado.
- Permitir exportar los resultados.

Verificar manualmente el cálculo con un pequeño corpus de prueba cuyos resultados esperados se conozcan.

#### Etapa 9. Modelado de tópicos

Implementar un módulo de modelado de tópicos apropiado para el corpus y para los datos disponibles.

- Inspeccionar el tamaño del corpus, su dispersión y la matriz de términos.
- Seleccionar y justificar un algoritmo apropiado.
- Considerar LDA con una representación basada en frecuencias de términos y alternativas compatibles con el objetivo.
- No utilizar automáticamente una matriz TF-IDF como entrada de LDA sin justificar su compatibilidad metodológica.
- Permitir configurar el número de tópicos.
- Mostrar los términos principales de cada tópico, sus pesos y los mensajes representativos.
- Permitir explorar la distribución de tópicos por periodo.
- Registrar parámetros, semilla aleatoria y método utilizado.
- Explicar que los tópicos son estructuras estadísticas y no categorías semánticas perfectas.

Si se usa un algoritmo estocástico, establecer una semilla reproducible cuando la implementación lo permita.

### 6. DICCIONARIO PROPIO DE SENTIMIENTOS EN ESPAÑOL

El proyecto debe incorporar un diccionario propio, adaptado al lenguaje que aparece en el corpus real.

Debe contener como mínimo 15 categorías emocionales diferenciadas. No basta con tener 15 palabras: deben existir al menos 15 categorías documentadas y cada una debe poder asociarse a términos o expresiones relevantes.

Procedimiento:

1. Analizar vocabulario, frecuencias y expresiones recurrentes del corpus.
2. Identificar palabras, expresiones y variantes lingüísticas potencialmente emocionales.
3. Proponer categorías emocionales y documentar su significado.
4. Construir una tabla de términos, expresiones, categoría, polaridad o intensidad, reglas y procedencia.
5. Revisar las ambigüedades, negaciones y expresiones coloquiales.
6. Guardar una versión inicial del diccionario con fecha y número de versión.
7. Permitir que el usuario revise, corrija, agregue o elimine términos.
8. Registrar cada modificación y el diccionario empleado en cada análisis.

Como punto de partida, evalúa estas categorías, pero no fuerces todas si el corpus exige una taxonomía mejor fundamentada:

- Alegría.
- Tristeza.
- Ira.
- Miedo.
- Sorpresa.
- Asco.
- Amor o afecto.
- Gratitud.
- Confianza.
- Esperanza.
- Anticipación.
- Frustración.
- Ansiedad.
- Orgullo.
- Vergüenza.
- Diversión.
- Aburrimiento.
- Alivio.

La taxonomía final debe contener al menos 15 categorías utilizables y documentadas. Distingue entre emociones, estados afectivos y otras etiquetas si su naturaleza conceptual difiere.

**Reglas metodológicas:**

- No afirmes que una palabra pertenece a una emoción con certeza absoluta.
- No infieras el sentimiento de una persona como una verdad psicológica.
- Distingue sentimiento detectado por reglas léxicas de sentimiento validado manualmente.
- Trata las palabras ambiguas en contexto cuando sea posible.
- Implementa reglas para negaciones e intensificadores.
- Permite incorporar expresiones de varias palabras.
- Evita contar simultáneamente una expresión compuesta y sus componentes como si fueran evidencia independiente, salvo que exista una regla explícita.
- Identifica términos desconocidos o sin categoría.
- Conserva trazabilidad entre mensaje, términos detectados y categoría asignada.

El diccionario propio debe generarse a partir de la evidencia del corpus y la revisión documentada. No inventes que fue validado por expertos ni que alcanza una determinada precisión si no se realizó esa evaluación.

### 7. IMPORTACIÓN DE DICCIONARIOS DESDE EL DASHBOARD

El dashboard debe permitir cargar diccionarios externos y utilizar el diccionario propio del proyecto.

Admite, como mínimo, CSV y JSON. Si resulta viable, añade TXT con un formato documentado.

Define un esquema canónico con campos equivalentes a:

- término o expresión;
- categoría emocional;
- polaridad;
- intensidad o peso;
- idioma;
- notas o procedencia.

Los campos obligatorios deben validarse y los opcionales deben tener valores por defecto documentados.

El sistema debe:

- Mostrar una vista previa antes de importar.
- Validar la estructura y los tipos de datos.
- Informar de filas inválidas, términos duplicados y categorías desconocidas.
- Permitir mapear columnas si el archivo externo utiliza nombres distintos.
- Ofrecer un modo de importación que no sobrescriba el diccionario vigente.
- Permitir guardar el diccionario importado como una nueva versión.
- Mostrar qué diccionario se utilizó en cada ejecución.
- Permitir seleccionar el diccionario activo.
- Registrar el nombre del archivo, versión, fecha, resultado y errores de la importación.

Nunca reemplaces silenciosamente el diccionario existente ni elimines sus versiones anteriores.

### 8. ANÁLISIS DE SENTIMIENTOS

Integrar el diccionario propio y los diccionarios importados con el pipeline de análisis.

El sistema debe permitir:

- Analizar mensajes individuales.
- Calcular frecuencias por categoría emocional.
- Mostrar la distribución emocional por día, semana o mes.
- Filtrar mensajes por categoría y periodo.
- Consultar ejemplos de mensajes asociados a cada categoría, respetando la privacidad del corpus.
- Visualizar palabras y expresiones que contribuyen a cada resultado.
- Comparar ejecuciones realizadas con diferentes diccionarios.
- Identificar mensajes sin coincidencias léxicas.
- Exportar resultados con trazabilidad.

Documenta el método de puntuación y cómo se combinan términos, expresiones, negaciones, intensificadores y emojis.

No sumes señales de diferentes fuentes arbitrariamente. Define una escala interpretable y una estrategia explícita para resolver contradicciones. Si una categoría se asigna por coincidencia léxica, preséntala como una estimación automática.

No uses reacciones de usuarios, respuestas o contexto conversacional como señales si no existen en los datos o no se han validado. No asumas que el autor de un mensaje siente necesariamente la emoción que expresa.

### 9. AVATAR EMOCIONAL INTERACTIVO

Diseña un pequeño personaje visual inspirado en los personajes de inicio de sesión que se cubrían los ojos, con apariencia amigable, original y no asociada a una marca ajena.

El avatar debe estar integrado en el dashboard y reflejar los resultados agregados del análisis seleccionado.

Características:

- Personaje con cuerpo, rostro, ojos y manos expresivos.
- Estado neutral para ausencia de datos.
- Expresiones visuales diferentes para las emociones seleccionadas.
- Animaciones sencillas y suaves, sin efectos excesivos.
- Interacción con los filtros de fechas, sentimientos y diccionarios.
- Estado de carga mientras se ejecuta el análisis.
- Mensaje claro cuando no existan resultados suficientes.

Puedes implementar la animación con JavaScript, SVG, CSS o las tecnologías compatibles con el dashboard existente.

La selección de la expresión debe derivarse de los resultados calculados, no de un valor fijo ni de una selección aleatoria. Define una regla transparente para determinar la emoción dominante y muestra también su frecuencia o proporción.

Si hay empate o las diferencias no son significativas, muestra una expresión neutral o mixta en lugar de afirmar una emoción dominante.

El avatar representa una distribución agregada de los mensajes seleccionados, no un diagnóstico emocional de una persona.

### 10. DASHBOARD: INTEGRACIÓN DE V1 Y V2

Mantén accesible la versión anterior y añade una sección claramente identificada para V2.

El usuario debe poder navegar entre ambas versiones sin mezclar sus resultados ni sobrescribir los datos originales.

Organiza el dashboard en módulos coherentes:

1. Inicio y resumen del corpus.
2. Selección de versión analítica.
3. Importación y validación de corpus.
4. Limpieza y tokenización.
5. Stopwords.
6. Unigramas, bigramas y n-gramas.
7. Características lingüísticas superficiales.
8. Frecuencias y exploración léxica.
9. TF, IDF y TF-IDF.
10. Modelado de tópicos.
11. Diccionario de sentimientos.
12. Importación y administración de diccionarios.
13. Análisis de sentimientos.
14. Avatar emocional.
15. Comparación de ejecuciones.
16. Bitácora.
17. Documentación y metodología.

Adapta los nombres y el orden a la interfaz real, pero mantén todas las funcionalidades accesibles.

Cada módulo debe presentar controles, resultados, mensajes de estado y explicaciones breves. No muestres gráficos vacíos sin indicar el motivo.

Todos los filtros deben actualizar los resultados correspondientes de forma coherente. Evita que los gráficos utilicen conjuntos de datos distintos sin indicarlo.

### 11. VERSIONADO ANALÍTICO

La nueva versión debe poder distinguirse de V1 dentro del dashboard y de la bitácora.

Implementa un sistema de versiones analíticas que identifique, como mínimo:

- versión del proyecto;
- identificador de ejecución;
- versión del corpus;
- versión del diccionario;
- configuración del pipeline;
- parámetros del modelo de tópicos;
- fecha y hora;
- estado de ejecución;
- ruta de los resultados;
- mensajes de error o advertencias.

No es necesario duplicar todo el corpus para cada versión. Utiliza referencias y metadatos cuando sea seguro, manteniendo separadas las configuraciones y los resultados de cada ejecución.

Una ejecución de V2 no debe alterar los resultados históricos de V1.

Si cambia el diccionario, el corpus o los parámetros del análisis, registra esa diferencia. Permite comparar resultados entre ejecuciones cuando las condiciones sean compatibles.

### 12. BITÁCORA PERSISTENTE

Amplía la bitácora existente en lugar de crear una segunda bitácora desconectada.

Debe registrar:

- inicio y fin de cada ejecución;
- usuario o identidad de sesión cuando esté disponible y sea apropiado;
- versión analítica;
- corpus seleccionado;
- importaciones;
- diccionario utilizado;
- cambios de configuración;
- etapas completadas;
- cantidad de registros procesados;
- resultados generados;
- advertencias y errores;
- duración de las operaciones;
- estado final.

Si ya existe una base de datos para la bitácora, inspecciónala y amplíala mediante migraciones compatibles. Si no existe, selecciona una solución persistente apropiada al proyecto.

La interfaz debe permitir filtrar la bitácora por fecha, versión, operación y estado. Incluye detalles técnicos útiles sin exponer credenciales ni almacenar innecesariamente el texto íntegro de las conversaciones.

Una operación fallida también debe registrarse. No registres una ejecución como exitosa si solo se completaron algunas etapas.

### 13. ESTRUCTURA DE RESULTADOS Y REPRODUCIBILIDAD

Organiza las salidas según la estructura real del proyecto. Como referencia, utiliza áreas diferenciadas para:

- datos originales;
- datos intermedios;
- resultados finales;
- diccionarios;
- configuraciones;
- registros de ejecución;
- pruebas;
- informes.

Cada resultado debe indicar de qué corpus, versión del pipeline y configuración procede.

Permite volver a ejecutar el análisis de forma reproducible sin importar manualmente archivos intermedios generados por ejecuciones anteriores.

Evita que los resultados antiguos se mezclen con los nuevos por coincidencia de nombres. Utiliza identificadores de ejecución, metadatos o carpetas de salida versionadas.

No subas datos privados del grupo de Telegram al repositorio público. Comprueba las reglas de exclusión de archivos y documenta cómo mantener los datos sensibles fuera del control de versiones.

### 14. PRUEBAS Y CONTROL DE CALIDAD

Crea o amplía las pruebas automatizadas en R.

Como mínimo, verifica:

- importación de corpus válidos e inválidos;
- detección de mensajes vacíos y duplicados;
- tokenización;
- eliminación de stopwords;
- conservación de negaciones;
- cálculo correcto de unigramas y bigramas;
- límites entre mensajes al generar n-gramas;
- cálculo de TF, IDF y TF-IDF con un ejemplo manual;
- carga de diccionarios CSV y JSON;
- detección de filas inválidas y términos duplicados;
- funcionamiento de las categorías emocionales;
- comportamiento ante mensajes sin coincidencias;
- agregación temporal;
- reproducibilidad de resultados;
- persistencia de la bitácora;
- separación entre V1 y V2;
- actualización coherente de los gráficos y del avatar.

Documenta las pruebas que no puedan ejecutarse por falta de dependencias o de datos.

No utilices resultados sintéticos como evidencia de que el sistema funciona con el corpus real. Ejecuta pruebas unitarias con datos de prueba y, cuando sea posible, una prueba de integración con una muestra anonimizada del corpus real.

### 15. DOCUMENTACIÓN ACADÉMICA

Actualiza la documentación existente para describir V1 y V2.

El informe debe explicar:

- objetivo del proyecto;
- descripción del corpus y sus limitaciones;
- arquitectura del sistema;
- preparación y limpieza de los datos;
- tokenización y stopwords;
- n-gramas y frecuencias;
- características lingüísticas superficiales;
- fundamentos matemáticos de TF, IDF y TF-IDF;
- metodología del modelado de tópicos;
- construcción y limitaciones del diccionario emocional;
- método de análisis de sentimientos;
- diseño del avatar y del dashboard;
- estructura y utilidad de la bitácora;
- pruebas realizadas;
- resultados empíricos;
- limitaciones, sesgos y posibles mejoras.

Distingue resultados reales de ejemplos metodológicos. No inventes referencias bibliográficas ni métricas de precisión.

Mantén el proyecto preparado para compilar el informe con LaTeX y utilizarlo en Overleaf. Reutiliza la estructura de informe existente y no reemplaces archivos de documentación sin preservar las modificaciones anteriores.

### 16. FASES DE IMPLEMENTACIÓN

Ejecuta el trabajo en fases independientes. No intentes implementar todo en una única respuesta.

**FASE 0 — Auditoría y planificación**

- Inspeccionar repositorio.
- Identificar V1, dependencias, scripts, dashboard, datos y bitácora.
- Elaborar un mapa de arquitectura.
- Identificar riesgos, incompatibilidades y cambios necesarios.
- Presentar un plan con archivos que se modificarán o crearán.

**FASE 1 — Arquitectura y pipeline secuencial**

- Reorganizar o modularizar los scripts R.
- Implementar limpieza, tokenización y stopwords.
- Incorporar unigramas, bigramas, n-gramas y características lingüísticas.
- Añadir validaciones y pruebas.

**FASE 2 — Frecuencias, TF-IDF y tópicos**

- Implementar frecuencias y visualizaciones.
- Calcular TF, IDF y TF-IDF.
- Incorporar modelado de tópicos.
- Documentar fórmulas, parámetros y pruebas.

**FASE 3 — Diccionario propio e importación externa**

- Construir la estructura del diccionario emocional.
- Adaptarla al vocabulario del corpus.
- Crear la importación de diccionarios externos.
- Implementar validaciones, versiones y trazabilidad.
- Integrar el análisis de sentimientos.

**FASE 4 — Dashboard y avatar emocional**

- Incorporar todos los módulos de análisis.
- Mantener accesible V1.
- Añadir la navegación de V2.
- Implementar el avatar interactivo.
- Validar filtros, gráficos y estados vacíos.

**FASE 5 — Bitácora y versionado**

- Integrar la nueva versión con la bitácora existente.
- Registrar ejecuciones, corpus, diccionarios y parámetros.
- Asegurar que los resultados históricos se preserven.
- Incorporar filtros y comparación de ejecuciones.

**FASE 6 — Integración, pruebas y documentación**

- Ejecutar pruebas unitarias y de integración.
- Corregir fallos.
- Verificar rutas y dependencias.
- Actualizar documentación técnica y académica.
- Elaborar instrucciones reproducibles de instalación y ejecución.
- Presentar el estado final, las limitaciones y los pasos pendientes.

### 17. PROTOCOLO DE CONTINUIDAD

Al concluir cada fase, genera o actualiza un archivo de seguimiento, por ejemplo `docs/PLAN_V2.md`, que contenga:

- fase actual;
- tareas completadas;
- archivos creados y modificados;
- pruebas ejecutadas y sus resultados;
- problemas pendientes;
- decisiones técnicas y justificaciones;
- instrucciones exactas para continuar;
- siguiente fase recomendada.

No dependas exclusivamente del historial de conversación para continuar el trabajo.

### 18. CRITERIOS DE ACEPTACIÓN

La V2 solo se considerará terminada cuando:

1. El pipeline R pueda ejecutarse de manera secuencial y reproducible.
2. Tokenización, stopwords, n-gramas y características lingüísticas generen resultados verificables.
3. TF, IDF y TF-IDF hayan sido contrastados con un ejemplo manual.
4. El módulo de tópicos funcione con una metodología documentada.
5. Exista un diccionario propio con al menos 15 categorías emocionales documentadas.
6. El dashboard permita importar, validar y seleccionar diccionarios externos.
7. El análisis emocional refleje el diccionario realmente seleccionado.
8. El avatar responda a resultados calculados y filtros del dashboard.
9. V1 y V2 sean distinguibles y accesibles.
10. La bitácora registre ejecuciones exitosas y fallidas con trazabilidad.
11. Las pruebas automatizadas pasen o sus fallos estén documentados explícitamente.
12. El informe y las instrucciones de ejecución estén actualizados.
13. Los datos privados del corpus no se publiquen accidentalmente.

### INSTRUCCIÓN INICIAL

Comienza exclusivamente con la FASE 0.

Inspecciona el repositorio existente y entrega un diagnóstico concreto de la arquitectura actual, funcionalidades ya implementadas, brechas, dependencias, riesgos y plan de cambios. No modifiques archivos durante esta primera inspección.

Cuando termine la auditoría, espera mi autorización para comenzar la FASE 1. No ejecutes todas las fases automáticamente.