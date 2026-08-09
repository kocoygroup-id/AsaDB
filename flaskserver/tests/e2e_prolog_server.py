"""Real Flask -> supervised SWI-Prolog end-to-end regression.

This intentionally uses Flask's complete request stack and the normal backend
supervisor.  It does not replace the Prolog engine with a fake.
"""

from __future__ import annotations

import os
import tempfile
import threading
import time
from pathlib import Path

from asadb_server.app import create_app
from werkzeug.serving import make_server


def shutdown(app) -> None:
    app.extensions["asadb_maintenance"].stop()
    app.extensions["asadb_file_api"].stop()
    app.extensions["asadb_jobs"].shutdown()
    app.extensions["asadb_backends"].stop_all()


def require(response, expected: int, label: str) -> None:
    if response.status_code != expected:
        raise AssertionError(
            f"{label}: expected HTTP {expected}, got {response.status_code}: "
            f"{response.get_data(as_text=True)[:2000]}"
        )


def wait_for_panel_reservoir(client, job_id: str) -> dict:
    deadline = time.time() + 60
    while time.time() < deadline:
        response = client.get(f"/api/reservoir/job?id={job_id}")
        require(response, 200, "panel Reservoir poll")
        job = response.get_json()
        if job.get("result_available"):
            result = client.get(f"/api/reservoir/result?id={job_id}")
            require(result, 200, "panel Reservoir result")
            return result.get_json()
        if job.get("status") in {"failed", "cancelled", "interrupted"}:
            raise AssertionError(f"panel Reservoir import failed: {job}")
        time.sleep(0.05)
    raise AssertionError("panel Reservoir import timed out")


