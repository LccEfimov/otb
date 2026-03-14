from __future__ import annotations

import pytest

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


def test_create_question_rejects_less_than_two_non_empty_answers():
    init_db()
    service = QuestionService()
    category = service.create_category("Промышленная безопасность")

    with pytest.raises(ValueError, match="минимум два непустых"):
        service.create_question(
            category.id,
            "Вопрос",
            [
                {"text": "  ", "is_correct": False},
                {"text": "Ответ 1", "is_correct": True},
            ],
        )


def test_create_question_rejects_answers_without_correct_option():
    init_db()
    service = QuestionService()
    category = service.create_category("Промышленная безопасность")

    with pytest.raises(ValueError, match="хотя бы один правильный"):
        service.create_question(
            category.id,
            "Вопрос",
            [
                {"text": "Ответ 1", "is_correct": False},
                {"text": "Ответ 2", "is_correct": False},
            ],
        )


def test_update_question_rejects_duplicate_answer_texts():
    init_db()
    service = QuestionService()
    category = service.create_category("Охрана труда")
    question = service.create_question(
        category.id,
        "Исходный вопрос",
        [
            {"text": "Да", "is_correct": True},
            {"text": "Нет", "is_correct": False},
        ],
    )

    with pytest.raises(ValueError, match="не должны полностью дублироваться"):
        service.update_question(
            question.id,
            category.id,
            "Обновленный вопрос",
            [
                {"text": "Вариант", "is_correct": True},
                {"text": " вариант ", "is_correct": False},
            ],
        )
