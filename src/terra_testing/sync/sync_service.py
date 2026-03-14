from __future__ import annotations

import logging

from sqlalchemy import text

from terra_testing.config.settings import get_settings
from terra_testing.db.session import get_remote_engine
from terra_testing.repositories.sync_queue_repository import SyncQueueRepository
from terra_testing.repositories.sync_repository import SyncRepository
from terra_testing.services.audit_service import AuditService

logger = logging.getLogger(__name__)


class SyncService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.sync_repository = SyncRepository()
        self.sync_queue_repository = SyncQueueRepository()
        self.audit_service = AuditService()

    def _can_sync_for_event(self, *, enabled: bool) -> tuple[bool, str | None]:
        if not enabled:
            return False, "disabled_by_flag"
        if not self.settings.remote_sync_enabled or not self.settings.remote_db_url:
            return False, "disabled"
        return True, None

    def _probe_remote(self) -> None:
        engine = get_remote_engine()
        if engine is None:
            raise RuntimeError("Remote engine is not configured")
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))

    def _sync_result(self, result_id: int) -> bool:
        queue_item = self.sync_queue_repository.get_by_result_id(result_id)
        if queue_item is not None:
            self.sync_queue_repository.mark_processing(queue_item.id)

        self._probe_remote()

        self.sync_repository.mark_synced(result_id)
        if queue_item is not None:
            self.sync_queue_repository.mark_synced(queue_item.id)
        return True

    def sync_after_login(self, user_id: int) -> dict:
        can_sync, reason = self._can_sync_for_event(enabled=self.settings.sync_after_login)
        if not can_sync:
            logger.info("Remote sync skipped after login: %s", reason)
            return {"synced": 0, "failed": 0, "total": 0, "reason": reason}
        logger.info("Starting post-login sync for user_id=%s", user_id)
        self._probe_remote()
        return self.retry_pending_sync(actor=f"user:{user_id}", event_type="sync_retry_after_login")

    def sync_after_test_completion(self, result_id: int) -> dict:
        self.sync_queue_repository.enqueue_result(result_id)
        can_sync, reason = self._can_sync_for_event(enabled=self.settings.sync_after_test_completion)
        if not can_sync:
            logger.info("Remote sync skipped after test completion: %s", reason)
            return {"synced": 0, "failed": 0, "total": 1, "reason": reason}

        logger.info("Starting post-test sync for result_id=%s", result_id)
        try:
            self._sync_result(result_id)
            self.audit_service.log("sync_result_success", "system", f"Синхронизирован result #{result_id}")
            return {"synced": 1, "failed": 0, "total": 1}
        except Exception as exc:
            logger.warning("Post-test sync failed for result_id=%s: %s", result_id, exc)
            self.sync_repository.mark_failed(result_id, str(exc))
            queue_item = self.sync_queue_repository.get_by_result_id(result_id)
            if queue_item is not None:
                self.sync_queue_repository.mark_failed(queue_item.id, str(exc))
            self.audit_service.log("sync_result_failed", "system", f"Ошибка синхронизации result #{result_id}: {exc}")
            return {"synced": 0, "failed": 1, "total": 1, "error": str(exc)}

    def retry_result(self, result_id: int, *, actor: str = "admin") -> dict:
        retry_limit = self.settings.sync_retry_limit
        queue_item = self.sync_queue_repository.enqueue_result(result_id)

        if queue_item.retry_count >= retry_limit:
            reason = "retry limit exceeded"
            self.sync_queue_repository.mark_exhausted(queue_item.id, reason)
            self.audit_service.log("sync_retry_result_exhausted", actor, f"Лимит повторов исчерпан для result #{result_id}")
            return {"synced": 0, "failed": 1, "total": 1, "error": reason}

        try:
            self._sync_result(result_id)
            self.audit_service.log("sync_retry_result", actor, f"Повторная синхронизация result #{result_id} успешна")
            return {"synced": 1, "failed": 0, "total": 1}
        except Exception as exc:
            self.sync_repository.mark_failed(result_id, str(exc))
            queue_item = self.sync_queue_repository.get_by_result_id(result_id)
            if queue_item is not None:
                self.sync_queue_repository.mark_failed(queue_item.id, str(exc))
                if queue_item.retry_count + 1 >= retry_limit:
                    self.sync_queue_repository.mark_exhausted(queue_item.id, "retry limit exceeded")
            self.audit_service.log("sync_retry_result_failed", actor, f"Ошибка повторной синхронизации result #{result_id}: {exc}")
            return {"synced": 0, "failed": 1, "total": 1, "error": str(exc)}

    def retry_pending_sync(self, *, actor: str = "admin", event_type: str = "sync_retry_batch") -> dict:
        items = self.sync_queue_repository.list_retryable_pending_like(retry_limit=self.settings.sync_retry_limit)
        synced = 0
        failed = 0

        for item in items:
            if item.retry_count >= self.settings.sync_retry_limit:
                self.sync_queue_repository.mark_exhausted(item.id, "retry limit exceeded")
                failed += 1
                continue

            try:
                if item.entity_type == "test_result":
                    self._sync_result(item.entity_id)
                    synced += 1
                else:
                    self.sync_queue_repository.mark_synced(item.id)
                    synced += 1
            except Exception as exc:
                self.sync_queue_repository.mark_failed(item.id, str(exc))
                if item.retry_count + 1 >= self.settings.sync_retry_limit:
                    self.sync_queue_repository.mark_exhausted(item.id, "retry limit exceeded")
                if item.entity_type == "test_result":
                    self.sync_repository.mark_failed(item.entity_id, str(exc))
                failed += 1

        total = len(items)
        self.audit_service.log(event_type, actor, f"batch retry: synced={synced}, failed={failed}, total={total}")
        return {"synced": synced, "failed": failed, "total": total}
