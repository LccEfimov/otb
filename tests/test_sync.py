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


def _seed_result() -> int:
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

    correct_answer = next(answer for answer in question.answers if answer.is_correct)
    result = ResultRepository().create_result(
        user_id=user.id,
        assignment_id=None,
        correct_answers=1,
        total_questions=1,
        score_percent=100,
        status="passed",
        answers=[{"question_id": question.id, "selected_answer_id": correct_answer.id, "is_correct": True}],
    )
    return result.id


def test_sync_skips_when_disabled():
    init_db()
    service = SyncService()
    service.sync_after_login(1)


def test_successful_remote_sync_marks_result_and_queue_synced(monkeypatch):
    monkeypatch.setenv("REMOTE_SYNC_ENABLED", "true")
    monkeypatch.setenv("REMOTE_DB_URL", "mysql+pymysql://user:pass@127.0.0.1:3306/db")
    reset_settings_cache()
    reset_engines()
    init_db()
    result_id = _seed_result()

    service = SyncService()
    calls = {"upsert": 0}

    def _upsert_stub(result):
        calls["upsert"] += 1
        assert result.id == result_id

    monkeypatch.setattr(service.sync_repository, "upsert_result_to_remote", _upsert_stub)

    summary = service.sync_after_test_completion(result_id)

    updated_result = ResultRepository().get_result(result_id)
    queue_item = SyncQueueRepository().get_by_result_id(result_id)

    assert summary == {"synced": 1, "failed": 0, "total": 1}
    assert calls["upsert"] == 1
    assert updated_result is not None
    assert updated_result.sync_state == "synced"
    assert updated_result.sync_error is None
    assert queue_item is not None
    assert queue_item.status == "synced"
    assert queue_item.last_error is None


def test_failed_remote_sync_marks_result_failed_and_saves_error(monkeypatch):
    monkeypatch.setenv("REMOTE_SYNC_ENABLED", "true")
    monkeypatch.setenv("REMOTE_DB_URL", "mysql+pymysql://user:pass@127.0.0.1:3306/db")
    reset_settings_cache()
    reset_engines()
    init_db()
    result_id = _seed_result()

    service = SyncService()

    def _raise_remote_error(_result):
        raise RuntimeError("remote write failed")

    monkeypatch.setattr(service.sync_repository, "upsert_result_to_remote", _raise_remote_error)

    summary = service.sync_after_test_completion(result_id)

    updated_result = ResultRepository().get_result(result_id)
    queue_item = SyncQueueRepository().get_by_result_id(result_id)

    assert summary == {"synced": 0, "failed": 1, "total": 1, "error": "remote write failed"}
    assert updated_result is not None
    assert updated_result.sync_state == "failed"
    assert updated_result.sync_error == "remote write failed"
    assert updated_result.retry_count == 1
    assert queue_item is not None
    assert queue_item.status == "failed"
    assert queue_item.last_error == "remote write failed"


def test_sync_after_login_returns_disabled_by_flag(monkeypatch):
    monkeypatch.setenv("REMOTE_SYNC_ENABLED", "true")
    monkeypatch.setenv("REMOTE_DB_URL", "mysql+pymysql://user:pass@127.0.0.1:3306/db")
    monkeypatch.setenv("SYNC_AFTER_LOGIN", "false")
    reset_settings_cache()
    reset_engines()
    init_db()

    service = SyncService()
    summary = service.sync_after_login(1)

    assert summary == {"synced": 0, "failed": 0, "total": 0, "reason": "disabled_by_flag"}
