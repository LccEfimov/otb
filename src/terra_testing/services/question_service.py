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
        return self.repository.create_question(category_id=category_id, text=text, answers=answers)

    def update_question(self, question_id: int, category_id: int, text: str, answers: list[dict]):
        return self.repository.update_question(question_id=question_id, category_id=category_id, text=text, answers=answers)

    def set_question_active(self, question_id: int, is_active: bool):
        return self.repository.set_question_active(question_id, is_active)
