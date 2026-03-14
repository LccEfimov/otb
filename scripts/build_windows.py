from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


def main() -> None:
    dist_dir = Path("dist")
    dist_dir.mkdir(parents=True, exist_ok=True)

    entrypoint = Path("src/terra_testing/main.py")
    if not entrypoint.exists():
        raise FileNotFoundError(f"Entrypoint not found: {entrypoint}")

    cmd = ["flet", "pack", str(entrypoint), "--name", "TerraTesting"]
    subprocess.run(cmd, check=True)

    generated_dir = Path("build")
    if generated_dir.exists() and not any(dist_dir.iterdir()):
        for item in generated_dir.iterdir():
            target = dist_dir / item.name
            if item.is_dir():
                shutil.copytree(item, target, dirs_exist_ok=True)
            else:
                shutil.copy2(item, target)


if __name__ == "__main__":
    main()
