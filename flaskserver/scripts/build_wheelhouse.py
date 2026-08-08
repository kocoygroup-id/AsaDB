#!/usr/bin/env python3
"""Build the offline Flask Server wheelhouse for release maintainers.

Run this only while preparing a source/pack release, on a machine with pip and
network access.  End users never execute this file: bootstrap_python.py uses
the completed wheelhouse with --no-index.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


SERVER_ROOT = Path(__file__).resolve().parents[1]
WHEELHOUSE = SERVER_ROOT / "wheels"
LOCKFILE = SERVER_ROOT / "requirements-bundled.txt"
TARGETS = (
    ("manylinux_2_17_x86_64", "310", "cp310"),
    ("manylinux_2_17_x86_64", "311", "cp311"),
    ("manylinux_2_17_x86_64", "312", "cp312"),
    ("manylinux_2_17_x86_64", "313", "cp313"),
    ("win_amd64", "310", "cp310"),
    ("win_amd64", "311", "cp311"),
    ("win_amd64", "312", "cp312"),
    ("win_amd64", "313", "cp313"),
)


def run(arguments: list[str]) -> None:
    subprocess.run(arguments, check=True)


def main() -> int:
    if not LOCKFILE.is_file():
        raise SystemExit(f"missing lockfile: {LOCKFILE}")
    if WHEELHOUSE.exists():
        shutil.rmtree(WHEELHOUSE)
    WHEELHOUSE.mkdir(parents=True)

    # pip is self-contained enough to bootstrap an environment created with
    # venv --without-pip. setuptools and wheel make local package installation
    # deterministic without contacting PyPI.
    run([
        sys.executable, "-m", "pip", "download", "--only-binary=:all:",
        "--dest", str(WHEELHOUSE), "pip", "setuptools", "wheel",
    ])
    for platform_tag, py_version, abi in TARGETS:
        run([
            sys.executable, "-m", "pip", "download", "--only-binary=:all:",
            "--dest", str(WHEELHOUSE), "--platform", platform_tag,
            "--python-version", py_version, "--implementation", "cp",
            "--abi", abi, "--requirement", str(LOCKFILE),
        ])
    print(f"Built {len(list(WHEELHOUSE.glob('*.whl')))} wheels in {WHEELHOUSE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
