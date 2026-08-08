from __future__ import annotations

import hashlib
import hmac
from pathlib import Path
from typing import Any

from .client import AsaDBClient
from .errors import AsaServerError
from .file_store import AtomicJsonStore
from .registry import DatabaseRegistry
from .util import safe_id, utc_now


class ClusterManager:
    """
    Explicit-primary cluster coordinator inspired by SiriDB's server/pool/replica
    separation, but adapted to AsaDB's current one-writer local engine.

    It deliberately does not claim consensus or active-active writes. Each file
    has one configured primary node and zero or more read replicas.
    """

    def __init__(
        self,
        state_dir: Path,
        registry: DatabaseRegistry,
        node_id: str,
        public_url: str,
        cluster_key: str,
        enabled: bool,
    ):
        self.nodes = AtomicJsonStore(state_dir / "cluster-nodes")
        self.registry = registry
        self.node_id = node_id
        self.public_url = public_url.rstrip("/")
        self.cluster_key = cluster_key
        self.enabled = enabled
        self.ensure_local_node()

    def ensure_local_node(self) -> dict[str, Any]:
        node = self.nodes.read(self.node_id)
        if not isinstance(node, dict):
            node = {
                "id": self.node_id,
                "url": self.public_url,
                "enabled": True,
                "local": True,
                "status": "online",
                "lastSeenAt": utc_now(),
                "createdAt": utc_now(),
            }
            self.nodes.write(self.node_id, node)
        return node

    def add_node(self, node_id: str, url: str, *, enabled: bool = True) -> dict[str, Any]:
        safe_id(node_id, "node id")
        if not url.startswith(("http://", "https://")):
            raise AsaServerError("INVALID_NODE_URL", "Node URL must use HTTP or HTTPS.", 400)
        node = {
            "id": node_id,
            "url": url.rstrip("/"),
            "enabled": enabled,
            "local": node_id == self.node_id,
            "status": "unknown",
            "lastSeenAt": None,
            "createdAt": utc_now(),
        }
        self.nodes.write(node_id, node)
        return node

    def get_node(self, node_id: str) -> dict[str, Any]:
        node = self.nodes.read(node_id)
        if not isinstance(node, dict):
            raise AsaServerError("NODE_NOT_FOUND", "Cluster node is not registered.", 404)
        return node

    def list_nodes(self) -> list[dict[str, Any]]:
        return sorted(self.nodes.list(), key=lambda x: str(x.get("id", "")))

    def remove_node(self, node_id: str) -> None:
        if node_id == self.node_id:
            raise AsaServerError("LOCAL_NODE_REQUIRED", "Cannot remove the local node.", 409)
        self.get_node(node_id)
        self.nodes.delete(node_id)

    def verify_cluster_key(self, supplied: str | None) -> bool:
        if not supplied:
            return False
        return hmac.compare_digest(supplied, self.cluster_key)

    def client_for(self, node_id: str) -> AsaDBClient:
        if node_id != self.node_id and not self.enabled:
            raise AsaServerError(
                "CLUSTER_DISABLED",
                "Cluster mode is disabled on this node.",
                409,
            )
        node = self.get_node(node_id)
        return AsaDBClient(
            str(node["url"]),
            cluster_key=self.cluster_key,
        )

    def primary_node(self, database_id: str) -> str:
        return str(self.registry.get(database_id).get("primaryNode", self.node_id))

    def local_can_serve_read(self, database_id: str) -> bool:
        record = self.registry.get(database_id)
        if record.get("primaryNode") == self.node_id:
            return True
        return (
            self.node_id in record.get("replicaNodes", [])
            and record.get("replicaState") == "ready"
        )

    def require_local_primary(self, database_id: str) -> None:
        primary = self.primary_node(database_id)
        if primary != self.node_id:
            node = self.get_node(primary)
            raise AsaServerError(
                "PRIMARY_NODE_REQUIRED",
                "This operation must run on the database primary node.",
                409,
                {"primaryNode": primary, "primaryUrl": node.get("url")},
            )

    def query_remote(self, database_id: str, sql: str) -> dict[str, Any]:
        primary = self.primary_node(database_id)
        if primary == self.node_id:
            raise RuntimeError("query_remote called for local primary")
        return self.client_for(primary).query(database_id, sql)

    def heartbeat(self, node_id: str) -> dict[str, Any]:
        node = self.get_node(node_id)
        if node_id == self.node_id:
            node["status"] = "online"
            node["lastSeenAt"] = utc_now()
            self.nodes.write(node_id, node)
            return node
        client = self.client_for(node_id)
        try:
            result = client.request(
                "GET",
                "/api/v1/cluster/health",
                authenticated=False,
            )
        except Exception as exc:
            node["status"] = "offline"
            node["lastError"] = str(exc)
        else:
            node["status"] = "online"
            node["lastSeenAt"] = utc_now()
            node["remote"] = result
            node.pop("lastError", None)
        self.nodes.write(node_id, node)
        return node
