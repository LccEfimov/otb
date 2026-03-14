from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.services.schedule_service import ScheduleService
from terra_testing.services.user_service import UserService


def _create_user():
    with get_local_session() as session:
        role = Role(name="user")
        session.add(role)
        session.commit()
        session.refresh(role)
    return UserService().create_user("user01", "User", "User123!", role.id)


def test_assignment_can_be_updated():
    init_db()
    user = _create_user()
    service = ScheduleService()
    assignment = service.create_assignment(
        user_id=user.id,
        title="Old title",
        questions_count=10,
        max_attempts=2,
        due_at=None,
    )
    updated = service.update_assignment(
        assignment_id=assignment.id,
        user_id=user.id,
        title="New title",
        questions_count=20,
        max_attempts=3,
        due_at=None,
        status="assigned",
    )
    assert updated is not None
    assert updated.title == "New title"
    assert updated.questions_count == 20
    assert updated.max_attempts == 3
