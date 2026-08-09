from __future__ import annotations

import collections
import os
import queue
import re
import subprocess
import threading
import time
import uuid
from pathlib import Path
from typing import Any, Iterator

import requests

from .config import Settings
from .errors import BackendError, BackendUnavailable
from .registry import DatabaseRegistry
from .util import quote_identifier, reserve_local_port, result_rows

READY_RE = re.compile(r"AsAPanel running at http://127\.0\.0\.1:(\d+)/")


def query_result_has_error(result: dict[str, Any]) -> bool:
    """Return whether an AsaDB JSON query result contains a SQL error."""
    return any(
        isinstance(item, dict) and item.get("status") == "error"
        for item in result.get("results", [])
    )


def query_result_error_message(result: dict[str, Any]) -> str:
    for item in result.get("results", []):
        if isinstance(item, dict) and item.get("status") == "error":
            return str(item.get("message") or "Logical database does not exist.")
    return "Logical database does not exist."


class SizedReader:
    """File-like wrapper that gives Requests an exact Content-Length."""

    def __init__(self, stream, length: int):
        self.stream = stream
        self.length = max(0, int(length))

    def __len__(self) -> int:
        return self.length

    def read(self, size: int = -1):
        return self.stream.read(size)


class MultipartFileBody:
    """Streaming multipart body with read() and a known total length."""

    def __init__(
        self,
        path: Path,
        before: bytes,
        after: bytes,
    ):
        self.path = path
        self.before = before
        self.after = after
        self.total_length = len(before) + path.stat().st_size + len(after)
        self._before_offset = 0
        self._after_offset = 0
        self._file = None
        self._done = False

    def __len__(self) -> int:
        return self.total_length

    def _open_file(self):
        if self._file is False:
            return None
        if self._file is None:
            self._file = self.path.open("rb")
        return self._file

    def read(self, size: int = -1) -> bytes:
        if self._done:
            return b""
        if size is None or size < 0:
            size = self.total_length
        if size == 0:
            return b""

        output = bytearray()
        remaining = size

        if self._before_offset < len(self.before) and remaining > 0:
            chunk = self.before[self._before_offset:self._before_offset + remaining]
            output.extend(chunk)
            self._before_offset += len(chunk)
            remaining -= len(chunk)

        if self._before_offset >= len(self.before) and remaining > 0:
            handle = self._open_file()
            if handle is not None:
                chunk = handle.read(remaining)
                if chunk:
                    output.extend(chunk)
                    remaining -= len(chunk)
                else:
                    handle.close()
                    self._file = False

        file_finished = self._file is False
        if file_finished and self._after_offset < len(self.after) and remaining > 0:
            chunk = self.after[self._after_offset:self._after_offset + remaining]
            output.extend(chunk)
            self._after_offset += len(chunk)

        if file_finished and self._after_offset >= len(self.after):
            self._done = True
        return bytes(output)

    def close(self) -> None:
        if self._file not in (None, False):
            self._file.close()
        self._file = False
        self._done = True


