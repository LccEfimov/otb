from __future__ import annotations

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.role import Role
from terra_testing.services.question_service import QuestionService
from terra_testing.services.quiz_service import QuizService
from terra_testing.services.report_service import ReportService
from terra_testing.services.user_service import UserService


def _prepare_data():
    with get_local_session() as session:
        role = Role(name='user')
        session.add(role)
        session.commit()
        session.refresh(role)
    user = UserService().create_user('user01', 'User', 'User123!', role.id)
    qservice = QuestionService()
    category = qservice.create_category('Охрана труда')
    question = qservice.create_question(
        category.id,
        'Вопрос',
        [
            {'text': 'Верный', 'is_correct': True},
            {'text': 'Неверный', 'is_correct': False},
        ],
    )
    answer_id = next(answer.id for answer in question.answers if answer.is_correct)
    result = QuizService().complete_quiz_from_selection(
        user_id=user.id,
        questions=[question],
        selected_answer_ids={question.id: answer_id},
        assignment_id=None,
    )
    return [{'full_name': user.full_name, 'score_percent': result.score_percent, 'status': result.status}]


def test_report_files_are_created(tmp_path, monkeypatch):
    monkeypatch.setenv('EXPORT_DIR', str(tmp_path / 'exports'))
    init_db()
    rows = _prepare_data()

    service = ReportService()
    pdf_path = service.export_results_pdf(rows)
    excel_path = service.export_results_excel(rows)

    assert pdf_path.exists()
    assert excel_path.exists()
