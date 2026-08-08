from __future__ import annotations

import json
import os
import threading
import time
from pathlib import Path
from typing import Any

from .util import new_id, safe_id


class AtomicJsonStore:
    """Atomic, human-readable file storage used by the server control plane."""

    def __init__(self, root: Path):
        self.root = root.resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        self._locks: dict[str, threading.RLock] = {}
        self._guard = threading.Lock()

    def _lock_for(self, key: str) -> threading.RLock:
        with self._guard:
            return self._locks.setdefault(key, threading.RLock())

    def path(self, key: str) -> Path:
        safe_id(key, "file-store key")
        return self.root / f"{key}.json"

    def read(self, key: str, default: Any = None) -> Any:
        path = self.path(key)
        with self._lock_for(key):
            if not path.exists():
                return default
            return json.loads(path.read_text(encoding="utf-8"))

    def write(self, key: str, value: Any) -> None:
        path = self.path(key)
        with self._lock_for(key):
            temp = path.with_name(f".{path.name}.{new_id('tmp-')}")
            with temp.open("w", encoding="utf-8") as handle:
                json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            try:
                os.chmod(temp, 0o600)
            except OSError:
                pass
            os.replace(temp, path)

    def create(self, key: str, value: Any) -> bool:
        path = self.path(key)
        with self._lock_for(key):
            try:
                descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            except FileExistsError:
                return False
            try:
                with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
                    json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
                    handle.write("\n")
                    handle.flush()
                    os.fsync(handle.fileno())
            except Exception:
                path.unlink(missing_ok=True)
                raise
            return True

    def delete(self, key: str) -> None:
        with self._lock_for(key):
            self.path(key).unlink(missing_ok=True)

    def list(self) -> list[dict[str, Any]]:
        output: list[dict[str, Any]] = []
        for path in sorted(self.root.glob("*.json")):
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if isinstance(value, dict):
                output.append(value)
        return output

    def update(self, key: str, mutator) -> Any:
        with self._lock_for(key):
            current = self.read(key, {})
            updated = mutator(current)
            self.write(key, updated)
            return updated


class FileLease:
    """Cross-platform lock file with ownership and stale-lock recovery."""

    def __init__(self, path: Path, owner: str, ttl: float = 300):
        self.path = path
        self.owner = owner
        self.ttl = ttl
        self.acquired = False

    def acquire(self) -> bool:
        payload = json.dumps({"owner": self.owner, "created": time.time()})
        self.path.parent.mkdir(parents=True, exist_ok=True)
        while True:
            try:
                fd = os.open(self.path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            except FileExistsError:
                if self._stale():
                    self.path.unlink(missing_ok=True)
                    continue
                return False
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            self.acquired = True
            return True

    def _stale(self) -> bool:
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
            created = float(data.get("created", 0))
        except Exception:
            return True
        return time.time() - created > self.ttl

    def release(self) -> None:
        if not self.acquired:
            return
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        if data.get("owner") == self.owner:
            self.path.unlink(missing_ok=True)
        self.acquired = False

    def __enter__(self):
        if not self.acquire():
            raise RuntimeError(f"Lease is already held: {self.path}")
        return self

    def __exit__(self, *_):
        self.release()
