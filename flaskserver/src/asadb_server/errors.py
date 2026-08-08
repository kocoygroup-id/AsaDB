from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class AsaServerError(Exception):
    code: str
    message: str
    status: int = 400
    details: Any = None

    def payload(self, request_id: str | None = None) -> dict[str, Any]:
        body: dict[str, Any] = {
            "error": {"code": self.code, "message": self.message}
        }
        if self.details is not None:
            body["error"]["details"] = self.details
        if request_id:
            body["requestId"] = request_id
        return body


class AuthError(AsaServerError):
    pass


class PermissionDenied(AsaServerError):
    pass


class BackendError(AsaServerError):
    pass


class BackendUnavailable(BackendError):
    pass


class TransactionConflict(AsaServerError):
    pass
