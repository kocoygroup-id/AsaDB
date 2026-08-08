from __future__ import annotations

import json
from pathlib import Path

from asadb_server.file_client import FileApiClient


def test_file_api_client_atomic_submit_and_wait(tmp_path: Path):
    client = FileApiClient(tmp_path, timeout=1)
    request_id = client.submit("ping", {})
    request_file = tmp_path / "inbox" / f"{request_id}.request.json"
    assert request_file.exists()

    response_file = tmp_path / "outbox" / f"{request_id}.response.json"
    response_file.write_text(
        json.dumps({"id": request_id, "ok": True, "result": {"status": "ok"}}),
        encoding="utf-8",
    )
    result = client.wait(request_id, consume=True)
    assert result["result"]["status"] == "ok"
    assert not response_file.exists()
