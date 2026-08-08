from __future__ import annotations

from pathlib import Path

import pytest

from asadb_server.errors import TransactionConflict
from asadb_server.sessions import SessionManager


class FakeBackend:
    def __init__(self):
        self.sql = []

    def query(self, sql):
        self.sql.append(sql)
        return {"ok": sql}

    def begin_transaction(self, logical_database=None):
        sql = f"USE {logical_database}; BEGIN;" if logical_database else "BEGIN;"
        return self.query(sql)


class FakeBackends:
    def __init__(self):
        self.backends = {}

    def get(self, database_id):
        return self.backends.setdefault(database_id, FakeBackend())


def test_transaction_affinity_across_requests(tmp_path: Path):
    backends = FakeBackends()
    sessions = SessionManager(tmp_path, backends, ttl_seconds=3600)
    first = sessions.create("u1", "main")
    second = sessions.create("u2", "main")

    sessions.begin(first["id"], "u1")
    result = sessions.query(
        first["id"],
        "u1",
        "UPDATE x SET y = 1;",
        allow_write=True,
    )
    assert result["ok"].startswith("UPDATE")

    with pytest.raises(TransactionConflict):
        sessions.query(
            second["id"],
            "u2",
            "SELECT * FROM x;",
            allow_write=False,
        )

    sessions.commit(first["id"], "u1")
    result = sessions.query(
        second["id"],
        "u2",
        "SELECT * FROM x;",
        allow_write=False,
    )
    assert result["ok"].startswith("SELECT")


def test_close_rolls_back_active_transaction(tmp_path: Path):
    backends = FakeBackends()
    sessions = SessionManager(tmp_path, backends, ttl_seconds=3600)
    record = sessions.create("u1", "main")
    sessions.begin(record["id"], "u1")
    sessions.close(record["id"], "u1")
    assert "ROLLBACK;" in backends.get("main").sql


def test_logical_database_affinity(tmp_path: Path):
    class LogicalBackend(FakeBackend):
        def query_in_database(self, logical_database, sql):
            self.sql.append(f"[{logical_database}] {sql}")
            return {"logical": logical_database, "ok": sql}

    class LogicalBackends(FakeBackends):
        def get(self, database_id):
            return self.backends.setdefault(database_id, LogicalBackend())

    backends = LogicalBackends()
    sessions = SessionManager(tmp_path, backends, ttl_seconds=3600)
    record = sessions.create("u1", "main", "app")
    result = sessions.query(
        record["id"],
        "u1",
        "SELECT * FROM users;",
        allow_write=False,
    )
    assert result["logical"] == "app"

    sessions.begin(record["id"], "u1")
    sessions.query(
        record["id"],
        "u1",
        "SELECT * FROM users;",
        allow_write=False,
    )
    # During a transaction the backend's already-selected context is reused.
    assert backends.get("main").sql[-1] == "SELECT * FROM users;"
    sessions.rollback(record["id"], "u1")
