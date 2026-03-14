from __future__ import annotations

import shutil
import sys
from pathlib import Path

from terra_testing.config.settings import get_settings


def _sqlite_path_from_url(db_url: str) -> Path:
    if db_url.startswith("sqlite:///"):
        raw = db_url.replace("sqlite:///", "", 1)
        return Path(raw)
    raise ValueError("Only sqlite:/// URLs are supported by restore.py")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/restore.py <backup_file>")

    settings = get_settings()
    backup_file = Path(sys.argv[1])

    if not backup_file.exists():
        raise FileNotFoundError(f"Backup file not found: {backup_file}")

    target = _sqlite_path_from_url(settings.local_db_url)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(backup_file, target)
    print(f"Restore completed: {target}")


if __name__ == "__main__":
    main()
