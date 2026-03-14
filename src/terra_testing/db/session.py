from __future__ import annotations

from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from terra_testing.config.settings import get_settings


@lru_cache(maxsize=4)
def _engine_for_url(db_url: str, echo: bool) -> Engine:
    return create_engine(db_url, future=True, echo=echo)


@lru_cache(maxsize=4)
def _session_factory_for_url(db_url: str, echo: bool) -> sessionmaker[Session]:
    return sessionmaker(
        bind=_engine_for_url(db_url, echo),
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
        class_=Session,
    )


def get_local_engine() -> Engine:
    settings = get_settings()
    return _engine_for_url(settings.local_db_url, settings.app_debug)


def get_local_session() -> Session:
    settings = get_settings()
    factory = _session_factory_for_url(settings.local_db_url, settings.app_debug)
    return factory()


def get_remote_engine() -> Engine | None:
    settings = get_settings()
    if not settings.remote_sync_enabled or not settings.remote_db_url:
        return None
    return _engine_for_url(settings.remote_db_url, False)


def reset_engines() -> None:
    _session_factory_for_url.cache_clear()
    _engine_for_url.cache_clear()
