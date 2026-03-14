from __future__ import annotations

import json

from sqlalchemy import select, text
from sqlalchemy.orm import joinedload

from terra_testing.db.session import get_local_session
from terra_testing.db.session import get_remote_engine
from terra_testing.models.test_result import TestResult
from terra_testing.utils.time import utcnow


class SyncRepository:
    def get_result_for_remote(self, result_id: int) -> TestResult | None:
        with get_local_session() as session:
            stmt = (
                select(TestResult)
                .options(joinedload(TestResult.answers), joinedload(TestResult.user))
                .where(TestResult.id == result_id)
            )
            return session.execute(stmt).unique().scalar_one_or_none()

    def upsert_result_to_remote(self, result: TestResult) -> None:
        engine = get_remote_engine()
        if engine is None:
            raise RuntimeError("Remote engine is not configured")

        payload = {
            "id": result.id,
            "user_id": result.user_id,
            "assignment_id": result.assignment_id,
            "correct_answers": result.correct_answers,
            "total_questions": result.total_questions,
            "score_percent": result.score_percent,
            "status": result.status,
            "completed_at": result.completed_at,
            "answers_json": json.dumps(
                [
                    {
                        "id": answer.id,
                        "question_id": answer.question_id,
                        "selected_answer_id": answer.selected_answer_id,
                        "is_correct": answer.is_correct,
                    }
                    for answer in result.answers
                ],
                ensure_ascii=False,
            ),
            "updated_at": utcnow(),
        }

        with engine.begin() as connection:
            exists = connection.execute(
                text("SELECT 1 FROM remote_test_results WHERE id = :id"),
                {"id": result.id},
            ).scalar_one_or_none()

            if exists:
                connection.execute(
                    text(
                        """
                        UPDATE remote_test_results
                        SET user_id = :user_id,
                            assignment_id = :assignment_id,
                            correct_answers = :correct_answers,
                            total_questions = :total_questions,
                            score_percent = :score_percent,
                            status = :status,
                            completed_at = :completed_at,
                            answers_json = :answers_json,
                            updated_at = :updated_at
                        WHERE id = :id
                        """
                    ),
                    payload,
                )
                return

            connection.execute(
                text(
                    """
                    INSERT INTO remote_test_results (
                        id,
                        user_id,
                        assignment_id,
                        correct_answers,
                        total_questions,
                        score_percent,
                        status,
                        completed_at,
                        answers_json,
                        updated_at
                    ) VALUES (
                        :id,
                        :user_id,
                        :assignment_id,
                        :correct_answers,
                        :total_questions,
                        :score_percent,
                        :status,
                        :completed_at,
                        :answers_json,
                        :updated_at
                    )
                    """
                ),
                payload,
            )

    def mark_synced(self, result_id: int) -> None:
        with get_local_session() as session:
            result = session.get(TestResult, result_id)
            if result is None:
                return
            result.sync_state = "synced"
            result.sync_error = None
            result.last_synced_at = utcnow()
            session.commit()

    def mark_failed(self, result_id: int, error: str) -> None:
        with get_local_session() as session:
            result = session.get(TestResult, result_id)
            if result is None:
                return
            result.sync_state = "failed"
            result.sync_error = error[:1000]
            result.retry_count += 1
            session.commit()
