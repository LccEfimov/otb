from __future__ import annotations

import pytest

from terra_testing.config.settings import reset_settings_cache
from terra_testing.db.session import reset_engines


@pytest.fixture(autouse=True)
def isolate_test_database(tmp_path, monkeypatch):
    db_path = tmp_path / "test.db"
    monkeypatch.setenv("LOCAL_DB_URL", f"sqlite:///{db_path}")
    monkeypatch.setenv("REMOTE_SYNC_ENABLED", "false")
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("APP_DEBUG", "false")
    reset_settings_cache()
    reset_engines()
    yield
    reset_settings_cache()
    reset_engines()
