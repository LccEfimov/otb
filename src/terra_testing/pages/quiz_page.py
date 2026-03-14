from __future__ import annotations

import asyncio
import math
import time
import uuid

import flet as ft

from terra_testing.app.access import require_user
from terra_testing.app.session_state import SessionState
from terra_testing.components.app_shell import build_shell
from terra_testing.services.quiz_service import QuizService


class QuizPage:
    def __init__(self, page: ft.Page) -> None:
        self.page = page
        self.quiz_service = QuizService()
        self.message = ft.Text()
        self.timer_text = ft.Text()

    def _load_or_create_quiz_state(self) -> dict | None:
        quiz_state = self.page.session.get('quiz_state')
        active_assignment_id = self.page.session.get('active_assignment_id')
        state: SessionState = self.page.session.get('state')
        user_id = state.user_id if state and state.user_id is not None else 1

        if quiz_state and quiz_state.get('assignment_id') == active_assignment_id:
            return quiz_state

        try:
            start_payload = self.quiz_service.start_quiz(user_id=user_id, assignment_id=active_assignment_id)
        except ValueError as exc:
            self.message.value = str(exc)
            self.message.color = ft.Colors.RED
            return None

        quiz_state = {
            'assignment_id': active_assignment_id,
            'question_ids': [question.id for question in start_payload['questions']],
            'selected_answer_ids': {},
            'seconds_per_question': start_payload['seconds_per_question'],
            'current_index': 0,
            'current_question_id': None,
            'deadline_ts': None,
            'timer_token': None,
        }
        self.page.session.set('quiz_state', quiz_state)
        return quiz_state

    def _select_answer(self, question_id: int, value: str | None) -> None:
        quiz_state = self._load_or_create_quiz_state()
        if quiz_state is None:
            return
        quiz_state['selected_answer_ids'][question_id] = int(value) if value else None
        self.page.session.set('quiz_state', quiz_state)

    def _bump_timer(self, quiz_state: dict, question_id: int) -> dict:
        if quiz_state.get('current_question_id') != question_id:
            quiz_state['current_question_id'] = question_id
            quiz_state['deadline_ts'] = time.time() + int(quiz_state['seconds_per_question'])
            quiz_state['timer_token'] = uuid.uuid4().hex
            self.page.session.set('quiz_state', quiz_state)
        return quiz_state

    async def _countdown_task(self, token: str) -> None:
        while True:
            await asyncio.sleep(1)
            quiz_state = self.page.session.get('quiz_state')
            if not quiz_state or quiz_state.get('timer_token') != token:
                return
            if self.page.route != '/quiz':
                return
            deadline_ts = quiz_state.get('deadline_ts')
            if deadline_ts is None:
                return
            remaining = max(0, int(math.ceil(deadline_ts - time.time())))
            self.timer_text.value = f'Осталось времени: {remaining} сек.'
            try:
                self.page.update()
            except Exception:
                return
            if remaining <= 0:
                self._advance_on_timeout()
                return

    def _start_timer_task(self, token: str) -> None:
        try:
            self.page.run_task(self._countdown_task, token)
        except Exception:
            pass

    def _move_to_index(self, new_index: int) -> None:
        quiz_state = self._load_or_create_quiz_state()
        if quiz_state is None:
            return
        max_index = max(0, len(quiz_state['question_ids']) - 1)
        quiz_state['current_index'] = max(0, min(max_index, new_index))
        quiz_state['current_question_id'] = None
        quiz_state['deadline_ts'] = None
        quiz_state['timer_token'] = None
        self.page.session.set('quiz_state', quiz_state)
        self.page.go('/quiz')

    def _next_question(self, _: ft.ControlEvent) -> None:
        quiz_state = self._load_or_create_quiz_state()
        if quiz_state is None:
            return
        self._move_to_index(quiz_state.get('current_index', 0) + 1)

    def _prev_question(self, _: ft.ControlEvent) -> None:
        quiz_state = self._load_or_create_quiz_state()
        if quiz_state is None:
            return
        self._move_to_index(quiz_state.get('current_index', 0) - 1)

    def _finish_quiz(self) -> None:
        quiz_state = self._load_or_create_quiz_state()
        if quiz_state is None:
            self.page.go('/user')
            return
        state: SessionState = self.page.session.get('state')
        user_id = state.user_id if state and state.user_id is not None else 1
        questions = self.quiz_service.question_repository.get_questions_by_ids(quiz_state['question_ids'])

        result = self.quiz_service.complete_quiz_from_selection(
            user_id=user_id,
            questions=questions,
            selected_answer_ids=quiz_state['selected_answer_ids'],
            assignment_id=quiz_state.get('assignment_id'),
        )
        self.page.session.set('quiz_state', None)
        self.page.session.set('active_assignment_id', None)
        self.page.session.set('last_result_id', result.id)
        self.page.go('/results')

    def _submit_quiz(self, _: ft.ControlEvent) -> None:
        self._finish_quiz()

    def _advance_on_timeout(self) -> None:
        quiz_state = self.page.session.get('quiz_state')
        if not quiz_state:
            return
        current_index = quiz_state.get('current_index', 0)
        if current_index < len(quiz_state.get('question_ids', [])) - 1:
            self._move_to_index(current_index + 1)
        else:
            self._finish_quiz()

    def build(self) -> ft.View:
        denied = require_user(self.page, "Тестирование", "/quiz")
        if denied is not None:
            return denied
        quiz_state = self._load_or_create_quiz_state()
        controls: list[ft.Control] = []
        if self.message.value:
            controls.append(self.message)

        if quiz_state is None:
            controls.append(ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/user')))
            return ft.View(route='/quiz', controls=build_shell('Прохождение теста', controls, page=self.page))

        questions = self.quiz_service.question_repository.get_questions_by_ids(quiz_state['question_ids'])
        total_questions = len(questions)
        current_index = min(quiz_state.get('current_index', 0), max(0, total_questions - 1))
        quiz_state['current_index'] = current_index
        self.page.session.set('quiz_state', quiz_state)

        controls.extend([
            ft.Text(f'Вопрос {current_index + 1} из {total_questions}'),
            ft.Text(f'Норматив: {quiz_state["seconds_per_question"]} секунд на вопрос'),
        ])

        if not questions:
            controls.append(ft.Text('Нет доступных вопросов для теста.'))
            controls.append(ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/user')))
            return ft.View(route='/quiz', controls=build_shell('Прохождение теста', controls, page=self.page))

        question = questions[current_index]
        quiz_state = self._bump_timer(quiz_state, question.id)
        deadline_ts = quiz_state.get('deadline_ts')
        remaining = max(0, int(math.ceil(deadline_ts - time.time()))) if deadline_ts else int(quiz_state['seconds_per_question'])
        self.timer_text.value = f'Осталось времени: {remaining} сек.'
        if quiz_state.get('timer_token'):
            self._start_timer_task(quiz_state['timer_token'])

        selected_value = quiz_state['selected_answer_ids'].get(question.id)
        radio = ft.RadioGroup(
            value=str(selected_value) if selected_value is not None else None,
            content=ft.Column(controls=[ft.Radio(value=str(answer.id), label=answer.text) for answer in question.answers]),
            on_change=lambda e, question_id=question.id: self._select_answer(question_id, e.control.value),
        )
        controls.append(self.timer_text)
        controls.append(
            ft.Card(
                content=ft.Container(
                    padding=16,
                    content=ft.Column(
                        controls=[
                            ft.Text(question.text, weight=ft.FontWeight.BOLD),
                            radio,
                        ]
                    ),
                )
            )
        )

        nav = [ft.OutlinedButton('Назад', on_click=lambda _: self.page.go('/user'))]
        if current_index > 0:
            nav.append(ft.OutlinedButton('Предыдущий', on_click=self._prev_question))
        if current_index < total_questions - 1:
            nav.append(ft.FilledButton('Следующий', on_click=self._next_question))
        else:
            nav.append(ft.FilledButton('Завершить тест', on_click=self._submit_quiz))
        controls.append(ft.Row(nav, wrap=True))

        return ft.View(route='/quiz', controls=build_shell('Прохождение теста', controls, page=self.page))
