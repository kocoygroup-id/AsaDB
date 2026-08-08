from __future__ import annotations

import json
from pathlib import Path

from asadb_server.file_store import AtomicJsonStore, FileLease


def test_atomic_json_store_roundtrip(tmp_path: Path):
    store = AtomicJsonStore(tmp_path / "objects")
    assert store.create("item-1", {"id": "item-1", "value": 1})
    assert not store.create("item-1", {"id": "item-1", "value": 2})
    assert store.read("item-1")["value"] == 1

    updated = store.update(
        "item-1",
        lambda current: {**current, "value": current["value"] + 1},
    )
    assert updated["value"] == 2
    assert store.list()[0]["value"] == 2

    store.delete("item-1")
    assert store.read("item-1") is None


def test_file_lease_exclusion(tmp_path: Path):
    path = tmp_path / "database.lock"
    first = FileLease(path, "first", ttl=30)
    second = FileLease(path, "second", ttl=30)
    assert first.acquire()
    assert not second.acquire()
    first.release()
    assert second.acquire()
    second.release()
