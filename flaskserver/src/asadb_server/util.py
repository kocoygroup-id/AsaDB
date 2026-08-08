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


def sql_statements(sql: str) -> list[str]:
    """Split SQL only at top-level semicolons.

    This is intentionally not an SQL parser.  It is a small lexer used at the
    HTTP authorization boundary so a semicolon in a literal, quoted identifier,
    or comment cannot hide a second statement.  The Prolog engine remains the
    authoritative parser for accepted SQL.
    """
    statements: list[str] = []
    current: list[str] = []
    index = 0
    quote: str | None = None
    length = len(sql)

    while index < length:
        char = sql[index]
        following = sql[index + 1] if index + 1 < length else ""
        if quote:
            current.append(char)
            if char == quote:
                # SQL escapes a quote by doubling it: 'it''s'.
                if following == quote:
                    current.append(following)
                    index += 2
                    continue
                quote = None
            elif char == "\\" and quote in {"'", '"'} and following:
                # Preserve common backslash escapes as one literal unit.
                current.append(following)
                index += 2
                continue
            index += 1
            continue

        if char in {"'", '"', chr(96)}:
            quote = char
            current.append(char)
            index += 1
            continue
        if char == "-" and following == "-":
            index = sql.find("\n", index + 2)
            if index < 0:
                break
            current.append(" ")
            index += 1
            continue
        if char == "#":
            index = sql.find("\n", index + 1)
            if index < 0:
                break
            current.append(" ")
            index += 1
            continue
        if char == "/" and following == "*":
            end = sql.find("*/", index + 2)
            if end < 0:
                # An unterminated comment is not an authorized read.
                return []
            current.append(" ")
            index = end + 2
            continue
        if char == ";":
            statement = "".join(current).strip()
            if statement:
                statements.append(statement)
            current = []
            index += 1
            continue
        current.append(char)
        index += 1

    if quote:
        # Let the database report the syntax error, but never treat malformed
        # input as a safe reader query.
        return []
    statement = "".join(current).strip()
    if statement:
        statements.append(statement)
    return statements


def is_single_select_statement(sql: str) -> bool:
    """Return true only for the conservative reader-safe SQL subset.

    Reader accounts deliberately support one top-level SELECT statement only.
    WITH, SHOW, and EXPLAIN are not granted by inference: a future parser-backed
    classifier can expand this set without weakening the current boundary.
    """
    statements = sql_statements(sql)
    return len(statements) == 1 and bool(
        re.match(r"^SELECT\b", statements[0], flags=re.IGNORECASE)
    )


def looks_like_write(sql: str) -> bool:
    """Whether SQL requires database.write at the server boundary.

    Anything other than one unambiguous SELECT is treated as write-capable.
    This fails closed for reader accounts and blocks multi-statement bypasses.
    """
    return not is_single_select_statement(sql)
