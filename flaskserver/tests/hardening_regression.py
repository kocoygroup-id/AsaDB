"""Dependency-light server hardening regression gate.

Run with the bundled offline Python environment:

    python flaskserver/tests/hardening_regression.py
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from asadb_server.errors import AsaServerError, TransactionConflict
from asadb_server.sessions import SessionManager
from asadb_server.util import is_single_select_statement, looks_like_write


class FakeBackend:
    def __init__(self) -> None:
        self.sql: list[str] = []
        self.fail_on: set[str] = set()

    def query(self, sql: str) -> dict[str, str]:
        self.sql.append(sql)
        if sql in self.fail_on:
            raise RuntimeError(f"backend rejected {sql}")
        return {"ok": sql}

    def begin_transaction(self, logical_database=None) -> dict[str, str]:
        return self.query("BEGIN;")


class FakeBackends:
    def __init__(self) -> None:
        self.backends: dict[str, FakeBackend] = {}

    def get(self, database_id: str) -> FakeBackend:
        return self.backends.setdefault(database_id, FakeBackend())


class ServerHardeningRegression(unittest.TestCase):
    def test_reader_policy_is_single_top_level_select(self) -> None:
        self.assertTrue(is_single_select_statement("SELECT ';' AS literal; -- done\n"))
        self.assertFalse(is_single_select_statement("SELECT 1; UPDATE users SET admin = 1"))
        self.assertFalse(is_single_select_statement("WITH x AS (SELECT 1) SELECT * FROM x"))
        self.assertTrue(looks_like_write("SELECT 1; DELETE FROM users"))

    def test_commit_failure_keeps_lease_until_confirmed_recovery(self) -> None:
        with tempfile.TemporaryDirectory(prefix="asadb-hardening-") as directory:
            backends = FakeBackends()
            sessions = SessionManager(Path(directory), backends, ttl_seconds=3600)
            first = sessions.create("u1", "main")
            second = sessions.create("u2", "main")
            backend = backends.get("main")
            sessions.begin(first["id"], "u1")
            backend.fail_on.add("COMMIT;")

            with self.assertRaises(RuntimeError):
                sessions.commit(first["id"], "u1")
            failed = sessions.get(first["id"], "u1")
            self.assertTrue(failed["transactionActive"])
            self.assertEqual(failed["transactionState"], "commit_failed")
            with self.assertRaises(TransactionConflict) as blocked:
                sessions.query(second["id"], "u2", "SELECT 1;", allow_write=False)
            self.assertEqual(blocked.exception.code, "DATABASE_TRANSACTION_BUSY")

            backend.fail_on.remove("COMMIT;")
            recovered = sessions.commit(first["id"], "u1")["session"]
            self.assertFalse(recovered["transactionActive"])
            self.assertEqual(recovered["transactionState"], "committed")

    def test_rollback_failure_is_not_reported_as_success(self) -> None:
        with tempfile.TemporaryDirectory(prefix="asadb-hardening-") as directory:
            backends = FakeBackends()
            sessions = SessionManager(Path(directory), backends, ttl_seconds=3600)
            record = sessions.create("u1", "main")
            backend = backends.get("main")
            sessions.begin(record["id"], "u1")
            backend.fail_on.add("ROLLBACK;")

            with self.assertRaises(RuntimeError):
                sessions.rollback(record["id"], "u1")
            failed = sessions.get(record["id"], "u1")
            self.assertTrue(failed["transactionActive"])
            self.assertEqual(failed["transactionState"], "rollback_failed")


if __name__ == "__main__":
    unittest.main(verbosity=2)
