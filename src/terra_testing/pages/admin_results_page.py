from __future__ import annotations

from datetime import datetime

import flet as ft

from terra_testing.app.access import require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.components.sync_badge import sync_badge
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.repositories.user_repository import UserRepository


class AdminResultsPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.result_repository = ResultRepository()
        self.user_repository = UserRepository()

        self.user_filter = ft.Dropdown(label="Сотрудник", width=240, on_change=self._apply_filters)
        self.status_filter = ft.Dropdown(
            label="Статус",
            width=180,
            options=[ft.dropdown.Option("all", "Все"), ft.dropdown.Option("passed", "Пройден"), ft.dropdown.Option("failed", "Не пройден")],
            value=page.session.get("admin_results_status_filter") or "all",
            on_change=self._apply_filters,
        )
        self.sync_filter = ft.Dropdown(
            label="Sync",
            width=180,
            options=[
                ft.dropdown.Option("all", "Все"),
                ft.dropdown.Option("pending", "Pending"),
                ft.dropdown.Option("synced", "Synced"),
                ft.dropdown.Option("failed", "Failed"),
            ],
            value=page.session.get("admin_results_sync_filter") or "all",
            on_change=self._apply_filters,
        )
        self.date_from = ft.TextField(label="С даты (YYYY-MM-DD)", width=180, value=page.session.get("admin_results_date_from") or "", on_submit=self._apply_filters)
        self.date_to = ft.TextField(label="По дату (YYYY-MM-DD)", width=180, value=page.session.get("admin_results_date_to") or "", on_submit=self._apply_filters)
        self.message = ft.Text()

    def _apply_filters(self, _: ft.ControlEvent | None = None) -> None:
        self.page.session.set("admin_results_user_filter", self.user_filter.value)
        self.page.session.set("admin_results_status_filter", self.status_filter.value)
        self.page.session.set("admin_results_sync_filter", self.sync_filter.value)
        self.page.session.set("admin_results_date_from", self.date_from.value)
        self.page.session.set("admin_results_date_to", self.date_to.value)
        self.page.go("/admin/results")

    def _init_filters(self) -> None:
        users = self.user_repository.list_users()
        options = [ft.dropdown.Option("all", "Все")] + [ft.dropdown.Option(str(user.id), user.full_name) for user in users]
        self.user_filter.options = options
        self.user_filter.value = self.page.session.get("admin_results_user_filter") or "all"

    def _parse_day(self, raw: str | None):
        value = (raw or "").strip()
        if not value:
            return None
        try:
            return datetime.strptime(value, "%Y-%m-%d")
        except ValueError:
            self.message.value = f"Неверная дата: {value}"
            self.message.color = ft.Colors.RED
            return None

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Все результаты", "/admin/results")
        if denied is not None:
            return denied

        self._init_filters()
        users = {user.id: user for user in self.user_repository.list_users()}
        selected_user = None if self.user_filter.value in {None, "all"} else int(self.user_filter.value)
        day_from = self._parse_day(self.date_from.value)
        day_to = self._parse_day(self.date_to.value)
        results = self.result_repository.list_filtered_results_by_day(
            user_id=selected_user,
            status=self.status_filter.value,
            sync_state=self.sync_filter.value,
            day_from=day_from,
            day_to=day_to,
        )
        rows = []
        for result in results:
            user = users.get(result.user_id)
            rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Text(str(result.id))),
                        ft.DataCell(ft.Text(user.full_name if user else f"User #{result.user_id}")),
                        ft.DataCell(ft.Text(str(result.correct_answers))),
                        ft.DataCell(ft.Text(str(result.total_questions))),
                        ft.DataCell(ft.Text(str(result.score_percent))),
                        ft.DataCell(ft.Text(result.status)),
                        ft.DataCell(ft.Text(result.completed_at.strftime("%Y-%m-%d %H:%M"))),
                        ft.DataCell(sync_badge(result.sync_state)),
                    ]
                )
            )

        passed_count = sum(1 for result in results if result.status == "passed")
        failed_count = sum(1 for result in results if result.status == "failed")

        controls = [
            ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
            ft.Row([self.user_filter, self.status_filter, self.sync_filter, self.date_from, self.date_to, ft.OutlinedButton("Применить", on_click=self._apply_filters)], wrap=True),
        ]
        if self.message.value:
            controls.append(self.message)
        controls.extend([
            ft.Text(
                f"Найдено результатов: {len(rows)} | "
                f"Пройдено: {passed_count} | Не пройдено: {failed_count}"
            ),
            ft.DataTable(
                columns=[
                    ft.DataColumn(ft.Text("ID")),
                    ft.DataColumn(ft.Text("Сотрудник")),
                    ft.DataColumn(ft.Text("Верных")),
                    ft.DataColumn(ft.Text("Всего")),
                    ft.DataColumn(ft.Text("%")),
                    ft.DataColumn(ft.Text("Статус")),
                    ft.DataColumn(ft.Text("Дата")),
                    ft.DataColumn(ft.Text("Sync")),
                ],
                rows=rows,
            ),
        ])
        return ft.View(
            route="/admin/results",
            controls=build_shell("Все результаты", controls, page=self.page),
        )
