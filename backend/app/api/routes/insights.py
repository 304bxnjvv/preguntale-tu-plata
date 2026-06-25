from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.models.schemas import (
    SuscripcionesResponse,
    ComparativoResponse,
    FinScoreResponse,
    TarjetaEstadoResponse,
    AlertasResponse,
)
from app.services.insights_service import detectar_suscripciones, comparativo_mensual, calcular_finscore
from app.services.tarjeta_service import get_estado
from app.services.alertas_service import evaluar_alertas

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


@router.get("/insights/finscore", response_model=FinScoreResponse)
async def get_finscore(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    data = calcular_finscore(session, user_id)
    return FinScoreResponse(**data)


@router.get("/insights/tarjeta", response_model=TarjetaEstadoResponse)
async def get_tarjeta(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return get_estado(session, user_id)


@router.get("/insights/alertas", response_model=AlertasResponse)
async def get_alertas(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return AlertasResponse(items=evaluar_alertas(session, user_id))
