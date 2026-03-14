from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select

from terra_testing.db.session import get_local_session
from terra_testing.models.sync_queue import SyncQueueItem
from terra_testing.models.test_result import TestAnswer, TestResult


class ResultRepository:
    def create_result(
        self,
        *,
        user_id: int,
        assignment_id: int | None,
        correct_answers: int,
        total_questions: int,
        score_percent: int,
        status: str,
        answers: list[dict],
    ) -> TestResult:
        with get_local_session() as session:
            result = TestResult(
                user_id=user_id,
                assignment_id=assignment_id,
                correct_answers=correct_answers,
                total_questions=total_questions,
                score_percent=score_percent,
                status=status,
            )
            session.add(result)
            session.flush()
            result_id = result.id

            for item in answers:
                session.add(
                    TestAnswer(
                        result_id=result.id,
                        question_id=item["question_id"],
                        selected_answer_id=item.get("selected_answer_id"),
                        is_correct=item["is_correct"],
                    )
                )

            session.add(
                SyncQueueItem(
                    entity_type="test_result",
                    entity_id=result.id,
                    status="pending",
                    payload_snapshot=None,
                )
            )

            session.commit()
        return self.get_result(result_id)

    def get_result(self, result_id: int) -> TestResult | None:
        with get_local_session() as session:
            return session.get(TestResult, result_id)

    def count_attempts_for_assignment(self, user_id: int, assignment_id: int | None) -> int:
        if assignment_id is None:
            return 0
        with get_local_session() as session:
            stmt = select(func.count(TestResult.id)).where(
                TestResult.user_id == user_id,
                TestResult.assignment_id == assignment_id,
            )
            return int(session.execute(stmt).scalar_one())

    def count_pending_sync(self) -> int:
        with get_local_session() as session:
            stmt = select(func.count(TestResult.id)).where(TestResult.sync_state == "pending")
            return int(session.execute(stmt).scalar_one())

    def count_failed_sync(self) -> int:
        with get_local_session() as session:
            stmt = select(func.count(TestResult.id)).where(TestResult.sync_state == "failed")
            return int(session.execute(stmt).scalar_one())

    def count_synced(self) -> int:
        with get_local_session() as session:
            stmt = select(func.count(TestResult.id)).where(TestResult.sync_state == "synced")
            return int(session.execute(stmt).scalar_one())

    def list_results_for_user(self, user_id: int) -> list[TestResult]:
        with get_local_session() as session:
            stmt = select(TestResult).where(TestResult.user_id == user_id).order_by(TestResult.completed_at.desc())
            return list(session.execute(stmt).scalars().all())

    def list_all_results(self) -> list[TestResult]:
        with get_local_session() as session:
            stmt = select(TestResult).order_by(TestResult.completed_at.desc())
            return list(session.execute(stmt).scalars().all())

    def list_pending_sync(self) -> list[TestResult]:
        with get_local_session() as session:
            stmt = (
                select(TestResult)
                .where(TestResult.sync_state.in_(["pending", "failed"]))
                .order_by(TestResult.completed_at.desc())
            )
            return list(session.execute(stmt).scalars().all())

    def list_filtered_results(
        self,
        *,
        user_id: int | None = None,
        status: str | None = None,
        sync_state: str | None = None,
        completed_from: datetime | None = None,
        completed_to: datetime | None = None,
    ) -> list[TestResult]:
        with get_local_session() as session:
            stmt = select(TestResult)
            if user_id is not None:
                stmt = stmt.where(TestResult.user_id == user_id)
            if status and status != "all":
                stmt = stmt.where(TestResult.status == status)
            if sync_state and sync_state != "all":
                stmt = stmt.where(TestResult.sync_state == sync_state)
            if completed_from is not None:
                stmt = stmt.where(TestResult.completed_at >= completed_from)
            if completed_to is not None:
                stmt = stmt.where(TestResult.completed_at < completed_to)
            stmt = stmt.order_by(TestResult.completed_at.desc())
            return list(session.execute(stmt).scalars().all())

    @staticmethod
    def normalize_date_range(date_from: datetime | None, date_to: datetime | None) -> tuple[datetime | None, datetime | None]:
        normalized_from = date_from
        normalized_to = date_to
        if normalized_from is not None and normalized_from.tzinfo is None:
            normalized_from = normalized_from.replace(tzinfo=timezone.utc)
        if normalized_to is not None and normalized_to.tzinfo is None:
            normalized_to = normalized_to.replace(tzinfo=timezone.utc)
        return normalized_from, normalized_to

    def list_filtered_results_by_day(
        self,
        *,
        user_id: int | None = None,
        status: str | None = None,
        sync_state: str | None = None,
        day_from: datetime | None = None,
        day_to: datetime | None = None,
    ) -> list[TestResult]:
        completed_from, completed_to = self.normalize_date_range(day_from, day_to)
        if completed_to is not None:
            completed_to = completed_to + timedelta(days=1)
        return self.list_filtered_results(
            user_id=user_id,
            status=status,
            sync_state=sync_state,
            completed_from=completed_from,
            completed_to=completed_to,
        )
