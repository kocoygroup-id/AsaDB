from __future__ import annotations

import threading
from pathlib import Path
from typing import Any

from .backend import BackendManager
from .errors import AsaServerError, TransactionConflict
from .file_store import AtomicJsonStore
from .util import epoch, looks_like_write, new_id, utc_now


class SessionManager:
    """
    File-backed client sessions with transaction affinity.

    AsaDB intentionally retains one writer. An active transaction therefore
    owns an exclusive lease for its database backend until COMMIT/ROLLBACK.
    Other client requests are rejected while that lease is active, preventing
    cross-client reads from observing transaction-local state.
    """

    def __init__(
        self,
        state_dir: Path,
        backends: BackendManager,
        ttl_seconds: int,
    ):
        self.store = AtomicJsonStore(state_dir / "sessions")
        self.backends = backends
        self.ttl_seconds = ttl_seconds
        self._lock = threading.RLock()
        self._session_locks: dict[str, threading.RLock] = {}
        self._tx_owner: dict[str, str] = {}
        self._recover()

    def _session_lock(self, session_id: str) -> threading.RLock:
        with self._lock:
            return self._session_locks.setdefault(session_id, threading.RLock())

    def _recover(self) -> None:
        # Backend processes are not preserved across server restarts. Mark any
        # persisted transaction session aborted instead of pretending it survived.
        for session in self.store.list():
            changed = False
            if session.get("transactionActive"):
                session["transactionActive"] = False
                session["transactionState"] = "aborted_on_server_restart"
                changed = True
            if changed:
                session["updatedAt"] = utc_now()
                self.store.write(str(session["id"]), session)

    def create(
        self,
        user_id: str,
        database_id: str,
        logical_database: str | None = None,
    ) -> dict[str, Any]:
        session_id = new_id("ses-")
        now = epoch()
        record = {
            "id": session_id,
            "userId": user_id,
            "databaseId": database_id,
            "logicalDatabase": logical_database,
            "createdAt": utc_now(),
            "updatedAt": utc_now(),
            "expiresAt": now + self.ttl_seconds,
            "transactionActive": False,
            "transactionState": "idle",
        }
        self.store.write(session_id, record)
        return record

    def get(self, session_id: str, user_id: str | None = None) -> dict[str, Any]:
        session = self.store.read(session_id)
        if not isinstance(session, dict):
            raise AsaServerError("SESSION_NOT_FOUND", "Session does not exist.", 404)
        if float(session.get("expiresAt", 0)) <= epoch():
            self.close(session_id, force=True)
            raise AsaServerError("SESSION_EXPIRED", "Session has expired.", 410)
        if user_id is not None and session.get("userId") != user_id:
            raise AsaServerError("SESSION_NOT_FOUND", "Session does not exist.", 404)
        return session

    def touch(self, session: dict[str, Any]) -> dict[str, Any]:
        session["updatedAt"] = utc_now()
        session["expiresAt"] = epoch() + self.ttl_seconds
        self.store.write(str(session["id"]), session)
        return session

    def begin(self, session_id: str, user_id: str) -> dict[str, Any]:
        with self._session_lock(session_id):
            session = self.get(session_id, user_id)
            database_id = str(session["databaseId"])
            if session.get("transactionActive"):
                raise TransactionConflict(
                    "TRANSACTION_ALREADY_ACTIVE",
                    "This session already has an active transaction.",
                    409,
                )
            with self._lock:
                owner = self._tx_owner.get(database_id)
                if owner and owner != session_id:
                    raise TransactionConflict(
                        "DATABASE_TRANSACTION_BUSY",
                        "Another client owns the database transaction lease.",
                        423,
                    )
                self._tx_owner[database_id] = session_id
            try:
                result = self.backends.get(database_id).begin_transaction(
                    session.get("logicalDatabase")
                )
            except Exception:
                with self._lock:
                    self._tx_owner.pop(database_id, None)
                raise
            session["transactionActive"] = True
            session["transactionState"] = "active"
            self.touch(session)
            return {"session": session, "result": result}

    def query(
        self,
        session_id: str,
        user_id: str,
        sql: str,
        *,
        allow_write: bool,
    ) -> dict[str, Any]:
        with self._session_lock(session_id):
            session = self.get(session_id, user_id)
            database_id = str(session["databaseId"])
            self.assert_database_available(database_id, session_id)
            if session.get("transactionActive") and session.get("transactionState") != "active":
                raise TransactionConflict(
                    "TRANSACTION_RECOVERY_REQUIRED",
                    "The transaction outcome is uncertain; retry COMMIT or ROLLBACK before running SQL.",
                    409,
                    {"transactionState": session.get("transactionState")},
                )
            if looks_like_write(sql) and not allow_write:
                raise AsaServerError(
                    "WRITE_FORBIDDEN",
                    "This user cannot execute write SQL.",
                    403,
                )
            backend = self.backends.get(database_id)
            logical_database = session.get("logicalDatabase")
            if logical_database and not session.get("transactionActive"):
                result = backend.query_in_database(str(logical_database), sql)
            else:
                result = backend.query(sql)
            self.touch(session)
            return result

    def commit(self, session_id: str, user_id: str) -> dict[str, Any]:
        return self._finish(session_id, user_id, "COMMIT;", "committed")

    def rollback(self, session_id: str, user_id: str) -> dict[str, Any]:
        return self._finish(session_id, user_id, "ROLLBACK;", "rolled_back")

    def _finish(
        self,
        session_id: str,
        user_id: str,
        sql: str,
        final_state: str,
    ) -> dict[str, Any]:
        with self._session_lock(session_id):
            session = self.get(session_id, user_id)
            if not session.get("transactionActive"):
                raise TransactionConflict(
                    "NO_ACTIVE_TRANSACTION",
                    "This session has no active transaction.",
                    409,
                )
            database_id = str(session["databaseId"])
            with self._lock:
                owner = self._tx_owner.get(database_id)
            if owner != session_id:
                raise TransactionConflict(
                    "TRANSACTION_LEASE_LOST",
                    "Transaction affinity was lost; restart the session.",
                    409,
                )
            try:
                result = self.backends.get(database_id).query(sql)
            except Exception:
                # Do not report a transaction outcome that the backend did not
                # confirm.  Keep its exclusive lease so a different client
                # cannot observe or overwrite possibly transaction-local state.
                session["transactionState"] = (
                    "commit_failed" if final_state == "committed" else "rollback_failed"
                )
                self.touch(session)
                raise
            else:
                with self._lock:
                    self._tx_owner.pop(database_id, None)
                session["transactionActive"] = False
                session["transactionState"] = final_state
                self.touch(session)
                return {"session": session, "result": result}

    def assert_database_available(
        self,
        database_id: str,
        session_id: str | None = None,
    ) -> None:
        with self._lock:
            owner = self._tx_owner.get(database_id)
        if owner and owner != session_id:
            raise TransactionConflict(
                "DATABASE_TRANSACTION_BUSY",
                "Database is reserved by another transaction session.",
                423,
            )

    def close(self, session_id: str, user_id: str | None = None, *, force: bool = False) -> None:
        lock = self._session_lock(session_id)
        with lock:
            session = self.get(session_id, user_id) if not force else self.store.read(session_id)
            if not isinstance(session, dict):
                return
            database_id = str(session.get("databaseId", ""))
            if session.get("transactionActive"):
                try:
                    self.backends.get(database_id).query("ROLLBACK;")
                except Exception:
                    # A failed cleanup is an uncertain transaction, not a
                    # successful logout/close.  Preserve the session and lease
                    # for an explicit recovery attempt or administrator action.
                    session["transactionState"] = "rollback_failed"
                    self.touch(session)
                    raise
            with self._lock:
                if self._tx_owner.get(database_id) == session_id:
                    self._tx_owner.pop(database_id, None)
            self.store.delete(session_id)
        with self._lock:
            self._session_locks.pop(session_id, None)

    def list_for_user(self, user_id: str, include_all: bool = False) -> list[dict[str, Any]]:
        sessions = self.store.list()
        if include_all:
            return sessions
        return [x for x in sessions if x.get("userId") == user_id]

    def reap(self) -> int:
        removed = 0
        for session in self.store.list():
            if float(session.get("expiresAt", 0)) <= epoch():
                self.close(str(session["id"]), force=True)
                removed += 1
        return removed
