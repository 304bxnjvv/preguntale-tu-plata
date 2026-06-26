"""
Servicio de categorías personalizadas por usuario.
Las categorías custom se gestionan manualmente; el categorizador automático
(reglas + LLM) sigue usando solo las 11 categorías base de CATEGORIAS.
"""
from __future__ import annotations

import unicodedata
from sqlalchemy.orm import Session

from app.db.models import CategoriaUsuario
from app.services.categorias import CATEGORIAS


def _strip_accents(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def _normalize_for_compare(s: str) -> str:
    return _strip_accents(s.strip().lower())


def listar(session: Session, user_id: str) -> list[str]:
    """Devuelve los nombres de las categorías custom del usuario, ordenadas por created_at."""
    rows = (
        session.query(CategoriaUsuario)
        .filter_by(user_id=user_id)
        .order_by(CategoriaUsuario.created_at)
        .all()
    )
    return [r.nombre for r in rows]


def agregar(session: Session, user_id: str, nombre: str) -> str:
    """Agrega una categoría personalizada para el usuario.

    Reglas de validación:
    - nombre.strip() no vacío y len <= 30.
    - No puede coincidir (case/accent insensitive) con ninguna de las 11 categorías base.
    - No puede coincidir (case/accent insensitive) con una custom existente del mismo user.

    Devuelve el nombre guardado (trimmed).
    Raises ValueError si no pasa la validación.
    """
    nombre_trim = nombre.strip()
    if not nombre_trim:
        raise ValueError("El nombre de la categoría no puede estar vacío.")
    if len(nombre_trim) > 30:
        raise ValueError("El nombre de la categoría no puede superar 30 caracteres.")

    nombre_key = _normalize_for_compare(nombre_trim)

    # Chequeo contra las 11 categorías base
    for base in CATEGORIAS:
        if _normalize_for_compare(base) == nombre_key:
            raise ValueError(
                f"'{nombre_trim}' coincide con la categoría base '{base}'. "
                "Elige un nombre distinto."
            )

    # Chequeo contra las custom existentes
    for custom in listar(session, user_id):
        if _normalize_for_compare(custom) == nombre_key:
            raise ValueError(
                f"Ya existe una categoría personalizada llamada '{custom}'."
            )

    row = CategoriaUsuario(user_id=user_id, nombre=nombre_trim)
    session.add(row)
    session.commit()
    return nombre_trim


def eliminar(session: Session, user_id: str, nombre: str) -> bool:
    """Elimina la categoría custom del usuario.

    No afecta presupuestos ni transacciones que ya la usen.
    Devuelve True si existía y fue borrada, False si no existía.
    """
    nombre_key = _normalize_for_compare(nombre)
    rows = session.query(CategoriaUsuario).filter_by(user_id=user_id).all()
    for row in rows:
        if _normalize_for_compare(row.nombre) == nombre_key:
            session.delete(row)
            session.commit()
            return True
    return False


def categorias_efectivas(session: Session, user_id: str) -> list[str]:
    """Las 11 categorías base + las custom del usuario (base primero, sin duplicados)."""
    custom = listar(session, user_id)
    base_keys = {_normalize_for_compare(c) for c in CATEGORIAS}
    extra = [c for c in custom if _normalize_for_compare(c) not in base_keys]
    return list(CATEGORIAS) + extra
