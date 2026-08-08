from __future__ import annotations

from functools import wraps
from typing import Callable, TypeVar

from flask import current_app, g, request, session

from .errors import AuthError
from .rbac import require_permission

F = TypeVar("F", bound=Callable)


def supplied_token() -> str | None:
    authorization = request.headers.get("Authorization", "")
    if authorization.lower().startswith("bearer "):
        return authorization[7:].strip()
    header = request.headers.get("X-AsaDB-Token")
    if header:
        return header
    cookie = request.cookies.get("asadb_auth")
    if cookie:
        return cookie
    value = session.get("asadb_auth")
    return str(value) if value else None


def current_user() -> dict:
    existing = getattr(g, "asadb_user", None)
    if isinstance(existing, dict):
        return existing
    auth = current_app.extensions["asadb_auth"]
    user = auth.user_for_token(supplied_token())
    g.asadb_user = user
    return user


def auth_required(
    permission: str | None = None,
    *,
    database_parameter: str | None = None,
):
    def decorator(func: F) -> F:
        @wraps(func)
        def wrapped(*args, **kwargs):
            user = current_user()
            if permission:
                database_id = (
                    str(kwargs.get(database_parameter))
                    if database_parameter and kwargs.get(database_parameter) is not None
                    else None
                )
                require_permission(user, permission, database_id)
            return func(*args, **kwargs)
        return wrapped  # type: ignore[return-value]
    return decorator


def cluster_required(func: F) -> F:
    @wraps(func)
    def wrapped(*args, **kwargs):
        cluster = current_app.extensions["asadb_cluster"]
        supplied = request.headers.get("X-AsaDB-Cluster-Key")
        if not cluster.verify_cluster_key(supplied):
            raise AuthError("CLUSTER_AUTH_REQUIRED", "Invalid cluster credential.", 401)
        return func(*args, **kwargs)
    return wrapped  # type: ignore[return-value]
