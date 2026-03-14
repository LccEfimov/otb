from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    app_name: str = Field(default="TerraTesting", alias="APP_NAME")
    app_env: str = Field(default="development", alias="APP_ENV")
    app_debug: bool = Field(default=True, alias="APP_DEBUG")
    app_language: str = Field(default="ru", alias="APP_LANGUAGE")

    local_db_enabled: bool = Field(default=True, alias="LOCAL_DB_ENABLED")
    local_db_url: str = Field(default="sqlite:///./data/training_system.db", alias="LOCAL_DB_URL")

    remote_sync_enabled: bool = Field(default=False, alias="REMOTE_SYNC_ENABLED")
    remote_db_url: str = Field(default="", alias="REMOTE_DB_URL")

    questions_per_test: int = Field(default=20, alias="QUESTIONS_PER_TEST")
    pass_percent: int = Field(default=70, alias="PASS_PERCENT")
    seconds_per_question: int = Field(default=30, alias="SECONDS_PER_QUESTION")
    max_attempts: int = Field(default=3, alias="MAX_ATTEMPTS")

    export_dir: Path = Field(default=Path("./data/exports"), alias="EXPORT_DIR")
    backup_dir: Path = Field(default=Path("./data/backup"), alias="BACKUP_DIR")
    log_dir: Path = Field(default=Path("./logs"), alias="LOG_DIR")

    seed_admin_login: str = Field(default="admin", alias="SEED_ADMIN_LOGIN")
    seed_admin_password: str = Field(default="Admin123!", alias="SEED_ADMIN_PASSWORD")
    seed_user_login: str = Field(default="user01", alias="SEED_USER_LOGIN")
    seed_user_password: str = Field(default="User123!", alias="SEED_USER_PASSWORD")

    sync_retry_limit: int = Field(default=3, alias="SYNC_RETRY_LIMIT")
    sync_after_login: bool = Field(default=True, alias="SYNC_AFTER_LOGIN")
    sync_after_test_completion: bool = Field(default=True, alias="SYNC_AFTER_TEST_COMPLETION")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    settings = Settings()
    settings.export_dir.mkdir(parents=True, exist_ok=True)
    settings.backup_dir.mkdir(parents=True, exist_ok=True)
    settings.log_dir.mkdir(parents=True, exist_ok=True)
    Path("./data").mkdir(parents=True, exist_ok=True)
    return settings


def reset_settings_cache() -> None:
    get_settings.cache_clear()
