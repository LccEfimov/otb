from __future__ import annotations

import json

from sqlalchemy import func, select

from terra_testing.db.session import get_local_session
from terra_testing.models.sync_queue import SyncQueueItem
from terra_testing.utils.time import utcnow


class SyncQueueRepository:
    def enqueue_result(self, result_id: int, payload: dict | None = None) -> SyncQueueItem:
        with get_local_session() as session:
            existing = session.execute(
                select(SyncQueueItem).where(
                    SyncQueueItem.entity_type == "test_result",
                    SyncQueueItem.entity_id == result_id,
                )
            ).scalar_one_or_none()
            if existing is not None:
                return existing

            item = SyncQueueItem(
                entity_type="test_result",
                entity_id=result_id,
                status="pending",
                payload_snapshot=json.dumps(payload or {}, ensure_ascii=False),
            )
            session.add(item)
            session.commit()
            session.refresh(item)
            return item

    def get_by_result_id(self, result_id: int) -> SyncQueueItem | None:
        with get_local_session() as session:
            stmt = select(SyncQueueItem).where(
                SyncQueueItem.entity_type == "test_result",
                SyncQueueItem.entity_id == result_id,
            )
            return session.execute(stmt).scalar_one_or_none()

    def list_items(self, *, status: str | None = None) -> list[SyncQueueItem]:
        with get_local_session() as session:
            stmt = select(SyncQueueItem)
            if status and status != "all":
                stmt = stmt.where(SyncQueueItem.status == status)
            stmt = stmt.order_by(SyncQueueItem.created_at.desc(), SyncQueueItem.id.desc())
            return list(session.execute(stmt).scalars().all())

    def list_pending_like(self) -> list[SyncQueueItem]:
        with get_local_session() as session:
            stmt = (
                select(SyncQueueItem)
                .where(SyncQueueItem.status.in_(["pending", "failed"]))
                .order_by(SyncQueueItem.created_at.desc(), SyncQueueItem.id.desc())
            )
            return list(session.execute(stmt).scalars().all())

    def mark_processing(self, item_id: int) -> None:
        with get_local_session() as session:
            item = session.get(SyncQueueItem, item_id)
            if item is None:
                return
            item.status = "processing"
            item.last_attempt_at = utcnow()
            session.commit()

    def mark_synced(self, item_id: int) -> None:
        with get_local_session() as session:
            item = session.get(SyncQueueItem, item_id)
            if item is None:
                return
            item.status = "synced"
            item.last_error = None
            item.last_attempt_at = utcnow()
            session.commit()

    def mark_failed(self, item_id: int, error: str) -> None:
        with get_local_session() as session:
            item = session.get(SyncQueueItem, item_id)
            if item is None:
                return
            item.status = "failed"
            item.last_error = error[:1000]
            item.last_attempt_at = utcnow()
            item.retry_count += 1
            session.commit()

    def count_by_status(self, status: str) -> int:
        with get_local_session() as session:
            stmt = select(func.count(SyncQueueItem.id)).where(SyncQueueItem.status == status)
            return int(session.execute(stmt).scalar_one())
