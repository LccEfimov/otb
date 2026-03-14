from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.services.audit_service import AuditService


def test_audit_log_is_created():
    init_db()
    service = AuditService()
    entry = service.log('user_created', 'admin', 'Создан тестовый пользователь')
    items = service.list_recent()
    assert entry.id is not None
    assert items[0].event_type == 'user_created'
