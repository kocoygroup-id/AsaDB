from __future__ import annotations

import json
import time
from pathlib import Path

from asadb_server.file_api import FileApiGateway


def test_file_api_inbox_outbox(tmp_path: Path):
    gateway = FileApiGateway(tmp_path, poll_interval=0.01)
    gateway.register("echo", lambda payload: payload)
    gateway.start()
    try:
        request_id = gateway.submit_file({
            "action": "echo",
            "payload": {"hello": "world"},
        })
        output = tmp_path / "outbox" / f"{request_id}.response.json"
        deadline = time.time() + 2
        while time.time() < deadline and not output.exists():
            time.sleep(0.01)
        assert output.exists()
        value = json.loads(output.read_text(encoding="utf-8"))
        assert value["ok"] is True
        assert value["result"]["hello"] == "world"
    finally:
        gateway.stop()
