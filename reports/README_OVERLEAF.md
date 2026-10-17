# Informe en LaTeX (listo para Overleaf)

Este directorio contiene el informe académico completo en `.tex`, generado de forma
automática por el pipeline (`scripts/09_generate_report.R`).

## Cómo subirlo a Overleaf

1. Comprime **toda** la carpeta `reports/` (incluyendo `sections/`, `tables/`,
   `figures/`, `generated/`, `preamble.tex` y `references.bib`).
2. En Overleaf: *New Project → Upload Project* y sube el `.zip`.
3. Comprueba que el documento principal sea `main.tex`.
4. Compilador: **pdfLaTeX** (por defecto). Overleaf ejecuta `bibtex` automáticamente.

El proyecto es autocontenido: no requiere paquetes especiales más allá de los estándar
de TeX Live (babel-spanish, booktabs, natbib, microtype, etc.).

## Estructura

```
reports/
├── main.tex              # documento principal
├── preamble.tex          # paquetes, estilo y macros
├── references.bib        # bibliografía (BibTeX)
├── sections/             # 12 secciones del informe
├── tables/               # tablas .tex y .csv generadas por el pipeline
├── figures/              # figuras .png generadas por el pipeline
└── generated/            # values.tex y stats.tex (macros numéricas)
```

## Cifras automáticas

El informe no contiene números escritos a mano. Todas las cifras provienen de
`generated/values.tex` y `generated/stats.tex`, reescritos en cada ejecución del
pipeline. Para actualizar el informe tras reanalizar los datos:

```
Rscript scripts/09_generate_report.R
```

## Compilación local

```
cd reports
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```
