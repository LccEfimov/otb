from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import joinedload

from terra_testing.db.session import get_local_session
from terra_testing.models.schedule import TestAssignment


class ScheduleRepository:
    def list_assignments(self) -> list[TestAssignment]:
        with get_local_session() as session:
            stmt = select(TestAssignment).options(joinedload(TestAssignment.user)).order_by(TestAssignment.id.desc())
            return list(session.execute(stmt).scalars().unique().all())

    def count_active_assignments(self) -> int:
        with get_local_session() as session:
            stmt = select(func.count(TestAssignment.id)).where(TestAssignment.status == 'assigned')
            return int(session.execute(stmt).scalar_one())

    def list_assignments_for_user(self, user_id: int) -> list[TestAssignment]:
        with get_local_session() as session:
            stmt = (
                select(TestAssignment)
                .options(joinedload(TestAssignment.user))
                .where(TestAssignment.user_id == user_id)
                .order_by(TestAssignment.id.desc())
            )
            return list(session.execute(stmt).scalars().unique().all())

    def get_assignment(self, assignment_id: int) -> TestAssignment | None:
        with get_local_session() as session:
            stmt = select(TestAssignment).options(joinedload(TestAssignment.user)).where(TestAssignment.id == assignment_id)
            return session.execute(stmt).scalar_one_or_none()

    def create_assignment(
        self,
        *,
        user_id: int,
        title: str,
        questions_count: int,
        max_attempts: int,
        due_at=None,
    ) -> TestAssignment:
        with get_local_session() as session:
            assignment = TestAssignment(
                user_id=user_id,
                title=title,
                questions_count=questions_count,
                max_attempts=max_attempts,
                due_at=due_at,
            )
            session.add(assignment)
            session.commit()
            session.refresh(assignment)
            return self.get_assignment(assignment.id)

    def update_assignment(
        self,
        *,
        assignment_id: int,
        user_id: int,
        title: str,
        questions_count: int,
        max_attempts: int,
        due_at=None,
        status: str = 'assigned',
    ) -> TestAssignment | None:
        with get_local_session() as session:
            assignment = session.get(TestAssignment, assignment_id)
            if assignment is None:
                return None
            assignment.user_id = user_id
            assignment.title = title
            assignment.questions_count = questions_count
            assignment.max_attempts = max_attempts
            assignment.due_at = due_at
            assignment.status = status
            session.commit()
            session.refresh(assignment)
            return self.get_assignment(assignment.id)

    def set_status(self, assignment_id: int, status: str) -> TestAssignment | None:
        with get_local_session() as session:
            assignment = session.get(TestAssignment, assignment_id)
            if assignment is None:
                return None
            assignment.status = status
            session.commit()
            session.refresh(assignment)
            return self.get_assignment(assignment.id)

    def mark_completed(self, assignment_id: int) -> TestAssignment | None:
        return self.set_status(assignment_id, 'completed')
