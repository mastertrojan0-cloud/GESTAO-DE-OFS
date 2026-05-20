from datetime import datetime, timezone
from typing import Optional, Any, TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import String, DateTime, Integer, ForeignKey, CheckConstraint, BigInteger
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID as PG_UUID, JSONB

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class Report(Base):
    __tablename__ = "reports"
    __table_args__ = (
        CheckConstraint(
            "type IN ('individual', 'semanal')",
            name="ck_reports_type",
        ),
    )

    id: Mapped[UUID] = mapped_column(PG_UUID(), primary_key=True, default=uuid4)
    type: Mapped[str] = mapped_column(String(50), nullable=False)
    parameters: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict, nullable=False)
    file_path: Mapped[Optional[str]] = mapped_column(String(500))
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger)
    generated_by: Mapped[UUID] = mapped_column(
        PG_UUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )

    generator: Mapped["User"] = relationship(
        "User", back_populates="reports", foreign_keys=[generated_by], lazy="selectin"
    )
