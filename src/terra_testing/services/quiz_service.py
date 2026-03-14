from __future__ import annotations

from terra_testing.config.settings import get_settings
from terra_testing.repositories.question_repository import QuestionRepository
from terra_testing.repositories.result_repository import ResultRepository
from terra_testing.repositories.schedule_repository import ScheduleRepository
from terra_testing.services.audit_service import AuditService
from terra_testing.sync.sync_service import SyncService
from terra_testing.utils.time import utcnow


class QuizService:
    # Правило v1.0: назначение автоматически завершается только при исчерпании
    # лимита попыток. Отдельные политики (например, "завершать при passed")
    # должны быть явно добавлены как отдельное бизнес-правило.
    ASSIGNMENT_COMPLETION_POLICY = 'attempts_exhausted_only'

    def __init__(self) -> None:
        self.settings = get_settings()
        self.question_repository = QuestionRepository()
        self.result_repository = ResultRepository()
        self.schedule_repository = ScheduleRepository()
        self.sync_service = SyncService()
        self.audit_service = AuditService()

    def start_quiz(self, user_id: int, assignment_id: int | None = None) -> dict:
        limit = self.settings.questions_per_test
        if assignment_id is not None:
            assignment = self.schedule_repository.get_assignment(assignment_id)
            if assignment is None:
                raise ValueError('Назначение не найдено')
            if assignment.user_id != user_id:
                raise ValueError('Назначение принадлежит другому пользователю')
            if assignment.status == 'completed':
                raise ValueError('Назначение уже завершено')
            if assignment.due_at and assignment.due_at < utcnow().replace(tzinfo=None):
                raise ValueError('Срок выполнения назначения истёк')
            attempts = self.result_repository.count_attempts_for_assignment(user_id, assignment_id)
            if attempts >= assignment.max_attempts:
                raise ValueError('Превышен лимит попыток для назначенного теста')
            limit = assignment.questions_count

        questions = self.question_repository.random_questions(limit)
        return {
            'assignment_id': assignment_id,
            'questions': questions,
            'total_questions': len(questions),
            'seconds_per_question': self.settings.seconds_per_question,
        }

    def calculate_result(self, answers: list[dict]) -> dict:
        total = len(answers)
        correct = sum(1 for item in answers if item['is_correct'])
        score_percent = int((correct / total) * 100) if total else 0
        status = 'passed' if score_percent >= self.settings.pass_percent else 'failed'
        return {
            'correct_answers': correct,
            'total_questions': total,
            'score_percent': score_percent,
            'status': status,
        }

    def build_answer_payload(self, questions, selected_answer_ids: dict[int, int | None]) -> list[dict]:
        payload: list[dict] = []
        for question in questions:
            selected_answer_id = selected_answer_ids.get(question.id)
            correct_answer_ids = {answer.id for answer in question.answers if answer.is_correct}
            payload.append(
                {
                    'question_id': question.id,
                    'selected_answer_id': selected_answer_id,
                    'is_correct': selected_answer_id in correct_answer_ids,
                }
            )
        return payload

    def complete_quiz_from_selection(
        self,
        *,
        user_id: int,
        questions,
        selected_answer_ids: dict[int, int | None],
        assignment_id: int | None,
    ):
        answers = self.build_answer_payload(questions, selected_answer_ids)
        result = self.complete_quiz(user_id=user_id, assignment_id=assignment_id, answers=answers)
        if assignment_id is not None:
            attempts = self.result_repository.count_attempts_for_assignment(user_id, assignment_id)
            assignment = self.schedule_repository.get_assignment(assignment_id)
            if assignment is not None and attempts >= assignment.max_attempts:
                self.schedule_repository.mark_completed(assignment_id)
        return result

    def complete_quiz(self, *, user_id: int, assignment_id: int | None, answers: list[dict]):
        if assignment_id is not None:
            attempts = self.result_repository.count_attempts_for_assignment(user_id, assignment_id)
            assignment = self.schedule_repository.get_assignment(assignment_id)
            if assignment is not None and attempts >= assignment.max_attempts:
                raise ValueError('Превышен лимит попыток для назначенного теста')

        result_payload = self.calculate_result(answers)
        result = self.result_repository.create_result(
            user_id=user_id,
            assignment_id=assignment_id,
            answers=answers,
            **result_payload,
        )
        self.audit_service.log('quiz_completed', str(user_id), f'Завершён тест result_id={result.id}, status={result.status}, score={result.score_percent}')
        if self.sync_service.settings.sync_after_test_completion:
            try:
                self.sync_service.sync_after_test_completion(result.id)
            except Exception:
                pass
        return result
