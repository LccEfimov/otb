from __future__ import annotations

import importlib.util
from pathlib import Path

from terra_testing.db.init_db import init_db
from terra_testing.db.session import get_local_session
from terra_testing.models.question import Question
from terra_testing.models.user import User


def _load_seed_module():
    seed_path = Path(__file__).resolve().parents[1] / "scripts" / "seed.py"
    spec = importlib.util.spec_from_file_location("seed", seed_path)
    module = importlib.util.module_from_spec(spec)
    assert spec is not None and spec.loader is not None
    spec.loader.exec_module(module)
    return module


seed = _load_seed_module()


def test_seed_creates_baseline_users_and_questions() -> None:
    init_db()

    seed.main()

    with get_local_session() as session:
        users_count = session.query(User).count()
        questions_count = session.query(Question).count()
        assert users_count >= seed.TOTAL_USERS
        assert questions_count >= seed.TOTAL_QUESTIONS

        for username in ("admin", "user01", "user16"):
            assert session.query(User).filter_by(username=username).one_or_none() is not None


def test_seed_is_idempotent_for_users_and_questions() -> None:
    init_db()

    seed.main()
    seed.main()

    with get_local_session() as session:
        assert session.query(User).count() >= seed.TOTAL_USERS
        assert session.query(Question).count() == seed.TOTAL_QUESTIONS
