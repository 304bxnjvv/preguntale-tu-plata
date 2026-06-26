"""Endpoints de presupuestos (topes) y metas de ahorro."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.models.schemas import (
    MetaIn,
    MetaOut,
    MetaPatchIn,
    MetasResponse,
    OkResponse,
    PresupuestoEstadoOut,
    PresupuestoIn,
    PresupuestosResponse,
)
from app.services.meta_service import (
    actualizar_meta,
    crear_meta,
    eliminar_meta,
    listar_metas,
)
from app.services.presupuesto_service import (
    delete_tope,
    estado_presupuestos,
    set_tope,
)
from app.services.categorias_usuario_service import categorias_efectivas

router = APIRouter()


# ---------------------------------------------------------------------------
# Presupuestos
# ---------------------------------------------------------------------------

@router.get("/presupuestos", response_model=PresupuestosResponse)
async def get_presupuestos(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    items = estado_presupuestos(session, user_id)
    return PresupuestosResponse(items=items)


@router.post("/presupuestos", response_model=PresupuestoEstadoOut)
async def post_presupuesto(
    body: PresupuestoIn,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    try:
        validas = categorias_efectivas(session, user_id)
        estado = set_tope(session, user_id, body.categoria, body.monto_tope, validas)
    except ValueError:
        raise HTTPException(status_code=422, detail="categoría inválida")
    return PresupuestoEstadoOut(**estado)


@router.delete("/presupuestos/{categoria}", response_model=OkResponse)
async def delete_presupuesto(
    categoria: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = delete_tope(session, user_id, categoria)
    return OkResponse(ok=ok)


# ---------------------------------------------------------------------------
# Metas
# ---------------------------------------------------------------------------

@router.get("/metas", response_model=MetasResponse)
async def get_metas(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    items = listar_metas(session, user_id)
    return MetasResponse(items=items)


@router.post("/metas", response_model=MetaOut)
async def post_meta(
    body: MetaIn,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    meta = crear_meta(
        session,
        user_id,
        body.nombre,
        body.monto_objetivo,
        body.fecha_objetivo,
    )
    return MetaOut(**meta)


@router.patch("/metas/{meta_id}", response_model=MetaOut)
async def patch_meta(
    meta_id: str,
    body: MetaPatchIn,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    campos = body.model_dump(exclude_unset=True)
    meta = actualizar_meta(session, user_id, meta_id, **campos)
    if meta is None:
        raise HTTPException(status_code=404, detail="meta no encontrada")
    return MetaOut(**meta)


@router.delete("/metas/{meta_id}", response_model=OkResponse)
async def delete_meta(
    meta_id: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = eliminar_meta(session, user_id, meta_id)
    return OkResponse(ok=ok)
