from __future__ import annotations

import json
import os
import time
from pathlib import Path
from typing import Any

from .util import new_id


class FileApiClient:
    """Same-host client for the atomic inbox/outbox File-Based API."""

    def __init__(self, root: str | Path, timeout: float = 120):
        self.root = Path(root).expanduser().resolve()
        self.inbox = self.root / "inbox"
        self.outbox = self.root / "outbox"
        self.timeout = timeout
        self.inbox.mkdir(parents=True, exist_ok=True)
        self.outbox.mkdir(parents=True, exist_ok=True)

    def submit(self, action: str, payload: dict[str, Any]) -> str:
        request_id = new_id("file-")
        request = {
            "id": request_id,
            "action": action,
            "payload": payload,
        }
        temporary = self.inbox / f".{request_id}.tmp"
        final = self.inbox / f"{request_id}.request.json"
        temporary.write_text(
            json.dumps(request, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        try:
            temporary.chmod(0o600)
        except OSError:
            pass
        os.replace(temporary, final)
        return request_id

    def wait(
        self,
        request_id: str,
        *,
        timeout: float | None = None,
        consume: bool = False,
    ) -> dict[str, Any]:
        response_file = self.outbox / f"{request_id}.response.json"
        deadline = time.time() + (self.timeout if timeout is None else timeout)
        while time.time() < deadline:
            if response_file.exists():
                response = json.loads(response_file.read_text(encoding="utf-8"))
                if consume:
                    response_file.unlink(missing_ok=True)
                return response
            time.sleep(0.05)
        raise TimeoutError(f"Timed out waiting for File API request {request_id}")

    def request(
        self,
        action: str,
        payload: dict[str, Any],
        *,
        timeout: float | None = None,
        consume: bool = False,
    ) -> dict[str, Any]:
        request_id = self.submit(action, payload)
        return self.wait(request_id, timeout=timeout, consume=consume)
