from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import joinedload, selectinload

from terra_testing.db.session import get_local_session
from terra_testing.models.answer import Answer
from terra_testing.models.question import Question, QuestionCategory


class QuestionRepository:
    def list_questions(self) -> list[Question]:
        with get_local_session() as session:
            stmt = (
                select(Question)
                .options(joinedload(Question.category), selectinload(Question.answers))
                .order_by(Question.id.asc())
            )
            return list(session.execute(stmt).scalars().unique().all())

    def count_questions(self) -> int:
        with get_local_session() as session:
            stmt = select(func.count(Question.id)).where(Question.is_active.is_(True))
            return int(session.execute(stmt).scalar_one())

    def list_categories(self) -> list[QuestionCategory]:
        with get_local_session() as session:
            stmt = select(QuestionCategory).order_by(QuestionCategory.name.asc())
            return list(session.execute(stmt).scalars().all())

    def get_question(self, question_id: int) -> Question | None:
        with get_local_session() as session:
            stmt = (
                select(Question)
                .options(joinedload(Question.category), selectinload(Question.answers))
                .where(Question.id == question_id)
            )
            return session.execute(stmt).scalars().unique().one_or_none()

    def random_questions(self, limit: int) -> list[Question]:
        with get_local_session() as session:
            stmt = (
                select(Question)
                .options(joinedload(Question.category), selectinload(Question.answers))
                .where(Question.is_active.is_(True))
                .order_by(func.random())
                .limit(limit)
            )
            return list(session.execute(stmt).scalars().unique().all())

    def get_questions_by_ids(self, question_ids: list[int]) -> list[Question]:
        if not question_ids:
            return []
        with get_local_session() as session:
            stmt = (
                select(Question)
                .options(joinedload(Question.category), selectinload(Question.answers))
                .where(Question.id.in_(question_ids))
            )
            questions = list(session.execute(stmt).scalars().unique().all())
            by_id = {question.id: question for question in questions}
            return [by_id[qid] for qid in question_ids if qid in by_id]

    def get_answer_map(self, question_ids: list[int]) -> dict[int, list[Answer]]:
        questions = self.get_questions_by_ids(question_ids)
        return {question.id: list(question.answers) for question in questions}

    def create_category(self, name: str) -> QuestionCategory:
        with get_local_session() as session:
            category = QuestionCategory(name=name)
            session.add(category)
            session.commit()
            session.refresh(category)
            return category

    def create_question(self, *, category_id: int, text: str, answers: list[dict]) -> Question:
        with get_local_session() as session:
            question = Question(category_id=category_id, text=text)
            session.add(question)
            session.flush()
            question_id = question.id
            for answer in answers:
                session.add(
                    Answer(
                        question_id=question.id,
                        text=answer["text"],
                        is_correct=answer.get("is_correct", False),
                    )
                )
            session.commit()
        return self.get_question(question_id)

    def update_question(self, *, question_id: int, category_id: int, text: str, answers: list[dict]) -> Question | None:
        with get_local_session() as session:
            question = session.get(Question, question_id)
            if question is None:
                return None
            question.category_id = category_id
            question.text = text
            session.query(Answer).filter(Answer.question_id == question_id).delete()
            session.flush()
            for answer in answers:
                session.add(
                    Answer(
                        question_id=question_id,
                        text=answer["text"],
                        is_correct=answer.get("is_correct", False),
                    )
                )
            session.commit()
        return self.get_question(question_id)

    def set_question_active(self, question_id: int, is_active: bool) -> Question | None:
        with get_local_session() as session:
            question = session.get(Question, question_id)
            if question is None:
                return None
            question.is_active = is_active
            session.commit()
        return self.get_question(question_id)
