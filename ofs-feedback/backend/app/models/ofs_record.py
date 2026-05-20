from datetime import datetime, timezone, date, time
from typing import Optional, List, TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import (
    String, Boolean, DateTime, Integer, Text, Date, Time, ForeignKey, CheckConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.company import Company
    from app.models.contract import Contract
    from app.models.user import User


class OfsRecord(Base):
    __tablename__ = "ofs_records"
    __table_args__ = (
        CheckConstraint(
            "tipo_observacao IN ('Positivo/Seguro', 'Negativo/Inseguro')",
            name="ck_ofs_tipo_observacao",
        ),
        CheckConstraint(
            "status_registro IN ('Gerado', 'Editado', 'Cancelado')",
            name="ck_ofs_status_registro",
        ),
        CheckConstraint("semana BETWEEN 1 AND 53", name="ck_ofs_semana"),
        CheckConstraint("mes BETWEEN 1 AND 12", name="ck_ofs_mes"),
    )

    id: Mapped[UUID] = mapped_column(PG_UUID(), primary_key=True, default=uuid4)
    codigo: Mapped[str] = mapped_column(String(17), unique=True, nullable=False, default="")
    data_registro: Mapped[date] = mapped_column(Date, default=date.today, nullable=False)
    hora_registro: Mapped[time] = mapped_column(
        Time, default=lambda: datetime.now().time(), nullable=False
    )
    semana: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    mes: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    ano: Mapped[int] = mapped_column(Integer, nullable=False, default=2026)

    usuario_id: Mapped[UUID] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    usuario_nome_snapshot: Mapped[str] = mapped_column(String(200), nullable=False)
    usuario_login_snapshot: Mapped[str] = mapped_column(String(100), nullable=False)
    usuario_email_snapshot: Mapped[Optional[str]] = mapped_column(String(200))
    usuario_perfil_snapshot: Mapped[str] = mapped_column(String(20), nullable=False)
    empresa_usuario_snapshot: Mapped[Optional[str]] = mapped_column(String(150))

    contrato_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="SET NULL")
    )

    empresa_observada_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("companies.id", ondelete="SET NULL")
    )
    empresa_observada_outros: Mapped[Optional[str]] = mapped_column(String(150))

    nome_observado: Mapped[str] = mapped_column(String(200), nullable=False)
    atividade_observada: Mapped[str] = mapped_column(String(300), nullable=False)
    local_observado: Mapped[str] = mapped_column(String(200), nullable=False)

    turno: Mapped[str] = mapped_column(String(50), nullable=False)
    tipo_observacao: Mapped[str] = mapped_column(String(20), nullable=False)

    comportamento_observado: Mapped[str] = mapped_column(Text, nullable=False)
    observacao_complementar: Mapped[Optional[str]] = mapped_column(Text)

    status_registro: Mapped[str] = mapped_column(String(20), default="Gerado", nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    edit_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    criado_por: Mapped[UUID] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    criado_em: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    editado_por: Mapped[Optional[UUID]] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="SET NULL")
    )
    editado_em: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    cancelado_por: Mapped[Optional[UUID]] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="SET NULL")
    )
    cancelado_em: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    motivo_cancelamento: Mapped[Optional[str]] = mapped_column(Text)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    deleted_by: Mapped[Optional[UUID]] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="SET NULL")
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    usuario: Mapped["User"] = relationship(
        "User", back_populates="ofs_records", foreign_keys=[usuario_id], lazy="selectin"
    )
    criador: Mapped["User"] = relationship(
        "User", back_populates="ofs_records_criados", foreign_keys=[criado_por], lazy="selectin"
    )
    empresa_observada: Mapped[Optional["Company"]] = relationship(
        "Company", back_populates="ofs_records", foreign_keys=[empresa_observada_id], lazy="selectin"
    )
    contrato: Mapped[Optional["Contract"]] = relationship(
        "Contract", back_populates="ofs_records", foreign_keys=[contrato_id], lazy="selectin"
    )
    edit_logs: Mapped[List["OfsEditLog"]] = relationship(
        "OfsEditLog", back_populates="ofs_record", lazy="selectin", order_by="OfsEditLog.edited_at.desc()",
    )


class OfsEditLog(Base):
    __tablename__ = "ofs_edit_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ofs_record_id: Mapped[UUID] = mapped_column(
        PG_UUID(), ForeignKey("ofs_records.id"), nullable=False
    )
    edited_by: Mapped[UUID] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    field_changed: Mapped[str] = mapped_column(String(100), nullable=False)
    old_value: Mapped[Optional[str]] = mapped_column(Text)
    new_value: Mapped[Optional[str]] = mapped_column(Text)
    edited_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    ofs_record: Mapped["OfsRecord"] = relationship("OfsRecord", back_populates="edit_logs", lazy="selectin")
    editor: Mapped["User"] = relationship("User", back_populates="edit_logs", foreign_keys=[edited_by], lazy="selectin")


# Backward-compatibility aliases
OfcRecord = OfsRecord
OfcEditLog = OfsEditLog
