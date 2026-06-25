from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.services.demo_service import seed_demo, clear_demo

router = APIRouter(prefix="/demo", tags=["demo"])


@router.post("/seed", status_code=status.HTTP_201_CREATED)
def demo_seed(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    inserted = seed_demo(session, user_id)
    return {"inserted": inserted}


@router.delete("/seed")
def demo_clear(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    deleted = clear_demo(session, user_id)
    return {"deleted": deleted}
