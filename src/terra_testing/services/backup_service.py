from __future__ import annotations

import shutil
from datetime import datetime
from pathlib import Path

from terra_testing.config.settings import get_settings


class BackupService:
    def __init__(self) -> None:
        self.settings = get_settings()

    def _db_path(self) -> Path:
        db_url = self.settings.local_db_url
        if not db_url.startswith('sqlite:///'):
            raise ValueError('BackupService supports only SQLite URLs.')
        return Path(db_url.replace('sqlite:///', '', 1))

    def create_backup(self) -> Path:
        source = self._db_path()
        if not source.exists():
            raise FileNotFoundError(source)
        target = self.settings.backup_dir / f'training_system_{datetime.now():%Y%m%d_%H%M%S}.db'
        shutil.copy2(source, target)
        return target

    def list_backups(self) -> list[Path]:
        return sorted(self.settings.backup_dir.glob('*.db'), reverse=True)

    def restore_backup(self, backup_path: str | Path) -> Path:
        source = Path(backup_path)
        if not source.exists():
            raise FileNotFoundError(source)
        target = self._db_path()
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        return target
