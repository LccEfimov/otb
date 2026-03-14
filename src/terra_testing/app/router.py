from __future__ import annotations

import flet as ft

from terra_testing.app.session_state import SessionState
from terra_testing.pages.admin_dashboard_page import AdminDashboardPage
from terra_testing.pages.admin_results_page import AdminResultsPage
from terra_testing.pages.audit_log_page import AuditLogPage
from terra_testing.pages.login_page import LoginPage
from terra_testing.pages.questions_management_page import QuestionsManagementPage
from terra_testing.pages.quiz_page import QuizPage
from terra_testing.pages.reports_page import ReportsPage
from terra_testing.pages.results_page import ResultsPage
from terra_testing.pages.schedule_management_page import ScheduleManagementPage
from terra_testing.pages.settings_page import SettingsPage
from terra_testing.pages.sync_monitor_page import SyncMonitorPage
from terra_testing.pages.user_dashboard_page import UserDashboardPage
from terra_testing.pages.users_management_page import UsersManagementPage


ROUTES = {
    "/login": LoginPage,
    "/admin": AdminDashboardPage,
    "/admin/users": UsersManagementPage,
    "/admin/questions": QuestionsManagementPage,
    "/admin/schedule": ScheduleManagementPage,
    "/admin/results": AdminResultsPage,
    "/admin/sync": SyncMonitorPage,
    "/admin/audit": AuditLogPage,
    "/user": UserDashboardPage,
    "/quiz": QuizPage,
    "/results": ResultsPage,
    "/reports": ReportsPage,
    "/settings": SettingsPage,
}

ADMIN_ROUTES = {route for route in ROUTES if route.startswith('/admin')}
USER_ROUTES = {'/user', '/quiz', '/results', '/settings'}
SHARED_AUTH_ROUTES = {'/results', '/settings'}


def get_session_state(page: ft.Page) -> SessionState:
    state = page.session.get('state')
    return state if isinstance(state, SessionState) else SessionState()


def route_is_allowed(route: str, state: SessionState) -> bool:
    if route == '/login':
        return True
    if not state.is_authenticated:
        return False
    if route in ADMIN_ROUTES or route == '/reports':
        return state.role == 'admin'
    if route in USER_ROUTES:
        if route == '/settings':
            return True
        return state.role in {'admin', 'user'}
    if route in SHARED_AUTH_ROUTES:
        return True
    return route in ROUTES


def fallback_route_for_state(state: SessionState, requested_route: str) -> str:
    if not state.is_authenticated:
        return '/login'
    if requested_route in ADMIN_ROUTES and state.role != 'admin':
        return '/user'
    if requested_route == '/login':
        return '/admin' if state.role == 'admin' else '/user'
    return '/admin' if state.role == 'admin' else '/user'


def configure_routing(page: ft.Page) -> None:
    def route_change(route: ft.RouteChangeEvent) -> None:
        state = get_session_state(page)
        requested_route = page.route if page.route in ROUTES else '/login'
        effective_route = requested_route if route_is_allowed(requested_route, state) else fallback_route_for_state(state, requested_route)

        if effective_route != page.route:
            page.go(effective_route)
            return

        page.views.clear()
        view_cls = ROUTES.get(effective_route, LoginPage)
        page.views.append(view_cls(page).build())
        page.update()

    page.on_route_change = route_change
