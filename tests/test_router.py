from terra_testing.app.router import fallback_route_for_state, route_is_allowed
from terra_testing.app.session_state import SessionState


def test_unauthenticated_user_cannot_open_admin_route():
    state = SessionState()
    assert route_is_allowed('/admin', state) is False
    assert fallback_route_for_state(state, '/admin') == '/login'


def test_admin_can_open_admin_route():
    state = SessionState(user_id=1, username='admin', role='admin', is_authenticated=True)
    assert route_is_allowed('/admin', state) is True
    assert route_is_allowed('/admin/questions', state) is True


def test_regular_user_is_redirected_from_admin_route():
    state = SessionState(user_id=2, username='user01', role='user', is_authenticated=True)
    assert route_is_allowed('/admin', state) is False
    assert fallback_route_for_state(state, '/admin/questions') == '/user'


def test_authenticated_user_is_redirected_from_login():
    state = SessionState(user_id=2, username='user01', role='user', is_authenticated=True)
    assert fallback_route_for_state(state, '/login') == '/user'


def test_regular_user_cannot_open_reports_route():
    state = SessionState(user_id=2, username='user01', role='user', is_authenticated=True)
    assert route_is_allowed('/reports', state) is False
    assert fallback_route_for_state(state, '/reports') == '/user'


def test_admin_can_open_reports_route():
    state = SessionState(user_id=1, username='admin', role='admin', is_authenticated=True)
    assert route_is_allowed('/reports', state) is True


def test_authenticated_admin_unknown_route_falls_back_to_admin():
    state = SessionState(user_id=1, username='admin', role='admin', is_authenticated=True)
    assert fallback_route_for_state(state, '/unknown') == '/admin'


def test_authenticated_user_unknown_route_falls_back_to_user():
    state = SessionState(user_id=2, username='user01', role='user', is_authenticated=True)
    assert fallback_route_for_state(state, '/unknown') == '/user'


def test_unauthenticated_unknown_route_falls_back_to_login():
    state = SessionState()
    assert fallback_route_for_state(state, '/unknown') == '/login'
