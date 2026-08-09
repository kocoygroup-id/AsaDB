from __future__ import annotations

import getpass
import json
import os
import subprocess
import sys
import threading
import time
import webbrowser
from pathlib import Path
from typing import Any

import click
from waitress import serve

from .app import create_app
from . import __version__
from .auth import AuthManager
from .client import AsaDBClient, RemoteError
from .config import Settings
from .file_api import FileApiGateway
from .registry import DatabaseRegistry


def config_home() -> Path:
    override = os.getenv("ASADB_CLIENT_CONFIG")
    if override:
        return Path(override).expanduser().resolve()
    if os.name == "nt":
        base = Path(os.getenv("APPDATA", Path.home()))
    else:
        base = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "asadb"


def profiles_file() -> Path:
    path = config_home() / "profiles.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def load_profiles() -> dict[str, Any]:
    path = profiles_file()
    if not path.exists():
        return {"current": None, "profiles": {}}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {"current": None, "profiles": {}}
    return value if isinstance(value, dict) else {"current": None, "profiles": {}}


def save_profiles(value: dict[str, Any]) -> None:
    path = profiles_file()
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(value, indent=2), encoding="utf-8")
    os.replace(temp, path)
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def profile_client(profile_name: str | None = None) -> AsaDBClient:
    profiles = load_profiles()
    name = profile_name or profiles.get("current")
    profile = profiles.get("profiles", {}).get(name)
    if not isinstance(profile, dict):
        raise click.ClickException("No remote profile is configured. Run: asadb remote login")
    return AsaDBClient(
        str(profile["url"]),
        token=profile.get("token"),
        timeout=float(profile.get("timeout", 120)),
    )


def echo_json(value: Any) -> None:
    click.echo(json.dumps(value, ensure_ascii=False, indent=2, default=str))


@click.group(context_settings={"help_option_names": ["-h", "--help"]})
@click.version_option(__version__)
def main():
    """AsaDB local/server launcher, remote client, and administration CLI."""


@main.command("init")
@click.option("--username", default="admin", show_default=True)
@click.option("--password", default=None, help="Admin password; omitted prompts securely.")
@click.option("--database-id", default="main", show_default=True)
@click.option("--filename", default="data.asa", show_default=True)
@click.option("--skip-database", is_flag=True)
def init_command(
    username: str,
    password: str | None,
    database_id: str,
    filename: str,
    skip_database: bool,
):
    """Initialize the file-based control plane and first administrator."""
    settings = Settings.load()
    settings.prepare()
    missing = settings.validate_repo()
    if missing:
        click.echo("Warning: repository integration files are missing:")
        for item in missing:
            click.echo(f"  - {item}")

    password = password or getpass.getpass(f"Password for {username}: ")
    auth = AuthManager(settings.state_dir, settings.token_ttl_seconds)
    user = auth.bootstrap_admin(username, password)

    registry = DatabaseRegistry(settings.state_dir, settings.data_dir, settings.node_id)
    database = None
    if not skip_database:
        try:
            database = registry.register(database_id, filename)
        except Exception as exc:
            if "already" not in str(exc).lower():
                raise
            database = registry.get(database_id, require_enabled=False)

    click.echo("AsaDB Flask Server initialized.")
    echo_json({
        "admin": user,
        "database": database,
        "stateDir": str(settings.state_dir),
        "dataDir": str(settings.data_dir),
    })


