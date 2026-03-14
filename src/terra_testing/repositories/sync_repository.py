from __future__ import annotations

from terra_testing.db.session import get_local_session
from terra_testing.models.test_result import TestResult
from terra_testing.utils.time import utcnow


class SyncRepository:
    def mark_synced(self, result_id: int) -> None:
        with get_local_session() as session:
            result = session.get(TestResult, result_id)
            if result is None:
                return
            result.sync_state = "synced"
            result.sync_error = None
            result.last_synced_at = utcnow()
            session.commit()

    def mark_failed(self, result_id: int, error: str) -> None:
        with get_local_session() as session:
            result = session.get(TestResult, result_id)
            if result is None:
                return
            result.sync_state = "failed"
            result.sync_error = error[:1000]
            result.retry_count += 1
            session.commit()
