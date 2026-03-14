from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from terra_testing.db.base import Base


class TestAssignment(Base):
    __tablename__ = "test_assignments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="assigned", nullable=False)
    due_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    questions_count: Mapped[int] = mapped_column(Integer, default=20, nullable=False)
    max_attempts: Mapped[int] = mapped_column(Integer, default=3, nullable=False)

    user = relationship("User", back_populates="assignments")
