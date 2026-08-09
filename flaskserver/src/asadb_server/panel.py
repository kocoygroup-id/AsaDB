from __future__ import annotations

import ipaddress
import re
from html import escape
from pathlib import Path
from typing import Iterator

from flask import (
    Blueprint,
    Response,
    current_app,
    jsonify,
    redirect,
    render_template,
    request,
    send_from_directory,
    session,
    stream_with_context,
    url_for,
)

from .backend import SizedReader
from .errors import AsaServerError, AuthError
from .rbac import has_permission, require_permission
from .util import looks_like_write
from .web_security import current_user, supplied_token

panel = Blueprint("panel", __name__)


def ext(name: str):
    return current_app.extensions[name]


def browser_user():
    try:
        return current_user()
    except Exception:
        return None


def is_loopback_request() -> bool:
    """Return true only for a browser connected from the local machine.

    Flask's ProxyFix runs before this helper when a trusted reverse proxy is
    configured, so ``remote_addr`` is the client address in that deployment.
    Failure to parse an address is deliberately treated as non-local.
    """
    try:
        return ipaddress.ip_address(request.remote_addr or "").is_loopback
    except ValueError:
        return False


def local_workspace_available() -> bool:
    """Local Workspace is an authenticated, loopback-only portal context.

    It does *not* skip the login page.  The former idea of an unauthenticated
    browser bypass conflicts with the production login-first launcher and
    would be unsafe when a service is accidentally exposed on a network.
    """
    return ext("asadb_settings").allow_local_only and is_loopback_request()


def current_workspace_mode() -> str | None:
    mode = session.get("asadb_workspace_mode")
    return mode if mode in {"local", "server"} else None


@panel.route("/login", methods=["GET", "POST"])
def login_page():
    if request.method == "GET" and browser_user():
        return redirect(url_for("panel.mode_page"))
    if request.method == "POST":
        username = request.form.get("username", "")
        limit_key = f"{request.remote_addr or 'unknown'}:{username.casefold()}"
        limiter = ext("asadb_login_limiter")
        try:
            limiter.check(limit_key)
            token, user = ext("asadb_auth").authenticate(
                username,
                request.form.get("password", ""),
            )
        except AuthError as error:
            limiter.failure(limit_key)
            return render_template("login.html", error=error.message), error.status
        limiter.success(limit_key)
        session["asadb_auth"] = token
        # Server Workspace is the safe production default for the unified
        # launcher.  It makes `swipl asadb` reach the supervised Prolog
        # backend immediately after authentication instead of silently
        # falling back to the browser sandbox.  Local Workspace remains an
        # explicit, authenticated choice from the workspace switcher.
        if ext("asadb_registry").list():
            session["asadb_workspace_mode"] = "server"
            response = redirect(url_for("panel.panel_root"))
        else:
            # An explicitly initialized control plane without a database must
            # still be able to reach the mode/admin flow and register one.
            session.pop("asadb_workspace_mode", None)
            response = redirect(url_for("panel.mode_page"))
        response.set_cookie(
            "asadb_auth",
            token,
            httponly=True,
            secure=request.is_secure,
            samesite="Lax",
            max_age=ext("asadb_settings").token_ttl_seconds,
        )
        return response
    return render_template("login.html", local_workspace_available=local_workspace_available())


@panel.route("/logout", methods=["GET", "POST"])
def logout_page():
    user = browser_user()
    if request.method == "GET":
        if not user:
            return redirect(url_for("panel.login_page"))
        sessions = ext("asadb_sessions").list_for_user(str(user["id"]))
        active_transactions = sum(
            1 for record in sessions if record.get("transactionActive")
        )
        return render_template(
            "logout.html",
            active_transactions=active_transactions,
        )
    if user:
        sessions = ext("asadb_sessions")
        for record in sessions.list_for_user(str(user["id"])):
            sessions.close(str(record["id"]), force=True)
    token = supplied_token()
    if token:
        ext("asadb_auth").revoke(token)
    session.clear()
    response = redirect(url_for("panel.login_page"))
    response.delete_cookie("asadb_auth")
    return response