def main() -> None:
    repo = Path(os.environ["ASADB_REPO_ROOT"]).resolve()
    with tempfile.TemporaryDirectory(prefix="asadb-flask-e2e-") as root:
        base = Path(root)
        os.environ.update({
            "ASADB_REPO_ROOT": str(repo),
            "ASADB_DATA_DIR": str(base / "databases"),
            "ASADB_STATE_DIR": str(base / "state"),
            "ASADB_TEMP_DIR": str(base / "tmp"),
            "ASADB_SECRET_KEY": "integration-secret-key",
            "ASADB_CLUSTER_KEY": "integration-cluster-key",
            "ASADB_BACKEND_START_TIMEOUT": "30",
            "ASADB_ALLOW_LOCAL_ONLY": "true",
        })
        app = create_app({"TESTING": True})
        try:
            app.extensions["asadb_auth"].bootstrap_admin(
                "admin", "very-secure-password"
            )
            registry = app.extensions["asadb_registry"]
            registry.register("main", "main.asa")
            registry.register("restore", "restore.asa")
            client = app.test_client()

            require(
                client.post(
                    "/api/v1/auth/login",
                    json={"username": "admin", "password": "very-secure-password"},
                ),
                200,
                "API login",
            )
            browser_login = client.post(
                "/login",
                data={"username": "admin", "password": "very-secure-password"},
            )
            require(browser_login, 302, "browser login")
            if browser_login.headers.get("Location") != "/":
                raise AssertionError(
                    "browser login did not enter Server Workspace by default: "
                    f"{browser_login.headers.get('Location')}"
                )
            default_panel = client.get("/")
            require(default_panel, 200, "default Server Workspace")
            if b"Server Workspace" not in default_panel.data:
                raise AssertionError(
                    "default browser panel did not render Server Workspace"
                )
            require(client.post("/mode", data={"mode": "local"}), 302, "Local Workspace")
            local_query = client.post("/api/query", data={"sql": "SHOW DATABASES;"})
            require(local_query, 200, "Local Workspace query")
            local_payload = local_query.get_json()
            local_results = local_payload.get("results", []) if local_payload else []
            if not local_results or local_results[-1].get("status") != "table":
                raise AssertionError(
                    "Local Workspace did not reach the Prolog backend: "
                    f"{local_query.get_data(as_text=True)}"
                )
            # Local Workspace SQL DROP: this is the same authenticated panel
            # command path used by a typed DROP DATABASE statement.
            local_drop = client.post(
                "/api/query",
                data={"sql": "CREATE DATABASE local_drop; USE local_drop; DROP DATABASE local_drop;"},
            )
            require(local_drop, 200, "Local Workspace SQL DROP DATABASE")
            local_catalog = client.post("/api/query", data={"sql": "SHOW DATABASES;"})
            require(local_catalog, 200, "Local Workspace catalog after DROP")
            if b"local_drop" in local_catalog.data:
                raise AssertionError("Local Workspace DROP DATABASE resurrected local_drop")
            require(client.post("/mode", data={"mode": "server"}), 302, "Server Workspace")

            # Exercise the exact authenticated browser proxy used by the
            # AsAPanel Import menu.  Dialect metadata must survive Flask so
            # the Prolog backend converts CSV/XLSX instead of parsing bytes as
            # raw SQL.
            csv_payload = b"id,name\n1,Ayu\n2,Asa\n"
            panel_import = client.post(
                "/api/reservoir/jobs",
                data=csv_payload,
                headers={
                    "Content-Type": "application/octet-stream",
                    "Content-Length": str(len(csv_payload)),
                    "X-AsaDB-Job-Label": "panel.csv",
                    "X-AsaDB-Idempotency-Key": "panel-csv-e2e",
                    "X-AsaDB-Stop-On-Error": "true",
                    "X-AsaDB-Import-Format": "csv",
                    "X-AsaDB-Import-Name": "panel.csv",
                    "X-AsaDB-Import-Table": "panel_csv",
                    "X-AsaDB-Import-Mode": "replace",
                },
            )
            require(panel_import, 202, "panel CSV admission")
            admission = panel_import.get_json()
            wait_for_panel_reservoir(client, admission["job_id"])
            imported = client.post(
                "/api/query",
                data={
                    "sql": (
                        "USE main; SELECT id, name FROM panel_csv ORDER BY id;"
                    )
                },
            )
            require(imported, 200, "panel imported CSV query")
            if b"Ayu" not in imported.data or b"Asa" not in imported.data:
                raise AssertionError(
                    f"panel CSV rows missing: {imported.get_data(as_text=True)}"
                )

            # The browser defaults the import selector to ``auto``.  Exercise
            # that exact Reservoir upload route with MySQL-style SQL as well:
            # headers have to survive Flask, dialect detection has to select
            # MySQL from the original filename, and the resulting transaction
            # must commit before the panel reports success.
            mysql_payload = b"""
CREATE DATABASE panel_mysql;
USE panel_mysql;
CREATE TABLE `panel_rows` (`id` INT PRIMARY KEY, `name` VARCHAR(40));
INSERT INTO `panel_rows` (`id`, `name`) VALUES (1, 'Ayu'), (2, 'Asa');
""".lstrip()
            mysql_import = client.post(
                "/api/reservoir/jobs",
                data=mysql_payload,
                headers={
                    "Content-Type": "application/octet-stream",
                    "Content-Length": str(len(mysql_payload)),
                    "X-AsaDB-Job-Label": "panel.mysql",
                    "X-AsaDB-Idempotency-Key": "panel-mysql-auto-e2e",
                    "X-AsaDB-Stop-On-Error": "true",
                    "X-AsaDB-Import-Format": "auto",
                    "X-AsaDB-Import-Name": "panel.mysql",
                    "X-AsaDB-Import-Table": "",
                    "X-AsaDB-Import-Mode": "replace",
                },
            )
            require(mysql_import, 202, "panel MySQL auto admission")
            mysql_admission = mysql_import.get_json()
            wait_for_panel_reservoir(client, mysql_admission["job_id"])
            mysql_rows = client.post(
                "/api/query",
                data={
                    "sql": (
                        "USE panel_mysql; "
                        "SELECT id, name FROM panel_rows ORDER BY id;"
                    )
                },
            )
            require(mysql_rows, 200, "panel imported MySQL query")
            if b"Ayu" not in mysql_rows.data or b"Asa" not in mysql_rows.data:
                raise AssertionError(
                    "panel MySQL auto-import rows missing: "
                    f"{mysql_rows.get_data(as_text=True)}"
                )

            panel_export = client.post(
                "/api/export",
                data={
                    "database": "main",
                    "format": "csv",
                    "output": "save",
                    "tables": "panel_csv",
                    "data_tables": "panel_csv",
                    "include_schema": "true",
                    "include_data": "true",
                },
            )
            require(panel_export, 200, "panel CSV export")
            if b"id,name" not in panel_export.data or b"Ayu" not in panel_export.data:
                raise AssertionError("panel export omitted backend rows")

            # Server Workspace trash-button path emits this direct small DDL
            # request, then verifies SHOW DATABASES and refreshes the catalog.
            panel_drop = client.post(
                "/api/query",
                data={
                    "sql": (
                        "CREATE DATABASE server_drop; USE server_drop; "
                        "CREATE TABLE disposable (id INT); "
                        "INSERT INTO disposable VALUES (1); "
                        "DROP DATABASE server_drop;"
                    )
                },
            )
            require(panel_drop, 200, "panel CREATE/DROP DATABASE")
            databases_after_drop = client.post(
                "/api/query", data={"sql": "SHOW DATABASES;"}
            )
            require(databases_after_drop, 200, "panel databases after DROP")
            if b"server_drop" in databases_after_drop.data:
                raise AssertionError(
                    "panel DROP DATABASE left a catalog entry: "
                    f"drop={panel_drop.get_data(as_text=True)}; "
                    f"databases={databases_after_drop.get_data(as_text=True)}"
                )
            # A failed USE must leave Flask's logical-database session intact.
            require(
                client.post(
                    "/api/query",
                    data={"sql": "CREATE DATABASE retained_panel; USE retained_panel;"},
                ),
                200,
                "panel retained database setup",
            )
            failed_use = client.post(
                "/api/query", data={"sql": "USE never_created_panel;"}
            )
            require(failed_use, 200, "panel missing USE response")
            if b'"status":"error"' not in failed_use.data:
                raise AssertionError(
                    "USE of a missing database was accepted: "
                    f"{failed_use.get_data(as_text=True)}"
                )
            still_selected = client.post(
                "/api/query", data={"sql": "CREATE TABLE retained_ok (id INT);"}
            )
            require(still_selected, 200, "failed USE retained prior selection")
            if b'"status":"error"' in still_selected.data:
                raise AssertionError(
                    "failed USE changed Flask logical database: "
                    f"{still_selected.get_data(as_text=True)}"
                )
            require(
                client.post(
                    "/api/query", data={"sql": "DROP DATABASE retained_panel;"}
                ),
                200,
                "drop retained selected database",
            )
            post_drop_request = client.post("/api/query", data={"sql": "SHOW DATABASES;"})
            require(post_drop_request, 200, "new panel request after DROP")
            if b"retained_panel" in post_drop_request.data:
                raise AssertionError("new request resurrected dropped selected database")

            setup = client.post(
                "/api/v1/databases/main/query",
                json={
                    "sql": (
                        "CREATE DATABASE app; USE app; "
                        "CREATE TABLE smoke (id INT, name VARCHAR(20)); "
                        "INSERT INTO smoke VALUES (1, 'committed');"
                    )
                },
            )
            require(setup, 200, "database setup")

            session = client.post(
                "/api/v1/sessions",
                json={"databaseId": "main", "logicalDatabase": "app"},
            )
            require(session, 201, "create transaction session")
            session_id = session.get_json()["session"]["id"]
            require(client.post(f"/api/v1/sessions/{session_id}/begin"), 200, "BEGIN")
            require(
                client.post(
                    f"/api/v1/sessions/{session_id}/query",
                    json={"sql": "INSERT INTO smoke VALUES (2, 'commit');"},
                ),
                200,
                "transaction INSERT",
            )
            require(client.post(f"/api/v1/sessions/{session_id}/commit"), 200, "COMMIT")

            rollback_session = client.post(
                "/api/v1/sessions",
                json={"databaseId": "main", "logicalDatabase": "app"},
            )
            require(rollback_session, 201, "create rollback session")
            rollback_id = rollback_session.get_json()["session"]["id"]
            require(client.post(f"/api/v1/sessions/{rollback_id}/begin"), 200, "BEGIN rollback")
            require(
                client.post(
                    f"/api/v1/sessions/{rollback_id}/query",
                    json={"sql": "INSERT INTO smoke VALUES (3, 'rollback');"},
                ),
                200,
                "rollback INSERT",
            )
            require(
                client.post(f"/api/v1/sessions/{rollback_id}/rollback"),
                200,
                "ROLLBACK",
            )

            stream = client.post(
                "/api/v1/databases/main/stream",
                json={
                    "logicalDatabase": "app",
                    "sql": "SELECT id, name FROM smoke ORDER BY id;",
                    "pageSize": 1,
                },
            )
            require(stream, 200, "stream")
            stream_body = stream.get_data(as_text=True)
            if '"committed"' not in stream_body or '"commit"' not in stream_body:
                raise AssertionError(f"stream returned unexpected rows: {stream_body}")
            if "rollback" in stream_body:
                raise AssertionError(f"rollback was persisted: {stream_body}")

            backup = client.post(
                "/api/v1/databases/main/backup",
                json={"logicalDatabase": "app"},
            )
            require(backup, 200, "backup")
            snapshot = backup.data
            if not snapshot:
                raise AssertionError("backup returned an empty snapshot")

            restore = client.post(
                "/api/v1/databases/restore/restore",
                data=snapshot,
                content_type="application/octet-stream",
            )
            require(restore, 200, "restore")
            restored = client.post(
                "/api/v1/databases/restore/query",
                json={
                    "logicalDatabase": "app",
                    "sql": "SELECT id, name FROM smoke ORDER BY id;",
                },
            )
            require(restored, 200, "restored query")
            restored_text = restored.get_data(as_text=True)
            if "committed" not in restored_text or "commit" not in restored_text:
                raise AssertionError(f"restore data mismatch: {restored_text}")

            require(
                client.post("/api/v1/databases/main/save"),
                200,
                "explicit save before restart",
            )
            require(
                client.post("/api/v1/databases/main/restart"),
                200,
                "backend restart",
            )
            after_restart_catalog = client.post(
                "/api/v1/databases/main/query", json={"sql": "SHOW DATABASES;"}
            )
            require(after_restart_catalog, 200, "catalog after backend restart")
            for dropped_name in ("local_drop", "server_drop", "retained_panel"):
                if dropped_name in after_restart_catalog.get_data(as_text=True):
                    raise AssertionError(
                        f"backend restart resurrected {dropped_name}: "
                        f"{after_restart_catalog.get_data(as_text=True)}"
                    )
            after_restart = client.post(
                "/api/v1/databases/main/query",
                json={
                    "logicalDatabase": "app",
                    "sql": "SELECT id, name FROM smoke ORDER BY id;",
                },
            )
            require(after_restart, 200, "query after restart")
            after_restart_text = after_restart.get_data(as_text=True)
            if "committed" not in after_restart_text:
                after_restart_star = client.post(
                    "/api/v1/databases/main/query",
                    json={
                        "logicalDatabase": "app",
                        "sql": "SELECT * FROM smoke ORDER BY id;",
                    },
                )
                after_restart_tables = client.post(
                    "/api/v1/databases/main/query",
                    json={
                        "logicalDatabase": "app",
                        "sql": "SHOW TABLES;",
                    },
                )
                backend_status = app.extensions["asadb_backends"].get("main").status()
                raise AssertionError(
                    "data was not durable after backend restart: "
                    f"projection={after_restart_text}; "
                    f"star={after_restart_star.get_data(as_text=True)}; "
                    f"tables={after_restart_tables.get_data(as_text=True)}; "
                    f"backend={backend_status}"
                )
        finally:
            shutdown(app)

    replication_e2e(repo)


