from __future__ import annotations

from terra_testing.config.settings import reset_settings_cache
from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session, reset_engines
from terra_testing.models.role import Role
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.repositories.sync_queue_repository import SyncQueueRepository
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
    result = ResultRepository().create_result(
        user_id=user.id,
        assignment_id=None,
        correct_answers=0,
        total_questions=1,
        score_percent=0,
        status="failed",
        answers=[{"question_id": question.id, "selected_answer_id": None, "is_correct": False}],
    )
    return result


def test_create_result_enqueues_sync_item():
    init_db()
    result = _seed_result()
    item = SyncQueueRepository().get_by_result_id(result.id)
    assert item is not None
    assert item.status == "pending"
    assert item.entity_type == "test_result"


def test_retry_result_updates_sync_queue(monkeypatch):
    init_db()
    result = _seed_result()
    service = SyncService()
    monkeypatch.setattr(service.sync_repository, "upsert_result_to_remote", lambda _result: None)

    summary = service.retry_result(result.id)

    item = SyncQueueRepository().get_by_result_id(result.id)
    assert summary["synced"] == 1
    assert item is not None
    assert item.status == "synced"


def test_retry_after_failed_remote_sync_succeeds(monkeypatch):
    monkeypatch.setenv("REMOTE_SYNC_ENABLED", "true")
    monkeypatch.setenv("REMOTE_DB_URL", "mysql+pymysql://user:pass@127.0.0.1:3306/db")
    reset_settings_cache()
    reset_engines()
    init_db()
    result = _seed_result()
    service = SyncService()

    state = {"attempt": 0}

    def _flaky_upsert(_result):
        state["attempt"] += 1
        if state["attempt"] == 1:
            raise RuntimeError("temporary mysql error")

    monkeypatch.setattr(service.sync_repository, "upsert_result_to_remote", _flaky_upsert)

    first = service.sync_after_test_completion(result.id)
    second = service.retry_result(result.id)

    updated_result = ResultRepository().get_result(result.id)
    item = SyncQueueRepository().get_by_result_id(result.id)

    assert first["failed"] == 1
    assert second["synced"] == 1
    assert updated_result is not None
    assert updated_result.sync_state == "synced"
    assert updated_result.sync_error is None
    assert item is not None
    assert item.status == "synced"
    assert item.retry_count == 1
    assert item.last_error is None
