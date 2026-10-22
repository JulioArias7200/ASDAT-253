# DAT-253, Mineria de Datos
# Proyecto: Analisis de sentimientos - Telegram

Elaborado por: Iver Samuel Medina Balboa<br>
Esta guia esta desarrollada para la ejecucion en cualquier maquina,
Se recomienda utilizar WSL entorno de Linux en WSL.


> Si algo falla, ve directo a la sección [Problemas frecuentes](#12-problemas-frecuentes).

---

## Índice

1. [¿Qué es esto?](#1-qué-es-esto)
2. [Glosario mínimo](#2-glosario-mínimo)
3. [Instalar las herramientas base](#3-instalar-las-herramientas-base)
4. [Descargar el proyecto](#4-descargar-el-proyecto)
5. [Abrir la terminal en la carpeta correcta](#5-abrir-la-terminal-en-la-carpeta-correcta)
6. [Instalar las dependencias de R](#6-instalar-las-dependencias-de-r)
7. [Configurar el proyecto](#7-configurar-el-proyecto)
8. [Poner el corpus (los mensajes)](#8-poner-el-corpus-los-mensajes)
9. [Ejecutar el análisis completo](#9-ejecutar-el-análisis-completo)
10. [Abrir el panel (dashboard)](#10-abrir-el-panel-dashboard)
11. [Generar el informe PDF](#11-generar-el-informe-pdf)
12. [Ejecutar en cualquier otra PC](#13-ejecutar-en-cualquier-otra-pc)
13. [Problemas frecuentes](#14-problemas-frecuentes)
14. [Chuleta de comandos](#15-chuleta-de-comandos)

---

## 1. ¿Qué es esto?

Es un programa que:

1. Lee un archivo JSON exportado de un grupo de Telegram.
2. Analiza el **sentimiento** (positivo / negativo) y las **emociones** de cada mensaje.
3. Genera gráficos, un panel web interactivo y un **informe en PDF**.

Todo está escrito en **R** y se ejecuta con tres tipos de comandos:

- `Rscript scripts/XX.R` → ejecuta un paso del análisis.
- `Rscript dashboard/run.R` → abre el panel web.
- `Rscript scripts/10_test.R` → comprueba que todo funciona.

---

## 2. Glosario mínimo

| Palabra | Qué significa aquí |
|---|---|
| **terminal** | La ventana negra donde escribes comandos. |
| **R** | El lenguaje de programación con el que está hecho el proyecto. |
| **Rscript** | El comando que ejecuta archivos `.R`. |
| **renv** | El gestor que instala las librerías correctas del proyecto. |
| **corpus** | El archivo con los mensajes (`result.json`). |
| **pipeline** | El conjunto de pasos 01 → 10. |
| **dashboard** | El panel web con gráficos. |
| **bitácora** | Un registro (base de datos) de todo lo que se ejecutó. |

Los símbolos de la guía:

- 💡 = consejo.
- ⚠️ = cuidado, es fácil equivocarse.
- ✅ = cómo saber que salió bien.

---

## 3. Instalar las herramientas base

Necesitas **R** y **Git**. Elige tu sistema:

### Windows

Recomendado usar **WSL** (una Ubuntu dentro de Windows), que es lo que usa este proyecto.
Abre **PowerShell como administrador** y ejecuta:

```powershell
wsl --install
```

Reinicia el PC. Se abrirá una terminal de Ubuntu donde crearás un usuario y contraseña.
Luego, dentro de esa terminal Ubuntu, instala R:

```bash
sudo apt update
sudo apt install -y r-base git
```

💡 Si no quieres instalar nada en el sistema, descarga R desde <https://cran.r-project.org>
y Git desde <https://git-scm.com>, y usa **RStudio** (opcional).

### macOS

Instala [Homebrew](https://brew.sh) y luego:

```bash
brew install r git
```

### Linux (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y r-base git
```

### Comprobar que quedaron instalados

```bash
R --version
git --version
```

✅ Debes ver un número de versión en ambos. Si R es **4.2 o superior**, perfecto.

Instala también `renv`:

```bash
Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv")'
```

---

## 4. Descargar el proyecto

### Opción A: con Git (recomendado)

```bash
cd ~
git clone https://github.com/ismedinab96/ASDAT-253.git
cd AS_Telegram-main
```


### Opción B: sin Git

Descarga el ZIP del repositorio, descomprímelo y entra en la carpeta con `cd`.

✅ Quedaste bien si al ejecutar `ls` ves carpetas como `R`, `scripts`, `dashboard`.

---

## 5. Abrir la terminal en la carpeta correcta

Señal de que estás en el lugar correcto:

```bash
ls
```

Debe aparecer al menos: `R  scripts  dashboard  config  data  reports`.

⚠️ **Todos los comandos de esta guía se ejecutan desde aquí.** Si te pierdes:

```bash
cd ~/AS_Telegram-main
```

---

## 6. Instalar las dependencias de R

Esto descarga e instala todas las librerías que el proyecto necesita (puede tardar unos
minutos la primera vez):

```bash
Rscript -e 'renv::restore()'
```

💡 Si te pregunta algo, escribe `y` y pulsa Enter. Al final dice algo como
`The library is already synchronized`.

✅ Cómo comprobar que funcionó:

```bash
Rscript -e 'library(quanteda); library(topicmodels); cat("DEPS OK\n")'
```

Debe imprimir `DEPS OK`.

⚠️ Si falla en `topicmodels` por `libgsl.so`, haz la sección siguiente.

### (Solo si falló por GSL) Instalar GSL sin administrador

```bash
mkdir -p ~/opt/gsl && cd ~/opt/gsl
apt-get download libgsl28 libgslcblas0 2>/dev/null || true
for deb in *.deb; do dpkg-deb -x "$deb" .; done
cd ~/AS_Telegram-main
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"
Rscript -e 'library(topicmodels); cat("GSL OK\n")'
```

💡 Cuando ejecutes el pipeline, **recuerda exportar `LD_LIBRARY_PATH`** (está incluido en
todos los ejemplos de abajo).

---

## 7. Configurar el proyecto

```bash
cp config/config.example.yml config/config.yml
```

Esto crea tu configuración local (no se sube a GitHub, así que puedes editarla con
tranquilidad). Por defecto ya funciona; solo cámbiala si sabes lo que haces.

---

## 8. Poner el corpus (los mensajes)

1. Abre Telegram Desktop → tu grupo → **Exportar historial de chat** → formato
   **JSON**.
2. Copia el archivo resultante dentro del proyecto, con este nombre exacto:

```
data/raw/result.json
```

💡 En WSL, si el archivo está en tu Windows, normalmente lo encuentras en
`/mnt/c/Users/TU_USUARIO/Downloads/`. Cópialo así:

```bash
cp "/mnt/c/Users/TU_USUARIO/Downloads/result.json" data/raw/result.json
```

⚠️ **Nunca subas este archivo a GitHub** (son datos privados). Ya está ignorado por el
proyecto, no te preocupes.

✅ Comprobar que está:

```bash
ls -l data/raw/result.json
```

---

## 9. Ejecutar el análisis completo

Es lo que hace todo el trabajo. Copia y pega este bloque completo:

```bash
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"

for s in 01_import 02_validate 03_clean 04_sentiment 05_topics \
         05n_ngrams 05f_features 06_temporal 06t_tfidf 07_markov \
         08_evaluate 09_generate_report 10_test; do
  echo "================ $s ================"
  Rscript "scripts/$s.R" || { echo "FALLÓ $s"; break; }
done
```

También puedes usar el orquestador, que ejecuta todo en procesos independientes:

```bash
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"
Rscript scripts/00_run_all.R            # V1 + V2
Rscript scripts/00_run_all.R 04 09      # solo pasos que coincidan
```

Qué hace cada paso:

| Paso | Qué hace en palabras simples |
|---|---|
| `01_import` | Lee `result.json` y lo guarda en la base de datos. |
| `02_validate` | Comprueba que los datos están bien formados. |
| `03_clean` | Limpia el texto (sin borrar emojis ni negaciones). |
| `04_sentiment` | Calcula sentimiento y emociones de cada mensaje. |
| `05_topics` | Descubre los temas de conversación. |
| `05n_ngrams` | Cuenta unigramas, bigramas y trigramas por mensaje. |
| `05f_features` | Calcula 17 características superficiales por mensaje. |
| `06_temporal` | Calcula tendencias por día / semana / mes. |
| `06t_tfidf` | Pondera los términos con TF--IDF (documento = mensaje). |
| `07_markov` | Analiza cómo se encadenan los estados. |
| `08_evaluate` | Mide la cobertura y calidad del análisis. |
| `09_generate_report` | Crea gráficos, tablas y el PDF. |
| `10_test` | Ejecuta las pruebas automáticas. |

✅ **Señal de éxito:** cada paso imprime una línea `OK <paso>` y el bloque termina con
`OK 10_test`.

Los resultados de V2 se guardan **solo** en `data/results/v2/` (`ngrams.rds`,
`linguistic_features.rds`, `tfidf.rds` y `tfidf.csv`); los artefactos de V1 no se
sobrescriben. El dashboard los muestra en las pestañas **N-gramas**,
**Frecuencias**, **Características** y **TF-IDF**.

💡 Si quieres ejecutar un solo paso (por ejemplo el sentimiento):

```bash
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"
Rscript scripts/04_sentiment.R
```

---

## 9.1 Importar un diccionario externo (V2)

Desde el dashboard (**Diccionario → Importar**): elige CSV, JSON o TXT, revisa el mapeo
de columnas, valida la vista previa e importa. La importación crea una versión nueva en
`data/dictionary/versions/` y **nunca** sobrescribe el diccionario activo; para usarla hay
que pulsar **Activar** (se guarda un respaldo de la versión anterior).

Desde R:

```r
source("R/bootstrap.R"); bootstrap()
imp <- import_external_dictionary("mi_diccionario.csv")
activate_dictionary_version(imp$version)
list_dictionary_versions()
```

Esquema canónico: `term, category, polarity, weight, language, notes, source`. Las
categorías deben pertenecer a las 18 emociones del proyecto.

> ⚡ **Auto-actualización**: si al importar marcas **Activar al importar** (o activas una
> versión en «Versiones del diccionario»), el dashboard recalcula en caliente todo el
> análisis (sentimientos, temporal, transiciones, evaluación y avatar) con las palabras
> del grupo y guarda un respaldo del análisis anterior en `data/results/backups/`.

---

## 10. Abrir el panel (dashboard)

```bash
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"
Rscript dashboard/run.R
```

Verás algo como `Listening on http://127.0.0.1:3838`. Abre esa dirección en el navegador.

- Para usar otro puerto: `Rscript dashboard/run.R 8080`.
- Para detenerlo: pulsa `Ctrl + C` en la terminal.

⚠️ Si el panel dice "Falta sentiment.rds", es que no ejecutaste el paso 9. Hazlo primero.

---

## 11. Generar el informe PDF

El informe se genera dentro del paso `09_generate_report`, pero si quieres hacerlo solo:

```bash
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"
Rscript scripts/09_generate_report.R
```

Para compilar el PDF necesitas un **motor LaTeX** (`pdflatex`). Si no lo tienes:

```bash
Rscript -e 'tinytex::install_tinytex()'   # instala LaTeX sin permisos de admin
export PATH="$HOME/bin:$PATH"
tlmgr install babel-spanish lm booktabs caption enumitem
```

✅ El resultado es `reports/main.pdf`. Ábrelo o verifica que existe:

```bash
ls -l reports/main.pdf
```

💡 Si no instalas LaTeX, los gráficos y tablas igual se generan y quedan en
`reports/figures/` y `reports/tables/`; solo faltará el PDF final.

---

## 12. Ejecutar en cualquier otra PC

En un PC nuevo, pasos mínimos (asumiendo Linux/WSL; en Windows usa WSL, en macOS Homebrew):

```bash
# 1) Instalar R y Git  (ver sección 3)
sudo apt update && sudo apt install -y r-base git

# 2) Descargar el proyecto
cd ~
git clone <URL_DE_TU_REPOSITORIO>
cd AS_Telegram-main

# 3) Instalar la herramienta renv
Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv")'

# 4) Instalar dependencias del proyecto
Rscript -e 'renv::restore()'

# 5) (Si falla topicmodels) instalar GSL de usuario  -> ver sección 6
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"

# 6) Configuración
cp config/config.example.yml config/config.yml

# 7) Poner el corpus en  data/raw/result.json  -> ver sección 8

# 8) Ejecutar todo
for s in 01_import 02_validate 03_clean 04_sentiment 05_topics \
         06_temporal 07_markov 08_evaluate 09_generate_report 10_test; do
  Rscript "scripts/$s.R" || break
done

# 9) Abrir el panel
Rscript dashboard/run.R
```

Notas por sistema:

- **Windows:** usa WSL (Ubuntu). Los comandos son idénticos.
- **macOS:** instala R y Git con Homebrew; `apt` no existe. Para GSL, `brew install gsl` y
  no necesitas `LD_LIBRARY_PATH`.
- **LaTeX:** opcional. Sin él se genera todo salvo `reports/main.pdf`.

💡 **Lo único que cambia entre PCs es instalar las herramientas y poner el corpus.** El
resto (`renv::restore()` + pipeline) es idéntico.

---

## 13. Problemas frecuentes

| Síntoma | Qué hacer |
|---|---|
| `Rscript: command not found` | R no está instalado o no está en el PATH. Repite la sección 3. |
| `libgsl.so.28: cannot open shared object file` | Exporta `LD_LIBRARY_PATH` (sección 6). |
| `pdflatex: not found` | Instala TinyTeX y añade `$HOME/bin` al PATH (sección 11). |
| `Cannot open file 'data/raw/result.json'` | El corpus no está en su sitio (sección 8). |
| El dashboard dice "Falta sentiment.rds" | Ejecuta primero el pipeline (sección 9). |
| `The project is out-of-sync` | Ejecuta `Rscript -e 'renv::snapshot()'`. |
| El análisis tarda mucho | Es normal la primera vez con muchos mensajes; espera. |
| Quiero empezar de cero | Borra `database/as_telegram.sqlite` y `data/interim|processed|results/*`, y repite la sección 9. |

---

## 14. Tips

```bash
# Entrar al proyecto
cd ~/AS_Telegram-main

# Preparar el entorno (una vez)
Rscript -e 'renv::restore()'
cp config/config.example.yml config/config.yml
export LD_LIBRARY_PATH="$HOME/opt/gsl/usr/lib/x86_64-linux-gnu"

# Ejecutar todo el análisis
for s in 01_import 02_validate 03_clean 04_sentiment 05_topics \
         06_temporal 07_markov 08_evaluate 09_generate_report 10_test; do
  Rscript "scripts/$s.R" || break
done

# Panel web
Rscript dashboard/run.R

# Solo las pruebas
Rscript scripts/10_test.R

# Solo el informe
Rscript scripts/09_generate_report.R
```
