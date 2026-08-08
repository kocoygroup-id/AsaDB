from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import requests


class RemoteError(RuntimeError):
    def __init__(self, status: int, payload: Any):
        self.status = status
        self.payload = payload
        super().__init__(f"Remote AsaDB error {status}: {payload}")


@dataclass
class AsaDBClient:
    base_url: str
    token: str | None = None
    timeout: float = 120.0
    cluster_key: str | None = None

    def __post_init__(self):
        self.base_url = self.base_url.rstrip("/")

    def login(self, username: str, password: str) -> dict[str, Any]:
        result = self.request(
            "POST",
            "/api/v1/auth/login",
            {"username": username, "password": password},
            authenticated=False,
        )
        self.token = str(result["token"])
        return result

    def request(
        self,
        method: str,
        path: str,
        body: Any = None,
        *,
        authenticated: bool = True,
        headers: dict[str, str] | None = None,
    ) -> Any:
        request_headers = {"Accept": "application/json"}
        if body is not None:
            request_headers["Content-Type"] = "application/json"
        if authenticated and self.token:
            request_headers["Authorization"] = f"Bearer {self.token}"
        if self.cluster_key:
            request_headers["X-AsaDB-Cluster-Key"] = self.cluster_key
        if headers:
            request_headers.update(headers)
        data = None
        if body is not None:
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        request = Request(
            self.base_url + path,
            data=data,
            headers=request_headers,
            method=method.upper(),
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
                content_type = response.headers.get("Content-Type", "")
                if "application/json" in content_type or not raw:
                    return json.loads(raw.decode("utf-8")) if raw else {}
                return raw
        except HTTPError as exc:
            raw = exc.read()
            try:
                payload = json.loads(raw.decode("utf-8"))
            except Exception:
                payload = raw.decode("utf-8", errors="replace")
            raise RemoteError(exc.code, payload) from exc
        except URLError as exc:
            raise ConnectionError(f"Cannot connect to AsaDB server: {exc}") from exc

    def databases(self) -> list[dict[str, Any]]:
        return list(self.request("GET", "/api/v1/databases").get("databases", []))

    def query(
        self,
        database_id: str,
        sql: str,
        *,
        session_id: str | None = None,
        logical_database: str | None = None,
    ) -> dict[str, Any]:
        if session_id:
            return self.request(
                "POST",
                f"/api/v1/sessions/{session_id}/query",
                {"sql": sql},
            )
        body = {"sql": sql}
        if logical_database:
            body["logicalDatabase"] = logical_database
        return self.request(
            "POST",
            f"/api/v1/databases/{database_id}/query",
            body,
        )

    def stream_query(
        self,
        database_id: str,
        sql: str,
        *,
        page_size: int = 500,
        logical_database: str | None = None,
    ) -> Iterator[dict[str, Any]]:
        headers = {
            "Accept": "application/x-ndjson",
            "Content-Type": "application/json",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        payload = {"sql": sql, "pageSize": page_size}
        if logical_database:
            payload["logicalDatabase"] = logical_database
        data = json.dumps(payload).encode("utf-8")
        request = Request(
            self.base_url + f"/api/v1/databases/{database_id}/stream",
            data=data,
            headers=headers,
            method="POST",
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                for raw_line in response:
                    line = raw_line.decode("utf-8").strip()
                    if line:
                        yield json.loads(line)
        except HTTPError as exc:
            raise RemoteError(exc.code, exc.read().decode("utf-8", errors="replace")) from exc

    def create_session(
        self,
        database_id: str,
        logical_database: str | None = None,
    ) -> dict[str, Any]:
        body = {"databaseId": database_id}
        if logical_database:
            body["logicalDatabase"] = logical_database
        return self.request("POST", "/api/v1/sessions", body)

    def begin(self, session_id: str) -> dict[str, Any]:
        return self.request("POST", f"/api/v1/sessions/{session_id}/begin", {})

    def commit(self, session_id: str) -> dict[str, Any]:
        return self.request("POST", f"/api/v1/sessions/{session_id}/commit", {})

    def rollback(self, session_id: str) -> dict[str, Any]:
        return self.request("POST", f"/api/v1/sessions/{session_id}/rollback", {})

    def close_session(self, session_id: str) -> dict[str, Any]:
        return self.request("DELETE", f"/api/v1/sessions/{session_id}")

    def _requests_headers(self) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        if self.cluster_key:
            headers["X-AsaDB-Cluster-Key"] = self.cluster_key
        return headers

    def backup(
        self,
        database_id: str,
        logical_database: str,
        output: str | Path,
    ) -> Path:
        target = Path(output)
        response = requests.post(
            self.base_url + f"/api/v1/databases/{database_id}/backup",
            json={"logicalDatabase": logical_database},
            headers=self._requests_headers(),
            timeout=max(self.timeout, 600),
            stream=True,
        )
        if response.status_code >= 400:
            raise RemoteError(response.status_code, response.text[:2000])
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("wb") as handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    handle.write(chunk)
        return target

    def restore(
        self,
        database_id: str,
        snapshot: str | Path,
    ) -> dict[str, Any]:
        path = Path(snapshot)
        headers = self._requests_headers()
        headers.update({
            "Content-Type": "application/octet-stream",
            "Content-Length": str(path.stat().st_size),
        })
        with path.open("rb") as handle:
            response = requests.post(
                self.base_url + f"/api/v1/databases/{database_id}/restore",
                data=handle,
                headers=headers,
                timeout=max(self.timeout, 3600),
            )
        try:
            payload = response.json()
        except ValueError:
            payload = response.text
        if response.status_code >= 400:
            raise RemoteError(response.status_code, payload)
        return payload

    def reservoir_submit(
        self,
        database_id: str,
        source: str | Path,
        *,
        logical_database: str | None = None,
        label: str | None = None,
        idempotency_key: str | None = None,
        stop_on_error: bool = True,
        import_format: str | None = None,
    ) -> dict[str, Any]:
        path = Path(source)
        headers = self._requests_headers()
        headers.update({
            "Content-Type": "application/octet-stream",
            "Content-Length": str(path.stat().st_size),
            "X-AsaDB-Job-Label": label or path.name,
            "X-AsaDB-Stop-On-Error": "true" if stop_on_error else "false",
        })
        if logical_database:
            headers["X-AsaDB-Logical-Database"] = logical_database
        if idempotency_key:
            headers["X-AsaDB-Idempotency-Key"] = idempotency_key
        if import_format:
            headers["X-AsaDB-Import-Format"] = import_format
            headers["X-AsaDB-Import-Name"] = path.name
        with path.open("rb") as handle:
            response = requests.post(
                self.base_url + f"/api/v1/databases/{database_id}/reservoir",
                data=handle,
                headers=headers,
                timeout=max(self.timeout, 600),
            )
        try:
            payload = response.json()
        except ValueError:
            payload = response.text
        if response.status_code >= 400:
            raise RemoteError(response.status_code, payload)
        return payload

    def reservoir_job(self, database_id: str, job_id: str) -> dict[str, Any]:
        return self.request(
            "GET",
            f"/api/v1/databases/{database_id}/reservoir/jobs/{job_id}",
        )

    def reservoir_cancel(self, database_id: str, job_id: str) -> dict[str, Any]:
        return self.request(
            "POST",
            f"/api/v1/databases/{database_id}/reservoir/jobs/{job_id}/cancel",
            {},
        )
