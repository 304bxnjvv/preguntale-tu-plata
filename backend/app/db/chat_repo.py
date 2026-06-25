from sqlalchemy.orm import Session
from app.db.models import ChatMessage


def save_message(session: Session, user_id: str, role: str, content: str) -> ChatMessage:
    msg = ChatMessage(user_id=user_id, role=role, content=content)
    session.add(msg)
    session.commit()
    session.refresh(msg)
    return msg


def get_history(session: Session, user_id: str, limit: int = 100) -> list[ChatMessage]:
    """All messages for user, ascending by created_at."""
    return (
        session.query(ChatMessage)
        .filter(ChatMessage.user_id == user_id)
        .order_by(ChatMessage.created_at.asc())
        .limit(limit)
        .all()
    )


def get_recent_for_memory(
    session: Session, user_id: str, limit: int = 6
) -> list[ChatMessage]:
    """Last `limit` messages for user, returned ascending (oldest→newest) for prompt injection."""
    # Fetch the tail descending, then reverse in Python to get ascending order.
    rows = (
        session.query(ChatMessage)
        .filter(ChatMessage.user_id == user_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(limit)
        .all()
    )
    return list(reversed(rows))
