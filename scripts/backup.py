from __future__ import annotations

import shutil
from datetime import datetime
from pathlib import Path

from terra_testing.config.settings import get_settings


def _sqlite_path_from_url(db_url: str) -> Path:
    if db_url.startswith("sqlite:///"):
        raw = db_url.replace("sqlite:///", "", 1)
        return Path(raw)
    raise ValueError("Only sqlite:/// URLs are supported by backup.py")


def main() -> None:
    settings = get_settings()
    source = _sqlite_path_from_url(settings.local_db_url)

    if not source.exists():
        raise FileNotFoundError(f"SQLite file not found: {source}")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    target = settings.backup_dir / f"training_system_{timestamp}.db"
    shutil.copy2(source, target)
    print(f"Backup created: {target}")


if __name__ == "__main__":
    main()
