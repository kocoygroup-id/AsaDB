from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

from .util import utc_now


class AuditLog:
    def __init__(self, root: Path):
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()

    def append(self, event: str, **fields: Any) -> dict[str, Any]:
        record = {"timestamp": utc_now(), "event": event, **fields}
        day = record["timestamp"][:10]
        path = self.root / f"{day}.jsonl"
        line = json.dumps(record, ensure_ascii=False, separators=(",", ":"))
        with self._lock, path.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
        try:
            path.chmod(0o600)
        except OSError:
            pass
        return record

    def tail(self, limit: int = 100) -> list[dict[str, Any]]:
        lines: list[str] = []
        for path in sorted(self.root.glob("*.jsonl"), reverse=True):
            try:
                current = path.read_text(encoding="utf-8", errors="replace").splitlines()
            except OSError:
                continue
            lines = current + lines
            if len(lines) >= limit:
                break
        output: list[dict[str, Any]] = []
        for line in lines[-limit:]:
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                output.append(value)
        return output
