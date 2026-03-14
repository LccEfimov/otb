from __future__ import annotations

from datetime import datetime

from terra_testing.repositories.audit_repository import AuditRepository


class AuditService:
    def __init__(self) -> None:
        self.repository = AuditRepository()

    def log(self, event_type: str, actor: str, message: str):
        return self.repository.create(event_type=event_type, actor=actor, message=message)

    def list_recent(self, limit: int = 100):
        return self.repository.list_recent(limit=limit)

    def list_filtered(
        self,
        *,
        event_type: str | None = None,
        actor: str | None = None,
        day_from: datetime | None = None,
        day_to: datetime | None = None,
        limit: int = 500,
    ):
        return self.repository.list_filtered(
            event_type=event_type,
            actor=actor,
            day_from=day_from,
            day_to=day_to,
            limit=limit,
        )
