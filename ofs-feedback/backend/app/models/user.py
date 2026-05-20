from datetime import datetime, timezone
from typing import Optional, List, TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import String, Boolean, DateTime, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.company import Company
    from app.models.ofs_record import OfsRecord, OfsEditLog
    from app.models.audit_log import AuditLog
    from app.models.report import Report


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(PG_UUID(), primary_key=True, default=uuid4)
    username: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    email: Mapped[Optional[str]] = mapped_column(String(200))
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    company_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("companies.id", ondelete="RESTRICT"))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    login_attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    locked_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    last_login: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    password_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    company: Mapped[Optional["Company"]] = relationship("Company", back_populates="users", lazy="selectin")
    ofs_records: Mapped[List["OfsRecord"]] = relationship(
        "OfsRecord", back_populates="usuario", foreign_keys="OfsRecord.usuario_id", lazy="selectin"
    )
    ofs_records_criados: Mapped[List["OfsRecord"]] = relationship(
        "OfsRecord", back_populates="criador", foreign_keys="OfsRecord.criado_por", lazy="selectin"
    )
    edit_logs: Mapped[List["OfsEditLog"]] = relationship("OfsEditLog", back_populates="editor", lazy="selectin")
    audit_logs: Mapped[List["AuditLog"]] = relationship("AuditLog", back_populates="user", lazy="selectin")
    reports: Mapped[List["Report"]] = relationship("Report", back_populates="generator", lazy="selectin")
