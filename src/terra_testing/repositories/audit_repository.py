from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from terra_testing.db.session import get_local_session
from terra_testing.models.audit_log import AuditLog


class AuditRepository:
    def create(self, *, event_type: str, actor: str, message: str) -> AuditLog:
        with get_local_session() as session:
            entry = AuditLog(event_type=event_type, actor=actor, message=message)
            session.add(entry)
            session.commit()
            session.refresh(entry)
            return entry

    def list_recent(self, limit: int = 100) -> list[AuditLog]:
        with get_local_session() as session:
            stmt = select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit)
            return list(session.execute(stmt).scalars().all())

    @staticmethod
    def normalize_date_range(date_from: datetime | None, date_to: datetime | None) -> tuple[datetime | None, datetime | None]:
        normalized_from = date_from
        normalized_to = date_to
        if normalized_from is not None and normalized_from.tzinfo is None:
            normalized_from = normalized_from.replace(tzinfo=timezone.utc)
        if normalized_to is not None and normalized_to.tzinfo is None:
            normalized_to = normalized_to.replace(tzinfo=timezone.utc)
        return normalized_from, normalized_to

    def list_filtered(
        self,
        *,
        event_type: str | None = None,
        actor: str | None = None,
        day_from: datetime | None = None,
        day_to: datetime | None = None,
        limit: int = 500,
    ) -> list[AuditLog]:
        with get_local_session() as session:
            stmt = select(AuditLog)
            if event_type and event_type != "all":
                stmt = stmt.where(AuditLog.event_type == event_type)
            if actor:
                stmt = stmt.where(AuditLog.actor == actor)
            created_from, created_to = self.normalize_date_range(day_from, day_to)
            if created_to is not None:
                created_to = created_to + timedelta(days=1)
            if created_from is not None:
                stmt = stmt.where(AuditLog.created_at >= created_from)
            if created_to is not None:
                stmt = stmt.where(AuditLog.created_at < created_to)
            stmt = stmt.order_by(AuditLog.created_at.desc()).limit(limit)
            return list(session.execute(stmt).scalars().all())
