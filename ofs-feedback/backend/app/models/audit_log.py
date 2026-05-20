from datetime import datetime, timezone
from typing import Optional, Any, TYPE_CHECKING
from uuid import UUID

from sqlalchemy import String, DateTime, Integer, Text, ForeignKey, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class AuditLog(Base):
    __tablename__ = "audit_logs"
    __table_args__ = (
        CheckConstraint(
            "severity IN ('INFO', 'WARNING', 'CRITICAL')",
            name="ck_audit_severity",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    user_id: Mapped[Optional[UUID]] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="SET NULL")
    )
    username: Mapped[Optional[str]] = mapped_column(String(100))
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    resource: Mapped[str] = mapped_column(String(100), nullable=False)
    resource_id: Mapped[Optional[str]] = mapped_column(String(255))
    details: Mapped[Optional[Any]] = mapped_column(JSONB, default=dict)
    ip_address: Mapped[Optional[str]] = mapped_column(String(45))
    severity: Mapped[str] = mapped_column(String(20), default="INFO", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    user: Mapped[Optional["User"]] = relationship(
        "User", back_populates="audit_logs", foreign_keys=[user_id], lazy="selectin"
    )
