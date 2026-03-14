from __future__ import annotations

from terra_testing.config.settings import reset_settings_cache
from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session, reset_engines
from terra_testing.models.role import Role
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.services.question_service import QuestionService
from terra_testing.services.user_service import UserService
from terra_testing.sync.sync_service import SyncService


def test_sync_skips_when_disabled():
    init_db()
    service = SyncService()
    service.sync_after_login(1)  # should not raise


def test_failed_remote_sync_marks_result_failed(monkeypatch):
    monkeypatch.setenv('REMOTE_SYNC_ENABLED', 'true')
    monkeypatch.setenv('REMOTE_DB_URL', 'mysql+pymysql://user:pass@127.0.0.1:3306/db')
    reset_settings_cache()
    reset_engines()
    init_db()

    with get_local_session() as session:
        role = Role(name='user')
        session.add(role)
        session.commit()
        session.refresh(role)
    user = UserService().create_user('user01', 'User', 'User123!', role.id)

    qservice = QuestionService()
    category = qservice.create_category('Категория')
    question = qservice.create_question(
        category.id,
        'Вопрос',
        [
            {'text': 'Да', 'is_correct': True},
            {'text': 'Нет', 'is_correct': False},
        ],
    )

    correct_answer = next(answer for answer in question.answers if answer.is_correct)
    result = ResultRepository().create_result(
        user_id=user.id,
        assignment_id=None,
        correct_answers=1,
        total_questions=1,
        score_percent=100,
        status='passed',
        answers=[{'question_id': question.id, 'selected_answer_id': correct_answer.id, 'is_correct': True}],
    )

    service = SyncService()
    service.sync_after_test_completion(result.id)

    updated = ResultRepository().get_result(result.id)
    assert updated is not None
    assert updated.sync_state == 'failed'
    assert updated.retry_count == 1


def test_retry_pending_sync_marks_rows_synced(monkeypatch):
    monkeypatch.setenv('REMOTE_SYNC_ENABLED', 'true')
    monkeypatch.setenv('REMOTE_DB_URL', 'mysql+pymysql://user:pass@127.0.0.1:3306/db')
    reset_settings_cache()
    reset_engines()
    init_db()

    with get_local_session() as session:
        role = Role(name='user')
        session.add(role)
        session.commit()
        session.refresh(role)
    user = UserService().create_user('user01', 'User', 'User123!', role.id)

    qservice = QuestionService()
    category = qservice.create_category('Категория')
    question = qservice.create_question(
        category.id,
        'Вопрос',
        [
            {'text': 'Да', 'is_correct': True},
            {'text': 'Нет', 'is_correct': False},
        ],
    )
    result = ResultRepository().create_result(
        user_id=user.id,
        assignment_id=None,
        correct_answers=0,
        total_questions=1,
        score_percent=0,
        status='failed',
        answers=[{'question_id': question.id, 'selected_answer_id': None, 'is_correct': False}],
    )

    service = SyncService()
    monkeypatch.setattr(service, '_probe_remote', lambda: None)
    summary = service.retry_pending_sync()

    updated = ResultRepository().get_result(result.id)
    assert summary['synced'] == 1
    assert updated is not None
    assert updated.sync_state == 'synced'


def test_sync_after_login_returns_disabled_by_flag(monkeypatch):
    monkeypatch.setenv('REMOTE_SYNC_ENABLED', 'true')
    monkeypatch.setenv('REMOTE_DB_URL', 'mysql+pymysql://user:pass@127.0.0.1:3306/db')
    monkeypatch.setenv('SYNC_AFTER_LOGIN', 'false')
    reset_settings_cache()
    reset_engines()
    init_db()

    service = SyncService()
    summary = service.sync_after_login(1)

    assert summary == {'synced': 0, 'failed': 0, 'total': 0, 'reason': 'disabled_by_flag'}


def test_sync_after_test_completion_returns_disabled_by_flag(monkeypatch):
    monkeypatch.setenv('REMOTE_SYNC_ENABLED', 'true')
    monkeypatch.setenv('REMOTE_DB_URL', 'mysql+pymysql://user:pass@127.0.0.1:3306/db')
    monkeypatch.setenv('SYNC_AFTER_TEST_COMPLETION', 'false')
    reset_settings_cache()
    reset_engines()
    init_db()

    with get_local_session() as session:
        role = Role(name='user')
        session.add(role)
        session.commit()
        session.refresh(role)
    user = UserService().create_user('user01', 'User', 'User123!', role.id)

    qservice = QuestionService()
    category = qservice.create_category('Категория')
    question = qservice.create_question(
        category.id,
        'Вопрос',
        [
            {'text': 'Да', 'is_correct': True},
            {'text': 'Нет', 'is_correct': False},
        ],
    )

    correct_answer = next(answer for answer in question.answers if answer.is_correct)
    result = ResultRepository().create_result(
        user_id=user.id,
        assignment_id=None,
        correct_answers=1,
        total_questions=1,
        score_percent=100,
        status='passed',
        answers=[{'question_id': question.id, 'selected_answer_id': correct_answer.id, 'is_correct': True}],
    )

    service = SyncService()
    summary = service.sync_after_test_completion(result.id)

    assert summary == {'synced': 0, 'failed': 0, 'total': 1, 'reason': 'disabled_by_flag'}