@main.command("doctor")
def doctor():
    """Validate Python, SWI-Prolog, repository files, paths, and configuration."""
    settings = Settings.load()
    checks = [
        ("Python", sys.executable, True),
        ("SWI-Prolog", settings.swipl, bool(shutil_which(settings.swipl))),
        ("Repository root", settings.repo_root, settings.repo_root.exists()),
        ("AsaDB panel backend", settings.prolog_web, settings.prolog_web.exists()),
        ("AsaDB CLI", settings.prolog_cli, settings.prolog_cli.exists()),
        ("AsAPanel index", settings.web_root / "index.html", (settings.web_root / "index.html").exists()),
        ("Data directory", settings.data_dir, True),
        ("State directory", settings.state_dir, True),
    ]
    failed = False
    for name, value, ok in checks:
        click.echo(f"[{'OK' if ok else 'FAIL'}] {name}: {value}")
        failed = failed or not ok
    if settings.secret_key == "development-only-change-me":
        click.echo("[WARN] ASADB_SECRET_KEY still uses the development default.")
    if settings.cluster_key == "development-cluster-key":
        click.echo("[WARN] ASADB_CLUSTER_KEY still uses the development default.")
    if failed:
        raise SystemExit(1)


def shutil_which(command: str) -> str | None:
    import shutil
    return shutil.which(command)


def serve_server(
    host: str | None,
    port: int | None,
    threads: int | None,
    development: bool,
):
    """Start Waitress after all shared server safeguards are validated."""
    settings = Settings.load()
    app = create_app()
    host = host or settings.host
    port = port or settings.port
    public_bind = host not in {"127.0.0.1", "::1", "localhost"}
    if public_bind and settings.secret_key == "development-only-change-me":
        raise click.ClickException(
            "Refusing a public bind while ASADB_SECRET_KEY uses the default."
        )
    if settings.cluster_enabled and settings.cluster_key == "development-cluster-key":
        raise click.ClickException(
            "Refusing cluster mode while ASADB_CLUSTER_KEY uses the default."
        )
    if development:
        app.run(
            host=host,
            port=port,
            debug=settings.debug,
            threaded=True,
            use_reloader=False,
        )
    else:
        serve(
            app,
            host=host,
            port=port,
            threads=threads or settings.thread_pool_size,
            channel_timeout=max(60, int(settings.query_timeout) + 15),
        )


@main.command("server")
@click.option("--host", default=None)
@click.option("--port", default=None, type=int)
@click.option("--threads", default=None, type=click.IntRange(1, 256))
@click.option("--development", is_flag=True, help="Use Flask development server.")
def server_command(
    host: str | None,
    port: int | None,
    threads: int | None,
    development: bool,
):
    """Run an already initialized AsaDB Flask server."""
    serve_server(host, port, threads, development)


def first_run(settings: Settings, database_id: str, filename: str) -> None:
    """Create the minimal control plane once, without hidden credentials."""
    settings.prepare()
    auth = AuthManager(settings.state_dir, settings.token_ttl_seconds)
    if not auth.users.list():
        click.echo("First AsaDB start: create the administrator used by the login page.")
        username = click.prompt("Administrator username", default="admin")
        password = click.prompt(
            f"Password for {username}",
            hide_input=True,
            confirmation_prompt=True,
        )
        user = auth.bootstrap_admin(username, password)
        click.echo(f"Administrator '{user['username']}' created.")

    registry = DatabaseRegistry(settings.state_dir, settings.data_dir, settings.node_id)
    try:
        registry.get(database_id, require_enabled=False)
    except Exception as error:
        if getattr(error, "code", "") != "DATABASE_NOT_FOUND":
            raise
        registry.register(database_id, filename)
        click.echo(f"Registered database file '{filename}' as '{database_id}'.")


def start_portal(
    database_file: str,
    database_id: str,
    host: str | None,
    port: int | None,
    threads: int | None,
    open_browser: bool,
    development: bool,
):
    """One-command authenticated AsAPanel launcher for local and server work."""
    settings = Settings.load()
    first_run(settings, database_id, database_file)
    effective_host = host or settings.host
    effective_port = port or settings.port
    if open_browser:
        address_host = "127.0.0.1" if effective_host in {"0.0.0.0", "::"} else effective_host
        address = f"http://{address_host}:{effective_port}/login"
        # Waitress owns the current thread, therefore open after it has bound
        # in a short daemon timer.  A headless system simply ignores this.
        opener = threading.Timer(0.8, lambda: webbrowser.open(address))
        opener.daemon = True
        opener.start()
    click.echo(
        f"AsaDB portal is starting at http://{effective_host}:{effective_port}/login "
        "(sign in; Server Workspace opens by default; use Switch workspace for Local Workspace)."
    )
    serve_server(effective_host, effective_port, threads, development)


