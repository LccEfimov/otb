from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.services.user_service import UserService


def _create_user():
    with get_local_session() as session:
        role = Role(name="user")
        session.add(role)
        session.commit()
        session.refresh(role)
    return UserService().create_user("user01", "User", "User123!", role.id)


def test_change_password_rejects_wrong_current_password():
    init_db()
    user = _create_user()
    ok, message = UserService().change_password(user.id, "wrong", "NewPass123!")
    assert ok is False
    assert "неверный" in message.lower()


def test_change_password_accepts_correct_current_password():
    init_db()
    user = _create_user()
    service = UserService()
    ok, message = service.change_password(user.id, "User123!", "NewPass123!")
    assert ok is True
    assert "обновлён" in message.lower()
    assert service.verify_current_password(user.id, "NewPass123!") is True
