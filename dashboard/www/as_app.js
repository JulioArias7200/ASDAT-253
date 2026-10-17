/* =============================================================================
 * as_app.js — interactividad del dashboard AS_Telegram
 *  - Integración de Apache ECharts (temas claro/oscuro, redimensionado, animación)
 *  - Conmutador de tema claro/oscuro persistente
 *  - Contadores animados en los KPI
 *  - Aparición progresiva de secciones
 *  - Reloj en vivo de la cabecera
 * ========================================================================= */
(function () {
  "use strict";

  /* --------------------------------------------------------------------- */
  /* Temas de ECharts                                                      */
  /* --------------------------------------------------------------------- */
  function baseTheme(dark) {
    return {
      color: ["#6366f1", "#ec4899", "#06b6d4", "#10b981", "#f59e0b",
              "#8b5cf6", "#ef4444", "#14b8a6"],
      backgroundColor: "transparent",
      textStyle: { fontFamily: "Inter, Segoe UI, system-ui, sans-serif",
                   color: dark ? "#e2e8f0" : "#1e293b" },
      title: { textStyle: { color: dark ? "#f1f5f9" : "#0f172a", fontWeight: 700 } },
      legend: { textStyle: { color: dark ? "#cbd5e1" : "#475569" } },
      tooltip: {
        backgroundColor: dark ? "rgba(15,23,42,.95)" : "rgba(255,255,255,.97)",
        borderColor: "rgba(99,102,241,.35)", borderWidth: 1,
        textStyle: { color: dark ? "#e2e8f0" : "#1e293b" },
        extraCssText: "border-radius:12px;box-shadow:0 12px 30px -12px rgba(30,41,59,.5);padding:10px 12px;"
      },
      categoryAxis: {
        axisLine: { lineStyle: { color: dark ? "#334155" : "#cbd5e1" } },
        axisLabel: { color: dark ? "#94a3b8" : "#64748b" },
        splitLine: { show: false }
      },
      valueAxis: {
        axisLine: { show: false },
        axisLabel: { color: dark ? "#94a3b8" : "#64748b" },
        splitLine: { lineStyle: { color: dark ? "rgba(148,163,184,.14)" : "rgba(100,116,139,.14)" } }
      }
    };
  }

  var hasEcharts = typeof window.echarts !== "undefined";
  if (hasEcharts) {
    echarts.registerTheme("as-light", baseTheme(false));
    echarts.registerTheme("as-dark", baseTheme(true));
  }

  var charts = {};   // id -> { instance, option }
  var observers = {};// id -> ResizeObserver

  function currentTheme() {
    return document.documentElement.getAttribute("data-bs-theme") === "dark" ? "dark" : "light";
  }

  function chartThemeName() {
    return currentTheme() === "dark" ? "as-dark" : "as-light";
  }

  function ensureChart(id) {
    if (charts[id] && charts[id].instance) return charts[id].instance;
    var el = document.getElementById(id);
    if (!el || !hasEcharts) return null;
    var inst = echarts.init(el, chartThemeName(), { renderer: "canvas" });
    charts[id] = charts[id] || { instance: null, option: null };
    charts[id].instance = inst;
    if (window.ResizeObserver) {
      observers[id] = new ResizeObserver(function () {
        if (inst && !inst.isDisposed()) inst.resize();
      });
      observers[id].observe(el);
    }
    return inst;
  }

  function applyOption(id, option) {
    var entry = charts[id] || (charts[id] = { instance: null, option: null });
    entry.option = option;
    var inst = ensureChart(id);
    if (!inst) return;
    inst.setOption(option, true);
    // pequeño delay para paneles recién mostrados
    setTimeout(function () { if (!inst.isDisposed()) inst.resize(); }, 60);
  }

  /* --------------------------------------------------------------------- */
  /* Mensajes desde Shiny                                                  */
  /* --------------------------------------------------------------------- */
  function registerHandlers() {
    if (!window.Shiny || !Shiny.addCustomMessageHandler) return;

    Shiny.addCustomMessageHandler("as_echart", function (msg) {
      applyOption(msg.id, msg.option);
    });

    Shiny.addCustomMessageHandler("as_theme", function (msg) {
      setTheme(msg.theme);
    });
  }

  /* --------------------------------------------------------------------- */
  /* Tema claro / oscuro                                                   */
  /* --------------------------------------------------------------------- */
  function setTheme(theme) {
    document.documentElement.setAttribute("data-bs-theme", theme);
    try { localStorage.setItem("as-theme", theme); } catch (e) {}
    var btn = document.getElementById("as-theme-toggle");
    if (btn) {
      var sun  = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>';
      var moon = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>';
      btn.innerHTML = theme === "dark" ? sun : moon;
    }
    // Re-renderizar gráficos con el nuevo tema
    Object.keys(charts).forEach(function (id) {
      var entry = charts[id];
      if (!entry || !entry.instance) return;
      try { entry.instance.dispose(); } catch (e) {}
      entry.instance = null;
      var inst = ensureChart(id);
      if (inst && entry.option) inst.setOption(entry.option, true);
    });
  }

  function initTheme() {
    var saved = "light";
    try { saved = localStorage.getItem("as-theme") || "light"; } catch (e) {}
    setTheme(saved);
  }

  /* --------------------------------------------------------------------- */
  /* Contadores animados KPI                                               */
  /* --------------------------------------------------------------------- */
  function formatNumber(value, decimals) {
    try {
      return Number(value).toLocaleString("es-BO", {
        minimumFractionDigits: decimals, maximumFractionDigits: decimals
      });
    } catch (e) {
      return String(value);
    }
  }

  function animateCount(el) {
    if (el.dataset.asDone === "1") return;
    el.dataset.asDone = "1";
    var target = parseFloat(el.dataset.countup || "0");
    var decimals = parseInt(el.dataset.decimals || "0", 10);
    var suffix = el.dataset.suffix || "";
    var prefix = el.dataset.prefix || "";
    var duration = 900, start = null;
    function step(ts) {
      if (!start) start = ts;
      var p = Math.min((ts - start) / duration, 1);
      var eased = 1 - Math.pow(1 - p, 3);
      el.textContent = prefix + formatNumber(target * eased, decimals) + suffix;
      if (p < 1) requestAnimationFrame(step);
      else el.textContent = prefix + formatNumber(target, decimals) + suffix;
    }
    requestAnimationFrame(step);
  }

  function scanCounters(root) {
    (root || document).querySelectorAll("[data-countup]").forEach(function (el) {
      if (el.dataset.asDone === "1") return;
      var r = el.getBoundingClientRect();
      if (r.top < window.innerHeight && r.bottom > 0) animateCount(el);
      else el.textContent = (el.dataset.prefix || "") +
        formatNumber(parseFloat(el.dataset.countup || "0"), parseInt(el.dataset.decimals || "0", 10)) +
        (el.dataset.suffix || "");
    });
  }

  /* --------------------------------------------------------------------- */
  /* Aparición progresiva                                                  */
  /* --------------------------------------------------------------------- */
  function initReveal() {
    if (!window.IntersectionObserver) {
      document.querySelectorAll(".as-reveal").forEach(function (el) { el.classList.add("as-in"); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("as-in"); io.unobserve(e.target); }
      });
    }, { threshold: 0.08 });
    document.querySelectorAll(".as-reveal").forEach(function (el) { io.observe(el); });
  }

  /* --------------------------------------------------------------------- */
  /* Reloj en vivo                                                         */
  /* --------------------------------------------------------------------- */
  function initClock() {
    function tick() {
      var el = document.getElementById("as-clock");
      if (!el) return;
      var d = new Date();
      el.textContent = d.toLocaleTimeString("es-BO", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
    }
    tick(); setInterval(tick, 1000);
  }

  /* --------------------------------------------------------------------- */
  /* Observador global: nuevos nodos Shiny                                 */
  /* --------------------------------------------------------------------- */
  function initObserver() {
    var mo = new MutationObserver(function (mutations) {
      mutations.forEach(function (m) {
        m.addedNodes && m.addedNodes.forEach(function (n) {
          if (n.nodeType !== 1) return;
          scanCounters(n);
          if (n.classList && n.classList.contains("as-reveal")) n.classList.add("as-in");
        });
      });
    });
    mo.observe(document.body, { childList: true, subtree: true });
  }

  /* --------------------------------------------------------------------- */
  /* Arranque                                                              */
  /* --------------------------------------------------------------------- */
  function boot() {
    initTheme();
    registerHandlers();
    initReveal();
    initClock();
    initObserver();
    scanCounters(document);
    setTimeout(function () { scanCounters(document); }, 400);
    window.addEventListener("resize", function () {
      Object.keys(charts).forEach(function (id) {
        var e = charts[id];
        if (e && e.instance && !e.instance.isDisposed()) e.instance.resize();
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  // API pública para botones/HTML generado
  window.ASApp = {
    setTheme: setTheme,
    toggle: function () { setTheme(currentTheme() === "dark" ? "light" : "dark"); },
    apply: applyOption
  };
})();