@main.command("start")
@click.option("--database", "database_file", default="data.asa", show_default=True)
@click.option("--database-id", default="main", show_default=True)
@click.option("--host", default=None)
@click.option("--port", default=None, type=int)
@click.option("--threads", default=None, type=click.IntRange(1, 256))
@click.option("--no-open-browser", "open_browser", flag_value=False, default=True)
@click.option("--development", is_flag=True, help="Use Flask development server.")
def start_command(
    database_file: str,
    database_id: str,
    host: str | None,
    port: int | None,
    threads: int | None,
    open_browser: bool,
    development: bool,
):
    """One-command authenticated AsAPanel launcher for local and server work."""
    start_portal(
        database_file,
        database_id,
        host,
        port,
        threads,
        open_browser,
        development,
    )


@main.group("local")
def local_group():
    """Use the original repository in local mode."""


@local_group.command("panel")
@click.option("--database", "database_file", default="data.asa", show_default=True)
@click.option("--port", default=8088, show_default=True)
@click.option("--open-browser/--no-open-browser", default=True)
def local_panel(database_file: str, port: int, open_browser: bool):
    """Compatibility alias for the authenticated one-command browser portal."""
    start_portal(
        database_file,
        "main",
        None,
        port,
        None,
        open_browser,
        False,
    )


@local_group.command("cli")
@click.option("--database", "database_file", default="data.asa", show_default=True)
def local_cli(database_file: str):
    """Run the original interactive SWI-Prolog AsaDB CLI."""
    settings = Settings.load()
    command = [
        settings.swipl,
        "-q",
        "-s",
        str(settings.prolog_cli),
        "--",
        database_file,
    ]
    raise SystemExit(subprocess.call(command, cwd=settings.repo_root))


@local_group.command("sql")
@click.argument("sql")
@click.option("--database", "database_file", default="data.asa", show_default=True)
def local_sql(sql: str, database_file: str):
    """Execute a local SQL script through the original AsaDB CLI entrypoint."""
    settings = Settings.load()
    temp = settings.temp_dir / f"cli-{int(time.time() * 1000)}.sql"
    temp.parent.mkdir(parents=True, exist_ok=True)
    temp.write_text(sql, encoding="utf-8")
    try:
        command = [
            settings.swipl,
            "-q",
            "-s",
            str(settings.prolog_cli),
            "--",
            database_file,
            str(temp),
        ]
        raise SystemExit(subprocess.call(command, cwd=settings.repo_root))
    finally:
        temp.unlink(missing_ok=True)


@main.group("remote")
def remote_group():
    """Use AsaDB through the Flask server API."""


@remote_group.command("login")
@click.option("--url", prompt="Server URL", default="http://127.0.0.1:2026")
@click.option("--username", prompt=True)
@click.option("--password", prompt=True, hide_input=True)
@click.option("--profile", default="default", show_default=True)
def remote_login(url: str, username: str, password: str, profile: str):
    client = AsaDBClient(url)
    result = client.login(username, password)
    profiles = load_profiles()
    profiles.setdefault("profiles", {})[profile] = {
        "url": url.rstrip("/"),
        "token": client.token,
        "username": username,
        "timeout": 120,
    }
    profiles["current"] = profile
    save_profiles(profiles)
    click.echo(f"Logged in as {result['user']['username']} using profile '{profile}'.")


@remote_group.command("profiles")
def remote_profiles():
    echo_json(load_profiles())


@remote_group.command("use-profile")
@click.argument("profile")
def remote_use_profile(profile: str):
    profiles = load_profiles()
    if profile not in profiles.get("profiles", {}):
        raise click.ClickException(f"Unknown profile: {profile}")
    profiles["current"] = profile
    save_profiles(profiles)
    click.echo(f"Current profile: {profile}")


