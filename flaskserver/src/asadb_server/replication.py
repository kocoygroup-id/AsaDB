from __future__ import annotations

import hashlib
import json
import shutil
import tempfile
from pathlib import Path
from typing import Any

import requests

from .backend import BackendManager
from .cluster import ClusterManager
from .errors import AsaServerError
from .jobs import JobContext, JobQueue
from .registry import DatabaseRegistry
from .util import utc_now


class ReplicationManager:
    """
    Snapshot replication through AsaDB's official backend-produced .asb format.

    Replication is asynchronous and explicit-primary. It is not synchronous
    quorum replication and does not implement automatic leader election.
    """

    def __init__(
        self,
        registry: DatabaseRegistry,
        backends: BackendManager,
        cluster: ClusterManager,
        jobs: JobQueue,
        temp_dir: Path,
        availability_guard=None,
    ):
        self.registry = registry
        self.backends = backends
        self.cluster = cluster
        self.jobs = jobs
        self.temp_dir = temp_dir
        self.availability_guard = availability_guard
        self.jobs.register("replicate_snapshot", self._job_replicate)

    def submit(
        self,
        database_id: str,
        logical_database: str,
        target_node: str,
        *,
        user_id: str,
    ) -> dict[str, Any]:
        self.cluster.require_local_primary(database_id)
        if target_node not in self.registry.get(database_id).get("replicaNodes", []):
            raise AsaServerError(
                "NOT_A_REPLICA",
                "Target node is not configured as a replica for this database.",
                409,
            )
        return self.jobs.submit(
            "replicate_snapshot",
            {
                "databaseId": database_id,
                "logicalDatabase": logical_database,
                "targetNode": target_node,
            },
            user_id=user_id,
            database_id=database_id,
        )

    def _job_replicate(self, context: JobContext, payload: dict[str, Any]) -> dict[str, Any]:
        database_id = str(payload["databaseId"])
        logical_database = str(payload["logicalDatabase"])
        target_node = str(payload["targetNode"])
        if self.availability_guard is not None:
            self.availability_guard(database_id)
        context.progress(5, "Creating backend-owned AsaDB backup.")
        response = self.backends.get(database_id).backup(logical_database)

        self.temp_dir.mkdir(parents=True, exist_ok=True)
        snapshot = self.temp_dir / f"replication-{context.job_id}.asb"
        digest = hashlib.sha256()
        size = 0
        with snapshot.open("wb") as handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                context.check_cancelled()
                if not chunk:
                    continue
                handle.write(chunk)
                digest.update(chunk)
                size += len(chunk)
        context.progress(45, "Snapshot created.", snapshotBytes=size)

        node = self.cluster.get_node(target_node)
        url = str(node["url"]).rstrip("/") + f"/api/v1/internal/replication/{database_id}"
        context.progress(55, f"Uploading snapshot to {target_node}.")
        try:
            with snapshot.open("rb") as handle:
                remote = requests.post(
                    url,
                    data=handle,
                    headers={
                        "X-AsaDB-Cluster-Key": self.cluster.cluster_key,
                        "X-AsaDB-Logical-Database": logical_database,
                        "Content-Type": "application/octet-stream",
                        "Content-Length": str(snapshot.stat().st_size),
                    },
                    timeout=3600,
                )
            if remote.status_code >= 400:
                raise AsaServerError(
                    "REPLICA_REJECTED",
                    f"Replica returned HTTP {remote.status_code}: {remote.text[:1000]}",
                    502,
                )
            result = remote.json()
        finally:
            snapshot.unlink(missing_ok=True)

        context.progress(95, "Replica accepted and restored the snapshot.")
        record = self.registry.get(database_id)
        record["lastReplicatedAt"] = utc_now()
        self.registry.update(
            database_id,
            {"lastReplicatedAt": record["lastReplicatedAt"]},
        )
        return {
            "databaseId": database_id,
            "logicalDatabase": logical_database,
            "targetNode": target_node,
            "sha256": digest.hexdigest(),
            "bytes": size,
            "remote": result,
        }

    def receive(
        self,
        database_id: str,
        logical_database: str,
        uploaded_path: Path,
    ) -> dict[str, Any]:
        record = self.registry.get(database_id)
        if self.availability_guard is not None:
            self.availability_guard(database_id)
        if self.cluster.node_id not in record.get("replicaNodes", []):
            raise AsaServerError(
                "REPLICA_NOT_CONFIGURED",
                "This node is not configured as a replica.",
                409,
            )
        result = self.backends.get(database_id).import_upload(
            uploaded_path,
            format_name="auto",
            stop_on_error=True,
        )
        self.registry.update(
            database_id,
            {
                "replicaState": "ready",
                "lastReplicatedAt": utc_now(),
            },
        )
        return {
            "databaseId": database_id,
            "logicalDatabase": logical_database,
            "restored": True,
            "result": result,
        }
