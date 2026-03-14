from __future__ import annotations

from terra_testing.repositories.question_repository import QuestionRepository


class QuestionService:
    def __init__(self) -> None:
        self.repository = QuestionRepository()

    def list_questions(self):
        return self.repository.list_questions()

    def count_questions(self) -> int:
        return self.repository.count_questions()

    def list_categories(self):
        return self.repository.list_categories()

    def get_question(self, question_id: int):
        return self.repository.get_question(question_id)

    def create_category(self, name: str):
        return self.repository.create_category(name=name)

    def create_question(self, category_id: int, text: str, answers: list[dict]):
        self._validate_answers(answers)
        return self.repository.create_question(category_id=category_id, text=text, answers=answers)

    def update_question(self, question_id: int, category_id: int, text: str, answers: list[dict]):
        self._validate_answers(answers)
        return self.repository.update_question(question_id=question_id, category_id=category_id, text=text, answers=answers)

    def set_question_active(self, question_id: int, is_active: bool):
        return self.repository.set_question_active(question_id, is_active)

    @staticmethod
    def _validate_answers(answers: list[dict]) -> None:
        non_empty_answers = [answer for answer in answers if str(answer.get("text", "")).strip()]
        if len(non_empty_answers) < 2:
            raise ValueError("Нужно указать минимум два непустых варианта ответа.")

        if not any(answer.get("is_correct", False) for answer in non_empty_answers):
            raise ValueError("Нужно отметить хотя бы один правильный ответ.")

        normalized_texts = [str(answer.get("text", "")).strip().casefold() for answer in non_empty_answers]
        if len(set(normalized_texts)) != len(normalized_texts):
            raise ValueError("Тексты ответов не должны полностью дублироваться.")
