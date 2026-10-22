/* =============================================================================
 * emotional_avatar.js — avatar emocional interactivo (SVG)
 * Recibe el estado agregado desde Shiny (R) y dibuja una expresión.
 * Representa la interpretación del modelo, no el estado real de una persona.
 * ========================================================================= */
(function () {
  "use strict";

  // Parámetros visuales por emoción: boca, cejas, ojos, animación.
  var PROFILES = {
    alegria:        { mouth: "smile",      brows: "up",     eyes: "happy",      anim: "bounce", color: "#2e7d32" },
    diversion:      { mouth: "grin",       brows: "up",     eyes: "happy",      anim: "bounce", color: "#388e3c" },
    amor:           { mouth: "soft",       brows: "neutral",eyes: "heart",      anim: "pulse",  color: "#c2185b" },
    gratitud:       { mouth: "soft",       brows: "up",     eyes: "happy",      anim: "pulse",  color: "#5e35b1" },
    confianza:      { mouth: "soft",       brows: "neutral",eyes: "calm",       anim: "none",   color: "#00838f" },
    esperanza:      { mouth: "soft",       brows: "up",     eyes: "calm",       anim: "pulse",  color: "#0288d1" },
    orgullo:        { mouth: "smirk",      brows: "up",     eyes: "happy",      anim: "none",   color: "#f9a825" },
    alivio:         { mouth: "soft",       brows: "neutral",eyes: "closed",     anim: "none",   color: "#43a047" },
    anticipacion:   { mouth: "flat",       brows: "up",     eyes: "wide",       anim: "pulse",  color: "#00796b" },
    sorpresa:       { mouth: "o",          brows: "up",     eyes: "wide",       anim: "pulse",  color: "#6a1b9a" },
    tristeza:       { mouth: "frown",      brows: "sad",    eyes: "sad",        anim: "droop",  color: "#1565c0" },
    frustracion:    { mouth: "frown",      brows: "angry",  eyes: "sad",        anim: "shake",  color: "#6d4c41" },
    ansiedad:       { mouth: "wave",       brows: "worried",eyes: "wide",       anim: "shake",  color: "#ef6c00" },
    miedo:          { mouth: "wave",       brows: "worried",eyes: "wide",       anim: "shake",  color: "#37474f" },
    ira:            { mouth: "frown",      brows: "angry",  eyes: "narrow",     anim: "shake",  color: "#b71c1c" },
    asco:           { mouth: "frown",      brows: "angry",  eyes: "narrow",     anim: "none",   color: "#558b2f" },
    verguenza:      { mouth: "wave",       brows: "worried",eyes: "closed",     anim: "none",   color: "#d81b60" },
    aburrimiento:   { mouth: "flat",       brows: "neutral",eyes: "half",       anim: "droop",  color: "#616161" },
    sin_evidencia:  { mouth: "flat",       brows: "neutral",eyes: "calm",       anim: "none",   color: "#757575" }
  };

  function mouthPath(kind) {
    switch (kind) {
      case "smile":  return "M70,140 Q100,170 130,140";
      case "grin":   return "M68,138 Q100,180 132,138";
      case "frown":  return "M70,155 Q100,125 130,155";
      case "flat":   return "M72,148 L128,148";
      case "o":      return null; // círculo
      case "wave":   return "M68,150 Q84,138 100,150 Q116,162 132,150";
      case "soft":   return "M72,142 Q100,158 128,142";
      case "smirk":  return "M72,146 Q104,158 130,138";
      default:       return "M72,148 L128,148";
    }
  }

  function renderAvatar(host, state) {
    if (!host) return;
    var emo = (state && state.emotion) || "sin_evidencia";
    var prof = PROFILES[emo] || PROFILES.sin_evidencia;
    var label = (state && state.label) || emo;
    var n = (state && state.n) ? state.n : 0;

    host.innerHTML = "";
    host.setAttribute("data-emotion", emo);

    var ns = "http://www.w3.org/2000/svg";
    var svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", "0 0 200 220");
    svg.setAttribute("class", "as-avatar-svg as-anim-" + prof.anim);
    svg.setAttribute("role", "img");
    svg.setAttribute("aria-label", "Avatar emocional: " + label);

    function el(tag, attrs) {
      var e = document.createElementNS(ns, tag);
      for (var k in attrs) e.setAttribute(k, attrs[k]);
      return e;
    }

    // Cabeza
    svg.appendChild(el("circle", { cx: 100, cy: 110, r: 78, fill: "#fdf6e3", stroke: prof.color, "stroke-width": 4 }));

    // Ojos
    if (prof.eyes === "happy" || prof.eyes === "calm") {
      svg.appendChild(el("path", { d: "M64,96 Q74,86 84,96", fill: "none", stroke: "#333", "stroke-width": 4, "stroke-linecap": "round" }));
      svg.appendChild(el("path", { d: "M116,96 Q126,86 136,96", fill: "none", stroke: "#333", "stroke-width": 4, "stroke-linecap": "round" }));
    } else if (prof.eyes === "closed") {
      svg.appendChild(el("path", { d: "M64,98 L84,98", stroke: "#333", "stroke-width": 4, "stroke-linecap": "round" }));
      svg.appendChild(el("path", { d: "M116,98 L136,98", stroke: "#333", "stroke-width": 4, "stroke-linecap": "round" }));
    } else if (prof.eyes === "heart") {
      svg.appendChild(el("text", { x: 74, y: 104, "font-size": 26, "text-anchor": "middle" })).textContent = "♥";
      svg.appendChild(el("text", { x: 126, y: 104, "font-size": 26, "text-anchor": "middle" })).textContent = "♥";
    } else if (prof.eyes === "wide") {
      svg.appendChild(el("circle", { cx: 76, cy: 96, r: 12, fill: "#fff", stroke: "#333", "stroke-width": 3 }));
      svg.appendChild(el("circle", { cx: 124, cy: 96, r: 12, fill: "#fff", stroke: "#333", "stroke-width": 3 }));
      svg.appendChild(el("circle", { cx: 76, cy: 96, r: 5, fill: "#333" }));
      svg.appendChild(el("circle", { cx: 124, cy: 96, r: 5, fill: "#333" }));
    } else if (prof.eyes === "sad") {
      svg.appendChild(el("circle", { cx: 78, cy: 100, r: 6, fill: "#333" }));
      svg.appendChild(el("circle", { cx: 122, cy: 100, r: 6, fill: "#333" }));
      svg.appendChild(el("path", { d: "M66,88 Q78,94 90,88", fill: "none", stroke: "#333", "stroke-width": 3 }));
    } else if (prof.eyes === "half") {
      svg.appendChild(el("path", { d: "M66,98 Q76,92 86,98", fill: "none", stroke: "#333", "stroke-width": 4 }));
      svg.appendChild(el("path", { d: "M114,98 Q124,92 134,98", fill: "none", stroke: "#333", "stroke-width": 4 }));
    } else {
      svg.appendChild(el("circle", { cx: 78, cy: 98, r: 7, fill: "#333" }));
      svg.appendChild(el("circle", { cx: 122, cy: 98, r: 7, fill: "#333" }));
    }

    // Cejas
    var browStroke = { fill: "none", stroke: "#555", "stroke-width": 5, "stroke-linecap": "round" };
    if (prof.brows === "angry") {
      svg.appendChild(el("path", Object.assign({ d: "M62,74 L90,82" }, browStroke)));
      svg.appendChild(el("path", Object.assign({ d: "M138,74 L110,82" }, browStroke)));
    } else if (prof.brows === "worried") {
      svg.appendChild(el("path", Object.assign({ d: "M62,82 L90,72" }, browStroke)));
      svg.appendChild(el("path", Object.assign({ d: "M138,82 L110,72" }, browStroke)));
    } else if (prof.brows === "sad") {
      svg.appendChild(el("path", Object.assign({ d: "M62,80 L90,76" }, browStroke)));
      svg.appendChild(el("path", Object.assign({ d: "M138,80 L110,76" }, browStroke)));
    } else if (prof.brows === "up") {
      svg.appendChild(el("path", Object.assign({ d: "M64,72 Q78,64 92,72" }, browStroke)));
      svg.appendChild(el("path", Object.assign({ d: "M136,72 Q122,64 108,72" }, browStroke)));
    } else {
      svg.appendChild(el("path", Object.assign({ d: "M64,76 L92,76" }, browStroke)));
      svg.appendChild(el("path", Object.assign({ d: "M136,76 L108,76" }, browStroke)));
    }

    // Boca
    if (prof.mouth === "o") {
      svg.appendChild(el("ellipse", { cx: 100, cy: 150, rx: 14, ry: 18, fill: "#7b1fa2" }));
    } else {
      svg.appendChild(el("path", { d: mouthPath(prof.mouth), fill: "none", stroke: "#7b1fa2", "stroke-width": 5, "stroke-linecap": "round" }));
    }

    host.appendChild(svg);

    var cap = document.createElement("div");
    cap.className = "as-avatar-caption";
    cap.textContent = label + (n ? "  ·  " + n + " mensajes" : "");
    host.appendChild(cap);
  }

  if (window.Shiny && Shiny.addCustomMessageHandler) {
    Shiny.addCustomMessageHandler("avatar_state", function (msg) {
      var hosts = document.querySelectorAll(".as-avatar-host");
      for (var i = 0; i < hosts.length; i++) renderAvatar(hosts[i], msg);
    });
  }

  // Fallback estático por si Shiny no envía estado todavía.
  document.addEventListener("DOMContentLoaded", function () {
    var hosts = document.querySelectorAll(".as-avatar-host");
    for (var i = 0; i < hosts.length; i++) {
      if (!hosts[i].querySelector("svg")) renderAvatar(hosts[i], { emotion: "sin_evidencia", label: "Sin datos" });
    }
  });
})();
