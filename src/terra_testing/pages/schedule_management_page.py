from __future__ import annotations

from datetime import datetime

import flet as ft

from terra_testing.app.access import actor_name, require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.services.audit_service import AuditService
from terra_testing.services.schedule_service import ScheduleService
from terra_testing.services.user_service import UserService


class ScheduleManagementPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.schedule_service = ScheduleService()
        self.user_service = UserService()
        self.audit_service = AuditService()
        self.user_dropdown = ft.Dropdown(label='Сотрудник', width=260)
        self.title = ft.TextField(label='Название тестирования', width=320, value='Плановое тестирование')
        self.questions_count = ft.TextField(label='Вопросов', width=120, value='20')
        self.max_attempts = ft.TextField(label='Попыток', width=120, value='3')
        self.due_at = ft.TextField(label='Срок (YYYY-MM-DD HH:MM)', width=220)
        self.status_dropdown = ft.Dropdown(
            label='Статус',
            width=180,
            options=[
                ft.dropdown.Option('assigned', 'assigned'),
                ft.dropdown.Option('completed', 'completed'),
                ft.dropdown.Option('cancelled', 'cancelled'),
            ],
            value='assigned',
        )
        self.message = ft.Text()

    def _refresh_users(self) -> None:
        users = [user for user in self.user_service.list_users() if user.role and user.role.name == 'user']
        self.user_dropdown.options = [ft.dropdown.Option(str(user.id), f'{user.full_name} ({user.username})') for user in users]
        if users and self.user_dropdown.value is None:
            self.user_dropdown.value = str(users[0].id)

    def _edit_assignment_id(self) -> int | None:
        value = self.page.session.get('edit_assignment_id')
        return int(value) if value not in {None, ''} else None

    def _parse_due_at(self):
        raw = (self.due_at.value or '').strip()
        if not raw:
            return None
        return datetime.strptime(raw, '%Y-%m-%d %H:%M')

    def _reset_form(self) -> None:
        self.page.session.set('edit_assignment_id', None)
        self.title.value = 'Плановое тестирование'
        self.questions_count.value = '20'
        self.max_attempts.value = '3'
        self.due_at.value = ''
        self.status_dropdown.value = 'assigned'
        if self.user_dropdown.options:
            self.user_dropdown.value = self.user_dropdown.options[0].key

    def _load_edit_state(self) -> None:
        assignment_id = self._edit_assignment_id()
        if assignment_id is None:
            return
        assignment = self.schedule_service.get_assignment(assignment_id)
        if assignment is None:
            self.page.session.set('edit_assignment_id', None)
            return
        self.user_dropdown.value = str(assignment.user_id)
        self.title.value = assignment.title
        self.questions_count.value = str(assignment.questions_count)
        self.max_attempts.value = str(assignment.max_attempts)
        self.due_at.value = assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else ''
        self.status_dropdown.value = assignment.status

    def _start_edit(self, assignment_id: int) -> None:
        self.page.session.set('edit_assignment_id', assignment_id)
        self.page.go('/admin/schedule')

    def _cancel_edit(self, _: ft.ControlEvent) -> None:
        self._reset_form()
        self.page.go('/admin/schedule')

    def _save_assignment(self, _: ft.ControlEvent) -> None:
        if not self.user_dropdown.value:
            self.message.value = 'Выберите сотрудника'
            self.message.color = ft.Colors.RED
            self.page.update()
            return

        try:
            due_at = self._parse_due_at()
        except ValueError:
            self.message.value = 'Неверный формат даты'
            self.message.color = ft.Colors.RED
            self.page.update()
            return

        payload = {
            'user_id': int(self.user_dropdown.value),
            'title': (self.title.value or '').strip() or 'Плановое тестирование',
            'questions_count': int(self.questions_count.value or '20'),
            'max_attempts': int(self.max_attempts.value or '3'),
            'due_at': due_at,
        }
        actor = actor_name(self.page)
        assignment_id = self._edit_assignment_id()
        if assignment_id is None:
            assignment = self.schedule_service.create_assignment(**payload)
            self.audit_service.log('assignment_created', actor, f'Назначено тестирование #{assignment.id}')
            self.message.value = 'Назначение создано'
        else:
            assignment = self.schedule_service.update_assignment(
                assignment_id=assignment_id,
                status=self.status_dropdown.value or 'assigned',
                **payload,
            )
            self.audit_service.log('assignment_updated', actor, f'Обновлено назначение #{assignment_id}')
            self.message.value = 'Назначение обновлено'
        self.message.color = ft.Colors.GREEN
        self._reset_form()
        self.page.go('/admin/schedule')

    def _change_status(self, assignment_id: int, status: str) -> None:
        updated = self.schedule_service.set_status(assignment_id, status)
        if updated is not None:
            self.audit_service.log('assignment_status_changed', actor_name(self.page), f'Назначение #{assignment_id} -> {status}')
        self.page.go('/admin/schedule')

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Расписание тестирования", "/admin/schedule")
        if denied is not None:
            return denied

        self._refresh_users()
        self._load_edit_state()
        rows = []
        for assignment in self.schedule_service.list_assignments():
            rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Text(str(assignment.id))),
                        ft.DataCell(ft.Text(assignment.user.full_name if assignment.user else '')),
                        ft.DataCell(ft.Text(assignment.title)),
                        ft.DataCell(ft.Text(str(assignment.questions_count))),
                        ft.DataCell(ft.Text(str(assignment.max_attempts))),
                        ft.DataCell(ft.Text(assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else '')),
                        ft.DataCell(ft.Text(assignment.status)),
                        ft.DataCell(
                            ft.Row(
                                [
                                    ft.TextButton('Редактировать', on_click=lambda _, aid=assignment.id: self._start_edit(aid)),
                                    ft.TextButton('Assigned', on_click=lambda _, aid=assignment.id: self._change_status(aid, 'assigned')),
                                    ft.TextButton('Cancel', on_click=lambda _, aid=assignment.id: self._change_status(aid, 'cancelled')),
                                ],
                                wrap=True,
                            )
                        ),
                    ]
                )
            )

        edit_mode = self._edit_assignment_id() is not None
        return ft.View(
            route='/admin/schedule',
            controls=build_shell(
                'Управление расписанием',
                [
                    ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/admin')),
                    ft.Card(
                        content=ft.Container(
                            padding=16,
                            content=ft.Column(
                                controls=[
                                    ft.Text('Редактировать назначение' if edit_mode else 'Назначить тест', weight=ft.FontWeight.BOLD),
                                    ft.ResponsiveRow(
                                        controls=[
                                            ft.Container(self.user_dropdown, col={'sm': 12, 'md': 3}),
                                            ft.Container(self.title, col={'sm': 12, 'md': 3}),
                                            ft.Container(self.questions_count, col={'sm': 6, 'md': 2}),
                                            ft.Container(self.max_attempts, col={'sm': 6, 'md': 2}),
                                            ft.Container(self.status_dropdown, col={'sm': 12, 'md': 2}),
                                        ]
                                    ),
                                    ft.Row(
                                        [
                                            self.due_at,
                                            ft.FilledButton('Сохранить' if edit_mode else 'Назначить', on_click=self._save_assignment),
                                            ft.OutlinedButton('Сбросить', on_click=self._cancel_edit),
                                            self.message,
                                        ],
                                        wrap=True,
                                    ),
                                ]
                            ),
                        )
                    ),
                    ft.DataTable(
                        columns=[
                            ft.DataColumn(ft.Text('ID')),
                            ft.DataColumn(ft.Text('Сотрудник')),
                            ft.DataColumn(ft.Text('Тест')),
                            ft.DataColumn(ft.Text('Вопросов')),
                            ft.DataColumn(ft.Text('Попыток')),
                            ft.DataColumn(ft.Text('Срок')),
                            ft.DataColumn(ft.Text('Статус')),
                            ft.DataColumn(ft.Text('Действия')),
                        ],
                        rows=rows,
                    ),
                ],
                page=self.page,
            ),
        )