def configured_node(
    repo: Path,
    root: Path,
    node_id: str,
    *,
    public_url: str,
    primary_node: str,
    replica_nodes: list[str],
):
    node_root = root / node_id
    os.environ.update({
        "ASADB_REPO_ROOT": str(repo),
        "ASADB_DATA_DIR": str(node_root / "databases"),
        "ASADB_STATE_DIR": str(node_root / "state"),
        "ASADB_TEMP_DIR": str(node_root / "tmp"),
        "ASADB_SECRET_KEY": f"{node_id}-integration-secret-key",
        "ASADB_CLUSTER_KEY": "shared-integration-cluster-key",
        "ASADB_BACKEND_START_TIMEOUT": "30",
        "ASADB_NODE_ID": node_id,
        "ASADB_PUBLIC_URL": public_url,
        "ASADB_CLUSTER_ENABLED": "true",
    })
    app = create_app({"TESTING": True})
    app.extensions["asadb_auth"].bootstrap_admin("admin", "very-secure-password")
    app.extensions["asadb_registry"].register(
        "main",
        "main.asa",
        primary_node=primary_node,
        replica_nodes=replica_nodes,
    )
    return app


def login(client) -> None:
    require(
        client.post(
            "/api/v1/auth/login",
            json={"username": "admin", "password": "very-secure-password"},
        ),
        200,
        "cluster login",
    )


