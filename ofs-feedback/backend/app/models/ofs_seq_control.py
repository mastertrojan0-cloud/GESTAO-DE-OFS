from sqlalchemy import Integer, CheckConstraint, PrimaryKeyConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class OfsSeqControl(Base):
    __tablename__ = "ofs_seq_control"
    __table_args__ = (
        CheckConstraint("semana BETWEEN 1 AND 53", name="ck_seq_semana"),
        PrimaryKeyConstraint("ano", "semana"),
    )

    ano: Mapped[int] = mapped_column(Integer, nullable=False)
    semana: Mapped[int] = mapped_column(Integer, nullable=False)
    last_seq: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


# Backward-compatibility alias
OFSSeqControl = OfsSeqControl
