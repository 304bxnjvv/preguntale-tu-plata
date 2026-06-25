import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, Numeric, Date, DateTime, Integer
from app.db.base import Base


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    fecha = Column(Date, nullable=False)
    descripcion = Column(Text, nullable=False)
    monto = Column(Numeric, nullable=False)
    moneda = Column(String, nullable=False, default="CLP")
    tarjeta = Column(String, nullable=True)
    tipo = Column(String, nullable=False)
    categoria = Column(String, nullable=True)
    banco = Column(String, nullable=False)
    fuente = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class Upload(Base):
    __tablename__ = "uploads"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    filename = Column(String, nullable=False)
    n_transacciones = Column(Integer, nullable=False, default=0)
    fuente = Column(String, nullable=False, default="cartola")
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    role = Column(String, nullable=False)  # 'user' | 'assistant'
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
