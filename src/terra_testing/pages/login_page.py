from __future__ import annotations

import flet as ft

from terra_testing.app.session_state import SessionState
from terra_testing.services.auth_service import AuthService


class LoginPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.auth_service = AuthService()

        self.username = ft.TextField(label="Логин", autofocus=True, width=320)
        self.password = ft.TextField(label="Пароль", password=True, can_reveal_password=True, width=320)
        self.message = ft.Text(value="")

    def _handle_login(self, _: ft.ControlEvent) -> None:
        result = self.auth_service.login(
            username=self.username.value.strip(),
            password=self.password.value,
        )

        if result["success"]:
            self.page.session.set(
                "state",
                SessionState(
                    user_id=result["user_id"],
                    username=result["username"],
                    role=result["role"],
                    is_authenticated=True,
                ),
            )
            self.message.value = "Вход выполнен"
            self.message.color = ft.Colors.GREEN
            self.page.go("/admin" if result["role"] == "admin" else "/user")
        else:
            self.message.value = result["error"]
            self.message.color = ft.Colors.RED

        self.page.update()

    def build(self) -> ft.View:
        return ft.View(
            route="/login",
            controls=[
                ft.Container(
                    expand=True,
                    alignment=ft.alignment.center,
                    content=ft.Column(
                        controls=[
                            ft.Text("ИС тестирования знаний", size=28, weight=ft.FontWeight.BOLD),
                            self.username,
                            self.password,
                            ft.FilledButton("Войти", on_click=self._handle_login, width=320),
                            self.message,
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                )
            ],
        )
