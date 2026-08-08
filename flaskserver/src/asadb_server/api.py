from __future__ import annotations

import json
import os
import shutil
import tempfile
import time
from pathlib import Path
from typing import Any, Iterator

from flask import Blueprint, Response, current_app, g, jsonify, request, stream_with_context

from . import __version__
from .errors import AsaServerError, AuthError
from .rbac import BUILTIN_ROLES, has_permission, require_permission
from .util import looks_like_write, quote_identifier
from .web_security import auth_required, cluster_required, current_user, supplied_token

api = Blueprint("api_v1", __name__, url_prefix="/api/v1")


def ext(name: str):
    return current_app.extensions[name]


def body_object() -> dict[str, Any]:
    value = request.get_json(silent=True)
    if not isinstance(value, dict):
        raise AsaServerError("INVALID_JSON", "Request body must be a JSON object.", 400)
    return value


def sql_from_body() -> str:
    body = body_object()
    sql = body.get("sql")
    if not isinstance(sql, str) or not sql.strip():
        raise AsaServerError("INVALID_SQL", "Field 'sql' must be a non-empty string.", 400)
    return sql


@api.get("/health")
def health():
    settings = ext("asadb_settings")
    return jsonify(
        status="ok",
        service="asadb-flask-server",
        version=__version__,
        engineVersion=__version__,
        nodeId=settings.node_id,
        clusterEnabled=settings.cluster_enabled,
        repositoryReady=not settings.validate_repo(),
    )


@api.get("/readiness")
def readiness():
    """Report whether this process has the files required to accept work.

    This intentionally does not start every registered Prolog backend: doing
    so makes a liveness probe mutate process state and defeats idle backend
    supervision. A query or the deep doctor path performs that stronger test.
    """
    settings = ext("asadb_settings")
    missing = settings.validate_repo()
    registry = ext("asadb_registry")
    records = registry.list()
    return jsonify(
        ready=not missing,
        repositoryReady=not missing,
        missing=missing,
        registeredDatabases=len(records),
        nodeId=settings.node_id,
    ), (200 if not missing else 503)


@api.get("/metrics")
@auth_required("server.admin")
def metrics():
    """Small, dependency-free operational snapshot for an administrator."""
    sessions = ext("asadb_sessions")
    jobs = ext("asadb_jobs")
    backends = ext("asadb_backends")
    records = ext("asadb_registry").list()
    return jsonify(
        databases=len(records),
        activeSessions=len(sessions.list_for_user("", include_all=True)),
        activeTransactions=sum(
            1 for item in sessions.list_for_user("", include_all=True)
            if item.get("transactionActive")
        ),
        queuedJobs=sum(
            1 for item in jobs.list(include_all=True)
            if item.get("status") in {"queued", "running", "cancelling"}
        ),
        supervisedBackends=backends.statuses(),
    )


@api.post("/auth/login")
def login():
    body = body_object()
    username = body.get("username")
    password = body.get("password")
    if not isinstance(username, str) or not isinstance(password, str):
        raise AsaServerError("INVALID_CREDENTIALS", "Username and password are required.", 400)
    limit_key = f"{request.remote_addr or 'unknown'}:{username.casefold()}"
    limiter = ext("asadb_login_limiter")
    limiter.check(limit_key)
    try:
        token, user = ext("asadb_auth").authenticate(username, password)
    except AuthError:
        limiter.failure(limit_key)
        ext("asadb_audit").append(
            "auth.login_failed",
            username=username,
            remote=request.remote_addr,
        )
        raise
    limiter.success(limit_key)
    ext("asadb_audit").append(
        "auth.login",
        userId=user["id"],
        username=user["username"],
        remote=request.remote_addr,
    )
    response = jsonify(token=token, user=user)
    response.set_cookie(
        "asadb_auth",
        token,
        httponly=True,
        secure=request.is_secure,
        samesite="Lax",
        max_age=ext("asadb_settings").token_ttl_seconds,
    )
    return response


@api.post("/auth/logout")
@auth_required()
def logout():
    user = current_user()
    token = supplied_token()
    # Closing the user's durable sessions rolls back any active transaction
    # lease before the authentication token is revoked.
    sessions = ext("asadb_sessions")
    for record in sessions.list_for_user(str(user["id"])):
        sessions.close(str(record["id"]), force=True)
    if token:
        ext("asadb_auth").revoke(token)
    response = jsonify(loggedOut=True)
    response.delete_cookie("asadb_auth")
    return response


