from __future__ import annotations

import threading
import traceback
from concurrent.futures import Future, ThreadPoolExecutor
from pathlib import Path
from typing import Any, Callable

from .errors import AsaServerError
from .file_store import AtomicJsonStore
from .util import epoch, new_id, utc_now

JobHandler = Callable[["JobContext", dict[str, Any]], Any]


class JobCancelled(Exception):
    pass


class JobContext:
    def __init__(self, queue: "JobQueue", job_id: str):
        self.queue = queue
        self.job_id = job_id

    def progress(
        self,
        percent: float,
        message: str,
        **extra: Any,
    ) -> dict[str, Any]:
        return self.queue.update(
            self.job_id,
            {
                "progress": max(0.0, min(100.0, float(percent))),
                "message": message,
                **extra,
            },
        )

    def cancelled(self) -> bool:
        job = self.queue.get(self.job_id)
        return bool(job.get("cancelRequested"))

    def check_cancelled(self) -> None:
        if self.cancelled():
            raise JobCancelled("Job was cancelled.")


class JobQueue:
    def __init__(self, state_dir: Path, workers: int):
        self.store = AtomicJsonStore(state_dir / "jobs")
        self.executor = ThreadPoolExecutor(max_workers=max(1, workers), thread_name_prefix="asadb-job")
        self.handlers: dict[str, JobHandler] = {}
        self.futures: dict[str, Future] = {}
        self._lock = threading.RLock()
        self._recover()

    def _recover(self) -> None:
        for job in self.store.list():
            if job.get("status") in {"queued", "running", "cancelling"}:
                job["status"] = "interrupted"
                job["message"] = "Server restarted before the job completed."
                job["finishedAt"] = utc_now()
                self.store.write(str(job["id"]), job)

    def register(self, kind: str, handler: JobHandler) -> None:
        self.handlers[kind] = handler

    def submit(
        self,
        kind: str,
        payload: dict[str, Any],
        *,
        user_id: str,
        database_id: str | None = None,
    ) -> dict[str, Any]:
        if kind not in self.handlers:
            raise AsaServerError("UNKNOWN_JOB_KIND", f"Unknown job type: {kind}", 400)
        job_id = new_id("job-")
        job = {
            "id": job_id,
            "kind": kind,
            "payload": payload,
            "userId": user_id,
            "databaseId": database_id,
            "status": "queued",
            "progress": 0.0,
            "message": "Queued.",
            "cancelRequested": False,
            "createdAt": utc_now(),
            "startedAt": None,
            "finishedAt": None,
            "result": None,
            "error": None,
        }
        self.store.write(job_id, job)
        future = self.executor.submit(self._run, job_id)
        with self._lock:
            self.futures[job_id] = future
        return job

    def _run(self, job_id: str) -> None:
        job = self.get(job_id)
        handler = self.handlers[str(job["kind"])]
        self.update(
            job_id,
            {
                "status": "running",
                "startedAt": utc_now(),
                "message": "Running.",
            },
        )
        context = JobContext(self, job_id)
        try:
            context.check_cancelled()
            result = handler(context, dict(job.get("payload") or {}))
            context.check_cancelled()
        except JobCancelled as exc:
            self.update(
                job_id,
                {
                    "status": "cancelled",
                    "message": str(exc),
                    "finishedAt": utc_now(),
                },
            )
        except Exception as exc:
            self.update(
                job_id,
                {
                    "status": "failed",
                    "message": str(exc),
                    "error": {
                        "type": type(exc).__name__,
                        "message": str(exc),
                        "traceback": traceback.format_exc(limit=30),
                    },
                    "finishedAt": utc_now(),
                },
            )
        else:
            self.update(
                job_id,
                {
                    "status": "completed",
                    "progress": 100.0,
                    "message": "Completed.",
                    "result": result,
                    "finishedAt": utc_now(),
                },
            )
        finally:
            with self._lock:
                self.futures.pop(job_id, None)

    def get(self, job_id: str) -> dict[str, Any]:
        job = self.store.read(job_id)
        if not isinstance(job, dict):
            raise AsaServerError("JOB_NOT_FOUND", "Job does not exist.", 404)
        return job

    def update(self, job_id: str, values: dict[str, Any]) -> dict[str, Any]:
        job = self.get(job_id)
        job.update(values)
        job["updatedAt"] = utc_now()
        self.store.write(job_id, job)
        return job

    def cancel(self, job_id: str) -> dict[str, Any]:
        job = self.get(job_id)
        if job.get("status") in {"completed", "failed", "cancelled", "interrupted"}:
            return job
        job["cancelRequested"] = True
        job["status"] = "cancelling"
        job["message"] = "Cancellation requested."
        self.store.write(job_id, job)
        with self._lock:
            future = self.futures.get(job_id)
        if future is not None and future.cancel():
            return self.update(
                job_id,
                {
                    "status": "cancelled",
                    "message": "Cancelled before execution.",
                    "finishedAt": utc_now(),
                },
            )
        return job

    def list(self, *, user_id: str | None = None, include_all: bool = False) -> list[dict[str, Any]]:
        jobs = sorted(self.store.list(), key=lambda x: str(x.get("createdAt", "")), reverse=True)
        if include_all or user_id is None:
            return jobs
        return [x for x in jobs if x.get("userId") == user_id]

    def shutdown(self) -> None:
        self.executor.shutdown(wait=False, cancel_futures=True)
