from __future__ import annotations

from datetime import datetime

import flet as ft

from terra_testing.app.access import require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.repositories.user_repository import UserRepository
from terra_testing.services.report_service import ReportService


class ReportsPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.report_service = ReportService()
        self.result_repository = ResultRepository()
        self.user_repository = UserRepository()
        self.message = ft.Text()
        self.status_filter = ft.Dropdown(
            label='Статус',
            width=180,
            options=[ft.dropdown.Option('all', 'Все'), ft.dropdown.Option('passed', 'Пройден'), ft.dropdown.Option('failed', 'Не пройден')],
            value=page.session.get('reports_status_filter') or 'all',
            on_change=self._apply_filters,
        )
        self.sync_filter = ft.Dropdown(
            label='Sync',
            width=180,
            options=[ft.dropdown.Option('all', 'Все'), ft.dropdown.Option('pending', 'Pending'), ft.dropdown.Option('synced', 'Synced'), ft.dropdown.Option('failed', 'Failed')],
            value=page.session.get('reports_sync_filter') or 'all',
            on_change=self._apply_filters,
        )
        self.date_from = ft.TextField(label='С даты (YYYY-MM-DD)', width=180, value=page.session.get('reports_date_from') or '')
        self.date_to = ft.TextField(label='По дату (YYYY-MM-DD)', width=180, value=page.session.get('reports_date_to') or '')

    def _apply_filters(self, _: ft.ControlEvent | None = None) -> None:
        self.page.session.set('reports_status_filter', self.status_filter.value)
        self.page.session.set('reports_sync_filter', self.sync_filter.value)
        self.page.session.set('reports_date_from', self.date_from.value)
        self.page.session.set('reports_date_to', self.date_to.value)
        self.page.go('/reports')

    def _parse_day(self, raw: str | None):
        value = (raw or '').strip()
        if not value:
            return None
        try:
            return datetime.strptime(value, '%Y-%m-%d')
        except ValueError:
            self.message.value = f'Неверная дата: {value}'
            self.message.color = ft.Colors.RED
            return None

    def _build_rows(self) -> list[dict]:
        users = {user.id: user for user in self.user_repository.list_users()}
        day_from = self._parse_day(self.date_from.value)
        day_to = self._parse_day(self.date_to.value)
        rows = []
        for result in self.result_repository.list_filtered_results_by_day(
            status=self.status_filter.value,
            sync_state=self.sync_filter.value,
            day_from=day_from,
            day_to=day_to,
        ):
            user = users.get(result.user_id)
            rows.append(
                {
                    'full_name': user.full_name if user else f'User #{result.user_id}',
                    'score_percent': result.score_percent,
                    'status': result.status,
                    'sync_state': result.sync_state,
                    'completed_at': result.completed_at.strftime('%Y-%m-%d %H:%M'),
                }
            )
        return rows or [{'full_name': 'Нет данных', 'score_percent': 0, 'status': 'n/a', 'sync_state': 'n/a', 'completed_at': '-'}]

    def _export_pdf(self, _: ft.ControlEvent) -> None:
        path = self.report_service.export_results_pdf(self._build_rows())
        self.message.value = f'PDF сохранён: {path}'
        self.message.color = ft.Colors.GREEN
        self.page.update()

    def _export_excel(self, _: ft.ControlEvent) -> None:
        path = self.report_service.export_results_excel(self._build_rows())
        self.message.value = f'Excel сохранён: {path}'
        self.message.color = ft.Colors.GREEN
        self.page.update()

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Отчёты", "/reports")
        if denied is not None:
            return denied

        preview_rows = self._build_rows()[:10]
        controls = [
            ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/admin')),
            ft.Row([self.status_filter, self.sync_filter, self.date_from, self.date_to, ft.OutlinedButton('Применить', on_click=self._apply_filters)], wrap=True),
            ft.Row(
                controls=[
                    ft.FilledButton('Экспорт PDF', on_click=self._export_pdf),
                    ft.FilledButton('Экспорт Excel', on_click=self._export_excel),
                ]
            ),
        ]
        if self.message.value:
            controls.append(self.message)
        controls.append(
            ft.DataTable(
                columns=[
                    ft.DataColumn(ft.Text('Сотрудник')),
                    ft.DataColumn(ft.Text('Баллы')),
                    ft.DataColumn(ft.Text('Статус')),
                    ft.DataColumn(ft.Text('Sync')),
                    ft.DataColumn(ft.Text('Дата')),
                ],
                rows=[
                    ft.DataRow(
                        cells=[
                            ft.DataCell(ft.Text(row['full_name'])),
                            ft.DataCell(ft.Text(str(row['score_percent']))),
                            ft.DataCell(ft.Text(row['status'])),
                            ft.DataCell(ft.Text(row['sync_state'])),
                            ft.DataCell(ft.Text(row['completed_at'])),
                        ]
                    )
                    for row in preview_rows
                ],
            )
        )
        return ft.View(route='/reports', controls=build_shell('Отчёты', controls, page=self.page))