@api.get("/auth/me")
@auth_required()
def me():
    return jsonify(user=ext("asadb_auth").public_user(current_user()))


@api.get("/roles")
@auth_required()
def roles():
    return jsonify(
        roles=[
            {"name": name, "permissions": sorted(permissions)}
            for name, permissions in BUILTIN_ROLES.items()
        ]
    )


@api.get("/users")
@auth_required("user.manage")
def list_users():
    auth = ext("asadb_auth")
    return jsonify(users=[auth.public_user(user) for user in auth.users.list()])


@api.post("/users")
@auth_required("user.manage")
def create_user():
    body = body_object()
    user = ext("asadb_auth").create_user(
        str(body.get("username", "")),
        str(body.get("password", "")),
        bindings=body.get("bindings") if isinstance(body.get("bindings"), list) else None,
        enabled=bool(body.get("enabled", True)),
    )
    ext("asadb_audit").append(
        "user.created",
        actor=current_user()["id"],
        userId=user["id"],
    )
    return jsonify(user=user), 201


@api.patch("/users/<user_id>")
@auth_required("user.manage")
def update_user(user_id: str):
    body = body_object()
    user = ext("asadb_auth").update_user(
        user_id,
        password=body.get("password") if isinstance(body.get("password"), str) else None,
        enabled=body.get("enabled") if isinstance(body.get("enabled"), bool) else None,
        bindings=body.get("bindings") if isinstance(body.get("bindings"), list) else None,
    )
    return jsonify(user=user)


@api.delete("/users/<user_id>")
@auth_required("user.manage")
def delete_user(user_id: str):
    if user_id == current_user()["id"]:
        raise AsaServerError("SELF_DELETE_FORBIDDEN", "Cannot delete the current user.", 409)
    ext("asadb_auth").delete_user(user_id)
    return jsonify(deleted=True)


@api.get("/databases")
@auth_required("database.list")
def list_databases():
    registry = ext("asadb_registry")
    statuses = {
        item["databaseId"]: item
        for item in ext("asadb_backends").statuses()
    }
    user = current_user()
    records = []
    for record in registry.list():
        database_id = str(record["id"])
        if not has_permission(user, "database.read", database_id) and not has_permission(
            user, "database.list", database_id
        ):
            continue
        path = registry.path(database_id)
        backend_status = statuses.get(database_id, {"alive": False})
        item = {
            **record,
            "fileExists": path.exists(),
            "sizeBytes": path.stat().st_size if path.exists() else 0,
            "localRole": registry.local_role(database_id),
            "backend": (
                backend_status
                if has_permission(user, "server.admin")
                else {"alive": bool(backend_status.get("alive"))}
            ),
        }
        if has_permission(user, "server.admin"):
            item["path"] = str(path)
        records.append(item)
    return jsonify(databases=records)


@api.post("/databases")
@auth_required("database.create")
def register_database():
    body = body_object()
    record = ext("asadb_registry").register(
        str(body.get("id", "")),
        body.get("filename") if isinstance(body.get("filename"), str) else None,
        primary_node=body.get("primaryNode") if isinstance(body.get("primaryNode"), str) else None,
        replica_nodes=body.get("replicaNodes") if isinstance(body.get("replicaNodes"), list) else None,
        pool=int(body.get("pool", 0)),
        replication_logical_database=(
            str(body["replicationLogicalDatabase"])
            if isinstance(body.get("replicationLogicalDatabase"), str)
            and body.get("replicationLogicalDatabase")
            else None
        ),
    )
    ext("asadb_audit").append(
        "database.registered",
        actor=current_user()["id"],
        databaseId=record["id"],
        filename=record["filename"],
    )
    return jsonify(database=record), 201


@api.get("/databases/<database_id>")
@auth_required("database.read", database_parameter="database_id")
def database_detail(database_id: str):
    registry = ext("asadb_registry")
    record = registry.get(database_id)
    path = registry.path(database_id)
    item = {
        **record,
        "fileExists": path.exists(),
        "sizeBytes": path.stat().st_size if path.exists() else 0,
        "localRole": registry.local_role(database_id),
    }
    if has_permission(current_user(), "server.admin"):
        item["path"] = str(path)
    return jsonify(database=item)


@api.patch("/databases/<database_id>")
@auth_required("server.admin", database_parameter="database_id")
def update_database(database_id: str):
    return jsonify(database=ext("asadb_registry").update(database_id, body_object()))


