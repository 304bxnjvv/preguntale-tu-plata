"""
Account data service: hard-delete all user data across Transaction, ChatMessage, Upload.
"""
from sqlalchemy.orm import Session
from app.db.models import Transaction, ChatMessage, Upload


def delete_user_data(session: Session, user_id: str) -> dict:
    """
    Delete ALL rows for user_id in Transaction, ChatMessage, and Upload tables.
    Returns counts of deleted rows per table.
    """
    transactions = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .all()
    )
    t_count = len(transactions)
    for row in transactions:
        session.delete(row)

    chats = (
        session.query(ChatMessage)
        .filter(ChatMessage.user_id == user_id)
        .all()
    )
    c_count = len(chats)
    for row in chats:
        session.delete(row)

    uploads = (
        session.query(Upload)
        .filter(Upload.user_id == user_id)
        .all()
    )
    u_count = len(uploads)
    for row in uploads:
        session.delete(row)

    session.commit()
    return {"transactions": t_count, "chat": c_count, "uploads": u_count}
