from __future__ import annotations
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import CategoriaOverride
from app.services.categorias import comercio_key


def upsert_override(session: Session, user_id: str, key: str, categoria: str) -> None:
    row = session.query(CategoriaOverride).filter_by(user_id=user_id, comercio_key=key).first()
    if row is None:
        session.add(CategoriaOverride(user_id=user_id, comercio_key=key, categoria=categoria))
    else:
        row.categoria = categoria
        row.updated_at = datetime.now(timezone.utc)
    session.commit()


def get_override(session: Session, user_id: str, descripcion: str) -> str | None:
    desc_key = comercio_key(descripcion)
    if not desc_key:
        return None
    for row in session.query(CategoriaOverride).filter_by(user_id=user_id).all():
        if row.comercio_key and row.comercio_key in desc_key:
            return row.categoria
    return None