@api.delete("/databases/<database_id>")
@auth_required("database.drop", database_parameter="database_id")
def unregister_database(database_id: str):
    ext("asadb_sessions").assert_database_available(database_id)
    ext("asadb_backends").stop(database_id)
    record = ext("asadb_registry").unregister(database_id)
    return jsonify(database=record, fileDeleted=False)


def execute_stateless(
    database_id: str,
    sql: str,
    logical_database: str | None = None,
) -> dict[str, Any]:
    user = current_user()
    write = looks_like_write(sql)
    require_permission(user, "database.write" if write else "database.read", database_id)
    sessions = ext("asadb_sessions")
    sessions.assert_database_available(database_id)

    cluster = ext("asadb_cluster")
    primary = cluster.primary_node(database_id)
    if primary != cluster.node_id:
        if write or not cluster.local_can_serve_read(database_id):
            client = cluster.client_for(primary)
            remote = client.request(
                "POST",
                f"/api/v1/internal/query/{database_id}",
                {
                    "sql": sql,
                    **({"logicalDatabase": logical_database} if logical_database else {}),
                },
                authenticated=False,
            )
            return remote.get("result", remote) if isinstance(remote, dict) else {"value": remote}
    backend = ext("asadb_backends").get(database_id)
    if logical_database:
        return backend.query_in_database(logical_database, sql)
    return backend.query(sql)


@api.post("/databases/<database_id>/query")
@auth_required()
def query(database_id: str):
    body = body_object()
    sql = body.get("sql")
    if not isinstance(sql, str) or not sql.strip():
        raise AsaServerError("INVALID_SQL", "Field 'sql' must be a non-empty string.", 400)
    logical_database = (
        body.get("logicalDatabase")
        if isinstance(body.get("logicalDatabase"), str) and body.get("logicalDatabase")
        else None
    )
    started = time.perf_counter()
    result = execute_stateless(database_id, sql, logical_database)
    duration = round((time.perf_counter() - started) * 1000, 3)
    ext("asadb_audit").append(
        "query.executed",
        actor=current_user()["id"],
        databaseId=database_id,
        write=looks_like_write(sql),
        durationMs=duration,
        sqlBytes=len(sql.encode("utf-8")),
    )
    return jsonify(databaseId=database_id, durationMs=duration, result=result)


