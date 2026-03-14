from datetime import timedelta

import pytest
from sqlalchemy import select

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.services.question_service import QuestionService
from terra_testing.services.quiz_service import QuizService
from terra_testing.services.schedule_service import ScheduleService
from terra_testing.services.user_service import UserService
from terra_testing.utils.time import utcnow


def _create_user(username: str, role_name: str = 'user'):
    with get_local_session() as session:
        role = session.scalar(select(Role).where(Role.name == role_name))
        if role is None:
            role = Role(name=role_name)
            session.add(role)
            session.commit()
            session.refresh(role)
    return UserService().create_user(username, username, 'User123!', role.id)


def _seed_questions() -> list:
    qservice = QuestionService()
    category = qservice.create_category('Охрана труда')
    qservice.create_question(
        category.id,
        'Вопрос 1',
        [
            {'text': 'Верный', 'is_correct': True},
            {'text': 'Неверный', 'is_correct': False},
        ],
    )
    qservice.create_question(
        category.id,
        'Вопрос 2',
        [
            {'text': 'Неверный', 'is_correct': False},
            {'text': 'Верный', 'is_correct': True},
        ],
    )
    return qservice.list_questions()


def test_start_quiz_rejects_completed_assignment():
    init_db()
    user = _create_user('user01')
    _seed_questions()
    assignment = ScheduleService().create_assignment(
        user_id=user.id,
        title='Проверка знаний',
        questions_count=2,
        max_attempts=1,
        due_at=None,
    )
    ScheduleService().mark_completed(assignment.id)

    with pytest.raises(ValueError):
        QuizService().start_quiz(user.id, assignment.id)


def test_start_quiz_rejects_foreign_assignment():
    init_db()
    user1 = _create_user('user01')
    user2 = _create_user('user02')
    _seed_questions()
    assignment = ScheduleService().create_assignment(
        user_id=user1.id,
        title='Проверка знаний',
        questions_count=2,
        max_attempts=1,
        due_at=None,
    )

    with pytest.raises(ValueError):
        QuizService().start_quiz(user2.id, assignment.id)


def test_start_quiz_rejects_overdue_assignment():
    init_db()
    user = _create_user('user01')
    _seed_questions()
    assignment = ScheduleService().create_assignment(
        user_id=user.id,
        title='Просроченный тест',
        questions_count=2,
        max_attempts=1,
        due_at=(utcnow() - timedelta(days=1)).replace(tzinfo=None),
    )

    with pytest.raises(ValueError):
        QuizService().start_quiz(user.id, assignment.id)
