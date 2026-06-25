from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.models.schemas import SuscripcionesResponse, ComparativoResponse
from app.services.insights_service import detectar_suscripciones, comparativo_mensual

router = APIRouter()


@router.get("/insights/suscripciones", response_model=SuscripcionesResponse)
async def get_suscripciones(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    data = detectar_suscripciones(session, user_id)
    return SuscripcionesResponse(**data)


@router.get("/insights/comparativo", response_model=ComparativoResponse)
async def get_comparativo(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    data = comparativo_mensual(session, user_id)
    return ComparativoResponse(**data)
