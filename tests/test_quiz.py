from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.services.question_service import QuestionService
from terra_testing.services.quiz_service import QuizService
from terra_testing.services.schedule_service import ScheduleService
from terra_testing.services.user_service import UserService


def _create_user_with_role(name: str = "user"):
    with get_local_session() as session:
        role = Role(name=name)
        session.add(role)
        session.commit()
        session.refresh(role)
        return UserService().create_user("user01", "User", "User123!", role.id)


def _seed_questions() -> list:
    qservice = QuestionService()
    category = qservice.create_category("Охрана труда")
    qservice.create_question(
        category.id,
        "Вопрос 1",
        [
            {"text": "Верный", "is_correct": True},
            {"text": "Неверный", "is_correct": False},
        ],
    )
    qservice.create_question(
        category.id,
        "Вопрос 2",
        [
            {"text": "Неверный", "is_correct": False},
            {"text": "Верный", "is_correct": True},
        ],
    )
    return qservice.list_questions()


def test_calculate_result_pass():
    init_db()
    service = QuizService()
    result = service.calculate_result(
        [
            {"question_id": 1, "selected_answer_id": 1, "is_correct": True},
            {"question_id": 2, "selected_answer_id": 2, "is_correct": True},
            {"question_id": 3, "selected_answer_id": 3, "is_correct": False},
        ]
    )
    assert result["correct_answers"] == 2
    assert result["score_percent"] == 66
    assert result["status"] == "failed"


def test_complete_quiz_from_selection_saves_result():
    init_db()
    user = _create_user_with_role()
    questions = _seed_questions()
    service = QuizService()

    selected_answer_ids = {
        questions[0].id: next(answer.id for answer in questions[0].answers if answer.is_correct),
        questions[1].id: next(answer.id for answer in questions[1].answers if not answer.is_correct),
    }

    result = service.complete_quiz_from_selection(
        user_id=user.id,
        questions=questions,
        selected_answer_ids=selected_answer_ids,
        assignment_id=None,
    )

    assert result.total_questions == 2
    assert result.correct_answers == 1
    assert result.sync_state in {"pending", "failed", "synced"}


def test_assignment_attempt_limit_is_enforced():
    init_db()
    user = _create_user_with_role()
    questions = _seed_questions()
    assignment = ScheduleService().create_assignment(
        user_id=user.id,
        title="Проверка знаний",
        questions_count=2,
        max_attempts=1,
        due_at=None,
    )
    service = QuizService()
    selected_answer_ids = {question.id: question.answers[0].id for question in questions}

    service.complete_quiz_from_selection(
        user_id=user.id,
        questions=questions,
        selected_answer_ids=selected_answer_ids,
        assignment_id=assignment.id,
    )

    try:
        service.complete_quiz_from_selection(
            user_id=user.id,
            questions=questions,
            selected_answer_ids=selected_answer_ids,
            assignment_id=assignment.id,
        )
    except ValueError as exc:
        assert "лимит попыток" in str(exc)
    else:
        raise AssertionError("Expected ValueError for attempt limit")