def wait_for_job(client, job_id: str, expected: str) -> dict:
    deadline = time.time() + 60
    while time.time() < deadline:
        response = client.get(f"/api/v1/jobs/{job_id}")
        require(response, 200, "replication job poll")
        job = response.get_json()["job"]
        if job["status"] in {"completed", "failed", "cancelled", "interrupted"}:
            if job["status"] != expected:
                raise AssertionError(f"replication job expected {expected}: {job}")
            return job
        time.sleep(0.2)
    raise AssertionError("replication job timed out")


def replication_e2e(repo: Path) -> None:
    """Exercise a primary and replica through the real snapshot HTTP path."""
    with tempfile.TemporaryDirectory(prefix="asadb-replication-e2e-") as root:
        base = Path(root)
        primary = configured_node(
            repo, base, "primary",
            public_url="http://127.0.0.1:1",
            primary_node="primary",
            replica_nodes=["replica", "offline"],
        )
        try:
            primary_client = primary.test_client()
            login(primary_client)
            require(
                primary_client.post(
                    "/api/v1/databases/main/query",
                    json={
                        "sql": (
                            "CREATE DATABASE app; USE app; "
                            "CREATE TABLE replica_smoke (id INT, name VARCHAR(20)); "
                            "INSERT INTO replica_smoke VALUES (1, 'primary');"
                        )
                    },
                ),
                200,
                "primary setup",
            )

            replica = configured_node(
                repo, base, "replica",
                public_url="http://127.0.0.1:1",
                primary_node="primary",
                replica_nodes=["replica"],
            )
            server = make_server("127.0.0.1", 0, replica)
            replica_url = f"http://127.0.0.1:{server.server_port}"
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                primary.extensions["asadb_cluster"].add_node("replica", replica_url)
                primary.extensions["asadb_cluster"].add_node(
                    "offline", "http://127.0.0.1:9"
                )
                started = primary_client.post(
                    "/api/v1/replication/main",
                    json={"logicalDatabase": "app", "targetNode": "replica"},
                )
                require(started, 202, "primary-to-replica snapshot")
                completed = wait_for_job(
                    primary_client, started.get_json()["job"]["id"], "completed"
                )
                if not completed.get("result", {}).get("sha256"):
                    raise AssertionError(f"replication did not report snapshot digest: {completed}")
                replica_record = replica.extensions["asadb_registry"].get("main")
                if replica_record.get("replicaState") != "ready":
                    raise AssertionError(
                        f"replica accepted a snapshot without ready state: {replica_record}"
                    )
                if not replica.extensions["asadb_cluster"].local_can_serve_read("main"):
                    raise AssertionError(
                        f"replica cannot serve its accepted snapshot: {replica_record}"
                    )

                replica_client = replica.test_client()
                login(replica_client)
                copied = replica_client.post(
                    "/api/v1/databases/main/query",
                    json={
                        "logicalDatabase": "app",
                        "sql": "SELECT id, name FROM replica_smoke ORDER BY id;",
                    },
                )
                require(copied, 200, "replica read")
                if "primary" not in copied.get_data(as_text=True):
                    raise AssertionError("replica did not expose restored primary data")

                previous = primary.extensions["asadb_registry"].get("main")[
                    "lastReplicatedAt"
                ]
                failed = primary_client.post(
                    "/api/v1/replication/main",
                    json={"logicalDatabase": "app", "targetNode": "offline"},
                )
                require(failed, 202, "offline replica submission")
                wait_for_job(primary_client, failed.get_json()["job"]["id"], "failed")
                current = primary.extensions["asadb_registry"].get("main")[
                    "lastReplicatedAt"
                ]
                if current != previous:
                    raise AssertionError("failed replication incorrectly advanced durable state")
            finally:
                server.shutdown()
                thread.join(timeout=10)
                shutdown(replica)
        finally:
            shutdown(primary)


if __name__ == "__main__":
    main()
