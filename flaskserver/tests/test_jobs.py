from __future__ import annotations

import time
from pathlib import Path

from asadb_server.jobs import JobQueue


def wait_for(queue: JobQueue, job_id: str, timeout: float = 3):
    deadline = time.time() + timeout
    while time.time() < deadline:
        job = queue.get(job_id)
        if job["status"] in {"completed", "failed", "cancelled"}:
            return job
        time.sleep(0.02)
    raise AssertionError("job timeout")


def test_job_queue_persists_progress(tmp_path: Path):
    queue = JobQueue(tmp_path, workers=2)

    def handler(context, payload):
        context.progress(50, "half")
        return {"value": payload["value"] + 1}

    queue.register("increment", handler)
    job = queue.submit("increment", {"value": 4}, user_id="u1")
    completed = wait_for(queue, job["id"])
    assert completed["status"] == "completed"
    assert completed["progress"] == 100.0
    assert completed["result"]["value"] == 5
    queue.shutdown()
