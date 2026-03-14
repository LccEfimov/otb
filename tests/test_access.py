from __future__ import annotations

from terra_testing.app.access import is_admin, is_authenticated, is_user
from terra_testing.app.session_state import SessionState


class _Session:
    def __init__(self, state):
        self._state = state

    def get(self, key):
        if key == "state":
            return self._state
        return None


class _Page:
    def __init__(self, state):
        self.session = _Session(state)


def test_access_helpers_for_authenticated_user():
    page = _Page(SessionState(user_id=1, username="user", role="user", is_authenticated=True))
    assert is_authenticated(page) is True
    assert is_user(page) is True
    assert is_admin(page) is False


def test_access_helpers_for_admin():
    page = _Page(SessionState(user_id=1, username="admin", role="admin", is_authenticated=True))
    assert is_authenticated(page) is True
    assert is_user(page) is True
    assert is_admin(page) is True
