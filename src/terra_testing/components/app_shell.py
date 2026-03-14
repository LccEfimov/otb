from __future__ import annotations

import flet as ft

from terra_testing.app.session_state import SessionState


def _nav_button(label: str, route: str, page: ft.Page) -> ft.OutlinedButton:
    return ft.OutlinedButton(label, on_click=lambda _: page.go(route))


def _logout(page: ft.Page) -> None:
    page.session.set('state', SessionState())
    page.session.set('quiz_state', None)
    page.session.set('active_assignment_id', None)
    page.session.set('edit_user_id', None)
    page.session.set('edit_question_id', None)
    page.go('/login')


def build_shell(title: str, body: list[ft.Control], page: ft.Page | None = None) -> list[ft.Control]:
    actions: list[ft.Control] = []
    if page is not None:
        state: SessionState | None = page.session.get('state')
        if state and state.is_authenticated:
            if state.role == 'admin':
                actions.extend([
                    _nav_button('Главная', '/admin', page),
                    _nav_button('Пользователи', '/admin/users', page),
                    _nav_button('Вопросы', '/admin/questions', page),
                    _nav_button('Расписание', '/admin/schedule', page),
                    _nav_button('Результаты', '/admin/results', page),
                    _nav_button('Синхронизация', '/admin/sync', page),
                    _nav_button('Аудит', '/admin/audit', page),
                    _nav_button('Отчёты', '/reports', page),
                    _nav_button('Настройки', '/settings', page),
                ])
            else:
                actions.extend([
                    _nav_button('Главная', '/user', page),
                    _nav_button('Результаты', '/results', page),
                    _nav_button('Настройки', '/settings', page),
                ])
            actions.append(ft.VerticalDivider(width=1))
            actions.append(ft.Text(state.username or '', size=12))
            actions.append(ft.FilledButton('Выход', on_click=lambda _: _logout(page)))

    appbar = ft.AppBar(title=ft.Text(title), actions=actions)
    return [appbar, *body]
