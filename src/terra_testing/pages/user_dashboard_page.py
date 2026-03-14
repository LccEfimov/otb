from __future__ import annotations

import flet as ft

from terra_testing.app.access import require_user
from terra_testing.components.app_shell import build_shell
from terra_testing.services.schedule_service import ScheduleService


class UserDashboardPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.schedule_service = ScheduleService()

    def _start_assignment(self, assignment_id: int) -> None:
        self.page.session.set('active_assignment_id', assignment_id)
        self.page.go('/quiz')

    def build(self) -> ft.View:
        denied = require_user(self.page, "Кабинет сотрудника", "/user")
        if denied is not None:
            return denied

        state = self.page.session.get('state')
        user_id = state.user_id if state and state.user_id is not None else 1
        assignment_infos = self.schedule_service.list_assignments_for_user(user_id)

        controls: list[ft.Control] = [
            ft.Row(
                controls=[
                    ft.OutlinedButton('Результаты', on_click=lambda _: self.page.go('/results')),
                    ft.OutlinedButton('Настройки', on_click=lambda _: self.page.go('/settings')),
                ]
            )
        ]

        if not assignment_infos:
            controls.append(ft.Text('Пока нет назначенных тестов. Можно запустить свободный тест из общего банка.'))
            controls.append(ft.FilledButton('Начать тест', on_click=lambda _: self.page.go('/quiz')))
        else:
            for info in assignment_infos:
                assignment = info['assignment']
                reason = 'Готово к запуску'
                if assignment.status == 'completed':
                    reason = 'Назначение уже завершено'
                elif info['is_overdue']:
                    reason = 'Срок выполнения истёк'
                elif info['attempts_left'] <= 0:
                    reason = 'Попытки исчерпаны'
                controls.append(
                    ft.Card(
                        content=ft.Container(
                            padding=16,
                            content=ft.Column(
                                controls=[
                                    ft.Text(assignment.title, weight=ft.FontWeight.BOLD),
                                    ft.Text(f'Вопросов: {assignment.questions_count}'),
                                    ft.Text(f'Попыток использовано: {info["attempts_used"]} из {assignment.max_attempts}'),
                                    ft.Text(f'Статус: {assignment.status}'),
                                    ft.Text(f'Комментарий: {reason}'),
                                    ft.FilledButton(
                                        'Начать',
                                        disabled=not info['can_start'],
                                        on_click=lambda _, assignment_id=assignment.id: self._start_assignment(assignment_id),
                                    ),
                                ]
                            ),
                        )
                    )
                )

        return ft.View(route='/user', controls=build_shell('Кабинет сотрудника', controls, page=self.page))
