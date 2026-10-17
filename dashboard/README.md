# Dashboard AS_Telegram — guía de diseño y personalización

Dashboard Shiny con un tema propio (gradientes, tarjetas *glass*, KPIs animados y modo
claro/oscuro) y **Apache ECharts** como motor de visualización (servido localmente en
`www/echarts.min.js`, por lo que funciona sin conexión).

## Archivos

| Archivo | Rol |
|---|---|
| `dashboard/app.R` | Página, cabecera, pie, tema y registro de módulos |
| `dashboard/modules/mod_*.R` | UI y servidor de cada pestaña |
| `dashboard/www/as_theme.css` | Sistema visual (colores, tarjetas, KPI, animaciones) |
| `dashboard/www/as_app.js` | Motor ECharts, tema claro/oscuro, contadores, aparición |
| `dashboard/www/emotional_avatar.{js,css}` | Avatar emocional SVG |
| `R/dashboard_charts.R` | Utilidades de R: `as_card`, `as_kpi`, `as_echart`, `opt_*` |

## Cómo modificar la CABECERA (cabeza de página)

En `app.R` la cabecera se construye en el objeto `.hero` y se conecta con el argumento
`header` de `bslib::page_navbar()`:

```r
.hero <- shiny::div(class = "as-hero",
  shiny::div(class = "as-hero-inner",
    shiny::div(
      shiny::h1("AS_Telegram · Análisis de sentimiento"),
      shiny::p(class = "as-hero-sub", "Panel interactivo ...")
    ),
    shiny::div(class = "as-hero-controls", ...)
  )
)

bslib::page_navbar(
  ...,
  header = shiny::tagList(.head, .hero),   # <-- cabeceera global
  footer = .footer
)
```

- **Cambiar el título/subtítulo:** edita el `h1` y el `p` dentro de `.hero`.
- **Añadir un botón o chip:** agrega `shiny::span(class = "as-chip", ...)` en `.as-badges`.
- **Añadir CSS/JS propio:** amplía `.head` con
  `shiny::tags$link(rel = "stylesheet", href = "mi.css")` o
  `shiny::tags$script(src = "mi.js")` (los archivos van en `dashboard/www/`).
- **Estilo/posición:** edita la regla `.as-hero` en `as_theme.css`.

> Nota: en `bslib::page_navbar()`, `header` se coloca **por encima** de la barra de
> pestañas y `footer` **debajo** del contenido. Si prefieres que la barra quede arriba del
> todo, mueve `.hero` al inicio del *primer* `nav_panel` y deja `header = .head`.

## Cómo modificar el PIE DE PÁGINA

El pie es `.footer` en `app.R`, conectado al argumento `footer`:

```r
.footer <- shiny::div(class = "as-footer",
  shiny::div(class = "as-footer-inner",
    shiny::div(shiny::span(class = "as-footer-brand", "AS_Telegram"), ...),
    shiny::div(class = "as-muted small", "Aviso de uso ético ..."),
    shiny::div(shiny::span("Enlaces: "), shiny::tags$a(href = "...", "sitio"))
  )
)
```

- **Añadir enlaces:** usa `shiny::tags$a(href = "https://...", "texto")`.
- **Estilo del pie:** regla `.as-footer` en `as_theme.css`.
- **Fijarlo al fondo de la ventana (siempre visible):** añade en `as_theme.css`:

```css
.as-footer { position: sticky; bottom: 0; z-index: 1020; }
```

## Cómo añadir una pestaña nueva

1. Crea `dashboard/modules/mod_mine.R` con `mod_mine_ui(id)` y `mod_mine_server(id, ...)`.
2. En `app.R`, añade el panel y registra el servidor:

```r
bslib::nav_panel(shiny::span(as_icon("target", 16), " Mi pestaña"), mod_mine_ui("mine")),
# ...
mod_mine_server("mine", .data)
```

## Cómo añadir un gráfico ECharts

En la UI:

```r
as_card(title = "Mi gráfico", icon = "activity", as_echart(ns("mychart"), "360px"))
```

En el servidor del módulo (usa `ns <- session$ns`):

```r
as_render_echart(session, ns("mychart"), {
  d <- data.frame(cat = c("a", "b"), n = c(3, 1))
  opt_hbar(d, "cat", "n")          # o opt_donut / opt_vbar / opt_line / opt_heatmap
})
```

Constructores disponibles en `R/dashboard_charts.R`: `opt_donut`, `opt_hbar`, `opt_vbar`,
`opt_line`, `opt_heatmap`. Para algo a medida, devuelve una lista con la estructura de
opciones de ECharts (https://echarts.apache.org/en/option.html). Evita funciones
JavaScript dentro de la opción; usa plantillas de cadena (`"{b}: {c}"`).

## KPIs y tarjetas

```r
as_kpi_grid(
  as_kpi(1234, "Mensajes", icon = "chat", variant = "", sub = "total"),
  as_kpi(18.6, "Cobertura", icon = "percent", variant = "is-pink",
         raw = 18.6, decimals = 1, suffix = "%")
)
```

Variantes de color: `""` (índigo), `"is-cyan"`, `"is-pink"`, `"is-green"`.
Iconos: `chat, pie, calendar, percent, heart, activity, grid, clock, sun, moon,
download, search, refresh, database, file, book, smile, shuffle, list, upload, layers,
target`.

## Tema claro/oscuro

El botón de la cabecera llama a `window.ASApp.toggle()` (definido en `as_app.js`). El
tema se guarda en `localStorage` y ECharts se re-renderiza automáticamente. Para cambiar
los colores, edita las variables CSS `--as-*` en `:root` y `[data-bs-theme="dark"]`.

## Ejecutar

```bash
Rscript dashboard/run.R          # http://127.0.0.1:3838
Rscript dashboard/run.R 3999     # puerto personalizado
```