@panel.route("/mode", methods=["GET", "POST"])
def mode_page():
    """Choose the browser workspace after successful authentication."""
    user = browser_user()
    if not user:
        return redirect(url_for("panel.login_page"))
    if request.method == "POST":
        mode = request.form.get("mode", "")
        if mode == "local":
            if not local_workspace_available():
                raise AsaServerError(
                    "LOCAL_WORKSPACE_UNAVAILABLE",
                    "Local Workspace is available only to a loopback browser when enabled by the administrator.",
                    403,
                )
        elif mode != "server":
            raise AsaServerError("INVALID_WORKSPACE_MODE", "Choose Local or Server Workspace.", 400)
        session["asadb_workspace_mode"] = mode
        return redirect(url_for("panel.panel_root"))
    return render_template(
        "mode.html",
        user=ext("asadb_auth").public_user(user),
        local_workspace_available=local_workspace_available(),
    )


@panel.get("/admin")
def admin_page():
    user = browser_user()
    if not user:
        return redirect(url_for("panel.login_page"))
    require_permission(user, "server.admin")
    return render_template(
        "admin.html",
        user=ext("asadb_auth").public_user(user),
        node_id=ext("asadb_settings").node_id,
    )


@panel.get("/panel/select/<database_id>")
def select_database(database_id: str):
    user = browser_user()
    if not user:
        return redirect(url_for("panel.login_page"))
    require_permission(user, "panel.use", database_id)
    ext("asadb_registry").get(database_id)
    session["asadb_database_id"] = database_id
    return redirect(url_for("panel.panel_root"))


USE_RE = re.compile(
    r"(?:^|;)\s*USE\s+(?:`([^`]+)`|([A-Za-z0-9_.-]+))\s*;",
    re.IGNORECASE,
)
DROP_DATABASE_RE = re.compile(
    r"(?:^|;)\s*DROP\s+DATABASE(?:\s+IF\s+EXISTS)?\s+"
    r"(?:`([^`]+)`|([A-Za-z0-9_.-]+))\s*;",
    re.IGNORECASE,
)


def logical_database_for_sql(sql: str) -> str | None:
    """Select a candidate database without mutating the browser session.

    A failed `USE missing_db` must leave the session pointed at its previous
    database.  Persisting this before the backend replies was the Flask half
    of the DROP DATABASE resurrection path.
    """
    matches = USE_RE.findall(sql or "")
    if matches:
        selected = matches[-1][0] or matches[-1][1]
        return selected
    value = session.get("asadb_logical_database")
    return str(value) if isinstance(value, str) and value else None


def sync_logical_database_after_sql(sql: str, result: dict) -> None:
    results = result.get("results") if isinstance(result, dict) else None
    if not isinstance(results, list) or any(
        isinstance(item, dict) and item.get("status") == "error"
        for item in results
    ):
        return
    matches = USE_RE.findall(sql or "")
    if matches:
        selected = matches[-1][0] or matches[-1][1]
        session["asadb_logical_database"] = selected
    selected = session.get("asadb_logical_database")
    if not isinstance(selected, str):
        return
    dropped = {
        (quoted or plain).casefold()
        for quoted, plain in DROP_DATABASE_RE.findall(sql or "")
    }
    if selected.casefold() in dropped:
        session.pop("asadb_logical_database", None)


def selected_database_id() -> str:
    database_id = session.get("asadb_database_id")
    if isinstance(database_id, str):
        try:
            ext("asadb_registry").get(database_id)
            return database_id
        except Exception:
            pass
    preferred = ext("asadb_settings").default_database_file
    for record in ext("asadb_registry").list():
        if record.get("id") == preferred:
            session["asadb_database_id"] = preferred
            return preferred
    records = ext("asadb_registry").list()
    if not records:
        raise AsaServerError(
            "NO_DATABASE_FILES",
            "Register a database file from the admin page first.",
            409,
        )
    database_id = str(records[0]["id"])
    session["asadb_database_id"] = database_id
    return database_id


