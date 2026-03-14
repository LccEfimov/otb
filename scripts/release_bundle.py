from __future__ import annotations

import hashlib
import zipfile
from pathlib import Path


def sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def resolve_package_path(dist_dir: Path, package_path: Path | None = None) -> Path:
    if package_path is not None:
        return package_path

    candidates = [
        dist_dir / "TerraTesting.exe",
        dist_dir / "TerraTesting",
        dist_dir / "TerraTesting.app",
    ]

    for candidate in candidates:
        if candidate.exists():
            return candidate

    return dist_dir / "TerraTesting"


def bundle_windows_artifact(
    *,
    package_path: Path | None = None,
    build_dir: Path = Path("build"),
    dist_dir: Path = Path("dist"),
    zip_name: str = "TerraTesting-win.zip",
) -> tuple[Path, Path]:
    dist_dir.mkdir(parents=True, exist_ok=True)
    zip_path = dist_dir / zip_name
    selected_package_path = resolve_package_path(dist_dir=dist_dir, package_path=package_path)

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        if selected_package_path.exists():
            if selected_package_path.is_file():
                archive.write(selected_package_path, selected_package_path.name)
            else:
                for item in sorted(selected_package_path.rglob("*")):
                    if item.is_file():
                        archive.write(item, item.relative_to(selected_package_path.parent))
        elif build_dir.exists():
            for item in sorted(build_dir.rglob("*")):
                if item.is_file():
                    archive.write(item, item.relative_to(build_dir))
        else:
            raise FileNotFoundError(
                "Neither package path "
                f"'{selected_package_path}' nor build directory '{build_dir}' exists"
            )

    checksums_path = dist_dir / "checksums.txt"
    checksum_line = f"{sha256_file(zip_path)}  {zip_path.name}\n"
    checksums_path.write_text(checksum_line, encoding="utf-8")

    return zip_path, checksums_path


def main() -> None:
    zip_path, checksums_path = bundle_windows_artifact()
    print(f"Created: {zip_path}")
    print(f"Created: {checksums_path}")


if __name__ == "__main__":
    main()
