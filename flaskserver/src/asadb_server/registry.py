from __future__ import annotations

from pathlib import Path
from typing import Any

from .errors import AsaServerError
from .file_store import AtomicJsonStore
from .util import resolve_beneath, safe_asa_filename, safe_id, utc_now


class DatabaseRegistry:
    def __init__(self, state_dir: Path, data_dir: Path, node_id: str):
        self.store = AtomicJsonStore(state_dir / "databases")
        self.data_dir = data_dir.resolve()
        self.node_id = node_id

    def register(
        self,
        database_id: str,
        filename: str | None = None,
        *,
        primary_node: str | None = None,
        replica_nodes: list[str] | None = None,
        pool: int = 0,
        replication_logical_database: str | None = None,
    ) -> dict[str, Any]:
        safe_id(database_id, "database id")
        filename = safe_asa_filename(filename or f"{database_id}.asa")
        if self.store.read(database_id) is not None:
            raise AsaServerError("DATABASE_EXISTS", "Database file id already exists.", 409)
        for record in self.store.list():
            if record.get("filename") == filename:
                raise AsaServerError("DATABASE_FILE_EXISTS", "Filename is already registered.", 409)
        self.path_for_filename(filename)
        record = {
            "id": database_id,
            "filename": filename,
            "enabled": True,
            "pool": int(pool),
            "primaryNode": primary_node or self.node_id,
            "replicaNodes": replica_nodes or [],
            "replicaState": "primary" if (primary_node or self.node_id) == self.node_id else "unknown",
            "lastReplicatedAt": None,
            "replicationLogicalDatabase": replication_logical_database,
            "createdAt": utc_now(),
            "updatedAt": utc_now(),
        }
        self.store.write(database_id, record)
        return record

    def list(self) -> list[dict[str, Any]]:
        return sorted(self.store.list(), key=lambda x: str(x.get("id", "")))

    def get(self, database_id: str, *, require_enabled: bool = True) -> dict[str, Any]:
        safe_id(database_id, "database id")
        record = self.store.read(database_id)
        if not isinstance(record, dict):
            raise AsaServerError("DATABASE_NOT_FOUND", "Database file is not registered.", 404)
        if require_enabled and not record.get("enabled", False):
            raise AsaServerError("DATABASE_DISABLED", "Database file is disabled.", 409)
        return record

    def update(self, database_id: str, updates: dict[str, Any]) -> dict[str, Any]:
        record = self.get(database_id, require_enabled=False)
        allowed = {
            "enabled", "pool", "primaryNode", "replicaNodes",
            "replicaState", "lastReplicatedAt", "replicationLogicalDatabase",
        }
        for key, value in updates.items():
            if key in allowed:
                record[key] = value
        record["updatedAt"] = utc_now()
        self.store.write(database_id, record)
        return record

    def unregister(self, database_id: str) -> dict[str, Any]:
        record = self.get(database_id, require_enabled=False)
        self.store.delete(database_id)
        return record

    def path(self, database_id: str) -> Path:
        return self.path_for_filename(str(self.get(database_id)["filename"]))

    def path_for_filename(self, filename: str) -> Path:
        safe_asa_filename(filename)
        try:
            return resolve_beneath(self.data_dir, filename)
        except ValueError as exc:
            raise AsaServerError("INVALID_DATABASE_PATH", "Path escapes data directory.", 400) from exc

    def local_role(self, database_id: str) -> str:
        record = self.get(database_id)
        if record.get("primaryNode") == self.node_id:
            return "primary"
        if self.node_id in record.get("replicaNodes", []):
            return "replica"
        return "remote"
