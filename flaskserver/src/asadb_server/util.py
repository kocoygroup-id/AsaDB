from __future__ import annotations

import hashlib
import json
import re
import secrets
import socket
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

SAFE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$")
SAFE_ASA_FILE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,191}\.asa$")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def epoch() -> float:
    return time.time()


def new_id(prefix: str = "") -> str:
    value = uuid.uuid4().hex
    return f"{prefix}{value}" if prefix else value


def new_token(bytes_count: int = 32) -> str:
    return secrets.token_urlsafe(bytes_count)


def token_digest(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def safe_id(value: str, label: str = "identifier") -> str:
    if not isinstance(value, str) or not SAFE_ID.fullmatch(value):
        raise ValueError(f"Invalid {label}: {value!r}")
    return value


def safe_asa_filename(value: str) -> str:
    if not isinstance(value, str) or not SAFE_ASA_FILE.fullmatch(value):
        raise ValueError("Database filename must be a simple .asa filename.")
    return value


def resolve_beneath(root: Path, name: str) -> Path:
    candidate = (root / name).resolve()
    candidate.relative_to(root.resolve())
    return candidate


def reserve_local_port(min_port: int, max_port: int) -> int:
    for port in range(min_port, max_port + 1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(("127.0.0.1", port))
            except OSError:
                continue
            return port
    raise RuntimeError(f"No local port available in {min_port}-{max_port}")


def first_present(mapping: dict[str, Any], names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        if name in mapping:
            return mapping[name]
    return default


def result_rows(result: Any) -> tuple[list[str], list[Any], bool]:
    """Best-effort normalization of AsaDB JSON result variants."""
    if not isinstance(result, dict):
        return [], [], False

    for key in ("results", "statements"):
        values = result.get(key)
        if isinstance(values, list):
            for item in reversed(values):
                cols, rows, more = result_rows(item)
                if cols or rows:
                    return cols, rows, more

    columns = first_present(result, ("columns", "cols", "header"), [])
    rows = first_present(result, ("rows", "data", "records"), [])
    has_more = bool(first_present(result, ("has_more", "hasMore", "more", "truncated"), False))
    if not isinstance(columns, list):
        columns = []
    if not isinstance(rows, list):
        rows = []
    return [str(x) for x in columns], rows, has_more


def rows_as_dicts(result: Any) -> list[dict[str, Any]]:
    columns, rows, _ = result_rows(result)
    output: list[dict[str, Any]] = []
    for row in rows:
        if isinstance(row, dict):
            output.append(row)
        elif isinstance(row, list):
            output.append({
                columns[i] if i < len(columns) else str(i): value
                for i, value in enumerate(row)
            })
    return output


def quote_identifier(identifier: str) -> str:
    safe_id(identifier, "SQL identifier")
    return "`" + identifier.replace("`", "``") + "`"


def looks_like_write(sql: str) -> bool:
    stripped = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    stripped = re.sub(r"--[^\n]*", " ", stripped)
    tokens = re.findall(r"[A-Za-z_]+", stripped.upper())
    write_words = {
        "ALTER", "BEGIN", "COMMIT", "CREATE", "DELETE", "DROP", "GRANT",
        "INSERT", "LOGIN", "RENAME", "REPLACE", "RESTORE", "REVOKE",
        "ROLLBACK", "START", "TRUNCATE", "UPDATE", "USE",
    }
    return any(token in write_words for token in tokens[:12])
