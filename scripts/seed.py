from __future__ import annotations

from collections.abc import Iterable

from terra_testing.config.settings import get_settings
from terra_testing.db.session import get_local_session
from terra_testing.models.answer import Answer
from terra_testing.models.question import Question, QuestionCategory
from terra_testing.models.role import Role
from terra_testing.models.schedule import TestAssignment
from terra_testing.models.user import User
from terra_testing.utils.security import hash_password, verify_password

TOTAL_USERS = 17
TOTAL_QUESTIONS = 160

USER_SEED = [
    ("admin", "Администратор системы", "admin"),
    ("user01", "Демо пользователь 01", "user"),
    ("user02", "Демо пользователь 02", "user"),
    ("user03", "Демо пользователь 03", "user"),
    ("user04", "Демо пользователь 04", "user"),
    ("user05", "Демо пользователь 05", "user"),
    ("user06", "Демо пользователь 06", "user"),
    ("user07", "Демо пользователь 07", "user"),
    ("user08", "Демо пользователь 08", "user"),
    ("user09", "Демо пользователь 09", "user"),
    ("user10", "Демо пользователь 10", "user"),
    ("user11", "Демо пользователь 11", "user"),
    ("user12", "Демо пользователь 12", "user"),
    ("user13", "Демо пользователь 13", "user"),
    ("user14", "Демо пользователь 14", "user"),
    ("user15", "Демо пользователь 15", "user"),
    ("user16", "Демо пользователь 16", "user"),
]

QUESTION_TOPICS = {
    "Охрана труда": ["инструктаж", "СИЗ", "план эвакуации", "допуск"],
    "Геодезия": ["теодолит", "нивелирование", "репер", "погрешность"],
    "Электробезопасность": ["заземление", "блокировка", "наряд-допуск", "напряжение"],
    "Промышленная безопасность": ["риски", "инцидент", "регламент", "контроль"],
    "Пожарная безопасность": ["огнетушитель", "эвакуация", "датчик", "возгорание"],
    "Строительные нормы": ["СНиП", "допуски", "приёмка", "материалы"],
    "Проектирование": ["чертёж", "спецификация", "изменение", "версия"],
    "Качество и аудит": ["чек-лист", "несоответствие", "корректировка", "проверка"],
}


def build_question_seed() -> list[tuple[str, str, list[tuple[str, bool]]]]:
    seed: list[tuple[str, str, list[tuple[str, bool]]]] = []
    questions_per_category = TOTAL_QUESTIONS // len(QUESTION_TOPICS)
    for category_name, topics in QUESTION_TOPICS.items():
        for index in range(1, questions_per_category + 1):
            topic = topics[(index - 1) % len(topics)]
            question_text = (
                f"[{category_name}] Вопрос {index:03d}: какое действие наиболее корректно для темы '{topic}'?"
            )
            correct_option = (index % 4) + 1
            answers = [
                (f"Вариант 1: игнорировать требования по теме '{topic}'", correct_option == 1),
                (f"Вариант 2: выполнить только часть требований по теме '{topic}'", correct_option == 2),
                (f"Вариант 3: выполнить требования по теме '{topic}' согласно регламенту", correct_option == 3),
                (f"Вариант 4: передать задачу без фиксации статуса по теме '{topic}'", correct_option == 4),
            ]
            seed.append((category_name, question_text, answers))
    return seed


def _sync_answers(question: Question, answer_seed: Iterable[tuple[str, bool]]) -> None:
    expected_answers = [(text, is_correct) for text, is_correct in answer_seed]
    current_answers = [(answer.text, answer.is_correct) for answer in question.answers]
    if current_answers == expected_answers:
        return

    question.answers.clear()
    for answer_text, is_correct in expected_answers:
        question.answers.append(Answer(text=answer_text, is_correct=is_correct))


def main() -> None:
    settings = get_settings()
    question_seed = build_question_seed()

    with get_local_session() as session:
        def upsert_user(*, username: str, full_name: str, password: str, role_id: int) -> User:
            existing_user = session.query(User).filter_by(username=username).one_or_none()
            if existing_user is None:
                existing_user = User(
                    username=username,
                    full_name=full_name,
                    password_hash=hash_password(password),
                    is_active=True,
                    role_id=role_id,
                )
                session.add(existing_user)
                return existing_user

            existing_user.full_name = full_name
            existing_user.is_active = True
            existing_user.role_id = role_id
            if not verify_password(password, existing_user.password_hash):
                existing_user.password_hash = hash_password(password)
            return existing_user

        admin_role = session.query(Role).filter_by(name="admin").one_or_none()
        user_role = session.query(Role).filter_by(name="user").one_or_none()

        if admin_role is None:
            admin_role = Role(name="admin")
            session.add(admin_role)

        if user_role is None:
            user_role = Role(name="user")
            session.add(user_role)

        session.flush()

        for username, full_name, role_name in USER_SEED:
            role_id = admin_role.id if role_name == "admin" else user_role.id
            if username == "admin":
                password = settings.seed_admin_password
            elif username == "user01":
                password = settings.seed_user_password
            else:
                password = f"User{username[-2:]}123!"

            upsert_user(
                username=username,
                full_name=full_name,
                password=password,
                role_id=role_id,
            )

        # Respect env overrides for primary demo accounts.
        if settings.seed_admin_login != "admin":
            upsert_user(
                username=settings.seed_admin_login,
                full_name="Администратор системы",
                password=settings.seed_admin_password,
                role_id=admin_role.id,
            )

        if settings.seed_user_login != "user01":
            upsert_user(
                username=settings.seed_user_login,
                full_name="Тестовый пользователь",
                password=settings.seed_user_password,
                role_id=user_role.id,
            )

        session.flush()

        categories: dict[str, QuestionCategory] = {}
        for category_name in QUESTION_TOPICS:
            category = session.query(QuestionCategory).filter_by(name=category_name).one_or_none()
            if category is None:
                category = QuestionCategory(name=category_name)
                session.add(category)
                session.flush()
            category.is_active = True
            categories[category_name] = category

        for category_name, question_text, answers in question_seed:
            question = session.query(Question).filter_by(text=question_text).one_or_none()
            if question is None:
                question = Question(
                    category_id=categories[category_name].id,
                    text=question_text,
                    difficulty=1,
                    is_active=True,
                )
                session.add(question)
                session.flush()
            else:
                question.category_id = categories[category_name].id
                question.difficulty = 1
                question.is_active = True

            _sync_answers(question, answers)

        demo_user = session.query(User).filter_by(username="user01").one()
        existing_assignment = session.query(TestAssignment).filter_by(
            user_id=demo_user.id,
            title="Демо-тестирование",
        ).one_or_none()
        if existing_assignment is None:
            session.add(
                TestAssignment(
                    user_id=demo_user.id,
                    title="Демо-тестирование",
                    questions_count=min(len(question_seed), settings.questions_per_test),
                    max_attempts=settings.max_attempts,
                )
            )
        else:
            existing_assignment.questions_count = min(len(question_seed), settings.questions_per_test)
            existing_assignment.max_attempts = settings.max_attempts

        session.commit()

    print(
        f"Seed completed. Users baseline: >={TOTAL_USERS}, questions baseline: {TOTAL_QUESTIONS}."
    )


if __name__ == "__main__":
    main()
