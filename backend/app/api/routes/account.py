import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_user
from app.config import settings
from app.db.base import get_session
from app.services.account_service import delete_user_data, exportar_datos, eliminar_cuenta

router = APIRouter(prefix="/account", tags=["account"])


@router.delete("/data")
def account_delete_data(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return delete_user_data(session, user_id)


@router.get("/export")
def account_export(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """
    Exporta todos los datos del usuario como JSON descargable (Ley 21.719).
    """
    exportado_at = datetime.now(timezone.utc).isoformat()
    data = exportar_datos(session, user_id, exportado_at=exportado_at)
    body = json.dumps(data, ensure_ascii=False, indent=2)
    return Response(
        content=body,
        media_type="application/json",
        headers={"Content-Disposition": 'attachment; filename="mis-datos-preguntale.json"'},
    )


@router.delete("")
def account_delete_full(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """
    Borra la cuenta completa: datos financieros + usuario de Supabase Auth
    (gateado por SUPABASE_SERVICE_ROLE_KEY en settings).
    """
    return eliminar_cuenta(
        session,
        user_id,
        token_service_role=settings.supabase_service_role_key,
        supabase_url=settings.supabase_url,
    )
