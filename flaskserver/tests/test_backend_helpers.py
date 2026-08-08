from __future__ import annotations

from pathlib import Path

import requests

from asadb_server.backend import multipart_file_stream


def test_streaming_multipart_length(tmp_path: Path):
    source = tmp_path / "snapshot.asb"
    source.write_bytes(b"abc123")
    content_type, length, body = multipart_file_stream(
        source,
        field_name="file",
        fields={"format": "auto", "stop_on_error": "true"},
    )
    chunks = []
    while True:
        chunk = body.read(3)
        if not chunk:
            break
        chunks.append(chunk)
    payload = b"".join(chunks)
    body.close()
    assert content_type.startswith("multipart/form-data; boundary=")
    assert len(payload) == length
    assert b"abc123" in payload
    assert b'name="format"' in payload


def test_requests_keeps_content_length_for_streaming_multipart(tmp_path: Path):
    source = tmp_path / "snapshot.asb"
    source.write_bytes(b"x" * 1024)
    content_type, length, body = multipart_file_stream(
        source,
        field_name="file",
        fields={"format": "auto"},
    )
    prepared = requests.Request(
        "POST",
        "http://127.0.0.1/upload",
        data=body,
        headers={
            "Content-Type": content_type,
            "Content-Length": str(length),
        },
    ).prepare()
    assert prepared.headers["Content-Length"] == str(length)
    assert "Transfer-Encoding" not in prepared.headers
    body.close()
