from __future__ import annotations

import atexit
import json
import logging
import uuid
from pathlib import Path

from flask import Flask, g, jsonify, request
from werkzeug.middleware.proxy_fix import ProxyFix

from .api import api
from .audit import AuditLog
from .auth import AuthManager
from .backend import BackendManager
from .cluster import ClusterManager
from .config import Settings
from .errors import AsaServerError
from .file_api import FileApiGateway
from .fts import FullTextManager
from .jobs import JobQueue
from .maintenance import MaintenanceService
from .panel import panel
from .registry import DatabaseRegistry
from .rate_limit import LoginRateLimiter
from .replication import ReplicationManager
from .sessions import SessionManager


def create_app(test_config: dict | None = None) -> Flask:
    settings = Settings.load()
    settings.prepare()

    app = Flask(__name__, template_folder="templates", static_folder="static")
    app.secret_key = settings.secret_key
    app.config.update(
        MAX_CONTENT_LENGTH=settings.max_upload_bytes,
        JSON_SORT_KEYS=False,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
    )
    if test_config:
        app.config.update(test_config)
    if settings.trust_proxy:
        app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

    audit = AuditLog(settings.state_dir / "audit")
    auth = AuthManager(settings.state_dir, settings.token_ttl_seconds)
    login_limiter = LoginRateLimiter(max_failures=10, window_seconds=60)
    registry = DatabaseRegistry(settings.state_dir, settings.data_dir, settings.node_id)
    backends = BackendManager(settings, registry)
    sessions = SessionManager(settings.state_dir, backends, settings.session_ttl_seconds)
    jobs = JobQueue(settings.state_dir, settings.thread_pool_size)
    cluster = ClusterManager(
        settings.state_dir,
        registry,
        settings.node_id,
        settings.public_url,
        settings.cluster_key,
        settings.cluster_enabled,
    )
    fts = FullTextManager(
        settings.state_dir,
        backends,
        jobs,
        settings.stream_page_size,
        availability_guard=sessions.assert_database_available,
    )
    replication = ReplicationManager(
        registry,
        backends,
        cluster,
        jobs,
        settings.temp_dir,
        availability_guard=sessions.assert_database_available,
    )
    file_api = FileApiGateway(settings.state_dir / "file-api")
    maintenance = MaintenanceService(
        sessions=sessions,
        cluster=cluster,
        registry=registry,
        replication=replication,
        jobs=jobs,
        replication_interval=settings.replication_interval_seconds,
    )

    app.extensions.update({
        "asadb_settings": settings,
        "asadb_audit": audit,
        "asadb_auth": auth,
        "asadb_login_limiter": login_limiter,
        "asadb_registry": registry,
        "asadb_backends": backends,
        "asadb_sessions": sessions,
        "asadb_jobs": jobs,
        "asadb_cluster": cluster,
        "asadb_fts": fts,
        "asadb_replication": replication,
        "asadb_file_api": file_api,
        "asadb_maintenance": maintenance,
    })

    def file_api_user(payload):
        auth_payload = payload.get("auth") if isinstance(payload, dict) else None
        if not isinstance(auth_payload, dict):
            raise AsaServerError(
                "FILE_API_AUTH_REQUIRED",
                "File API payload requires auth.token or auth.username/password.",
                401,
            )
        token = auth_payload.get("token")
        if isinstance(token, str) and token:
            return auth.user_for_token(token)
        username = auth_payload.get("username")
        password = auth_payload.get("password")
        if isinstance(username, str) and isinstance(password, str):
            found = auth.find_user(username)
            issued, _ = auth.authenticate(username, password)
            try:
                return auth.user_for_token(issued)
            finally:
                auth.revoke(issued)
        raise AsaServerError("FILE_API_AUTH_REQUIRED", "Invalid File API credentials.", 401)

    def file_api_query(payload):
        from .rbac import require_permission
        from .util import looks_like_write
        user = file_api_user(payload)
        database_id = str(payload["databaseId"])
        sql = str(payload["sql"])
        require_permission(
            user,
            "database.write" if looks_like_write(sql) else "database.read",
            database_id,
        )
        sessions.assert_database_available(database_id)
        logical_database = payload.get("logicalDatabase")
        backend = backends.get(database_id)
        return (
            backend.query_in_database(str(logical_database), sql)
            if logical_database
            else backend.query(sql)
        )

    def file_api_metadata(payload):
        from .rbac import require_permission
        user = file_api_user(payload)
        database_id = str(payload["databaseId"])
        require_permission(user, "database.read", database_id)
        return backends.get(database_id).metadata()

    def query_job(context, payload):
        database_id = str(payload["databaseId"])
        sql = str(payload["sql"])
        context.progress(10, "Dispatching query to the AsaDB engine.")
        sessions.assert_database_available(database_id)
        logical_database = payload.get("logicalDatabase")
        backend = backends.get(database_id)
        result = (
            backend.query_in_database(str(logical_database), sql)
            if logical_database
            else backend.query(sql)
        )
        context.progress(95, "Query completed; publishing result.")
        return {"databaseId": database_id, "result": result}

    jobs.register("query", query_job)

    # Same-host, file-based API handlers.
    file_api.register("ping", lambda payload: {
        "status": "ok",
        "nodeId": settings.node_id,
    })
    file_api.register("query", file_api_query)
    file_api.register("metadata", file_api_metadata)
    file_api.start()
    maintenance.start()

    app.register_blueprint(api)
    app.register_blueprint(panel)

    @app.before_request
    def request_context():
        g.request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex

        # Browser cookie authentication is same-origin only. Bearer-token and
        # cluster-key clients are not subject to this browser CSRF check.
        if request.method in {"POST", "PUT", "PATCH", "DELETE"}:
            has_bearer = request.headers.get("Authorization", "").lower().startswith("bearer ")
            has_cluster_key = bool(request.headers.get("X-AsaDB-Cluster-Key"))
            is_login = request.path in {"/login", "/api/v1/auth/login"}
            if not has_bearer and not has_cluster_key and not is_login:
                origin = request.headers.get("Origin")
                if origin and origin.rstrip("/") != request.host_url.rstrip("/"):
                    raise AsaServerError(
                        "ORIGIN_REJECTED",
                        "Cross-origin state-changing request was rejected.",
                        403,
                    )

    @app.after_request
    def security_headers(response):
        response.headers["X-Request-ID"] = getattr(g, "request_id", "")
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["Referrer-Policy"] = "same-origin"
        response.headers["Permissions-Policy"] = (
            "camera=(), microphone=(), geolocation=(), payment=()"
        )
        response.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; "
            "style-src 'self' 'unsafe-inline'; img-src 'self' data:; "
            "font-src 'self' data:; media-src 'self'; connect-src 'self'; "
            "object-src 'none'; base-uri 'self'; frame-ancestors 'self'",
        )
        if request.is_secure:
            response.headers["Strict-Transport-Security"] = "max-age=31536000"
        if request.path.startswith("/api/"):
            response.headers["Cache-Control"] = "no-store"
        return response

    @app.errorhandler(ValueError)
    def invalid_value(error: ValueError):
        known = AsaServerError("INVALID_VALUE", str(error), 400)
        return jsonify(known.payload(getattr(g, "request_id", None))), 400

    @app.errorhandler(AsaServerError)
    def known_error(error: AsaServerError):
        return jsonify(error.payload(getattr(g, "request_id", None))), error.status

    @app.errorhandler(404)
    def not_found(_error):
        error = AsaServerError("NOT_FOUND", "Endpoint was not found.", 404)
        return jsonify(error.payload(getattr(g, "request_id", None))), 404

    @app.errorhandler(413)
    def too_large(_error):
        error = AsaServerError("REQUEST_TOO_LARGE", "Request body exceeds the server limit.", 413)
        return jsonify(error.payload(getattr(g, "request_id", None))), 413

    @app.errorhandler(Exception)
    def unhandled(error: Exception):
        app.logger.exception("Unhandled AsaDB server error")
        known = AsaServerError("INTERNAL_ERROR", "Internal server error.", 500)
        return jsonify(known.payload(getattr(g, "request_id", None))), 500

    def shutdown():
        try:
            maintenance.stop()
            file_api.stop()
        finally:
            jobs.shutdown()
            backends.stop_all()

    atexit.register(shutdown)
    logging.getLogger("werkzeug").setLevel(logging.INFO)
    return app
