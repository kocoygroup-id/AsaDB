"""Opt-in integration coverage for the real Flask -> Prolog server path."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

pytestmark = pytest.mark.integration
pytest.importorskip("flask")
pytest.importorskip("requests")

from asadb_server.app import create_app


def _shutdown(app) -> None:
    app.extensions["asadb_maintenance"].stop()
    app.extensions["asadb_file_api"].stop()
    app.extensions["asadb_jobs"].shutdown()
    app.extensions["asadb_backends"].stop_all()


@pytest.mark.skipif(
    os.getenv("ASADB_RUN_REAL_TESTS") != "1",
    reason="Set ASADB_RUN_REAL_TESTS=1 in a complete checkout with Flask and SWI-Prolog.",
)
def test_authenticated_panel_uses_the_official_prolog_engine(monkeypatch, tmp_path: Path):
    repo = Path(os.environ["ASADB_REPO_ROOT"]).resolve()
    monkeypatch.setenv("ASADB_REPO_ROOT", str(repo))
    monkeypatch.setenv("ASADB_DATA_DIR", str(tmp_path / "databases"))
    monkeypatch.setenv("ASADB_STATE_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("ASADB_TEMP_DIR", str(tmp_path / "tmp"))
    monkeypatch.setenv("ASADB_SECRET_KEY", "integration-secret-key")
    monkeypatch.setenv("ASADB_CLUSTER_KEY", "integration-cluster-key")
    monkeypatch.setenv("ASADB_BACKEND_START_TIMEOUT", "20")

    app = create_app({"TESTING": True})
    try:
        app.extensions["asadb_auth"].bootstrap_admin("admin", "very-secure-password")
        app.extensions["asadb_registry"].register("main", "main.asa")
        client = app.test_client()

        login = client.post(
            "/api/v1/auth/login",
            json={"username": "admin", "password": "very-secure-password"},
        )
        assert login.status_code == 200

        result = client.post(
            "/api/v1/databases/main/query",
            json={
                "sql": (
                    "CREATE DATABASE app; USE app; "
                    "CREATE TABLE smoke (id INT, name VARCHAR(20)); "
                    "INSERT INTO smoke VALUES (1, 'ok'); "
                    "SELECT name FROM smoke ORDER BY id;"
                )
            },
        )
        assert result.status_code == 200
        assert "ok" in result.get_data(as_text=True)

        panel = client.get("/")
        assert panel.status_code == 200
        assert b"asadb-server-bar" in panel.data
        assert b"assets/app-loader.js" in panel.data
        assert client.get("/assets/app-loader.js").status_code == 200

        panel_query = client.post(
            "/api/query",
            data={"sql": "USE app; SELECT name FROM smoke ORDER BY id;"},
        )
        assert panel_query.status_code == 200
        assert b"ok" in panel_query.data
    finally:
        _shutdown(app)
