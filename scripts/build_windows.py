from __future__ import annotations

import subprocess
from pathlib import Path

from release_bundle import bundle_windows_artifact


def main() -> None:
    dist_dir = Path("dist")
    dist_dir.mkdir(parents=True, exist_ok=True)

    entrypoint = Path("src/terra_testing/main.py")
    if not entrypoint.exists():
        raise FileNotFoundError(f"Entrypoint not found: {entrypoint}")

    cmd = ["flet", "pack", str(entrypoint), "--name", "TerraTesting"]
    subprocess.run(cmd, check=True)

    zip_path, checksums_path = bundle_windows_artifact(build_dir=Path("build"), dist_dir=dist_dir)
    print(f"Release asset: {zip_path}")
    print(f"Checksums: {checksums_path}")


if __name__ == "__main__":
    main()
