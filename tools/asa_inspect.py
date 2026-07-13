#!/usr/bin/env python3
# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
"""Tiny helper to inspect AsaDB .asa v1 files.

This does not execute SQL. It only decodes the prototype storage payload so a
human can debug early AsaDB files.
"""
from __future__ import annotations

import sys
from pathlib import Path

MAGIC = b"ASADB001\n"


def inspect(path: Path) -> str:
    raw = path.read_bytes()
    if not raw.startswith(MAGIC):
        raise SystemExit("Not an AsaDB v1 file: missing magic header")
    rest = raw[len(MAGIC):]
    line, payload = rest.split(b"\n", 1)
    expected = int(line.decode("ascii"))
    decoded = bytes((b ^ 0x5A) % 256 for b in payload)
    actual = sum(decoded) % 1_000_000_007
    text = decoded.decode("latin1")
    return f"file={path}\nchecksum_expected={expected}\nchecksum_actual={actual}\nvalid_checksum={expected == actual}\n\npayload:\n{text}\n"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: python tools/asa_inspect.py examples/empty.asa")
        return 2
    print(inspect(Path(argv[1])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
