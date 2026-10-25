# -*- coding: utf-8 -*-
"""
Modelos declarativos SQLAlchemy optimizados para Neon PostgreSQL.
"""
from app.extensions import db
from datetime import datetime

class Docente(db.Model):
    __tablename__ = "docentes"
    
    docente_id = db.Column(db.String(100), primary_key=True)
    nombre_completo = db.Column(db.String(255), nullable=False)
    materias_que_dicta = db.Column(db.Text)
    alias_regex = db.Column(db.Text)

    def to_dict(self):
        return {
            "docente_id": self.docente_id,
            "nombre_completo": self.nombre_completo,
            "materias_que_dicta": self.materias_que_dicta
        }

class Materia(db.Model):
    __tablename__ = "materias"
    
    codigo_materia = db.Column(db.String(50), primary_key=True)
    nombre_materia = db.Column(db.String(255), nullable=False)
    paralelos_disponibles = db.Column(db.String(100))
    docentes_asignados = db.Column(db.Text)
    alias_regex = db.Column(db.Text)

    def to_dict(self):
        return {
            "codigo_materia": self.codigo_materia,
            "nombre_materia": self.nombre_materia,
            "paralelos": self.paralelos_disponibles
        }

class OfertaHorario(db.Model):
    __tablename__ = "oferta_horarios"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    codigo_materia = db.Column(db.String(50), db.ForeignKey("materias.codigo_materia", ondelete="CASCADE"), index=True)
    nombre_materia = db.Column(db.String(255))
    paralelo = db.Column(db.String(20))
    docente = db.Column(db.String(255), index=True)
    docente_id = db.Column(db.String(100), db.ForeignKey("docentes.docente_id", ondelete="SET NULL"), nullable=True)
    horarios = db.Column(db.Text)

class Mensaje(db.Model):
    __tablename__ = "mensajes"
    
    mensaje_id = db.Column(db.BigInteger, primary_key=True)
    fecha = db.Column(db.DateTime, index=True)
    anio = db.Column(db.Integer, index=True)
    mes = db.Column(db.Integer)
    dia = db.Column(db.Integer)
    hora = db.Column(db.Integer)
    usuario_id = db.Column(db.String(100), index=True)
    usuario_nombre = db.Column(db.Text)
    es_respuesta = db.Column(db.Boolean, default=False)
    respuesta_a_id = db.Column(db.BigInteger, db.ForeignKey("mensajes.mensaje_id", ondelete="SET NULL"), nullable=True)
    padre_existe = db.Column(db.Boolean, default=False)
    texto_mensaje_padre = db.Column(db.Text)
    texto_original = db.Column(db.Text)
    texto_limpio = db.Column(db.Text)
    longitud_caracteres = db.Column(db.Integer)
    conteo_palabras = db.Column(db.Integer)
    es_pregunta = db.Column(db.Boolean, default=False)
    tiene_url = db.Column(db.Boolean, default=False)
    menciones_usuarios = db.Column(db.Text)
    tiene_imagen = db.Column(db.Boolean, default=False)
    ruta_imagen = db.Column(db.Text)
    imagen_texto_ocr = db.Column(db.Text)
    es_sticker = db.Column(db.Boolean, default=False)
    sticker_emoji = db.Column(db.String(50))
    sticker_emocion = db.Column(db.String(50), index=True)
    es_gif = db.Column(db.Boolean, default=False)
    gif_nombre = db.Column(db.Text)
    archivo_adjunto = db.Column(db.Text)
    thumbnail_adjunto = db.Column(db.Text)
    total_reacciones = db.Column(db.Integer, default=0)
    reaccion_principal = db.Column(db.String(50))
    reacciones_resumen = db.Column(db.Text)
    docente_mencionado = db.Column(db.Text, index=True)
    docente_id = db.Column(db.String(100), db.ForeignKey("docentes.docente_id", ondelete="SET NULL"), nullable=True)
    materia_mencionada = db.Column(db.Text, index=True)
    codigo_materia = db.Column(db.String(50), db.ForeignKey("materias.codigo_materia", ondelete="SET NULL"), nullable=True)
    entidad_heredada_hilo = db.Column(db.Boolean, default=False)
    contenido_multimodal_unificado = db.Column(db.Text)
    topico_lda_id = db.Column(db.Integer, default=0, index=True)
    topico_lda_prob = db.Column(db.Float, default=0.0)
    sentimiento_propio = db.Column(db.String(50), default="neutral", index=True)
    sentimiento_propio_score = db.Column(db.Float, default=0.0)
    emocion_propia = db.Column(db.String(50), default="neutral", index=True)
    nrc_emocion_top = db.Column(db.String(50), default="none", index=True)

class MencionDocente(db.Model):
    __tablename__ = "menciones_docentes"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    mensaje_id = db.Column(db.BigInteger, db.ForeignKey("mensajes.mensaje_id", ondelete="CASCADE"), index=True)
    docente_mencionado = db.Column(db.Text, index=True)
    docente_id = db.Column(db.String(100), db.ForeignKey("docentes.docente_id", ondelete="SET NULL"), nullable=True)
    materia_mencionada = db.Column(db.Text, index=True)
    codigo_materia = db.Column(db.String(50), db.ForeignKey("materias.codigo_materia", ondelete="SET NULL"), nullable=True)
    fecha = db.Column(db.DateTime, index=True)
    usuario_nombre = db.Column(db.Text)
    texto_limpio = db.Column(db.Text)
    es_pregunta = db.Column(db.Boolean, default=False)
    total_reacciones = db.Column(db.Integer, default=0)
    contenido_multimodal_unificado = db.Column(db.Text)
    topico_lda_id = db.Column(db.Integer, default=0, index=True)
    topico_lda_prob = db.Column(db.Float, default=0.0)
    sentimiento_propio = db.Column(db.String(50), default="neutral", index=True)
    sentimiento_propio_score = db.Column(db.Float, default=0.0)
    emocion_propia = db.Column(db.String(50), default="neutral", index=True)
    nrc_emocion_top = db.Column(db.String(50), default="none", index=True)