@remote_group.command("databases")
@click.option("--profile", default=None)
def remote_databases(profile: str | None):
    echo_json(profile_client(profile).databases())


@remote_group.command("query")
@click.argument("database_id")
@click.argument("sql")
@click.option("--profile", default=None)
@click.option("--session", "session_id", default=None)
@click.option("--logical-database", default=None)
def remote_query(
    database_id: str,
    sql: str,
    profile: str | None,
    session_id: str | None,
    logical_database: str | None,
):
    echo_json(profile_client(profile).query(
        database_id,
        sql,
        session_id=session_id,
        logical_database=logical_database,
    ))


@remote_group.command("stream")
@click.argument("database_id")
@click.argument("sql")
@click.option("--page-size", default=500, show_default=True)
@click.option("--profile", default=None)
@click.option("--logical-database", default=None)
def remote_stream(
    database_id: str,
    sql: str,
    page_size: int,
    profile: str | None,
    logical_database: str | None,
):
    for page in profile_client(profile).stream_query(
        database_id,
        sql,
        page_size=page_size,
        logical_database=logical_database,
    ):
        click.echo(json.dumps(page, ensure_ascii=False, separators=(",", ":")))


@remote_group.command("shell")
@click.argument("database_id")
@click.option("--profile", default=None)
def remote_shell(database_id: str, profile: str | None):
    """Interactive remote SQL shell. End commands with semicolon; .quit exits."""
    client = profile_client(profile)
    buffer: list[str] = []
    while True:
        prompt = "asadb(remote)> " if not buffer else "... "
        try:
            line = input(prompt)
        except (EOFError, KeyboardInterrupt):
            click.echo()
            break
        if line.strip() in {".quit", ".exit"}:
            break
        buffer.append(line)
        if ";" not in line:
            continue
        sql = "\n".join(buffer)
        buffer.clear()
        try:
            echo_json(client.query(database_id, sql))
        except Exception as exc:
            click.echo(f"error: {exc}", err=True)


@remote_group.group("session")
def remote_session_group():
    """Remote transaction sessions spanning multiple HTTP requests."""


@remote_session_group.command("create")
@click.argument("database_id")
@click.option("--profile", default=None)
@click.option("--logical-database", required=True)
def remote_session_create(
    database_id: str,
    profile: str | None,
    logical_database: str | None,
):
    echo_json(profile_client(profile).create_session(database_id, logical_database))


@remote_session_group.command("begin")
@click.argument("session_id")
@click.option("--profile", default=None)
def remote_session_begin(session_id: str, profile: str | None):
    echo_json(profile_client(profile).begin(session_id))


@remote_session_group.command("query")
@click.argument("session_id")
@click.argument("sql")
@click.option("--database-id", default="_", hidden=True)
@click.option("--profile", default=None)
def remote_session_query(
    session_id: str,
    sql: str,
    database_id: str,
    profile: str | None,
):
    echo_json(profile_client(profile).query(database_id, sql, session_id=session_id))


@remote_session_group.command("commit")
@click.argument("session_id")
@click.option("--profile", default=None)
def remote_session_commit(session_id: str, profile: str | None):
    echo_json(profile_client(profile).commit(session_id))


@remote_session_group.command("rollback")
@click.argument("session_id")
@click.option("--profile", default=None)
def remote_session_rollback(session_id: str, profile: str | None):
    echo_json(profile_client(profile).rollback(session_id))



@remote_group.command("backup")
@click.argument("database_id")
@click.argument("logical_database")
@click.argument("output", type=click.Path(dir_okay=False, path_type=Path))
@click.option("--profile", default=None)
def remote_backup(
    database_id: str,
    logical_database: str,
    output: Path,
    profile: str | None,
):
    path = profile_client(profile).backup(database_id, logical_database, output)
    click.echo(str(path))


