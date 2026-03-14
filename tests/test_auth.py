from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.services.auth_service import AuthService
from terra_testing.services.user_service import UserService


def _prepare_role(name: str) -> Role:
    with get_local_session() as session:
        role = Role(name=name)
        session.add(role)
        session.commit()
        session.refresh(role)
        return role


def test_login_success():
    init_db()
    role = _prepare_role("admin")
    UserService().create_user("admin", "Admin", "Admin123!", role.id)

    result = AuthService().login("admin", "Admin123!")
    assert result["success"] is True
    assert result["role"] == "admin"
    assert result["username"] == "admin"


def test_login_bad_password():
    init_db()
    role = _prepare_role("admin")
    UserService().create_user("admin", "Admin", "Admin123!", role.id)

    result = AuthService().login("admin", "wrong")
    assert result["success"] is False
    assert result["error"] == "Неверный пароль"


def test_login_skips_sync_when_flag_disabled(monkeypatch):
    init_db()
    role = _prepare_role("admin")
    UserService().create_user("admin", "Admin", "Admin123!", role.id)

    called = {"value": False}

    def _raise_if_called(user_id: int):
        called["value"] = True
        raise AssertionError("sync_after_login should not be called")

    service = AuthService()
    service.sync_service.settings.sync_after_login = False
    monkeypatch.setattr(service.sync_service, "sync_after_login", _raise_if_called)

    result = service.login("admin", "Admin123!")
    assert result["success"] is True
    assert called["value"] is False


def test_login_calls_sync_when_flag_enabled(monkeypatch):
    init_db()
    role = _prepare_role("admin")
    UserService().create_user("admin", "Admin", "Admin123!", role.id)

    called = {"value": False}

    def _mark_called(user_id: int):
        called["value"] = True
        return {"synced": 0, "failed": 0, "total": 0}

    service = AuthService()
    service.sync_service.settings.sync_after_login = True
    monkeypatch.setattr(service.sync_service, "sync_after_login", _mark_called)

    result = service.login("admin", "Admin123!")
    assert result["success"] is True
    assert called["value"] is True
