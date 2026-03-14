from __future__ import annotations

import flet as ft

from terra_testing.app.access import actor_name, require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.repositories.sync_queue_repository import SyncQueueRepository
from terra_testing.repositories.user_repository import UserRepository
from terra_testing.sync.sync_service import SyncService


class SyncMonitorPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.result_repository = ResultRepository()
        self.user_repository = UserRepository()
        self.sync_queue_repository = SyncQueueRepository()
        self.sync_service = SyncService()
        self.message = ft.Text()
        self.state_filter = ft.Dropdown(
            label="Показать",
            width=180,
            options=[
                ft.dropdown.Option("all", "Все"),
                ft.dropdown.Option("pending", "Pending"),
                ft.dropdown.Option("processing", "Processing"),
                ft.dropdown.Option("failed", "Failed"),
                ft.dropdown.Option("synced", "Synced"),
            ],
            value=page.session.get("sync_monitor_state_filter") or "all",
            on_change=self._apply_filter,
        )

    def _apply_filter(self, _: ft.ControlEvent) -> None:
        self.page.session.set("sync_monitor_state_filter", self.state_filter.value)
        self.page.go("/admin/sync")

    def _retry(self, _: ft.ControlEvent) -> None:
        summary = self.sync_service.retry_pending_sync(actor=actor_name(self.page))
        self.message.value = f"Повторная синхронизация: synced={summary['synced']}, failed={summary['failed']}"
        self.message.color = ft.Colors.GREEN if summary["failed"] == 0 else ft.Colors.ORANGE
        self.page.go("/admin/sync")

    def _retry_one(self, result_id: int) -> None:
        summary = self.sync_service.retry_result(result_id, actor=actor_name(self.page))
        self.message.value = f"Result #{result_id}: synced={summary['synced']}, failed={summary['failed']}"
        self.message.color = ft.Colors.GREEN if summary["failed"] == 0 else ft.Colors.ORANGE
        self.page.go("/admin/sync")

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Мониторинг синхронизации", "/admin/sync")
        if denied is not None:
            return denied

        users = {user.id: user for user in self.user_repository.list_users()}
        items = self.sync_queue_repository.list_items(status=self.state_filter.value or "all")

        rows = []
        for item in items:
            result = self.result_repository.get_result(item.entity_id) if item.entity_type == "test_result" else None
            user = users.get(result.user_id) if result is not None else None
            rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Text(str(item.id))),
                        ft.DataCell(ft.Text(item.entity_type)),
                        ft.DataCell(ft.Text(str(item.entity_id))),
                        ft.DataCell(ft.Text(user.full_name if user else "-")),
                        ft.DataCell(ft.Text(item.status)),
                        ft.DataCell(ft.Text(str(item.retry_count))),
                        ft.DataCell(ft.Text((item.last_error or "")[:80])),
                        ft.DataCell(ft.TextButton("Повторить", on_click=lambda _, rid=item.entity_id: self._retry_one(rid))),
                    ]
                )
            )

        return ft.View(
            route="/admin/sync",
            controls=build_shell(
                "Мониторинг синхронизации",
                [
                    ft.Row(
                        [
                            ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
                            self.state_filter,
                            ft.FilledButton("Повторить все", on_click=self._retry),
                        ],
                        wrap=True,
                    ),
                    self.message,
                    ft.Text(
                        f"Pending: {self.sync_queue_repository.count_by_status('pending')} | "
                        f"Failed: {self.sync_queue_repository.count_by_status('failed')} | "
                        f"Processing: {self.sync_queue_repository.count_by_status('processing')} | "
                        f"Synced: {self.sync_queue_repository.count_by_status('synced')}"
                    ),
                    ft.DataTable(
                        columns=[
                            ft.DataColumn(ft.Text("Queue ID")),
                            ft.DataColumn(ft.Text("Entity")),
                            ft.DataColumn(ft.Text("Entity ID")),
                            ft.DataColumn(ft.Text("Сотрудник")),
                            ft.DataColumn(ft.Text("Статус")),
                            ft.DataColumn(ft.Text("Retry")),
                            ft.DataColumn(ft.Text("Ошибка")),
                            ft.DataColumn(ft.Text("Действие")),
                        ],
                        rows=rows,
                    ),
                ],
                page=self.page,
            ),
        )
