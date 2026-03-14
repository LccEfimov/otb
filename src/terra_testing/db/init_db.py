from terra_testing.db.base import Base
from terra_testing.db.session import get_local_engine

# import models for metadata registration
from terra_testing.models import audit_log, question, role, schedule, sync_queue, system_setting, test_result, user  # noqa: F401


def init_db() -> None:
    Base.metadata.create_all(bind=get_local_engine())
