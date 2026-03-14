from __future__ import annotations

from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.repositories.schedule_repository import ScheduleRepository
from terra_testing.utils.time import utcnow


class ScheduleService:
    def __init__(self) -> None:
        self.repository = ScheduleRepository()
        self.result_repository = ResultRepository()

    def list_assignments(self):
        return self.repository.list_assignments()

    def count_active_assignments(self) -> int:
        return self.repository.count_active_assignments()

    def list_assignments_for_user(self, user_id: int):
        assignments = self.repository.list_assignments_for_user(user_id)
        enriched = []
        now = utcnow()
        for assignment in assignments:
            attempts_used = self.result_repository.count_attempts_for_assignment(user_id, assignment.id)
            is_overdue = bool(assignment.due_at and assignment.due_at < now.replace(tzinfo=None))
            can_start = assignment.status == 'assigned' and attempts_used < assignment.max_attempts and not is_overdue
            enriched.append({
                'assignment': assignment,
                'attempts_used': attempts_used,
                'attempts_left': max(assignment.max_attempts - attempts_used, 0),
                'is_overdue': is_overdue,
                'can_start': can_start,
            })
        return enriched

    def get_assignment(self, assignment_id: int):
        return self.repository.get_assignment(assignment_id)

    def create_assignment(self, **kwargs):
        return self.repository.create_assignment(**kwargs)

    def update_assignment(self, **kwargs):
        return self.repository.update_assignment(**kwargs)

    def set_status(self, assignment_id: int, status: str):
        return self.repository.set_status(assignment_id, status)

    def mark_completed(self, assignment_id: int):
        return self.repository.mark_completed(assignment_id)
