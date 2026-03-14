from __future__ import annotations

import flet as ft

from terra_testing.app.access import require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.components.stat_card import StatCard
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.services.question_service import QuestionService
from terra_testing.services.schedule_service import ScheduleService
from terra_testing.services.user_service import UserService


class AdminDashboardPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.user_service = UserService()
        self.question_service = QuestionService()
        self.schedule_service = ScheduleService()
        self.result_repository = ResultRepository()

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Панель администратора", "/admin")
        if denied is not None:
            return denied

        pending_total = self.result_repository.count_pending_sync() + self.result_repository.count_failed_sync()
        return ft.View(
            route="/admin",
            controls=build_shell(
                "Панель администратора",
                [
                    ft.ResponsiveRow(
                        controls=[
                            ft.Container(content=StatCard("Пользователи", str(self.user_service.count_users())), col={"sm": 6, "md": 3}),
                            ft.Container(content=StatCard("Активные вопросы", str(self.question_service.count_questions())), col={"sm": 6, "md": 3}),
                            ft.Container(content=StatCard("Активные назначения", str(self.schedule_service.count_active_assignments())), col={"sm": 6, "md": 3}),
                            ft.Container(content=StatCard("Pending sync", str(pending_total)), col={"sm": 6, "md": 3}),
                        ]
                    ),
                    ft.Row(
                        controls=[
                            ft.FilledButton("Пользователи", on_click=lambda _: self.page.go("/admin/users")),
                            ft.FilledButton("Вопросы", on_click=lambda _: self.page.go("/admin/questions")),
                            ft.FilledButton("Расписание", on_click=lambda _: self.page.go("/admin/schedule")),
                            ft.FilledButton("Результаты", on_click=lambda _: self.page.go("/admin/results")),
                            ft.FilledButton("Синхронизация", on_click=lambda _: self.page.go("/admin/sync")),
                            ft.FilledButton("Аудит", on_click=lambda _: self.page.go("/admin/audit")),
                            ft.FilledButton("Отчёты", on_click=lambda _: self.page.go("/reports")),
                            ft.FilledButton("Настройки", on_click=lambda _: self.page.go("/settings")),
                        ],
                        wrap=True,
                    ),
                ],
                page=self.page,
            ),
        )