class ReaccionGranular(db.Model):
    __tablename__ = "reacciones_granular"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    mensaje_id = db.Column(db.BigInteger, db.ForeignKey("mensajes.mensaje_id", ondelete="CASCADE"), index=True)
    fecha_mensaje = db.Column(db.DateTime)
    emoji = db.Column(db.String(50))
    conteo = db.Column(db.Integer, default=1)
    emocion_reaccion = db.Column(db.String(100), index=True)

class Modismo(db.Model):
    __tablename__ = "catalogo_modismos"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    modismo_nombre = db.Column(db.String(100), unique=True)
    categoria = db.Column(db.String(100), index=True)
    polaridad_base = db.Column(db.Float)
    total_ocurrencias = db.Column(db.Integer, default=0)
    mensajes_unicos = db.Column(db.Integer, default=0)
    menciones_con_docente = db.Column(db.Integer, default=0)
    menciones_con_materia = db.Column(db.Integer, default=0)
    menciones_con_sarcasmo = db.Column(db.Integer, default=0)
    ejemplo_kwic = db.Column(db.Text)

class DiccionarioJerga(db.Model):
    __tablename__ = "diccionario_jergas"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    termino_jerga = db.Column(db.String(100), index=True)
    categoria = db.Column(db.String(100), index=True)
    significado_en_contexto_umsa = db.Column(db.Text)
    polaridad_base = db.Column(db.Float)
    total_ocurrencias = db.Column(db.Integer, default=0)
    mensajes_afectados = db.Column(db.Integer, default=0)
    ejemplo_real_del_chat = db.Column(db.Text)

class EventoServicio(db.Model):
    __tablename__ = "eventos_servicio"
    
    id = db.Column(db.BigInteger, primary_key=True)
    fecha = db.Column(db.DateTime)
    actor = db.Column(db.String(255))
    actor_id = db.Column(db.String(100))
    accion = db.Column(db.Text)

class ModismoMensaje(db.Model):
    __tablename__ = "modismos_mensajes"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    mensaje_id = db.Column(db.BigInteger, db.ForeignKey("mensajes.mensaje_id", ondelete="CASCADE"), index=True)
    fecha = db.Column(db.DateTime, index=True)
    usuario_nombre = db.Column(db.Text)
    modismo_nombre = db.Column(db.String(100), index=True)
    termino_exacto = db.Column(db.String(100))
    categoria = db.Column(db.String(100), index=True)
    polaridad_asignada = db.Column(db.Float)
    es_sarcasmo_potencial = db.Column(db.Boolean, default=False)
    docente_mencionado = db.Column(db.Text)
    materia_mencionada = db.Column(db.Text)
    contexto_kwic = db.Column(db.Text)
    reacciones = db.Column(db.Text)
    texto_completo = db.Column(db.Text)

class GifAnimacion(db.Model):
    __tablename__ = "gifs_animaciones"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    mensaje_id = db.Column(db.BigInteger, db.ForeignKey("mensajes.mensaje_id", ondelete="CASCADE"), index=True)
    fecha = db.Column(db.DateTime)
    usuario_nombre = db.Column(db.Text)
    gif_nombre = db.Column(db.Text)
    archivo_adjunto = db.Column(db.Text)
    thumbnail_adjunto = db.Column(db.Text)
    texto_limpio = db.Column(db.Text)
    contenido_multimodal_unificado = db.Column(db.Text)

class OcrCache(db.Model):
    __tablename__ = "ocr_cache"
    
    clave_imagen = db.Column(db.Text, primary_key=True)
    texto_ocr = db.Column(db.Text)
    longitud_caracteres = db.Column(db.Integer, default=0)
    tiene_texto = db.Column(db.Boolean, default=False)
    fecha_registro = db.Column(db.DateTime, default=datetime.utcnow)

class LdaTopico(db.Model):
    __tablename__ = "lda_topicos"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    topico_id = db.Column(db.Integer, nullable=False, index=True)
    nombre_etiqueta = db.Column(db.Text, nullable=False)
    termino = db.Column(db.Text, nullable=False, index=True)
    beta_prob = db.Column(db.Float, nullable=False)
    ranking_pos = db.Column(db.Integer, nullable=False)

    def to_dict(self):
        return {
            "topico_id": self.topico_id,
            "nombre_etiqueta": self.nombre_etiqueta,
            "termino": self.termino,
            "beta_prob": self.beta_prob,
            "ranking_pos": self.ranking_pos
        }

class TfidfEntidad(db.Model):
    __tablename__ = "tfidf_entidades"
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    entidad_tipo = db.Column(db.String(50), nullable=False, index=True)
    entidad_id = db.Column(db.Text, nullable=False, index=True)
    termino = db.Column(db.Text, nullable=False, index=True)
    score_tfidf = db.Column(db.Float, nullable=False)
    ranking_pos = db.Column(db.Integer, nullable=False)

    def to_dict(self):
        return {
            "entidad_tipo": self.entidad_tipo,
            "entidad_id": self.entidad_id,
            "termino": self.termino,
            "score_tfidf": self.score_tfidf,
            "ranking_pos": self.ranking_pos
        }