@panel.get("/")
def panel_root():
    user = browser_user()
    if not user:
        return redirect(url_for("panel.login_page"))
    workspace_mode = current_workspace_mode()
    if workspace_mode is None:
        return redirect(url_for("panel.mode_page"))
    database_id = selected_database_id()
    require_permission(user, "panel.use", database_id)

    index_path = ext("asadb_settings").web_root / "index.html"
    html = index_path.read_text(encoding="utf-8")
    mode_name = "Local Workspace" if workspace_mode == "local" else "Server Workspace"
    admin_link = (
        '<a href="/admin">Admin</a>'
        if has_permission(user, "server.admin")
        else ""
    )
    server_bar = f"""
    <aside id="asadb-server-bar" class="asadb-server-bar" data-workspace-mode="{escape(workspace_mode)}" aria-label="AsaDB workspace status">
      <strong>{escape(mode_name)}</strong>
      <span>File <b>{escape(database_id)}</b></span>
      <span>User <b>{escape(str(user['username']))}</b></span>
      <span>Node <b>{escape(ext('asadb_settings').node_id)}</b></span>
      <nav>{admin_link}<a href="/mode">Switch workspace</a><a href="/logout">Logout</a></nav>
    </aside>
    """
    server_css = '<link rel="stylesheet" href="/static/server.css">'
    html = html.replace("</head>", server_css + "\n</head>")
    html = html.replace('<main class="main">', '<main class="main">' + server_bar, 1)
    return Response(html, mimetype="text/html")


_PUBLIC_PANEL_ASSET = re.compile(
    r"(?:style\.css|asadb-logo\.png|fonts/[A-Za-z0-9_.-]+\.(?:woff2?|ttf))$"
)


@panel.get("/panel-assets/<path:asset_path>")
def public_panel_asset(asset_path: str):
    """Serve only theme primitives needed by the pre-login pages.

    The panel script and API assets remain behind authentication.  Fonts, the
    logo, and the canonical stylesheet contain no user or database data and
    make login/admin use the exact same design tokens as AsAPanel.
    """
    if not _PUBLIC_PANEL_ASSET.fullmatch(asset_path):
        raise AsaServerError("ASSET_NOT_PUBLIC", "This panel asset requires login.", 404)
    return send_from_directory(ext("asadb_settings").web_root / "assets", asset_path)


@panel.get("/assets/<path:asset_path>")
def panel_asset(asset_path: str):
    user = browser_user()
    if not user:
        return redirect(url_for("panel.login_page"))
    return send_from_directory(ext("asadb_settings").web_root / "assets", asset_path)


@panel.get("/samples/<path:sample_path>")
def panel_sample(sample_path: str):
    user = browser_user()
    if not user:
        return redirect(url_for("panel.login_page"))
    return send_from_directory(ext("asadb_settings").web_root / "samples", sample_path)