@api.post("/databases/<database_id>/stream")
@auth_required("database.read", database_parameter="database_id")
def stream_query(database_id: str):
    body = body_object()
    sql = body.get("sql")
    if not isinstance(sql, str) or not sql.strip():
        raise AsaServerError("INVALID_SQL", "Field 'sql' must be a non-empty string.", 400)
    if looks_like_write(sql):
        raise AsaServerError("STREAM_READ_ONLY", "Streaming accepts SELECT-style reads only.", 400)
    logical_database = (
        body.get("logicalDatabase")
        if isinstance(body.get("logicalDatabase"), str) and body.get("logicalDatabase")
        else None
    )
    if not logical_database:
        raise AsaServerError(
            "LOGICAL_DATABASE_REQUIRED",
            "Streaming requires logicalDatabase for stable page affinity.",
            400,
        )
    page_size = int(body.get("pageSize", ext("asadb_settings").stream_page_size))
    page_size = max(1, min(page_size, ext("asadb_settings").max_result_rows))
    ext("asadb_sessions").assert_database_available(database_id)
    cluster = ext("asadb_cluster")
    if cluster.primary_node(database_id) != cluster.node_id and not cluster.local_can_serve_read(database_id):
        raise AsaServerError(
            "PRIMARY_NODE_REQUIRED",
            "Streaming must connect to a node that owns a readable copy.",
            409,
            {"primaryNode": cluster.primary_node(database_id)},
        )
    backend = ext("asadb_backends").get(database_id)

    @stream_with_context
    def generate() -> Iterator[bytes]:
        page_iterator = (
            backend.stream_query_pages_in_database(logical_database, sql, page_size)
            if logical_database
            else backend.stream_query_pages(sql, page_size)
        )
        for page in page_iterator:
            envelope = {
                "databaseId": database_id,
                "page": page["page"],
                "offset": page["offset"],
                "columns": page["columns"],
                "rows": page["rows"],
                "hasMore": page["hasMore"],
            }
            yield (json.dumps(envelope, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")

    return Response(generate(), mimetype="application/x-ndjson")


@api.post("/databases/<database_id>/analyze")
@auth_required("database.read", database_parameter="database_id")
def analyze(database_id: str):
    return jsonify(result=ext("asadb_backends").get(database_id).analyze(sql_from_body()))


@api.get("/databases/<database_id>/metadata")
@auth_required("database.read", database_parameter="database_id")
def metadata(database_id: str):
    return jsonify(result=ext("asadb_backends").get(database_id).metadata())


@api.get("/databases/<database_id>/catalog")
@auth_required("database.read", database_parameter="database_id")
def catalog(database_id: str):
    return jsonify(result=ext("asadb_backends").get(database_id).catalog())


@api.post("/databases/<database_id>/backup")
@auth_required("database.backup", database_parameter="database_id")
def backup(database_id: str):
    body = body_object()
    logical_database = body.get("logicalDatabase")
    if not isinstance(logical_database, str) or not logical_database:
        raise AsaServerError(
            "LOGICAL_DATABASE_REQUIRED",
            "logicalDatabase is required for an AsaDB production backup.",
            400,
        )
    ext("asadb_sessions").assert_database_available(database_id)
    response = ext("asadb_backends").get(database_id).backup(logical_database)

    @stream_with_context
    def generate_backup() -> Iterator[bytes]:
        try:
            yield from response.iter_content(chunk_size=1024 * 1024)
        finally:
            response.close()

    passthrough = {}
    for name in (
        "Content-Type",
        "Content-Length",
        "Content-Disposition",
        "X-AsaDB-Backup-Format",
        "X-AsaDB-Backup-SHA256",
    ):
        if response.headers.get(name):
            passthrough[name] = response.headers[name]
    return Response(generate_backup(), status=response.status_code, headers=passthrough)


@api.post("/databases/<database_id>/restore")
@auth_required("database.restore", database_parameter="database_id")
def restore(database_id: str):
    ext("asadb_cluster").require_local_primary(database_id)
    ext("asadb_sessions").assert_database_available(database_id)
    upload = request.files.get("snapshot")
    has_raw_body = bool(request.content_length and request.content_length > 0)
    if upload is None and not has_raw_body:
        raise AsaServerError("SNAPSHOT_REQUIRED", "Upload a .asb snapshot.", 400)
    fd, raw_path = tempfile.mkstemp(
        prefix="asadb-restore-",
        suffix=".asb",
        dir=ext("asadb_settings").temp_dir,
    )
    os.close(fd)
    path = Path(raw_path)
    try:
        if upload is not None:
            upload.save(path)
        else:
            with path.open("wb") as handle:
                shutil.copyfileobj(request.stream, handle, length=1024 * 1024)
        result = ext("asadb_backends").get(database_id).import_upload(
            path,
            format_name="auto",
            stop_on_error=True,
        )
    finally:
        path.unlink(missing_ok=True)
    return jsonify(databaseId=database_id, restored=True, result=result)


@api.post("/databases/<database_id>/reservoir")
@auth_required("job.submit", database_parameter="database_id")
def reservoir_submit(database_id: str):
    ext("asadb_cluster").require_local_primary(database_id)
    ext("asadb_sessions").assert_database_available(database_id)
    logical_database = request.headers.get("X-AsaDB-Logical-Database")
    content_length = request.content_length
    if content_length is None or content_length <= 0:
        raise AsaServerError(
            "CONTENT_LENGTH_REQUIRED",
            "Reservoir submission requires Content-Length.",
            411,
        )
    fd, raw_path = tempfile.mkstemp(
        prefix="asadb-reservoir-",
        suffix=".sql",
        dir=ext("asadb_settings").temp_dir,
    )
    os.close(fd)
    path = Path(raw_path)
    try:
        with path.open("wb") as handle:
            if logical_database:
                prefix = (
                    f"USE {quote_identifier(logical_database)};\\n"
                ).encode("utf-8")
                handle.write(prefix)
            shutil.copyfileobj(request.stream, handle, length=1024 * 1024)
        metadata = {}
        if request.headers.get("X-AsaDB-Import-Format"):
            metadata = {
                "format": request.headers.get("X-AsaDB-Import-Format", "auto"),
                "source_name": request.headers.get("X-AsaDB-Import-Name", path.name),
                "target_table": request.headers.get("X-AsaDB-Import-Table", ""),
                "mode": request.headers.get("X-AsaDB-Import-Mode", "replace"),
            }
        result = ext("asadb_backends").get(database_id).reservoir_submit(
            path,
            label=request.headers.get("X-AsaDB-Job-Label") or path.name,
            idempotency_key=request.headers.get("X-AsaDB-Idempotency-Key", ""),
            stop_on_error=request.headers.get(
                "X-AsaDB-Stop-On-Error", "true"
            ).lower() in {"1", "true", "yes", "on"},
            metadata=metadata,
        )
    finally:
        path.unlink(missing_ok=True)
    return jsonify(databaseId=database_id, reservoir=result), 202


@api.get("/databases/<database_id>/reservoir/jobs/<job_id>")
@auth_required("job.submit", database_parameter="database_id")
def reservoir_job(database_id: str, job_id: str):
    return jsonify(
        databaseId=database_id,
        job=ext("asadb_backends").get(database_id).reservoir_job(job_id),
    )


@api.get("/databases/<database_id>/reservoir/jobs/<job_id>/result")
@auth_required("job.submit", database_parameter="database_id")
def reservoir_result(database_id: str, job_id: str):
    offset = max(0, int(request.args.get("offset", "0")))
    limit = max(1, min(int(request.args.get("limit", "500")), 5000))
    return jsonify(
        databaseId=database_id,
        result=ext("asadb_backends").get(database_id).reservoir_result(
            job_id,
            offset,
            limit,
        ),
    )


@api.post("/databases/<database_id>/reservoir/jobs/<job_id>/cancel")
@auth_required("job.manage", database_parameter="database_id")
def reservoir_cancel(database_id: str, job_id: str):
    return jsonify(
        databaseId=database_id,
        job=ext("asadb_backends").get(database_id).reservoir_cancel(job_id),
    )


@api.get("/databases/<database_id>/reservoir/stats")
@auth_required("job.submit", database_parameter="database_id")
def reservoir_stats(database_id: str):
    return jsonify(
        databaseId=database_id,
        stats=ext("asadb_backends").get(database_id).reservoir_stats(),
    )


@api.post("/databases/<database_id>/save")
@auth_required("database.write", database_parameter="database_id")
def save(database_id: str):
    ext("asadb_cluster").require_local_primary(database_id)
    return jsonify(result=ext("asadb_backends").get(database_id).save())


@api.post("/databases/<database_id>/restart")
@auth_required("server.admin", database_parameter="database_id")
def restart(database_id: str):
    ext("asadb_sessions").assert_database_available(database_id)
    return jsonify(backend=ext("asadb_backends").restart(database_id))


@api.post("/sessions")
@auth_required("session.create")
def create_session():
    body = body_object()
    database_id = str(body.get("databaseId", ""))
    require_permission(current_user(), "database.read", database_id)
    ext("asadb_cluster").require_local_primary(database_id)
    logical_database = (
        body.get("logicalDatabase")
        if isinstance(body.get("logicalDatabase"), str) and body.get("logicalDatabase")
        else None
    )
    if not logical_database:
        raise AsaServerError(
            "LOGICAL_DATABASE_REQUIRED",
            "A client session must bind to one logicalDatabase.",
            400,
        )
    session_record = ext("asadb_sessions").create(
        current_user()["id"],
        database_id,
        logical_database,
    )
    return jsonify(session=session_record), 201


@api.get("/sessions")
@auth_required("session.create")
def list_sessions():
    user = current_user()
    include_all = has_permission(user, "session.manage")
    return jsonify(
        sessions=ext("asadb_sessions").list_for_user(user["id"], include_all=include_all)
    )


@api.get("/sessions/<session_id>")
@auth_required("session.create")
def session_detail(session_id: str):
    return jsonify(session=ext("asadb_sessions").get(session_id, current_user()["id"]))


@api.post("/sessions/<session_id>/begin")
@auth_required("session.create")
def session_begin(session_id: str):
    session_record = ext("asadb_sessions").get(session_id, current_user()["id"])
    require_permission(current_user(), "database.write", str(session_record["databaseId"]))
    return jsonify(**ext("asadb_sessions").begin(session_id, current_user()["id"]))


@api.post("/sessions/<session_id>/query")
@auth_required("session.create")
def session_query(session_id: str):
    sql = sql_from_body()
    session_record = ext("asadb_sessions").get(session_id, current_user()["id"])
    database_id = str(session_record["databaseId"])
    allow_write = has_permission(current_user(), "database.write", database_id)
    require_permission(current_user(), "database.read", database_id)
    result = ext("asadb_sessions").query(
        session_id,
        current_user()["id"],
        sql,
        allow_write=allow_write,
    )
    return jsonify(sessionId=session_id, databaseId=database_id, result=result)


@api.post("/sessions/<session_id>/commit")
@auth_required("session.create")
def session_commit(session_id: str):
    return jsonify(**ext("asadb_sessions").commit(session_id, current_user()["id"]))


@api.post("/sessions/<session_id>/rollback")
@auth_required("session.create")
def session_rollback(session_id: str):
    return jsonify(**ext("asadb_sessions").rollback(session_id, current_user()["id"]))


@api.delete("/sessions/<session_id>")
@auth_required("session.create")
def session_close(session_id: str):
    ext("asadb_sessions").close(session_id, current_user()["id"])
    return jsonify(closed=True)


@api.post("/jobs/query")
@auth_required("job.submit")
def submit_query_job():
    body = body_object()
    database_id = str(body.get("databaseId", ""))
    sql = str(body.get("sql", ""))
    if not sql.strip():
        raise AsaServerError("INVALID_SQL", "Field 'sql' must be non-empty.", 400)
    require_permission(
        current_user(),
        "database.write" if looks_like_write(sql) else "database.read",
        database_id,
    )
    job_payload = {"databaseId": database_id, "sql": sql}
    if isinstance(body.get("logicalDatabase"), str) and body.get("logicalDatabase"):
        job_payload["logicalDatabase"] = body["logicalDatabase"]
    job = ext("asadb_jobs").submit(
        "query",
        job_payload,
        user_id=current_user()["id"],
        database_id=database_id,
    )
    return jsonify(job=job), 202


@api.get("/jobs")
@auth_required("job.submit")
def jobs():
    user = current_user()
    include_all = has_permission(user, "job.manage")
    return jsonify(jobs=ext("asadb_jobs").list(user_id=user["id"], include_all=include_all))


@api.get("/jobs/<job_id>")
@auth_required("job.submit")
def job_detail(job_id: str):
    job = ext("asadb_jobs").get(job_id)
    if job.get("userId") != current_user()["id"] and not has_permission(current_user(), "job.manage"):
        raise AsaServerError("JOB_NOT_FOUND", "Job does not exist.", 404)
    return jsonify(job=job)


@api.post("/jobs/<job_id>/cancel")
@auth_required("job.submit")
def job_cancel(job_id: str):
    job = ext("asadb_jobs").get(job_id)
    if job.get("userId") != current_user()["id"] and not has_permission(current_user(), "job.manage"):
        raise AsaServerError("JOB_NOT_FOUND", "Job does not exist.", 404)
    return jsonify(job=ext("asadb_jobs").cancel(job_id))


@api.get("/fts")
@auth_required("fts.read")
def fts_list():
    database_id = request.args.get("databaseId")
    return jsonify(indexes=ext("asadb_fts").list(database_id))


@api.post("/fts")
@auth_required("fts.manage")
def fts_define():
    body = body_object()
    database_id = str(body.get("databaseId", ""))
    require_permission(current_user(), "fts.manage", database_id)
    logical_database = (
        str(body["logicalDatabase"])
        if isinstance(body.get("logicalDatabase"), str) and body.get("logicalDatabase")
        else None
    )
    if not logical_database:
        raise AsaServerError(
            "LOGICAL_DATABASE_REQUIRED",
            "FTS definitions require logicalDatabase for stable paging.",
            400,
        )
    definition = ext("asadb_fts").define(
        database_id,
        str(body.get("name", "")),
        source_sql=str(body.get("sourceSql", "")),
        id_column=str(body.get("idColumn", "")),
        text_columns=[str(x) for x in body.get("textColumns", [])],
        logical_database=logical_database,
    )
    return jsonify(index=definition), 201


@api.post("/fts/<database_id>/<index_name>/rebuild")
@auth_required("fts.manage", database_parameter="database_id")
def fts_rebuild(database_id: str, index_name: str):
    return jsonify(job=ext("asadb_fts").submit_rebuild(
        database_id,
        index_name,
        user_id=current_user()["id"],
    )), 202


@api.get("/fts/<database_id>/<index_name>/search")
@auth_required("fts.read", database_parameter="database_id")
def fts_search(database_id: str, index_name: str):
    query_text = request.args.get("q", "")
    limit = int(request.args.get("limit", "20"))
    return jsonify(**ext("asadb_fts").search(
        database_id,
        index_name,
        query_text,
        limit=limit,
    ))


@api.get("/cluster/health")
@cluster_required
def cluster_health():
    settings = ext("asadb_settings")
    return jsonify(
        status="online",
        nodeId=settings.node_id,
        backends=ext("asadb_backends").statuses(),
    )


@api.get("/cluster/nodes")
@auth_required("cluster.read")
def cluster_nodes():
    return jsonify(nodes=ext("asadb_cluster").list_nodes())


@api.post("/cluster/nodes")
@auth_required("cluster.manage")
def cluster_add_node():
    body = body_object()
    node = ext("asadb_cluster").add_node(
        str(body.get("id", "")),
        str(body.get("url", "")),
        enabled=bool(body.get("enabled", True)),
    )
    return jsonify(node=node), 201


@api.post("/cluster/nodes/<node_id>/heartbeat")
@auth_required("cluster.manage")
def cluster_heartbeat(node_id: str):
    return jsonify(node=ext("asadb_cluster").heartbeat(node_id))


@api.delete("/cluster/nodes/<node_id>")
@auth_required("cluster.manage")
def cluster_remove(node_id: str):
    ext("asadb_cluster").remove_node(node_id)
    return jsonify(deleted=True)


@api.post("/replication/<database_id>")
@auth_required("replication.manage", database_parameter="database_id")
def replicate(database_id: str):
    body = body_object()
    job = ext("asadb_replication").submit(
        database_id,
        str(body.get("logicalDatabase", "")),
        str(body.get("targetNode", "")),
        user_id=current_user()["id"],
    )
    return jsonify(job=job), 202


@api.post("/internal/query/<database_id>")
@cluster_required
def internal_query(database_id: str):
    body = body_object()
    sql = body.get("sql")
    if not isinstance(sql, str) or not sql.strip():
        raise AsaServerError("INVALID_SQL", "Field 'sql' must be a non-empty string.", 400)
    logical_database = (
        body.get("logicalDatabase")
        if isinstance(body.get("logicalDatabase"), str) and body.get("logicalDatabase")
        else None
    )
    ext("asadb_cluster").require_local_primary(database_id)
    ext("asadb_sessions").assert_database_available(database_id)
    backend = ext("asadb_backends").get(database_id)
    result = (
        backend.query_in_database(logical_database, sql)
        if logical_database
        else backend.query(sql)
    )
    return jsonify(result=result)


@api.post("/internal/replication/<database_id>")
@cluster_required
def internal_replication(database_id: str):
    logical_database = request.headers.get("X-AsaDB-Logical-Database", "")
    if not request.content_length or request.content_length <= 0:
        raise AsaServerError("SNAPSHOT_REQUIRED", "Snapshot body is required.", 400)
    suffix = ".asb"
    fd, raw_path = tempfile.mkstemp(
        prefix="asadb-replica-",
        suffix=suffix,
        dir=ext("asadb_settings").temp_dir,
    )
    os.close(fd)
    path = Path(raw_path)
    try:
        with path.open("wb") as handle:
            shutil.copyfileobj(request.stream, handle, length=1024 * 1024)
        result = ext("asadb_replication").receive(
            database_id,
            logical_database,
            path,
        )
    finally:
        path.unlink(missing_ok=True)
    return jsonify(**result)


@api.get("/audit")
@auth_required("audit.read")
def audit():
    limit = max(1, min(int(request.args.get("limit", "100")), 5000))
    return jsonify(events=ext("asadb_audit").tail(limit))


@api.get("/config")
@auth_required("config.manage")
def config_get():
    settings = ext("asadb_settings")
    path = settings.mutable_config_file
    value = {}
    if path.exists():
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            value = {}
    return jsonify(config=value, restartRequired=True)


@api.put("/config")
@auth_required("config.manage")
def config_put():
    body = body_object()
    allowed = {
        "thread_pool_size", "query_timeout", "session_ttl_seconds",
        "token_ttl_seconds", "max_result_rows", "stream_page_size",
        "cluster_enabled", "replication_interval_seconds",
        "default_database_file",
    }
    value = {key: item for key, item in body.items() if key in allowed}
    path = ext("asadb_settings").mutable_config_file
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(temp, path)
    return jsonify(config=value, restartRequired=True)
