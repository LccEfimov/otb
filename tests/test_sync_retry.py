from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.repositories.audit_repository import AuditRepository
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.services.question_service import QuestionService
from terra_testing.services.user_service import UserService
from terra_testing.sync.sync_service import SyncService


def _seed_result():
    with get_local_session() as session:
        role = Role(name="user")
        session.add(role)
        session.commit()
        session.refresh(role)
    user = UserService().create_user("user01", "User", "User123!", role.id)
    qservice = QuestionService()
    category = qservice.create_category("Категория")
    question = qservice.create_question(
        category.id,
        "Вопрос",
        [
            {"text": "Да", "is_correct": True},
            {"text": "Нет", "is_correct": False},
        ],
    )
    return ResultRepository().create_result(
        user_id=user.id,
        assignment_id=None,
        correct_answers=0,
        total_questions=1,
        score_percent=0,
        status="failed",
        answers=[{"question_id": question.id, "selected_answer_id": None, "is_correct": False}],
    )


def test_retry_single_result_marks_it_synced(monkeypatch):
    init_db()
    result = _seed_result()
    service = SyncService()
    monkeypatch.setattr(service, "_probe_remote", lambda: None)
    summary = service.retry_result(result.id)
    updated = ResultRepository().get_result(result.id)
    assert summary["synced"] == 1
    assert updated is not None
    assert updated.sync_state == "synced"


def test_retry_single_result_creates_audit_event(monkeypatch):
    init_db()
    result = _seed_result()
    service = SyncService()
    monkeypatch.setattr(service, "_probe_remote", lambda: None)
    service.retry_result(result.id, actor="admin")
    logs = AuditRepository().list_recent(limit=10)
    assert any(log.event_type == "sync_retry_result" for log in logs)


def test_retry_single_result_respects_retry_limit(monkeypatch):
    monkeypatch.setenv("SYNC_RETRY_LIMIT", "2")
    init_db()
    result = _seed_result()

    service = SyncService()
    queue_item = service.sync_queue_repository.enqueue_result(result.id)
    service.sync_queue_repository.mark_failed(queue_item.id, "network error")
    service.sync_queue_repository.mark_failed(queue_item.id, "network error")

    called = {"probe": False}

    def _probe_remote():
        called["probe"] = True

    monkeypatch.setattr(service, "_probe_remote", _probe_remote)

    summary = service.retry_result(result.id, actor="admin")
    updated_item = service.sync_queue_repository.get_by_result_id(result.id)

    assert summary == {"synced": 0, "failed": 1, "total": 1, "error": "retry limit exceeded"}
    assert called["probe"] is False
    assert updated_item is not None
    assert updated_item.status == "exhausted"
    assert updated_item.retry_count == 2
    assert updated_item.last_error == "retry limit exceeded"
