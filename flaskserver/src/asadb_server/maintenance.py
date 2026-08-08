from __future__ import annotations

import threading
import time
from typing import Any

from .cluster import ClusterManager
from .jobs import JobQueue
from .registry import DatabaseRegistry
from .replication import ReplicationManager
from .sessions import SessionManager


class MaintenanceService:
    """Periodic session cleanup, node heartbeats, and scheduled snapshots."""

    def __init__(
        self,
        *,
        sessions: SessionManager,
        cluster: ClusterManager,
        registry: DatabaseRegistry,
        replication: ReplicationManager,
        jobs: JobQueue,
        replication_interval: int,
    ):
        self.sessions = sessions
        self.cluster = cluster
        self.registry = registry
        self.replication = replication
        self.jobs = jobs
        self.replication_interval = max(0, int(replication_interval))
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._last_replication = time.monotonic()

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._loop,
            name="asadb-maintenance",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=3)

    def _loop(self) -> None:
        while not self._stop.wait(30):
            try:
                self.sessions.reap()
            except Exception:
                pass
            if not self.cluster.enabled:
                continue
            self._heartbeat_nodes()
            if (
                self.replication_interval > 0
                and time.monotonic() - self._last_replication >= self.replication_interval
            ):
                self._last_replication = time.monotonic()
                self._schedule_replication()

    def _heartbeat_nodes(self) -> None:
        for node in self.cluster.list_nodes():
            node_id = str(node.get("id", ""))
            if not node_id or node_id == self.cluster.node_id or not node.get("enabled", True):
                continue
            try:
                self.cluster.heartbeat(node_id)
            except Exception:
                pass

    def _schedule_replication(self) -> None:
        active = {
            (
                str(job.get("databaseId")),
                str((job.get("payload") or {}).get("targetNode")),
            )
            for job in self.jobs.list(include_all=True)
            if job.get("kind") == "replicate_snapshot"
            and job.get("status") in {"queued", "running", "cancelling"}
        }
        for record in self.registry.list():
            if record.get("primaryNode") != self.cluster.node_id:
                continue
            database_id = str(record.get("id", ""))
            logical_database = record.get("replicationLogicalDatabase")
            if not isinstance(logical_database, str) or not logical_database:
                continue
            for target in record.get("replicaNodes", []):
                key = (database_id, str(target))
                if key in active:
                    continue
                try:
                    self.replication.submit(
                        database_id,
                        logical_database,
                        str(target),
                        user_id=f"system:{self.cluster.node_id}",
                    )
                except Exception:
                    continue
