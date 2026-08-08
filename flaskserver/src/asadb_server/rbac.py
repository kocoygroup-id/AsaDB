from __future__ import annotations

from typing import Any

from .errors import PermissionDenied

ALL_PERMISSIONS = {
    "server.admin",
    "panel.use",
    "user.manage",
    "database.list",
    "database.create",
    "database.drop",
    "database.read",
    "database.write",
    "database.backup",
    "database.restore",
    "session.create",
    "session.manage",
    "job.submit",
    "job.manage",
    "cluster.read",
    "cluster.manage",
    "replication.read",
    "replication.manage",
    "fts.read",
    "fts.manage",
    "config.manage",
    "audit.read",
}

BUILTIN_ROLES = {
    "admin": {"*"},
    "operator": {
        "panel.use", "database.list", "database.create", "database.read",
        "database.write", "database.backup", "database.restore",
        "session.create", "session.manage", "job.submit", "job.manage",
        "cluster.read", "replication.read", "replication.manage",
        "fts.read", "fts.manage", "audit.read",
    },
    "writer": {
        "panel.use", "database.list", "database.read", "database.write",
        "session.create", "job.submit", "fts.read",
    },
    "reader": {
        "panel.use", "database.list", "database.read", "session.create",
        "fts.read",
    },
    "replicator": {
        "database.list", "database.read", "database.backup", "database.restore",
        "replication.read", "replication.manage", "job.submit",
    },
}


def binding_matches(binding: dict[str, Any], database_id: str | None) -> bool:
    scope = str(binding.get("scope", "*"))
    if scope == "*":
        return True
    if database_id and scope == f"database:{database_id}":
        return True
    return False


def permissions_for(user: dict[str, Any], database_id: str | None = None) -> set[str]:
    permissions: set[str] = set()
    for binding in user.get("bindings", []):
        if not isinstance(binding, dict) or not binding_matches(binding, database_id):
            continue
        role = str(binding.get("role", ""))
        permissions.update(BUILTIN_ROLES.get(role, set()))
    return permissions


def has_permission(user: dict[str, Any], permission: str, database_id: str | None = None) -> bool:
    permissions = permissions_for(user, database_id)
    return "*" in permissions or permission in permissions


def require_permission(
    user: dict[str, Any],
    permission: str,
    database_id: str | None = None,
) -> None:
    if not has_permission(user, permission, database_id):
        raise PermissionDenied(
            "FORBIDDEN",
            f"Permission '{permission}' is required.",
            403,
            {"databaseId": database_id} if database_id else None,
        )