@remote_group.command("restore")
@click.argument("database_id")
@click.argument("snapshot", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option("--profile", default=None)
def remote_restore(database_id: str, snapshot: Path, profile: str | None):
    echo_json(profile_client(profile).restore(database_id, snapshot))


@remote_group.group("reservoir")
def remote_reservoir_group():
    """Submit and monitor the repository's durable Reservoir jobs."""


@remote_reservoir_group.command("submit")
@click.argument("database_id")
@click.argument("source", type=click.Path(exists=True, dir_okay=False, path_type=Path))
@click.option("--logical-database", default=None)
@click.option("--label", default=None)
@click.option("--idempotency-key", default=None)
@click.option("--stop-on-error/--continue-on-error", default=True)
@click.option("--format", "import_format", default=None)
@click.option("--profile", default=None)
def remote_reservoir_submit(
    database_id: str,
    source: Path,
    logical_database: str | None,
    label: str | None,
    idempotency_key: str | None,
    stop_on_error: bool,
    import_format: str | None,
    profile: str | None,
):
    echo_json(profile_client(profile).reservoir_submit(
        database_id,
        source,
        logical_database=logical_database,
        label=label,
        idempotency_key=idempotency_key,
        stop_on_error=stop_on_error,
        import_format=import_format,
    ))


@remote_reservoir_group.command("job")
@click.argument("database_id")
@click.argument("job_id")
@click.option("--watch/--no-watch", default=False)
@click.option("--interval", default=0.5, show_default=True)
@click.option("--profile", default=None)
def remote_reservoir_job(
    database_id: str,
    job_id: str,
    watch: bool,
    interval: float,
    profile: str | None,
):
    client = profile_client(profile)
    while True:
        result = client.reservoir_job(database_id, job_id)
        echo_json(result)
        job = result.get("job", {})
        status = (
            job.get("status")
            or job.get("job", {}).get("status")
            or job.get("state")
        )
        if not watch or status in {
            "completed", "delivered", "failed", "cancelled", "interrupted"
        }:
            break
        time.sleep(max(0.1, interval))


@remote_reservoir_group.command("cancel")
@click.argument("database_id")
@click.argument("job_id")
@click.option("--profile", default=None)
def remote_reservoir_cancel(database_id: str, job_id: str, profile: str | None):
    echo_json(profile_client(profile).reservoir_cancel(database_id, job_id))


@remote_group.command("jobs")
@click.option("--profile", default=None)
def remote_jobs(profile: str | None):
    echo_json(profile_client(profile).request("GET", "/api/v1/jobs"))


@remote_group.command("job")
@click.argument("job_id")
@click.option("--watch/--no-watch", default=False)
@click.option("--interval", default=0.5, show_default=True)
@click.option("--profile", default=None)
def remote_job(job_id: str, watch: bool, interval: float, profile: str | None):
    client = profile_client(profile)
    while True:
        result = client.request("GET", f"/api/v1/jobs/{job_id}")
        echo_json(result)
        status = result.get("job", {}).get("status")
        if not watch or status in {"completed", "failed", "cancelled", "interrupted"}:
            break
        time.sleep(max(0.1, interval))


@remote_group.command("submit-query")
@click.argument("database_id")
@click.argument("sql")
@click.option("--logical-database", default=None)
@click.option("--profile", default=None)
def remote_submit_query(
    database_id: str,
    sql: str,
    logical_database: str | None,
    profile: str | None,
):
    body = {"databaseId": database_id, "sql": sql}
    if logical_database:
        body["logicalDatabase"] = logical_database
    echo_json(profile_client(profile).request("POST", "/api/v1/jobs/query", body))


@remote_group.group("fts")
def remote_fts_group():
    """Manage Python full-text sidecar indexes."""


@remote_fts_group.command("define")
@click.argument("database_id")
@click.argument("name")
@click.option("--source-sql", required=True)
@click.option("--id-column", required=True)
@click.option("--text-column", "text_columns", multiple=True, required=True)
@click.option("--logical-database", default=None)
@click.option("--profile", default=None)
def remote_fts_define(
    database_id: str,
    name: str,
    source_sql: str,
    id_column: str,
    text_columns: tuple[str, ...],
    logical_database: str | None,
    profile: str | None,
):
    body = {
        "databaseId": database_id,
        "name": name,
        "sourceSql": source_sql,
        "idColumn": id_column,
        "textColumns": list(text_columns),
    }
    if logical_database:
        body["logicalDatabase"] = logical_database
    echo_json(profile_client(profile).request("POST", "/api/v1/fts", body))


@remote_fts_group.command("rebuild")
@click.argument("database_id")
@click.argument("name")
@click.option("--profile", default=None)
def remote_fts_rebuild(database_id: str, name: str, profile: str | None):
    echo_json(profile_client(profile).request(
        "POST",
        f"/api/v1/fts/{database_id}/{name}/rebuild",
        {},
    ))


@remote_fts_group.command("search")
@click.argument("database_id")
@click.argument("name")
@click.argument("query")
@click.option("--limit", default=20, show_default=True)
@click.option("--profile", default=None)
def remote_fts_search(
    database_id: str,
    name: str,
    query: str,
    limit: int,
    profile: str | None,
):
    from urllib.parse import quote_plus
    path = (
        f"/api/v1/fts/{database_id}/{name}/search"
        f"?q={quote_plus(query)}&limit={int(limit)}"
    )
    echo_json(profile_client(profile).request("GET", path))


@remote_group.group("cluster")
def remote_cluster_group():
    """Inspect and administer explicit-primary cluster nodes."""


@remote_cluster_group.command("nodes")
@click.option("--profile", default=None)
def remote_cluster_nodes(profile: str | None):
    echo_json(profile_client(profile).request("GET", "/api/v1/cluster/nodes"))


@remote_cluster_group.command("add")
@click.argument("node_id")
@click.argument("url")
@click.option("--profile", default=None)
def remote_cluster_add(node_id: str, url: str, profile: str | None):
    echo_json(profile_client(profile).request(
        "POST",
        "/api/v1/cluster/nodes",
        {"id": node_id, "url": url},
    ))


@remote_cluster_group.command("heartbeat")
@click.argument("node_id")
@click.option("--profile", default=None)
def remote_cluster_heartbeat(node_id: str, profile: str | None):
    echo_json(profile_client(profile).request(
        "POST",
        f"/api/v1/cluster/nodes/{node_id}/heartbeat",
        {},
    ))


@remote_group.command("replicate")
@click.argument("database_id")
@click.argument("logical_database")
@click.argument("target_node")
@click.option("--profile", default=None)
def remote_replicate(
    database_id: str,
    logical_database: str,
    target_node: str,
    profile: str | None,
):
    echo_json(profile_client(profile).request(
        "POST",
        f"/api/v1/replication/{database_id}",
        {
            "logicalDatabase": logical_database,
            "targetNode": target_node,
        },
    ))


@main.group("file-api")
def file_api_group():
    """Submit same-host requests through inbox/outbox JSON files."""


@file_api_group.command("submit")
@click.argument("action")
@click.option("--payload", default="{}", help="JSON object.")
def file_api_submit(action: str, payload: str):
    settings = Settings.load()
    gateway = FileApiGateway(settings.state_dir / "file-api")
    try:
        value = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise click.ClickException(str(exc)) from exc
    if not isinstance(value, dict):
        raise click.ClickException("--payload must be a JSON object.")
    request_id = gateway.submit_file({"action": action, "payload": value})
    click.echo(request_id)


@file_api_group.command("wait")
@click.argument("request_id")
@click.option("--timeout", default=120.0, show_default=True)
def file_api_wait(request_id: str, timeout: float):
    settings = Settings.load()
    path = settings.state_dir / "file-api" / "outbox" / f"{request_id}.response.json"
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.exists():
            click.echo(path.read_text(encoding="utf-8"))
            return
        time.sleep(0.1)
    raise click.ClickException("Timed out waiting for File API response.")


if __name__ == "__main__":
    main()
