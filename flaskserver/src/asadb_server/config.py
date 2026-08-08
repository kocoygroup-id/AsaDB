from __future__ import annotations

import json
import os
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any


def env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise RuntimeError(f"{name} must be an integer") from exc


def default_repo_root() -> Path:
    """Find an adjacent AsaDB checkout without depending on the launch CWD.

    An installed deployment should set ``ASADB_REPO_ROOT`` explicitly.  This
    fallback makes both ``cd AsaDB && asadb server`` and
    ``cd AsaDB/flaskserver && asadb server`` work for a source checkout.
    """
    package_checkout_root = Path(__file__).resolve().parents[3]
    working_directory = Path.cwd().resolve()
    for candidate in (working_directory, working_directory.parent, package_checkout_root):
        if (candidate / "src" / "asadb_web.pl").is_file() and (
            candidate / "web" / "index.html"
        ).is_file():
            return candidate
    return working_directory


@dataclass(frozen=True)
class Settings:
    repo_root: Path
    swipl: str
    host: str
    port: int
    public_url: str
    secret_key: str
    debug: bool
    trust_proxy: bool
    max_upload_bytes: int
    data_dir: Path
    state_dir: Path
    temp_dir: Path
    thread_pool_size: int
    backend_start_timeout: float
    query_timeout: float
    session_ttl_seconds: int
    token_ttl_seconds: int
    max_result_rows: int
    stream_page_size: int
    backend_port_min: int
    backend_port_max: int
    node_id: str
    cluster_enabled: bool
    cluster_key: str
    replication_interval_seconds: int
    default_database_file: str
    allow_local_only: bool

    @property
    def prolog_web(self) -> Path:
        return self.repo_root / "src" / "asadb_web.pl"

    @property
    def prolog_cli(self) -> Path:
        return self.repo_root / "src" / "asadb.pl"

    @property
    def web_root(self) -> Path:
        return self.repo_root / "web"

    @property
    def mutable_config_file(self) -> Path:
        return self.state_dir / "config.json"

    @classmethod
    def load(cls) -> "Settings":
        configured_root = os.getenv("ASADB_REPO_ROOT")
        repo_root = (
            Path(configured_root).expanduser().resolve()
            if configured_root
            else default_repo_root()
        )
        state_dir = Path(os.getenv("ASADB_STATE_DIR", "./var/server-state")).expanduser().resolve()
        settings = cls(
            repo_root=repo_root,
            swipl=os.getenv("ASADB_SWIPL", "swipl"),
            host=os.getenv("ASADB_HOST", "127.0.0.1"),
            port=env_int("ASADB_PORT", 7879),
            public_url=os.getenv("ASADB_PUBLIC_URL", "http://127.0.0.1:7879").rstrip("/"),
            secret_key=os.getenv("ASADB_SECRET_KEY", "development-only-change-me"),
            debug=env_bool("ASADB_DEBUG", False),
            trust_proxy=env_bool("ASADB_TRUST_PROXY", False),
            max_upload_bytes=env_int("ASADB_MAX_UPLOAD_BYTES", 2 * 1024 * 1024 * 1024),
            data_dir=Path(os.getenv("ASADB_DATA_DIR", "./var/databases")).expanduser().resolve(),
            state_dir=state_dir,
            temp_dir=Path(os.getenv("ASADB_TEMP_DIR", "./var/tmp")).expanduser().resolve(),
            thread_pool_size=env_int("ASADB_THREAD_POOL_SIZE", 8),
            backend_start_timeout=float(os.getenv("ASADB_BACKEND_START_TIMEOUT", "30")),
            query_timeout=float(os.getenv("ASADB_QUERY_TIMEOUT", "120")),
            session_ttl_seconds=env_int("ASADB_SESSION_TTL_SECONDS", 8 * 3600),
            token_ttl_seconds=env_int("ASADB_TOKEN_TTL_SECONDS", 12 * 3600),
            max_result_rows=env_int("ASADB_MAX_RESULT_ROWS", 1000),
            stream_page_size=env_int("ASADB_STREAM_PAGE_SIZE", 500),
            backend_port_min=env_int("ASADB_BACKEND_PORT_MIN", 18088),
            backend_port_max=env_int("ASADB_BACKEND_PORT_MAX", 18999),
            node_id=os.getenv("ASADB_NODE_ID", "node-1"),
            cluster_enabled=env_bool("ASADB_CLUSTER_ENABLED", False),
            cluster_key=os.getenv("ASADB_CLUSTER_KEY", "development-cluster-key"),
            replication_interval_seconds=env_int("ASADB_REPLICATION_INTERVAL_SECONDS", 300),
            default_database_file=os.getenv("ASADB_DEFAULT_DATABASE_FILE", "main"),
            # This only exposes the authenticated Local Workspace choice to
            # a loopback browser.  It is deliberately not an authentication
            # bypass: the unified panel always requires a signed-in user.
            allow_local_only=env_bool("ASADB_ALLOW_LOCAL_ONLY", False),
        )
        return settings.with_mutable_overlay()

    def with_mutable_overlay(self) -> "Settings":
        path = self.mutable_config_file
        if not path.exists():
            return self
        try:
            overlay = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return self
        allowed: dict[str, object] = {
            "thread_pool_size": int,
            "query_timeout": (int, float),
            "session_ttl_seconds": int,
            "token_ttl_seconds": int,
            "max_result_rows": int,
            "stream_page_size": int,
            "cluster_enabled": bool,
            "replication_interval_seconds": int,
            "default_database_file": str,
            "allow_local_only": bool,
        }
        updates: dict[str, Any] = {}
        for key, expected in allowed.items():
            value = overlay.get(key)
            if isinstance(value, expected):
                updates[key] = value
        return replace(self, **updates)

    def prepare(self) -> None:
        for path in (
            self.data_dir,
            self.state_dir,
            self.temp_dir,
            self.state_dir / "users",
            self.state_dir / "tokens",
            self.state_dir / "sessions",
            self.state_dir / "jobs",
            self.state_dir / "databases",
            self.state_dir / "locks",
            self.state_dir / "audit",
            self.state_dir / "file-api" / "inbox",
            self.state_dir / "file-api" / "processing",
            self.state_dir / "file-api" / "outbox",
            self.state_dir / "fts",
            self.state_dir / "replication",
        ):
            created = not path.exists()
            path.mkdir(parents=True, exist_ok=True)
            # A caller may deliberately register an existing directory (for
            # example a checkout containing data.asa).  Never chmod that
            # parent merely because it is being opened as a database root.
            # Directories we create for server state remain private.
            if created:
                try:
                    path.chmod(0o700)
                except OSError:
                    pass

    def validate_repo(self) -> list[str]:
        missing: list[str] = []
        for path in (self.prolog_web, self.prolog_cli, self.web_root / "index.html"):
            if not path.exists():
                missing.append(str(path))
        return missing
