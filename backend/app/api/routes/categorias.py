"""Endpoints de categorías personalizadas por usuario."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.models.schemas import CategoriaIn, CategoriasResponse, OkResponse
from app.services.categorias import CATEGORIAS
from app.services.categorias_usuario_service import (
    agregar,
    categorias_efectivas,
    eliminar,
    listar,
)

router = APIRouter()


@router.get("/categorias", response_model=CategoriasResponse)
async def get_categorias(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    personalizadas = listar(session, user_id)
    todas = categorias_efectivas(session, user_id)
    return CategoriasResponse(
        base=list(CATEGORIAS),
        personalizadas=personalizadas,
        todas=todas,
    )


@router.post("/categorias", response_model=CategoriaIn)
async def post_categoria(
    body: CategoriaIn,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    try:
        nombre = agregar(session, user_id, body.nombre)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    return CategoriaIn(nombre=nombre)


@router.delete("/categorias/{nombre}", response_model=OkResponse)
async def delete_categoria(
    nombre: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = eliminar(session, user_id, nombre)
    return OkResponse(ok=ok)