@panel.route("/api/<path:api_path>", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
def panel_api_proxy(api_path: str):
    user = browser_user()
    if not user:
        raise AsaServerError("AUTH_REQUIRED", "Login is required.", 401)
    database_id = selected_database_id()
    require_permission(user, "panel.use", database_id)

    streaming_request_paths = {
        "execute_stream",
        "import_upload",
        "reservoir/jobs",
    }
    is_streaming_request = (
        request.method != "GET" and api_path in streaming_request_paths
    )
    if is_streaming_request:
        if request.content_length is None:
            raise AsaServerError(
                "CONTENT_LENGTH_REQUIRED",
                "Streaming panel requests require Content-Length.",
                411,
            )
        request_body = SizedReader(request.stream, request.content_length)
        sql = ""
    else:
        request_body = request.get_data(cache=True) if request.method != "GET" else None
        sql = request.form.get("sql", "")
    mutating_route = request.method != "GET" and api_path not in {
        "analyze", "query", "state", "catalog", "metadata",
        "reservoir/job", "reservoir/result", "reservoir/stats",
    }
    if api_path == "query" and looks_like_write(sql):
        mutating_route = True
    require_permission(
        user,
        "database.write" if mutating_route else "database.read",
        database_id,
    )
    if mutating_route:
        ext("asadb_cluster").require_local_primary(database_id)
    ext("asadb_sessions").assert_database_available(database_id)

    forwarded_headers = {}
    content_type = request.headers.get("Content-Type")
    if content_type:
        forwarded_headers["Content-Type"] = content_type
    for name in (
        "X-AsaDB-Job-Label",
        "X-AsaDB-Idempotency-Key",
        "X-AsaDB-Stop-On-Error",
        "X-AsaDB-Import-Format",
        "X-AsaDB-Import-Name",
        "X-AsaDB-Import-Table",
        "X-AsaDB-Import-Mode",
    ):
        if request.headers.get(name):
            forwarded_headers[name] = request.headers[name]
    # Requests must calculate the length for buffered/form bodies.  Reusing
    # the browser's original Content-Length after Flask has parsed a form can
    # desynchronize the persistent backend connection.  Only the exact-size
    # streaming wrapper preserves and requires the original length.
    if is_streaming_request:
        forwarded_headers["Content-Length"] = str(request.content_length)
        # The Prolog HTTP layer consumes uploads through a bounded range
        # stream.  End this one internal connection after the streamed body;
        # reusing it through two proxy layers can make residual framing bytes
        # look like the next request URI on some SWI-Prolog builds.
        forwarded_headers["Connection"] = "close"

    explicit_database_selection = bool(USE_RE.search(sql or ""))
    logical_database = logical_database_for_sql(sql)
    backend = ext("asadb_backends").get(database_id)
    # Query forms are already parsed for RBAC and workspace selection.  Send
    # them through the typed backend method instead of replaying their raw
    # URL-encoded body across a second persistent HTTP hop.  This also lets
    # Requests calculate a fresh body envelope and prevents SWI-Prolog from
    # rejecting a valid follow-up request as illegal_uri_query after a stream.
    if api_path == "query" and request.method == "POST":
        try:
            offset = max(0, int(request.form.get("offset", "0")))
        except ValueError:
            offset = 0
        # An explicit USE belongs to this SQL batch.  Prepending a separate
        # USE would fail for the common CREATE DATABASE ...; USE ...; panel
        # command because the database does not exist until the batch runs.
        if logical_database and not explicit_database_selection:
            result = backend.query_in_database(logical_database, sql, offset=offset)
        else:
            result = backend.query(sql, offset=offset)
        sync_logical_database_after_sql(sql, result)
        return jsonify(result)
    request_kwargs = {
        "data": request_body,
        "params": request.args,
        "headers": forwarded_headers,
        "stream": True,
        "timeout": max(ext("asadb_settings").query_timeout, 3600),
    }
    if logical_database:
        backend_response = backend.request_in_database(
            logical_database,
            request.method,
            "/api/" + api_path,
            **request_kwargs,
        )
    else:
        backend_response = backend.request(
            request.method,
            "/api/" + api_path,
            **request_kwargs,
        )

    excluded = {
        "connection", "content-encoding", "transfer-encoding", "keep-alive",
        "set-cookie",
    }
    response_headers = [
        (name, value)
        for name, value in backend_response.headers.items()
        if name.lower() not in excluded
    ]

    @stream_with_context
    def generate() -> Iterator[bytes]:
        try:
            yield from backend_response.iter_content(chunk_size=1024 * 1024)
        finally:
            backend_response.close()

    return Response(
        generate(),
        status=backend_response.status_code,
        headers=response_headers,
    )
