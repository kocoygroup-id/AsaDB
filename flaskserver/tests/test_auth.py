from __future__ import annotations

from pathlib import Path

import pytest

pytest.importorskip("werkzeug")

from asadb_server.auth import AuthManager
from asadb_server.errors import AuthError


def test_password_hash_and_token_digest(tmp_path: Path):
    auth = AuthManager(tmp_path, token_ttl_seconds=3600)
    user = auth.create_user(
        "admin",
        "very-secure-password",
        bindings=[{"role": "admin", "scope": "*"}],
    )
    stored = auth.find_user("admin")
    assert stored is not None
    assert stored["passwordHash"] != "very-secure-password"
    assert "very-secure-password" not in stored["passwordHash"]

    token, public = auth.authenticate("admin", "very-secure-password")
    assert auth.user_for_token(token)["id"] == user["id"]
    assert all(item.get("id") != token for item in auth.tokens.list())

    auth.revoke(token)
    with pytest.raises(AuthError):
        auth.user_for_token(token)
