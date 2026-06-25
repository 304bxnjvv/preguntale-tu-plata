from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.services.account_service import delete_user_data

router = APIRouter(prefix="/account", tags=["account"])


@router.delete("/data")
def account_delete_data(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return delete_user_data(session, user_id)
