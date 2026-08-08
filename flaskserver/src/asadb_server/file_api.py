from __future__ import annotations

import json
import os
import shutil
import threading
import time
from pathlib import Path
from typing import Any, Callable

from .util import new_id, utc_now


class FileApiGateway:
    """
    Optional same-host File-Based API.

    Clients atomically place `*.request.json` files in inbox. The gateway moves
    each request to processing, invokes a registered action, then writes one
    `*.response.json` file to outbox. This is useful for offline scripts, batch
    systems, and deployments that do not want an additional local socket.
    """

    def __init__(self, root: Path, poll_interval: float = 0.25):
        self.root = root
        self.inbox = root / "inbox"
        self.processing = root / "processing"
        self.outbox = root / "outbox"
        for path in (self.inbox, self.processing, self.outbox):
            path.mkdir(parents=True, exist_ok=True)
        self.poll_interval = poll_interval
        self.handlers: dict[str, Callable[[dict[str, Any]], Any]] = {}
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def register(self, action: str, handler: Callable[[dict[str, Any]], Any]) -> None:
        self.handlers[action] = handler

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True, name="asadb-file-api")
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)

    def submit_file(self, request: dict[str, Any]) -> str:
        request_id = str(request.get("id") or new_id("file-"))
        request["id"] = request_id
        temp = self.inbox / f".{request_id}.tmp"
        final = self.inbox / f"{request_id}.request.json"
        temp.write_text(json.dumps(request, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(temp, final)
        return request_id

    def _loop(self) -> None:
        while not self._stop.wait(self.poll_interval):
            for source in sorted(self.inbox.glob("*.request.json")):
                target = self.processing / source.name
                try:
                    os.replace(source, target)
                except OSError:
                    continue
                self._process(target)

    def _process(self, path: Path) -> None:
        request_id = path.name.split(".request.json")[0]
        try:
            request = json.loads(path.read_text(encoding="utf-8"))
            action = str(request.get("action", ""))
            handler = self.handlers.get(action)
            if handler is None:
                raise ValueError(f"Unknown File API action: {action}")
            result = handler(dict(request.get("payload") or {}))
            response = {
                "id": request_id,
                "ok": True,
                "result": result,
                "completedAt": utc_now(),
            }
        except Exception as exc:
            response = {
                "id": request_id,
                "ok": False,
                "error": {"type": type(exc).__name__, "message": str(exc)},
                "completedAt": utc_now(),
            }
        output = self.outbox / f"{request_id}.response.json"
        temp = output.with_suffix(".tmp")
        temp.write_text(json.dumps(response, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(temp, output)
        path.unlink(missing_ok=True)
