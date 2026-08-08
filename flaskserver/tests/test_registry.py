from __future__ import annotations

from pathlib import Path

import pytest

from asadb_server.registry import DatabaseRegistry


def test_registry_uses_safe_file_names(tmp_path: Path):
    registry = DatabaseRegistry(tmp_path / "state", tmp_path / "data", "node-1")
    record = registry.register("main", "data.asa")
    assert record["primaryNode"] == "node-1"
    assert registry.path("main") == (tmp_path / "data" / "data.asa").resolve()

    with pytest.raises(ValueError):
        registry.register("escape", "../escape.asa")


def test_registry_tracks_replica_state(tmp_path: Path):
    registry = DatabaseRegistry(tmp_path / "state", tmp_path / "data", "node-2")
    registry.register(
        "main",
        "data.asa",
        primary_node="node-1",
        replica_nodes=["node-2"],
    )
    assert registry.local_role("main") == "replica"
    registry.update("main", {"replicaState": "ready"})
    assert registry.get("main")["replicaState"] == "ready"
