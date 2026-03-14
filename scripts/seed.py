from __future__ import annotations

from terra_testing.config.settings import get_settings
from terra_testing.db.session import get_local_session
from terra_testing.models.answer import Answer
from terra_testing.models.question import Question, QuestionCategory
from terra_testing.models.role import Role
from terra_testing.models.schedule import TestAssignment
from terra_testing.models.user import User
from terra_testing.utils.security import hash_password


QUESTION_SEED = [
    (
        "Охрана труда",
        "Какое действие нужно выполнить перед началом работ на объекте?",
        [
            ("Пройти инструктаж по технике безопасности", True),
            ("Сразу приступить к работам", False),
            ("Пропустить проверку оборудования", False),
            ("Отключить связь", False),
        ],
    ),
    (
        "Геодезия",
        "Какой прибор применяется для измерения горизонтальных и вертикальных углов?",
        [
            ("Теодолит", True),
            ("Штангенциркуль", False),
            ("Мультиметр", False),
            ("Компас", False),
        ],
    ),
    (
        "Охрана труда",
        "Что необходимо сделать при обнаружении неисправности инструмента?",
        [
            ("Сообщить ответственному и прекратить работу", True),
            ("Продолжить работу", False),
            ("Скрыть неисправность", False),
            ("Передать без предупреждения другому сотруднику", False),
        ],
    ),
]


def main() -> None:
    settings = get_settings()

    with get_local_session() as session:
        admin_role = session.query(Role).filter_by(name="admin").one_or_none()
        user_role = session.query(Role).filter_by(name="user").one_or_none()

        if admin_role is None:
            admin_role = Role(name="admin")
            session.add(admin_role)

        if user_role is None:
            user_role = Role(name="user")
            session.add(user_role)

        session.flush()

        admin_user = session.query(User).filter_by(username=settings.seed_admin_login).one_or_none()
        if admin_user is None:
            admin_user = User(
                username=settings.seed_admin_login,
                full_name="Администратор системы",
                password_hash=hash_password(settings.seed_admin_password),
                is_active=True,
                role_id=admin_role.id,
            )
            session.add(admin_user)

        demo_user = session.query(User).filter_by(username=settings.seed_user_login).one_or_none()
        if demo_user is None:
            demo_user = User(
                username=settings.seed_user_login,
                full_name="Тестовый пользователь",
                password_hash=hash_password(settings.seed_user_password),
                is_active=True,
                role_id=user_role.id,
            )
            session.add(demo_user)

        session.flush()

        categories: dict[str, QuestionCategory] = {}
        for category_name, question_text, answers in QUESTION_SEED:
            category = session.query(QuestionCategory).filter_by(name=category_name).one_or_none()
            if category is None:
                category = QuestionCategory(name=category_name)
                session.add(category)
                session.flush()
            categories[category_name] = category

            existing_question = session.query(Question).filter_by(text=question_text).one_or_none()
            if existing_question is None:
                question = Question(category_id=category.id, text=question_text)
                session.add(question)
                session.flush()
                for answer_text, is_correct in answers:
                    session.add(Answer(question_id=question.id, text=answer_text, is_correct=is_correct))

        session.flush()

        existing_assignment = session.query(TestAssignment).filter_by(
            user_id=demo_user.id,
            title="Демо-тестирование",
        ).one_or_none()
        if existing_assignment is None:
            session.add(
                TestAssignment(
                    user_id=demo_user.id,
                    title="Демо-тестирование",
                    questions_count=min(len(QUESTION_SEED), settings.questions_per_test),
                    max_attempts=settings.max_attempts,
                )
            )

        session.commit()

    print("Seed completed.")


if __name__ == "__main__":
    main()
