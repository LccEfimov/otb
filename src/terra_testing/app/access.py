from __future__ import annotations

import flet as ft

from terra_testing.app.session_state import SessionState
from terra_testing.components.app_shell import build_shell


def get_state(page: ft.Page) -> SessionState:
    state = page.session.get("state")
    return state if isinstance(state, SessionState) else SessionState()


def is_authenticated(page: ft.Page) -> bool:
    return get_state(page).is_authenticated


def is_admin(page: ft.Page) -> bool:
    state = get_state(page)
    return state.is_authenticated and state.role == "admin"


def is_user(page: ft.Page) -> bool:
    state = get_state(page)
    return state.is_authenticated and state.role in {"admin", "user"}


def actor_name(page: ft.Page, fallback: str = "system") -> str:
    state = get_state(page)
    return state.username or fallback


def _denied_view(page: ft.Page, title: str, route: str, message: str) -> ft.View:
    return ft.View(
        route=route,
        controls=build_shell(
            title,
            [
                ft.Text(message),
                ft.FilledButton("Вернуться", on_click=lambda _: page.go("/user" if is_authenticated(page) else "/login")),
            ],
            page=page,
        ),
    )


def require_authenticated(page: ft.Page, title: str, route: str) -> ft.View | None:
    if is_authenticated(page):
        return None
    return _denied_view(page, title, route, "Необходима авторизация.")


def require_user(page: ft.Page, title: str, route: str) -> ft.View | None:
    if is_user(page):
        return None
    return _denied_view(page, title, route, "Доступ разрешён только авторизованным пользователям.")


def require_admin(page: ft.Page, title: str, route: str) -> ft.View | None:
    if is_admin(page):
        return None
    return _denied_view(page, title, route, "Доступ разрешён только администратору.")
