from __future__ import annotations

import flet as ft

from terra_testing.app.access import actor_name, get_state
from terra_testing.components.app_shell import build_shell
from terra_testing.services.audit_service import AuditService
from terra_testing.services.backup_service import BackupService
from terra_testing.services.user_service import UserService


class SettingsPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.user_service = UserService()
        self.backup_service = BackupService()
        self.audit_service = AuditService()
        self.current_password = ft.TextField(label="Текущий пароль", password=True, can_reveal_password=True, width=280)
        self.new_password = ft.TextField(label="Новый пароль", password=True, can_reveal_password=True, width=280)
        self.message = ft.Text()
        self.backup_dropdown = ft.Dropdown(label="Резервная копия", width=420)

    def _refresh_backups(self) -> None:
        backups = self.backup_service.list_backups()
        self.backup_dropdown.options = [ft.dropdown.Option(str(path), path.name) for path in backups]
        if backups and not self.backup_dropdown.value:
            self.backup_dropdown.value = str(backups[0])

    def _change_password(self, _: ft.ControlEvent) -> None:
        state = get_state(self.page)
        if not state.user_id:
            self.message.value = "Пользователь не авторизован"
            self.message.color = ft.Colors.RED
            self.page.update()
            return

        success, message = self.user_service.change_password(
            state.user_id,
            (self.current_password.value or "").strip(),
            (self.new_password.value or "").strip(),
        )
        self.message.value = message
        self.message.color = ft.Colors.GREEN if success else ft.Colors.RED

        if success:
            self.audit_service.log("password_changed", actor_name(self.page), "Пароль изменён через настройки")
            self.current_password.value = ""
            self.new_password.value = ""

        self.page.update()

    def _create_backup(self, _: ft.ControlEvent) -> None:
        path = self.backup_service.create_backup()
        self.audit_service.log("backup_created", actor_name(self.page), f"Создан backup {path.name}")
        self._refresh_backups()
        self.message.value = f"Резервная копия создана: {path.name}"
        self.message.color = ft.Colors.GREEN
        self.page.update()

    def _restore_backup(self, _: ft.ControlEvent) -> None:
        if not self.backup_dropdown.value:
            self.message.value = "Выберите резервную копию"
            self.message.color = ft.Colors.RED
            self.page.update()
            return
        restored = self.backup_service.restore_backup(self.backup_dropdown.value)
        self.audit_service.log("backup_restored", actor_name(self.page), f"Восстановлена база {restored.name}")
        self.message.value = f"База восстановлена из: {self.backup_dropdown.value}"
        self.message.color = ft.Colors.GREEN
        self.page.update()

    def build(self) -> ft.View:
        state = get_state(self.page)
        is_admin = bool(state.role == "admin")
        self._refresh_backups()

        controls: list[ft.Control] = [
            ft.Card(
                content=ft.Container(
                    padding=16,
                    content=ft.Column(
                        controls=[
                            ft.Text("Смена пароля", weight=ft.FontWeight.BOLD),
                            self.current_password,
                            self.new_password,
                            ft.FilledButton("Сменить пароль", on_click=self._change_password),
                        ]
                    ),
                )
            ),
            self.message,
        ]

        if is_admin:
            controls.append(
                ft.Card(
                    content=ft.Container(
                        padding=16,
                        content=ft.Column(
                            controls=[
                                ft.Text("Резервные копии", weight=ft.FontWeight.BOLD),
                                ft.Row(
                                    controls=[
                                        ft.FilledButton("Создать backup", on_click=self._create_backup),
                                        self.backup_dropdown,
                                        ft.OutlinedButton("Восстановить", on_click=self._restore_backup),
                                    ],
                                    wrap=True,
                                ),
                            ]
                        ),
                    )
                )
            )

        return ft.View(route="/settings", controls=build_shell("Настройки", controls, page=self.page))
