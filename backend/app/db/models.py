import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, Numeric, Date, DateTime
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
    created_at = Column(DateTime, default=datetime.utcnow)
