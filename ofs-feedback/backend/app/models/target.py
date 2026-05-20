from datetime import datetime, timezone, date
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, Boolean, DateTime, Integer, Date, ForeignKey, CheckConstraint, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.company import Company
    from app.models.contract import Contract


class Target(Base):
    __tablename__ = "targets"
    __table_args__ = (
        CheckConstraint("active_people >= 0", name="ck_targets_active_people"),
        CheckConstraint("weekly_target >= 1", name="ck_targets_weekly_target"),
        CheckConstraint("active_users >= 0", name="ck_targets_active_users"),
        UniqueConstraint("company_id", "contract_id", "week_start", name="uq_targets_company_contract_week"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    company_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("companies.id", ondelete="RESTRICT"), nullable=False
    )
    contract_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="SET NULL")
    )
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    active_people: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    weekly_target: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    active_users: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    company: Mapped["Company"] = relationship("Company", back_populates="targets", lazy="selectin")
    contract: Mapped[Optional["Contract"]] = relationship("Contract", back_populates="targets", lazy="selectin")

    @property
    def programmed_ofc(self) -> int:
        return self.active_people * self.weekly_target
