from __future__ import annotations

from pathlib import Path
import inspect

import pytest

pytest.importorskip("flask")
pytest.importorskip("werkzeug")

from asadb_server.app import create_app
from asadb_server import __version__
from asadb_server.auth import AuthManager
from asadb_server.cli import first_run
from asadb_server.config import Settings
from asadb_server.registry import DatabaseRegistry
from asadb_server import panel as panel_module


def test_health_and_password_login(monkeypatch, tmp_path: Path):
    repo = tmp_path / "repo"
    (repo / "src").mkdir(parents=True)
    (repo / "web").mkdir()
    (repo / "src" / "asadb_web.pl").write_text("% fake", encoding="utf-8")
    (repo / "src" / "asadb.pl").write_text("% fake", encoding="utf-8")
    (repo / "web" / "index.html").write_text("<html><body>panel</body></html>", encoding="utf-8")
    (repo / "web" / "assets").mkdir()
    (repo / "web" / "assets" / "style.css").write_text(":root {}", encoding="utf-8")
    (repo / "web" / "assets" / "asadb-logo.png").write_bytes(b"png")

    monkeypatch.setenv("ASADB_REPO_ROOT", str(repo))
    monkeypatch.setenv("ASADB_DATA_DIR", str(tmp_path / "data"))
    monkeypatch.setenv("ASADB_STATE_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("ASADB_TEMP_DIR", str(tmp_path / "temp"))
    monkeypatch.setenv("ASADB_SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("ASADB_CLUSTER_KEY", "test-cluster-key")
    monkeypatch.setenv("ASADB_ALLOW_LOCAL_ONLY", "true")

    app = create_app({"TESTING": True})
    auth = app.extensions["asadb_auth"]
    auth.bootstrap_admin("admin", "very-secure-password")
    app.extensions["asadb_registry"].register("main", "data.asa")

    client = app.test_client()
    health = client.get("/api/v1/health")
    assert health.status_code == 200
    health_body = health.get_json()
    assert health_body["service"] == "asadb-flask-server"
    assert health_body["version"] == __version__
    assert health_body["engineVersion"] == __version__

    readiness = client.get("/api/v1/readiness")
    assert readiness.status_code == 200
    assert readiness.get_json()["ready"] is True

    login = client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "very-secure-password"},
    )
    assert login.status_code == 200
    assert login.get_json()["user"]["username"] == "admin"

    metrics = client.get("/api/v1/metrics")
    assert metrics.status_code == 200
    assert metrics.get_json()["databases"] == 1

    user_id = login.get_json()["user"]["id"]
    session_record = app.extensions["asadb_sessions"].create(user_id, "main")
    logout = client.post("/api/v1/auth/logout")
    assert logout.status_code == 200
    assert app.extensions["asadb_sessions"].store.read(session_record["id"]) is None

    # The browser flow is intentionally login-first.  Server Workspace is the
    # safe backend default after credentials are accepted, and Local Workspace
    # is never a remote authentication bypass.
    browser_login = client.post(
        "/login",
        data={"username": "admin", "password": "very-secure-password"},
    )
    assert browser_login.status_code == 302
    assert browser_login.headers["Location"].endswith("/")
    default_panel = client.get("/")
    assert default_panel.status_code == 200
    assert b"Server Workspace" in default_panel.data
    mode_page = client.get("/mode")
    assert mode_page.status_code == 200
    assert b"Local Workspace" in mode_page.data
    select_local = client.post("/mode", data={"mode": "local"})
    assert select_local.status_code == 302
    panel = client.get("/")
    assert panel.status_code == 200
    assert b"Local Workspace" in panel.data
    assert b'<main class="main">\n    <aside id="asadb-server-bar"' in panel.data
    assert (
        b'<nav><a href="/admin">Admin</a><a href="/mode">Switch workspace</a>'
        b'<a href="/logout">Logout</a></nav>'
    ) in panel.data
    assert b"Admin</a> \xc2\xb7" not in panel.data
    server_css = client.get("/static/server.css").data
    assert b"position: fixed" not in server_css
    assert b'a[href="/admin"] + a[href="/mode"]::before' in server_css
    assert b"nav a + a::before" not in server_css
    panel_proxy_source = inspect.getsource(panel_module.panel_api_proxy)
    for import_header in (
        "X-AsaDB-Import-Format",
        "X-AsaDB-Import-Name",
        "X-AsaDB-Import-Table",
        "X-AsaDB-Import-Mode",
    ):
        assert import_header in panel_proxy_source
    assert client.get("/panel-assets/style.css").status_code == 200
    assert client.get("/panel-assets/app.js").status_code == 404

    admin = client.get("/admin")
    assert admin.status_code == 200
    assert b"server-admin-topbar" in admin.data
    assert b"Users &amp; roles" in admin.data

    remote_mode_page = client.get(
        "/mode", environ_overrides={"REMOTE_ADDR": "203.0.113.10"}
    )
    assert remote_mode_page.status_code == 200
    assert b"Local Workspace</strong>" not in remote_mode_page.data

    logout_session = app.extensions["asadb_sessions"].create(user_id, "main")
    confirmation = client.get("/logout")
    assert confirmation.status_code == 200
    assert app.extensions["asadb_sessions"].store.read(logout_session["id"]) is not None
    browser_logout = client.post("/logout")
    assert browser_logout.status_code == 302
    assert app.extensions["asadb_sessions"].store.read(logout_session["id"]) is None

    app.extensions["asadb_maintenance"].stop()
    app.extensions["asadb_file_api"].stop()
    app.extensions["asadb_jobs"].shutdown()
    app.extensions["asadb_backends"].stop_all()


def test_first_run_creates_only_the_missing_control_plane(monkeypatch, tmp_path: Path):
    monkeypatch.setenv("ASADB_REPO_ROOT", str(tmp_path / "repo"))
    monkeypatch.setenv("ASADB_DATA_DIR", str(tmp_path / "data"))
    monkeypatch.setenv("ASADB_STATE_DIR", str(tmp_path / "state"))
    monkeypatch.setenv("ASADB_TEMP_DIR", str(tmp_path / "temp"))
    monkeypatch.setenv("ASADB_SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("ASADB_CLUSTER_KEY", "test-cluster-key")
    answers = iter(["admin", "very-secure-password", "very-secure-password"])
    monkeypatch.setattr("asadb_server.cli.click.prompt", lambda *_args, **_kwargs: next(answers))

    settings = Settings.load()
    first_run(settings, "main", "data.asa")

    assert AuthManager(settings.state_dir, settings.token_ttl_seconds).find_user("admin")
    assert DatabaseRegistry(settings.state_dir, settings.data_dir, settings.node_id).get("main")[
        "filename"
    ] == "data.asa"
