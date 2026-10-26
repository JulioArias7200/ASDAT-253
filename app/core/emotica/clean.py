# -*- coding: utf-8 -*-
"""
Módulo de limpieza textual, extracción de emojis, elongación y detección de idioma.
Garantiza paridad con emotica/R/clean.R.
"""

import re
import unicodedata
from typing import List, Dict, Tuple, Any
import pandas as pd
from app.core.emotica.utils import ruta_recurso, leer_lineas_utf8

# Patrón robusto para caracteres pictográficos/emojis (Unicode 6.0+)
PATRON_EMOJI = re.compile(
    r"["
    r"\U0001F600-\U0001F64F"  # Emoticonos
    r"\U0001F300-\U0001F5FF"  # Símbolos y pictogramas
    r"\U0001F680-\U0001F6FF"  # Transporte y mapas
    r"\U0001F700-\U0001F77F"  # Alquimia
    r"\U0001F780-\U0001F7FF"  # Formas geométricas
    r"\U0001F800-\U0001F8FF"  # Flechas suplementarias
    r"\U0001F900-\U0001F9FF"  # Símbolos suplementarios
    r"\U0001FA00-\U0001FA6F"  # Ajedrez / símbolos
    r"\U0001FA70-\U0001FAFF"  # Símbolos varios
    r"\u2600-\u26FF"          # Símbolos varios
    r"\u2700-\u27BF"          # Dingbats
    r"\uFE00-\uFE0F"          # Selectores de variación
    r"\u200D"                 # Zero-width joiner
    r"]+",
    flags=re.UNICODE
)

# Selectores de variación y tonos de piel
PATRON_MODIFICADORES_EMOJI = re.compile(r"[\uFE0F\u200D\U0001F3FB-\U0001F3FF]")

def cargar_stopwords(idioma: str) -> List[str]:
    """Carga la lista de stopwords para un idioma desde resources/stopwords/<idioma>.txt."""
    f = ruta_recurso("resources", "stopwords", f"{idioma}.txt")
    if not f.exists():
        return []
    lineas = leer_lineas_utf8(f)
    return list(dict.fromkeys(l.strip() for l in lineas if l.strip()))

def idiomas_disponibles() -> List[str]:
    """Retorna los códigos de idiomas con lista de stopwords en resources/stopwords/."""
    d = ruta_recurso("resources", "stopwords")
    if not d.exists() or not d.is_dir():
        return []
    return [p.stem for p in d.glob("*.txt")]

def es_emoji(c: str) -> bool:
    """Determina si un caracter o glifo es un emoji."""
    return bool(PATRON_EMOJI.search(c))

def extraer_emojis(texto: str) -> str:
    """Extrae todos los emojis de un texto y los devuelve separados por espacio."""
    if not texto or not isinstance(texto, str):
        return ""
    emojis = PATRON_EMOJI.findall(texto)
    # Limpiar selectores de variación
    limpios = [PATRON_MODIFICADORES_EMOJI.sub("", e).strip() for e in emojis]
    limpios = [e for e in limpios if e]
    return " ".join(limpios)

def normalizar_texto(texto: str) -> str:
    """
    Normaliza el texto:
    1. Unicode NFC
    2. Elimina marcas <PII>
    3. Minúsculas
    4. Elimina modificadores de emoji
    5. Reduce elongaciones (ej: holaaaa -> holaa)
    6. Separa emojis con espacios y elimina signos de puntuación innecesarios
    7. Colapsa espacios en blanco
    """
    if not texto or not isinstance(texto, str):
        return ""
    
    # 1. NFC
    x = unicodedata.normalize("NFC", texto)
    
    # 2. Marcas PII
    x = re.sub(r"<[A-Z_]+>", " ", x)
    
    # 3. Minúsculas
    x = x.lower()
    
    # 4. Modificadores de emoji
    x = PATRON_MODIFICADORES_EMOJI.sub("", x)
    
    # 5. Reducción de elongación (holaaaa -> holaa)
    x = re.sub(r"([^\W\d_])\1{2,}", r"\1\1", x, flags=re.UNICODE)
    
    # 6. Espaciar emojis para tokenización correcta
    x = PATRON_EMOJI.sub(r" \g<0> ", x)
    
    # 7. Conservar letras, marcas de combinación, números, emojis y espacios
    # Reemplazar cualquier otro caracter (puntuación) por espacio
    resultado = []
    for c in x:
        cat = unicodedata.category(c)
        if cat.startswith("L") or cat.startswith("M") or cat.startswith("N") or cat.startswith("Z") or es_emoji(c):
            resultado.append(c)
        else:
            resultado.append(" ")
            
    x = "".join(resultado)
    return re.sub(r"\s+", " ", x).strip()

def limpiar_texto(df: pd.DataFrame) -> pd.DataFrame:
    """
    Ejecuta la limpieza textual completa sobre df['texto'].
    Agrega columnas: es_pregunta, emojis, texto_limpio, n_palabras, tiene_texto.
    """
    df = df.copy()
    raw_texto = df["texto"].fillna("").astype(str)
    
    df["es_pregunta"] = raw_texto.apply(lambda s: bool(re.search(r"[?¿]", s)))
    df["emojis"] = raw_texto.apply(extraer_emojis)
    df["texto_limpio"] = raw_texto.apply(normalizar_texto)
    df["n_palabras"] = df["texto_limpio"].apply(lambda t: len(re.findall(r"[\w]+", t, flags=re.UNICODE)))
    df["tiene_texto"] = df["texto_limpio"].str.len() > 0
    
    sin_texto = int((~df["tiene_texto"]).sum())
    con_emojis = int((df["emojis"].str.len() > 0).sum())
    preguntas = int(df["es_pregunta"].sum())
    
    df.attrs["detalle"] = f"sin texto util={sin_texto}; con emojis={con_emojis}; preguntas={preguntas}"
    return df

def detectar_idioma(textos_limpios: pd.Series, umbral: float = 0.10, muestra: int = 3000) -> Dict[str, Any]:
    """
    Detecta el idioma del corpus por proporción de stopwords (sin dependencias externas).
    Evalúa contra 'es', 'en', 'pt' o cualquier archivo en resources/stopwords/.
    """
    langs = idiomas_disponibles()
    validos = [t for t in textos_limpios if t and str(t).strip()]
    if not langs or not validos:
        return {"idioma": "und", "fracciones": {}}
    
    # Submuestreo si el corpus es muy grande
    if len(validos) > muestra:
        paso = len(validos) / muestra
        indices = [int(i * paso) for i in range(muestra)]
        sub_textos = [validos[i] for i in indices]
    else:
        sub_textos = validos
        
    todos_tokens = [tok for t in sub_textos for tok in t.split()]
    total_tokens = len(todos_tokens)
    if total_tokens == 0:
        return {"idioma": "und", "fracciones": {}}
    
    token_set = set(todos_tokens)
    conteos = pd.Series(todos_tokens).value_counts()
    
    fracciones = {}
    for l in langs:
        sw = set(cargar_stopwords(l))
        sw_encontradas = token_set.intersection(sw)
        cnt = sum(conteos[w] for w in sw_encontradas if w in conteos)
        fracciones[l] = round(cnt / total_tokens, 3)
        
    mejor_idioma = max(fracciones, key=fracciones.get)
    idioma_final = mejor_idioma if fracciones[mejor_idioma] >= umbral else "und"
    
    return {"idioma": idioma_final, "fracciones": fracciones}
