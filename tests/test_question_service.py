from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.services.question_service import QuestionService


def test_question_can_be_updated_with_new_answers():
    init_db()
    service = QuestionService()
    category = service.create_category("Охрана труда")
    question = service.create_question(
        category.id,
        "Старый вопрос",
        [
            {"text": "Да", "is_correct": True},
            {"text": "Нет", "is_correct": False},
        ],
    )

    updated = service.update_question(
        question.id,
        category.id,
        "Новый вопрос",
        [
            {"text": "Первый", "is_correct": False},
            {"text": "Второй", "is_correct": True},
            {"text": "Третий", "is_correct": False},
        ],
    )

    assert updated is not None
    assert updated.text == "Новый вопрос"
    assert len(updated.answers) == 3
    assert sum(1 for answer in updated.answers if answer.is_correct) == 1
