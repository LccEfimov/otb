from __future__ import annotations

import flet as ft

from terra_testing.app.access import require_user
from terra_testing.app.session_state import SessionState
from terra_testing.components.app_shell import build_shell
from terra_testing.components.sync_badge import sync_badge
from terra_testing.repositories.result_repository import ResultRepository


class ResultsPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.repository = ResultRepository()

    def build(self) -> ft.View:
        denied = require_user(self.page, "Результаты", "/results")
        if denied is not None:
            return denied

        state: SessionState = self.page.session.get('state')
        user_id = state.user_id if state and state.user_id is not None else 1
        results = self.repository.list_results_for_user(user_id)
        back_route = '/admin' if state and state.role == 'admin' else '/user'

        controls: list[ft.Control] = [ft.OutlinedButton('Назад', on_click=lambda _: self.page.go(back_route))]
        for result in results:
            controls.append(
                ft.Card(
                    content=ft.Container(
                        padding=16,
                        content=ft.Column(
                            controls=[
                                ft.Text(f'Результат #{result.id}', weight=ft.FontWeight.BOLD),
                                ft.Text(f'Правильных ответов: {result.correct_answers} из {result.total_questions}'),
                                ft.Text(f'Баллы: {result.score_percent}%'),
                                ft.Text(f'Статус: {result.status}'),
                                sync_badge(result.sync_state),
                            ]
                        ),
                    )
                )
            )

        if not results:
            controls.append(ft.Text('Результатов пока нет.'))

        return ft.View(route='/results', controls=build_shell('Результаты', controls, page=self.page))
