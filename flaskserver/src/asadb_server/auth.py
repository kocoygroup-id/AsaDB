from __future__ import annotations

from pathlib import Path
from typing import Any

from werkzeug.security import check_password_hash, generate_password_hash

from .errors import AuthError, AsaServerError
from .file_store import AtomicJsonStore
from .util import epoch, new_id, new_token, safe_id, token_digest, utc_now


class AuthManager:
    def __init__(self, state_dir: Path, token_ttl_seconds: int):
        self.users = AtomicJsonStore(state_dir / "users")
        self.tokens = AtomicJsonStore(state_dir / "tokens")
        self.token_ttl_seconds = token_ttl_seconds
        self._dummy_hash = generate_password_hash(
            "asadb-invalid-user-password",
            method="scrypt",
        )

    def create_user(
        self,
        username: str,
        password: str,
        *,
        bindings: list[dict[str, str]] | None = None,
        enabled: bool = True,
    ) -> dict[str, Any]:
        safe_id(username, "username")
        if len(password) < 8:
            raise AsaServerError(
                "WEAK_PASSWORD",
                "Password must contain at least 8 characters.",
                400,
            )
        if self.find_user(username) is not None:
            raise AsaServerError("USER_EXISTS", "Username already exists.", 409)
        user_id = new_id("usr-")
        user = {
            "id": user_id,
            "username": username,
            "passwordHash": generate_password_hash(password, method="scrypt"),
            "enabled": enabled,
            "bindings": bindings or [{"role": "reader", "scope": "*"}],
            "createdAt": utc_now(),
            "updatedAt": utc_now(),
        }
        self.users.write(user_id, user)
        return self.public_user(user)

    def bootstrap_admin(self, username: str, password: str) -> dict[str, Any]:
        existing = self.find_user(username)
        if existing:
            return self.public_user(existing)
        return self.create_user(
            username,
            password,
            bindings=[{"role": "admin", "scope": "*"}],
        )

    def find_user(self, username: str) -> dict[str, Any] | None:
        for user in self.users.list():
            if user.get("username") == username:
                return user
        return None

    def get_user(self, user_id: str) -> dict[str, Any]:
        user = self.users.read(user_id)
        if not isinstance(user, dict):
            raise AuthError("USER_NOT_FOUND", "User does not exist.", 404)
        return user

    def authenticate(self, username: str, password: str) -> tuple[str, dict[str, Any]]:
        user = self.find_user(username)
        valid_hash = user.get("passwordHash", self._dummy_hash) if user else self._dummy_hash
        password_ok = check_password_hash(valid_hash, password)
        if not password_ok or not user or not user.get("enabled", False):
            raise AuthError("INVALID_CREDENTIALS", "Invalid username or password.", 401)

        token = new_token(36)
        digest = token_digest(token)
        record = {
            "id": digest,
            "userId": user["id"],
            "createdAt": epoch(),
            "expiresAt": epoch() + self.token_ttl_seconds,
            "revoked": False,
        }
        self.tokens.write(digest, record)
        return token, self.public_user(user)

    def user_for_token(self, token: str | None) -> dict[str, Any]:
        if not token:
            raise AuthError("AUTH_REQUIRED", "Authentication is required.", 401)
        digest = token_digest(token)
        record = self.tokens.read(digest)
        if not isinstance(record, dict):
            raise AuthError("INVALID_TOKEN", "Token is invalid.", 401)
        if record.get("revoked") or float(record.get("expiresAt", 0)) <= epoch():
            self.tokens.delete(digest)
            raise AuthError("TOKEN_EXPIRED", "Token has expired.", 401)
        user = self.get_user(str(record["userId"]))
        if not user.get("enabled", False):
            raise AuthError("USER_DISABLED", "User is disabled.", 403)
        return user

    def revoke(self, token: str) -> None:
        self.tokens.delete(token_digest(token))

    def update_user(
        self,
        user_id: str,
        *,
        password: str | None = None,
        enabled: bool | None = None,
        bindings: list[dict[str, str]] | None = None,
    ) -> dict[str, Any]:
        user = self.get_user(user_id)
        if password is not None:
            if len(password) < 8:
                raise AsaServerError("WEAK_PASSWORD", "Password is too short.", 400)
            user["passwordHash"] = generate_password_hash(password, method="scrypt")
        if enabled is not None:
            user["enabled"] = bool(enabled)
        if bindings is not None:
            user["bindings"] = bindings
        user["updatedAt"] = utc_now()
        self.users.write(user_id, user)
        return self.public_user(user)

    def delete_user(self, user_id: str) -> None:
        self.get_user(user_id)
        self.users.delete(user_id)
        for token in self.tokens.list():
            if token.get("userId") == user_id:
                self.tokens.delete(str(token.get("id")))

    @staticmethod
    def public_user(user: dict[str, Any]) -> dict[str, Any]:
        return {
            key: value
            for key, value in user.items()
            if key != "passwordHash"
        }
