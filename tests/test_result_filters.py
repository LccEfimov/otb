from __future__ import annotations

from datetime import datetime, timedelta, timezone

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.models.test_result import TestResult
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.services.user_service import UserService


def _create_user():
    with get_local_session() as session:
        role = Role(name="user")
        session.add(role)
        session.commit()
        session.refresh(role)
    return UserService().create_user("user01", "User", "User123!", role.id)


def test_result_repository_filters_by_day_range():
    init_db()
    user = _create_user()
    with get_local_session() as session:
        old_result = TestResult(
            user_id=user.id,
            assignment_id=None,
            correct_answers=1,
            total_questions=1,
            score_percent=100,
            status="passed",
            completed_at=datetime.now(timezone.utc) - timedelta(days=5),
        )
        new_result = TestResult(
            user_id=user.id,
            assignment_id=None,
            correct_answers=1,
            total_questions=1,
            score_percent=100,
            status="passed",
            completed_at=datetime.now(timezone.utc),
        )
        session.add_all([old_result, new_result])
        session.commit()

    repo = ResultRepository()
    results = repo.list_filtered_results_by_day(
        day_from=datetime.now() - timedelta(days=1),
        day_to=datetime.now(),
    )
    assert len(results) == 1
    assert results[0].score_percent == 100
