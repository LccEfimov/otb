from __future__ import annotations

from datetime import datetime

import flet as ft

from terra_testing.app.access import require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.services.audit_service import AuditService
from terra_testing.services.report_service import ReportService


class AuditLogPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.audit_service = AuditService()
        self.report_service = ReportService()
        self.message = ft.Text()
        self.event_filter = ft.TextField(label="Тип события", width=180, value=page.session.get("audit_event_filter") or "")
        self.date_from = ft.TextField(label="С даты (YYYY-MM-DD)", width=180, value=page.session.get("audit_date_from") or "")
        self.date_to = ft.TextField(label="По дату (YYYY-MM-DD)", width=180, value=page.session.get("audit_date_to") or "")

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

    def _apply_filters(self, _: ft.ControlEvent | None = None) -> None:
        self.page.session.set("audit_event_filter", self.event_filter.value)
        self.page.session.set("audit_date_from", self.date_from.value)
        self.page.session.set("audit_date_to", self.date_to.value)
        self.page.go("/admin/audit")

    def _build_rows(self) -> list[dict]:
        rows = []
        day_from = self._parse_day(self.date_from.value)
        day_to = self._parse_day(self.date_to.value)
        for item in self.audit_service.list_filtered(
            event_type=(self.event_filter.value or "").strip() or None,
            day_from=day_from,
            day_to=day_to,
        ):
            rows.append(
                {
                    "id": item.id,
                    "created_at": item.created_at.strftime("%Y-%m-%d %H:%M"),
                    "event_type": item.event_type,
                    "actor": item.actor,
                    "message": item.message,
                }
            )
        return rows

    def _export_pdf(self, _: ft.ControlEvent) -> None:
        path = self.report_service.export_audit_pdf(self._build_rows())
        self.message.value = f"PDF сохранён: {path}"
        self.message.color = ft.Colors.GREEN
        self.page.update()

    def _export_excel(self, _: ft.ControlEvent) -> None:
        path = self.report_service.export_audit_excel(self._build_rows())
        self.message.value = f"Excel сохранён: {path}"
        self.message.color = ft.Colors.GREEN
        self.page.update()

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Журнал аудита", "/admin/audit")
        if denied is not None:
            return denied

        rows = [
            ft.DataRow(
                cells=[
                    ft.DataCell(ft.Text(str(item["id"]))),
                    ft.DataCell(ft.Text(item["created_at"])),
                    ft.DataCell(ft.Text(item["event_type"])),
                    ft.DataCell(ft.Text(item["actor"])),
                    ft.DataCell(ft.Text(item["message"][:120])),
                ]
            )
            for item in self._build_rows()
        ]

        return ft.View(
            route="/admin/audit",
            controls=build_shell(
                "Журнал аудита",
                [
                    ft.Row(
                        [
                            ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
                            self.event_filter,
                            self.date_from,
                            self.date_to,
                            ft.OutlinedButton("Применить", on_click=self._apply_filters),
                        ],
                        wrap=True,
                    ),
                    ft.Row(
                        [
                            ft.FilledButton("Экспорт PDF", on_click=self._export_pdf),
                            ft.FilledButton("Экспорт Excel", on_click=self._export_excel),
                        ]
                    ),
                    self.message,
                    ft.DataTable(
                        columns=[
                            ft.DataColumn(ft.Text("ID")),
                            ft.DataColumn(ft.Text("Дата")),
                            ft.DataColumn(ft.Text("Событие")),
                            ft.DataColumn(ft.Text("Актор")),
                            ft.DataColumn(ft.Text("Сообщение")),
                        ],
                        rows=rows,
                    ),
                ],
                page=self.page,
            ),
        )
