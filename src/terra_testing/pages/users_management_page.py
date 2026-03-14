from __future__ import annotations

import flet as ft

from terra_testing.app.access import actor_name, require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.services.audit_service import AuditService
from terra_testing.services.user_service import UserService


class UsersManagementPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.user_service = UserService()
        self.audit_service = AuditService()
        self.full_name = ft.TextField(label="ФИО", width=320)
        self.username = ft.TextField(label="Логин", width=220)
        self.password = ft.TextField(label="Пароль", password=True, can_reveal_password=True, width=220)
        self.role_dropdown = ft.Dropdown(label="Роль", width=180)
        self.message = ft.Text()

    def _is_admin(self) -> bool:
        return require_admin(self.page, "Управление пользователями", "/admin/users") is None

    def _edit_user_id(self) -> int | None:
        value = self.page.session.get("edit_user_id")
        return int(value) if value not in {None, ""} else None

    def _set_message(self, text: str, ok: bool) -> None:
        self.message.value = text
        self.message.color = ft.Colors.GREEN if ok else ft.Colors.RED
        self.page.update()

    def _refresh_roles(self) -> None:
        roles = self.user_service.list_roles()
        self.role_dropdown.options = [ft.dropdown.Option(str(role.id), role.name) for role in roles]
        if roles and self.role_dropdown.value is None:
            self.role_dropdown.value = str(roles[0].id)

    def _load_edit_state(self) -> None:
        edit_user_id = self._edit_user_id()
        if not edit_user_id:
            return
        user = self.user_service.get_user(edit_user_id)
        if user is None:
            self.page.session.set("edit_user_id", None)
            return
        self.full_name.value = user.full_name
        self.username.value = user.username
        self.username.disabled = True
        self.password.disabled = True
        self.password.value = ""
        self.role_dropdown.value = str(user.role_id)

    def _reset_form(self) -> None:
        self.page.session.set("edit_user_id", None)
        self.full_name.value = ""
        self.username.value = ""
        self.username.disabled = False
        self.password.value = ""
        self.password.disabled = False
        self.role_dropdown.value = self.role_dropdown.options[0].key if self.role_dropdown.options else None

    def _save_user(self, _: ft.ControlEvent) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для изменения пользователей", False)
            return
        if not self.full_name.value or not self.username.value or not self.role_dropdown.value:
            self._set_message("Заполните обязательные поля пользователя", False)
            return

        edit_user_id = self._edit_user_id()
        actor = actor_name(self.page)

        if edit_user_id is None:
            if not self.password.value:
                self._set_message("Введите пароль для нового пользователя", False)
                return
            user = self.user_service.create_user(
                username=self.username.value.strip(),
                full_name=self.full_name.value.strip(),
                password=self.password.value,
                role_id=int(self.role_dropdown.value),
            )
            self.audit_service.log("user_created", actor, f"Создан пользователь {user.username}")
            self._reset_form()
            self.page.go("/admin/users")
            return

        user = self.user_service.update_user(
            user_id=edit_user_id,
            full_name=self.full_name.value.strip(),
            role_id=int(self.role_dropdown.value),
        )
        if user is None:
            self._set_message("Пользователь не найден", False)
            return
        self.audit_service.log("user_updated", actor, f"Обновлён пользователь {user.username}")
        self._reset_form()
        self.page.go("/admin/users")

    def _start_edit(self, user_id: int) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для редактирования", False)
            return
        self.page.session.set("edit_user_id", user_id)
        self.page.go("/admin/users")

    def _cancel_edit(self, _: ft.ControlEvent) -> None:
        self._reset_form()
        self.page.go("/admin/users")

    def _toggle_active(self, user_id: int, is_active: bool) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для изменения статуса", False)
            return
        user = self.user_service.set_active(user_id, not is_active)
        if user is not None:
            action = "активирован" if user.is_active else "деактивирован"
            self.audit_service.log("user_status_changed", actor_name(self.page), f"Пользователь {user.username} {action}")
        self.page.go("/admin/users")

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Управление пользователями", "/admin/users")
        if denied is not None:
            return denied

        self._refresh_roles()
        self._load_edit_state()

        rows = []
        for user in self.user_service.list_users():
            action_label = "Отключить" if user.is_active else "Включить"
            rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Text(str(user.id))),
                        ft.DataCell(ft.Text(user.full_name)),
                        ft.DataCell(ft.Text(user.username)),
                        ft.DataCell(ft.Text(user.role.name if user.role else "")),
                        ft.DataCell(ft.Text("Да" if user.is_active else "Нет")),
                        ft.DataCell(
                            ft.Row(
                                controls=[
                                    ft.TextButton("Редактировать", on_click=lambda _, uid=user.id: self._start_edit(uid)),
                                    ft.TextButton(action_label, on_click=lambda _, uid=user.id, active=user.is_active: self._toggle_active(uid, active)),
                                ],
                                wrap=True,
                            )
                        ),
                    ]
                )
            )

        edit_mode = self._edit_user_id() is not None
        save_label = "Сохранить изменения" if edit_mode else "Создать"
        title = "Редактировать пользователя" if edit_mode else "Создать пользователя"

        return ft.View(
            route="/admin/users",
            controls=build_shell(
                "Управление пользователями",
                [
                    ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
                    ft.Card(
                        content=ft.Container(
                            padding=16,
                            content=ft.Column(
                                controls=[
                                    ft.Text(title, weight=ft.FontWeight.BOLD),
                                    ft.ResponsiveRow(
                                        controls=[
                                            ft.Container(self.full_name, col={"sm": 12, "md": 4}),
                                            ft.Container(self.username, col={"sm": 12, "md": 3}),
                                            ft.Container(self.password, col={"sm": 12, "md": 3}),
                                            ft.Container(self.role_dropdown, col={"sm": 12, "md": 2}),
                                        ]
                                    ),
                                    ft.Row(
                                        [
                                            ft.FilledButton(save_label, on_click=self._save_user),
                                            ft.OutlinedButton("Сбросить", on_click=self._cancel_edit),
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
                            ft.DataColumn(ft.Text("ID")),
                            ft.DataColumn(ft.Text("ФИО")),
                            ft.DataColumn(ft.Text("Логин")),
                            ft.DataColumn(ft.Text("Роль")),
                            ft.DataColumn(ft.Text("Активен")),
                            ft.DataColumn(ft.Text("Действия")),
                        ],
                        rows=rows,
                    ),
                ],
                page=self.page,
            ),
        )
