from datetime import datetime, timezone
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.models import Upload

LIMITE_MENSUAL = 20


class UploadLimitError(Exception):
    pass


def _inicio_mes() -> datetime:
    now = datetime.now(timezone.utc)
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def check_limit(session: Session, user_id: str) -> None:
    count = (
        session.query(func.count(Upload.id))
        .filter(Upload.user_id == user_id, Upload.created_at >= _inicio_mes())
        .scalar()
    ) or 0
    if count >= LIMITE_MENSUAL:
        raise UploadLimitError("Llegaste al límite de subidas del mes")


def log_upload(
    session: Session, user_id: str, filename: str, n: int, fuente: str = "cartola"
) -> None:
    session.add(Upload(user_id=user_id, filename=filename, n_transacciones=n, fuente=fuente))
    session.commit()
