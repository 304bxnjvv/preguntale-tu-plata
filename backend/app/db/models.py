import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, Numeric, Date, DateTime, Integer, Boolean, UniqueConstraint
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
    categoria_manual = Column(Boolean, nullable=False, default=False)
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


class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, unique=True, index=True)
    estado = Column(String, nullable=False, default="trial")  # trial|activa|cancelada|vencida
    trial_ends_at = Column(DateTime(timezone=True), nullable=True)
    periodo_fin = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class TarjetaEstado(Base):
    __tablename__ = "tarjeta_estado"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, unique=True, index=True)
    total_a_pagar = Column(Numeric, nullable=False, default=0)
    monto_minimo = Column(Numeric, nullable=False, default=0)
    fecha_vencimiento = Column(Date, nullable=True)
    cupo_total = Column(Numeric, nullable=False, default=0)
    cupo_utilizado = Column(Numeric, nullable=False, default=0)
    cuotas = Column(Text, nullable=False, default="[]")  # JSON string
    comprometido_proximo_mes = Column(Numeric, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class CategoriaOverride(Base):
    __tablename__ = "categoria_overrides"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    comercio_key = Column(String, nullable=False)
    categoria = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    __table_args__ = (UniqueConstraint("user_id", "comercio_key", name="uq_override_user_key"),)


class Presupuesto(Base):
    __tablename__ = "presupuestos"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    categoria = Column(String, nullable=False)
    monto_tope = Column(Numeric, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    __table_args__ = (UniqueConstraint("user_id", "categoria", name="uq_presupuesto_user_cat"),)


class Meta(Base):
    __tablename__ = "metas"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    nombre = Column(String, nullable=False)
    monto_objetivo = Column(Numeric, nullable=False, default=0)
    monto_actual = Column(Numeric, nullable=False, default=0)
    fecha_objetivo = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class CategoriaUsuario(Base):
    __tablename__ = "categorias_usuario"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    nombre = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    __table_args__ = (UniqueConstraint("user_id", "nombre", name="uq_categoria_usuario"),)