def multipart_file_stream(
    path: Path,
    *,
    field_name: str,
    fields: dict[str, str],
    content_type: str = "application/octet-stream",
):
    """Return (content-type, length, streaming file-like body)."""
    boundary = "----AsaDBFlask" + uuid.uuid4().hex
    before_parts: list[bytes] = []
    for name, value in fields.items():
        before_parts.append(
            (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
                f"{value}\r\n"
            ).encode("utf-8")
        )
    safe_name = path.name.replace('"', "_").replace("\r", "_").replace("\n", "_")
    before_parts.append(
        (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{field_name}"; filename="{safe_name}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode("utf-8")
    )
    before = b"".join(before_parts)
    after = f"\r\n--{boundary}--\r\n".encode("utf-8")
    body = MultipartFileBody(path, before, after)
    return f"multipart/form-data; boundary={boundary}", len(body), body


class PanelBackend:
    """Supervises one official src/asadb_web.pl process for one .asa file."""

    def __init__(
        self,
        settings: Settings,
        database_id: str,
        database_path: Path,
    ):
        self.settings = settings
        self.database_id = database_id
        self.database_path = database_path
        self.process: subprocess.Popen[str] | None = None
        self.port: int | None = None
        self.http = requests.Session()
        self.panel_token: str | None = None
        self._lifecycle_lock = threading.RLock()
        # The official web backend owns mutable process-wide state (notably
        # the selected logical database).  Serialising one physical .asa
        # backend keeps a USE + following request from bleeding into another
        # Flask client, while the public Flask server can still serve other
        # physical database files concurrently.
        self._execution_lock = threading.RLock()
        self._database_context_lock = threading.RLock()
        self._stdout_lines: collections.deque[str] = collections.deque(maxlen=200)
        self._stderr_lines: collections.deque[str] = collections.deque(maxlen=200)
        self._ready = threading.Event()
        self.started_at: float | None = None
        self.last_used_at = time.time()

    @property
    def alive(self) -> bool:
        return self.process is not None and self.process.poll() is None

    @property
    def base_url(self) -> str:
        if self.port is None:
            raise BackendUnavailable("BACKEND_NOT_READY", "AsaDB backend has no port.", 503)
        return f"http://127.0.0.1:{self.port}"

    def start(self) -> None:
        with self._lifecycle_lock:
            if self.alive and self._ready.is_set():
                return
            missing = self.settings.validate_repo()
            if missing:
                raise BackendUnavailable(
                    "REPOSITORY_INCOMPLETE",
                    "AsaDB repository files are missing.",
                    503,
                    missing,
                )
            self.database_path.parent.mkdir(parents=True, exist_ok=True)
            port = reserve_local_port(
                self.settings.backend_port_min,
                self.settings.backend_port_max,
            )
            command = [
                self.settings.swipl,
                "-q",
                "-s",
                str(self.settings.prolog_web),
                "--",
                str(self.database_path),
                str(port),
            ]
            # A backend can be stopped and started again by supervision.  Its
            # old Session is closed in stop(), so always begin a new backend
            # process with a fresh private connection pool and cookie jar.
            self.http.close()
            self.http = requests.Session()
            self._ready.clear()
            self.port = port
            self.process = subprocess.Popen(
                command,
                cwd=self.settings.repo_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
            )
            assert self.process.stdout is not None
            assert self.process.stderr is not None
            threading.Thread(target=self._read_stdout, daemon=True).start()
            threading.Thread(target=self._read_stderr, daemon=True).start()

            deadline = time.time() + self.settings.backend_start_timeout
            while time.time() < deadline:
                if not self.alive:
                    raise BackendUnavailable(
                        "BACKEND_EXITED",
                        "AsaDB Prolog backend exited during startup.",
                        503,
                        self.stderr_tail(),
                    )
                if self._ready.wait(timeout=0.15):
                    break
                try:
                    response = self.http.get(self.base_url + "/", timeout=0.5)
                    if response.status_code == 200:
                        self._ready.set()
                        break
                except requests.RequestException:
                    pass
            if not self._ready.is_set():
                self.stop(force=True)
                raise BackendUnavailable(
                    "BACKEND_START_TIMEOUT",
                    "Timed out while starting the AsaDB panel backend.",
                    504,
                    self.stderr_tail(),
                )

            # Root sets the official local asadb_token cookie used by all panel APIs.
            response = self.http.get(self.base_url + "/", timeout=5)
            if response.status_code != 200:
                self.stop(force=True)
                raise BackendUnavailable(
                    "BACKEND_HANDSHAKE_FAILED",
                    "Could not establish the internal AsAPanel token.",
                    503,
                )
            self.panel_token = (
                response.cookies.get("asadb_token")
                or self.http.cookies.get("asadb_token")
            )
            if not self.panel_token:
                self.stop(force=True)
                raise BackendUnavailable(
                    "BACKEND_TOKEN_MISSING",
                    "The internal AsAPanel did not issue its local API token.",
                    503,
                )
            self.started_at = time.time()
            self.last_used_at = time.time()

    def _read_stdout(self) -> None:
        process = self.process
        if process is None or process.stdout is None:
            return
        for line in process.stdout:
            clean = line.rstrip()
            self._stdout_lines.append(clean)
            match = READY_RE.search(clean)
            if match:
                self.port = int(match.group(1))
                self._ready.set()

    def _read_stderr(self) -> None:
        process = self.process
        if process is None or process.stderr is None:
            return
        for line in process.stderr:
            self._stderr_lines.append(line.rstrip())

    def request(
        self,
        method: str,
        path: str,
        *,
        data: Any = None,
        json_body: Any = None,
        files: Any = None,
        params: Any = None,
        headers: dict[str, str] | None = None,
        timeout: float | None = None,
        stream: bool = False,
    ) -> requests.Response:
        self.start()
        try:
            # Reuse the supervised Session: it owns the internal token and
            # maintains a localhost connection pool instead of creating a
            # TCP connection for every SQL request.
            with self._execution_lock:
                response = self.http.request(
                    method=method,
                    url=self.base_url + path,
                    data=data,
                    json=json_body,
                    files=files,
                    params=params,
                    headers=headers,
                    timeout=timeout or self.settings.query_timeout,
                    stream=stream,
                )
        except requests.RequestException as exc:
            raise BackendUnavailable(
                "BACKEND_REQUEST_FAILED",
                f"Internal AsaDB backend request failed: {exc}",
                503,
            ) from exc
        self.last_used_at = time.time()
        return response

    def query(self, sql: str, *, offset: int = 0) -> dict[str, Any]:
        response = self.request(
            "POST",
            "/api/query",
            data={"sql": sql, "offset": str(max(0, int(offset)))},
        )
        return self._json_or_error(response)

    def query_in_database(
        self,
        logical_database: str,
        sql: str,
        *,
        offset: int = 0,
    ) -> dict[str, Any]:
        with self._database_context_lock, self._execution_lock:
            # Select the logical database as a separate, serialized command.
            # Prepending USE to a read query turns it into a mixed statement
            # batch, so the Prolog web layer cannot use its immutable TVCC
            # read path.  Keeping the caller SQL intact also makes result
            # payloads contain only the command the caller asked to run.
            selected = self.query(f"USE {quote_identifier(logical_database)};")
            # USE is an existence check, never an implicit CREATE.  Do not
            # run the caller SQL in whatever prior context happens to remain
            # when logical-database selection failed.
            if query_result_has_error(selected):
                return selected
            return self.query(sql, offset=offset)

    def request_in_database(
        self,
        logical_database: str,
        method: str,
        path: str,
        **kwargs: Any,
    ) -> requests.Response:
        with self._database_context_lock, self._execution_lock:
            selected = self.query(f"USE {quote_identifier(logical_database)};")
            if query_result_has_error(selected):
                raise BackendError(
                    "LOGICAL_DATABASE_NOT_FOUND",
                    query_result_error_message(selected),
                    404,
                    selected,
                )
            return self.request(method, path, **kwargs)

    def begin_transaction(self, logical_database: str | None = None) -> dict[str, Any]:
        with self._database_context_lock, self._execution_lock:
            if logical_database:
                selected = self.query(f"USE {quote_identifier(logical_database)};")
                if query_result_has_error(selected):
                    return selected
                return self.query("BEGIN;")
            return self.query("BEGIN;")

    def analyze(self, sql: str) -> dict[str, Any]:
        response = self.request("POST", "/api/analyze", data={"sql": sql})
        return self._json_or_error(response)

    def metadata(self) -> dict[str, Any]:
        return self._json_or_error(self.request("GET", "/api/metadata"))

    def catalog(self) -> dict[str, Any]:
        return self._json_or_error(self.request("GET", "/api/catalog"))

    def state(self) -> dict[str, Any]:
        return self._json_or_error(self.request("GET", "/api/state"))

    def save(self) -> dict[str, Any]:
        return self._json_or_error(self.request("POST", "/api/save"))

    def shutdown(self) -> dict[str, Any]:
        return self._json_or_error(
            self.request("POST", "/api/shutdown", timeout=10)
        )

    def backup(self, logical_database: str) -> requests.Response:
        response = self.request(
            "POST",
            "/api/backup",
            data={"database": logical_database, "output": "save"},
            stream=True,
            timeout=max(self.settings.query_timeout, 600),
        )
        if response.status_code >= 400:
            self._raise_response(response)
        return response

    def import_upload(
        self,
        path: Path,
        *,
        format_name: str = "auto",
        stop_on_error: bool = True,
    ) -> dict[str, Any]:
        body_type, body_length, body = multipart_file_stream(
            path,
            field_name="file",
            fields={
                "format": format_name,
                "stop_on_error": "true" if stop_on_error else "false",
            },
        )
        try:
            response = self.request(
                "POST",
                "/api/import_upload",
                data=body,
                headers={
                    "Content-Type": body_type,
                    "Content-Length": str(body_length),
                },
                timeout=max(self.settings.query_timeout, 3600),
            )
        finally:
            body.close()
        return self._json_or_error(response)

    def reservoir_submit(
        self,
        path: Path,
        *,
        label: str | None = None,
        idempotency_key: str = "",
        stop_on_error: bool = True,
        metadata: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        headers = {
            "X-AsaDB-Job-Label": label or path.name,
            "X-AsaDB-Idempotency-Key": idempotency_key,
            "X-AsaDB-Stop-On-Error": "true" if stop_on_error else "false",
            "Content-Type": "application/octet-stream",
            "Content-Length": str(path.stat().st_size),
        }
        if metadata:
            header_names = {
                "format": "X-AsaDB-Import-Format",
                "source_name": "X-AsaDB-Import-Name",
                "target_table": "X-AsaDB-Import-Table",
                "mode": "X-AsaDB-Import-Mode",
            }
            for key, value in metadata.items():
                header_name = header_names.get(key)
                if header_name:
                    headers[header_name] = str(value)
        with path.open("rb") as handle:
            response = self.request(
                "POST",
                "/api/reservoir/jobs",
                data=handle,
                headers=headers,
                timeout=max(self.settings.query_timeout, 600),
            )
        return self._json_or_error(response)

    def reservoir_job(self, job_id: str) -> dict[str, Any]:
        return self._json_or_error(
            self.request("GET", "/api/reservoir/job", params={"id": job_id})
        )

    def reservoir_result(self, job_id: str, offset: int, limit: int) -> dict[str, Any]:
        return self._json_or_error(
            self.request(
                "GET",
                "/api/reservoir/result",
                params={"id": job_id, "offset": offset, "limit": limit},
            )
        )

    def reservoir_cancel(self, job_id: str) -> dict[str, Any]:
        return self._json_or_error(
            self.request("POST", "/api/reservoir/cancel", data={"id": job_id})
        )

    def reservoir_stats(self) -> dict[str, Any]:
        return self._json_or_error(self.request("GET", "/api/reservoir/stats"))

    def stream_query_pages(
        self,
        sql: str,
        page_size: int,
        *,
        start_offset: int = 0,
        max_pages: int = 1_000_000,
    ) -> Iterator[dict[str, Any]]:
        offset = max(0, int(start_offset))
        for page_number in range(max_pages):
            result = self.query(sql, offset=offset)
            columns, rows, has_more = result_rows(result)
            yield {
                "page": page_number,
                "offset": offset,
                "columns": columns,
                "rows": rows,
                "hasMore": has_more,
                "raw": result,
            }
            row_count = len(rows)
            if not has_more or row_count == 0:
                break
            offset += row_count if row_count else page_size

    def stream_query_pages_in_database(
        self,
        logical_database: str,
        sql: str,
        page_size: int,
        *,
        start_offset: int = 0,
        max_pages: int = 1_000_000,
    ) -> Iterator[dict[str, Any]]:
        with self._database_context_lock, self._execution_lock:
            # Select once and retain the context lock for the full page stream.
            selected = self.query(f"USE {quote_identifier(logical_database)};")
            if query_result_has_error(selected):
                raise BackendError(
                    "LOGICAL_DATABASE_NOT_FOUND",
                    query_result_error_message(selected),
                    404,
                    selected,
                )
            yield from self.stream_query_pages(
                sql,
                page_size,
                start_offset=start_offset,
                max_pages=max_pages,
            )

    def _json_or_error(self, response: requests.Response) -> dict[str, Any]:
        if response.status_code >= 400:
            self._raise_response(response)
        try:
            value = response.json()
        except ValueError as exc:
            raise BackendError(
                "INVALID_BACKEND_RESPONSE",
                "The internal AsaDB backend returned invalid JSON.",
                502,
                response.text[:1000],
            ) from exc
        if not isinstance(value, dict):
            return {"value": value}
        return value

    def _raise_response(self, response: requests.Response) -> None:
        message = response.text[:2000]
        try:
            payload = response.json()
            if isinstance(payload, dict):
                message = str(payload.get("message") or payload.get("error") or message)
        except ValueError:
            pass
        raise BackendError(
            "ASADB_BACKEND_ERROR",
            message or f"Backend returned HTTP {response.status_code}.",
            422 if response.status_code < 500 else 502,
            {"backendStatus": response.status_code},
        )

    def status(self) -> dict[str, Any]:
        return {
            "databaseId": self.database_id,
            "alive": self.alive,
            "pid": self.process.pid if self.alive and self.process else None,
            "port": self.port,
            "startedAt": self.started_at,
            "lastUsedAt": self.last_used_at,
            "stdoutTail": list(self._stdout_lines)[-10:],
            "stderrTail": self.stderr_tail(10),
        }

    def stderr_tail(self, limit: int = 30) -> list[str]:
        return list(self._stderr_lines)[-limit:]

    @staticmethod
    def _listener_alive(base_url: str) -> bool:
        try:
            response = requests.get(base_url + "/", timeout=0.25)
        except requests.RequestException:
            return False
        return response.status_code > 0

    def _wait_for_listener_exit(self, base_url: str, timeout: float = 10) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if not self._listener_alive(base_url):
                return True
            time.sleep(0.05)
        return not self._listener_alive(base_url)

    def _force_stop_process_tree(self, process: subprocess.Popen[str]) -> None:
        # A Windows launcher can leave the actual SWI-Prolog child running
        # after its parent wrapper has exited.  /T makes the fallback target
        # the known supervised process tree instead of an arbitrary process.
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        else:
            process.kill()

    def _force_stop_listener_processes(self) -> None:
        """Stop the verified private listener when a Windows wrapper escaped.

        `swipl.exe` normally is the server process.  Some Windows launch
        paths can nevertheless leave the listener in a descendant after the
        tracked wrapper has exited.  Querying `netstat` limits this fallback to
        the port that this supervisor reserved for this backend; it never
        enumerates or terminates unrelated processes.
        """
        if os.name != "nt" or self.port is None:
            return
        try:
            listing = subprocess.run(
                ["netstat", "-ano", "-p", "tcp"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=5,
                check=False,
            ).stdout
        except (OSError, subprocess.SubprocessError):
            return
        port = str(self.port)
        pids: set[str] = set()
        for line in listing.splitlines():
            fields = line.split()
            if len(fields) < 5 or fields[-2].upper() != "LISTENING":
                continue
            local_address = fields[1]
            if local_address.rsplit(":", 1)[-1] == port and fields[-1].isdigit():
                pids.add(fields[-1])
        for pid in pids:
            subprocess.run(
                ["taskkill", "/PID", pid, "/T", "/F"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )

    def _wait_for_catalog_settle(self, timeout: float = 10) -> None:
        catalog = self.database_path
        temporary = Path(str(catalog) + ".tmp")
        backup = Path(str(catalog) + ".bak")
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if catalog.exists() and not temporary.exists() and not backup.exists():
                return
            time.sleep(0.05)
        raise BackendUnavailable(
            "BACKEND_SHUTDOWN_INCOMPLETE",
            "AsaDB catalog did not reach a stable durable state before restart.",
            503,
            {
                "catalog": str(catalog),
                "catalogExists": catalog.exists(),
                "temporaryExists": temporary.exists(),
                "backupExists": backup.exists(),
            },
        )

    def stop(self, *, force: bool = False, require_durable: bool = False) -> None:
        with self._lifecycle_lock:
            process = self.process
            if process is None:
                return
            catalog_was_present = self.database_path.exists()
            base_url = self.base_url if self.port is not None else ""
            if process.poll() is None:
                with self._execution_lock:
                    if require_durable:
                        # A restart is a durability boundary.  Do not quietly
                        # discard a failed checkpoint and pretend the next
                        # process is a healthy continuation.
                        self.save()
                    else:
                        try:
                            self.save()
                        except Exception:
                            pass
                    if force:
                        self._force_stop_process_tree(process)
                    else:
                        try:
                            # Popen.terminate() is a forceful TerminateProcess on
                            # Windows.  Ask the authenticated Prolog endpoint to
                            # run asadb_shutdown/0 first; it saves state and runs
                            # its cleanup hooks before halt/0.  A bounded kill is
                            # retained only as a supervisor fallback.
                            self.shutdown()
                        except Exception:
                            process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    self._force_stop_process_tree(process)
                    process.wait(timeout=5)
            # `wait()` covers the tracked parent.  On Windows a launcher can
            # outlive that parent briefly, so prove that the old HTTP listener
            # has gone away before a new backend may touch the same .asa file.
            if base_url and not self._wait_for_listener_exit(base_url):
                self._force_stop_process_tree(process)
                self._force_stop_listener_processes()
                if not self._wait_for_listener_exit(base_url, timeout=5):
                    raise BackendUnavailable(
                        "BACKEND_SHUTDOWN_INCOMPLETE",
                        "The previous AsaDB backend listener did not stop.",
                        503,
                        {"databaseId": self.database_id, "baseUrl": base_url},
                    )
            if catalog_was_present:
                self._wait_for_catalog_settle()
            self.process = None
            self._ready.clear()
            self.panel_token = None
            self.http.close()


class BackendManager:
    def __init__(self, settings: Settings, registry: DatabaseRegistry):
        self.settings = settings
        self.registry = registry
        self._lock = threading.RLock()
        self._backends: dict[str, PanelBackend] = {}

    def get(self, database_id: str) -> PanelBackend:
        self.registry.get(database_id)
        with self._lock:
            backend = self._backends.get(database_id)
            if backend is None:
                backend = PanelBackend(
                    self.settings,
                    database_id,
                    self.registry.path(database_id),
                )
                self._backends[database_id] = backend
            return backend

    def restart(self, database_id: str) -> dict[str, Any]:
        with self._lock:
            backend = self._backends.pop(database_id, None)
        if backend is not None:
            # A restart is an administrative durability boundary, not a crash
            # simulation.  stop() saves first, requests a bounded graceful
            # shutdown, and only kills a process that does not exit in time.
            # Using force=True here could kill the Prolog process while the
            # platform is still completing its final filesystem writes.
            try:
                backend.stop(require_durable=True)
            except Exception:
                # Preserve the still-supervised backend if its durable stop
                # could not be proven.  Starting a second process for the
                # same catalog after that failure would risk split state.
                with self._lock:
                    self._backends.setdefault(database_id, backend)
                raise
        backend = self.get(database_id)
        backend.start()
        return backend.status()

    def stop(self, database_id: str, *, force: bool = False) -> None:
        with self._lock:
            backend = self._backends.pop(database_id, None)
        if backend:
            backend.stop(force=force)

    def stop_all(self) -> None:
        with self._lock:
            backends = list(self._backends.values())
            self._backends.clear()
        for backend in backends:
            backend.stop()

    def statuses(self) -> list[dict[str, Any]]:
        with self._lock:
            return [backend.status() for backend in self._backends.values()]
