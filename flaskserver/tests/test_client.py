from __future__ import annotations

from asadb_server.client import AsaDBClient


def test_client_normalizes_base_url():
    client = AsaDBClient("http://localhost:2026/")
    assert client.base_url == "http://localhost:2026"
