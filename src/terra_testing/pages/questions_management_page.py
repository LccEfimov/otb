from __future__ import annotations

import flet as ft

from terra_testing.app.access import actor_name, require_admin
from terra_testing.components.app_shell import build_shell
from terra_testing.services.audit_service import AuditService
from terra_testing.services.question_service import QuestionService


class QuestionsManagementPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.question_service = QuestionService()
        self.audit_service = AuditService()
        self.category_name = ft.TextField(label="Новая категория", width=260)
        self.category_dropdown = ft.Dropdown(label="Категория", width=220)
        self.question_text = ft.TextField(label="Текст вопроса", multiline=True, min_lines=2, max_lines=4, width=600)
        self.answer_1 = ft.TextField(label="Ответ 1", width=320)
        self.answer_2 = ft.TextField(label="Ответ 2", width=320)
        self.answer_3 = ft.TextField(label="Ответ 3", width=320)
        self.answer_4 = ft.TextField(label="Ответ 4", width=320)
        self.correct_index = ft.Dropdown(
            label="Правильный ответ",
            width=220,
            options=[ft.dropdown.Option("1"), ft.dropdown.Option("2"), ft.dropdown.Option("3"), ft.dropdown.Option("4")],
            value="1",
        )
        self.message = ft.Text()

    def _is_admin(self) -> bool:
        return require_admin(self.page, "Управление вопросами", "/admin/questions") is None

    def _edit_question_id(self) -> int | None:
        value = self.page.session.get("edit_question_id")
        return int(value) if value not in {None, ""} else None

    def _set_message(self, text: str, ok: bool) -> None:
        self.message.value = text
        self.message.color = ft.Colors.GREEN if ok else ft.Colors.RED
        self.page.update()

    def _answer_controls(self) -> list[ft.TextField]:
        return [self.answer_1, self.answer_2, self.answer_3, self.answer_4]

    def _refresh_categories(self) -> None:
        categories = self.question_service.list_categories()
        self.category_dropdown.options = [ft.dropdown.Option(str(category.id), category.name) for category in categories]
        if categories and self.category_dropdown.value is None:
            self.category_dropdown.value = str(categories[0].id)

    def _load_edit_state(self) -> None:
        question_id = self._edit_question_id()
        if not question_id:
            return
        question = self.question_service.get_question(question_id)
        if question is None:
            self.page.session.set("edit_question_id", None)
            return
        self.category_dropdown.value = str(question.category_id)
        self.question_text.value = question.text
        answers = list(question.answers)
        for control in self._answer_controls():
            control.value = ""
        correct_index = "1"
        for index, answer in enumerate(answers[:4], start=1):
            self._answer_controls()[index - 1].value = answer.text
            if answer.is_correct:
                correct_index = str(index)
        self.correct_index.value = correct_index

    def _reset_form(self) -> None:
        self.page.session.set("edit_question_id", None)
        self.question_text.value = ""
        for control in self._answer_controls():
            control.value = ""
        self.correct_index.value = "1"
        if self.category_dropdown.options:
            self.category_dropdown.value = self.category_dropdown.options[0].key

    def _build_answers(self) -> list[dict]:
        answers = []
        for index, control in enumerate(self._answer_controls(), start=1):
            text = (control.value or "").strip()
            if text:
                answers.append({"text": text, "is_correct": str(index) == self.correct_index.value})
        return answers

    def _create_category(self, _: ft.ControlEvent) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для создания категории", False)
            return
        name = (self.category_name.value or "").strip()
        if not name:
            self._set_message("Введите название категории", False)
            return
        category = self.question_service.create_category(name)
        self.audit_service.log("category_created", actor_name(self.page), f"Создана категория {category.name}")
        self.category_name.value = ""
        self.page.go("/admin/questions")

    def _save_question(self, _: ft.ControlEvent) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для сохранения вопроса", False)
            return
        if not self.category_dropdown.value or not self.question_text.value:
            self._set_message("Заполните категорию и текст вопроса", False)
            return

        answers = self._build_answers()
        if len(answers) < 2:
            self._set_message("Нужно минимум два варианта ответа", False)
            return
        if not any(answer["is_correct"] for answer in answers):
            self._set_message("Нужно выбрать правильный вариант ответа", False)
            return

        question_id = self._edit_question_id()
        actor = actor_name(self.page)
        if question_id is None:
            question = self.question_service.create_question(
                category_id=int(self.category_dropdown.value),
                text=self.question_text.value.strip(),
                answers=answers,
            )
            self.audit_service.log("question_created", actor, f"Создан вопрос #{question.id}")
        else:
            question = self.question_service.update_question(
                question_id=question_id,
                category_id=int(self.category_dropdown.value),
                text=self.question_text.value.strip(),
                answers=answers,
            )
            if question is None:
                self._set_message("Вопрос не найден", False)
                return
            self.audit_service.log("question_updated", actor, f"Обновлён вопрос #{question.id}")

        self._reset_form()
        self.page.go("/admin/questions")

    def _start_edit(self, question_id: int) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для редактирования", False)
            return
        self.page.session.set("edit_question_id", question_id)
        self.page.go("/admin/questions")

    def _cancel_edit(self, _: ft.ControlEvent) -> None:
        self._reset_form()
        self.page.go("/admin/questions")

    def _toggle_question_active(self, question_id: int, is_active: bool) -> None:
        if not self._is_admin():
            self._set_message("Недостаточно прав для изменения статуса", False)
            return
        question = self.question_service.set_question_active(question_id, not is_active)
        if question is not None:
            action = "активирован" if question.is_active else "деактивирован"
            self.audit_service.log("question_status_changed", actor_name(self.page), f"Вопрос #{question.id} {action}")
        self.page.go("/admin/questions")

    def build(self) -> ft.View:
        denied = require_admin(self.page, "Управление вопросами", "/admin/questions")
        if denied is not None:
            return denied

        self._refresh_categories()
        self._load_edit_state()

        rows = []
        for question in self.question_service.list_questions():
            action_label = "Отключить" if question.is_active else "Включить"
            rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Text(str(question.id))),
                        ft.DataCell(ft.Text(question.category.name if question.category else "")),
                        ft.DataCell(ft.Text(question.text[:80])),
                        ft.DataCell(ft.Text(str(len(question.answers)))),
                        ft.DataCell(ft.Text("Да" if question.is_active else "Нет")),
                        ft.DataCell(
                            ft.Row(
                                controls=[
                                    ft.TextButton("Редактировать", on_click=lambda _, qid=question.id: self._start_edit(qid)),
                                    ft.TextButton(action_label, on_click=lambda _, qid=question.id, active=question.is_active: self._toggle_question_active(qid, active)),
                                ],
                                wrap=True,
                            )
                        ),
                    ]
                )
            )

        categories = self.question_service.list_categories()
        category_rows = [
            ft.DataRow(cells=[
                ft.DataCell(ft.Text(str(category.id))),
                ft.DataCell(ft.Text(category.name)),
                ft.DataCell(ft.Text("Да" if category.is_active else "Нет")),
            ])
            for category in categories
        ]

        edit_mode = self._edit_question_id() is not None

        return ft.View(
            route="/admin/questions",
            controls=build_shell(
                "Управление вопросами",
                [
                    ft.OutlinedButton("Назад", on_click=lambda _: self.page.go("/admin")),
                    ft.Card(
                        content=ft.Container(
                            padding=16,
                            content=ft.Column(
                                controls=[
                                    ft.Text("Категории", weight=ft.FontWeight.BOLD),
                                    ft.Row([self.category_name, ft.FilledButton("Создать категорию", on_click=self._create_category)]),
                                    ft.DataTable(
                                        columns=[
                                            ft.DataColumn(ft.Text("ID")),
                                            ft.DataColumn(ft.Text("Категория")),
                                            ft.DataColumn(ft.Text("Активна")),
                                        ],
                                        rows=category_rows,
                                    ),
                                ]
                            ),
                        )
                    ),
                    ft.Card(
                        content=ft.Container(
                            padding=16,
                            content=ft.Column(
                                controls=[
                                    ft.Text("Редактировать вопрос" if edit_mode else "Новый вопрос", weight=ft.FontWeight.BOLD),
                                    ft.Row([self.category_dropdown, self.correct_index], wrap=True),
                                    self.question_text,
                                    ft.ResponsiveRow(
                                        controls=[
                                            ft.Container(self.answer_1, col={"sm": 12, "md": 6}),
                                            ft.Container(self.answer_2, col={"sm": 12, "md": 6}),
                                            ft.Container(self.answer_3, col={"sm": 12, "md": 6}),
                                            ft.Container(self.answer_4, col={"sm": 12, "md": 6}),
                                        ]
                                    ),
                                    ft.Row([
                                        ft.FilledButton("Сохранить вопрос", on_click=self._save_question),
                                        ft.OutlinedButton("Сбросить", on_click=self._cancel_edit),
                                        self.message,
                                    ], wrap=True),
                                ]
                            ),
                        )
                    ),
                    ft.DataTable(
                        columns=[
                            ft.DataColumn(ft.Text("ID")),
                            ft.DataColumn(ft.Text("Категория")),
                            ft.DataColumn(ft.Text("Вопрос")),
                            ft.DataColumn(ft.Text("Ответов")),
                            ft.DataColumn(ft.Text("Активен")),
                            ft.DataColumn(ft.Text("Действия")),
                        ],
                        rows=rows,
                    ),
                ],
                page=self.page,
            ),
        )
