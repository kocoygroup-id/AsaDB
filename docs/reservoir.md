# AsaDB Reservoir System

The Reservoir is AsaDB's bounded, durable bridge between AsAPanel and the
Prolog SQL executor. It is designed for traffic shaping, retry safety, and
observable progress. It is not a second database, a distributed message queue,
or a replacement for the storage engine.

## Why It Exists

Pasting a large SQL script into a browser creates a fast producer. The Prolog
parser, transaction manager, page-backed record manager, and disk are a slower
consumer. Sending many independent HTTP requests makes that mismatch worse:
requests can overlap, retries can duplicate writes, audio/UI completion can
race, and browser memory can grow before the backend has accepted the work.

The Reservoir separates acceptance from execution. The frontend deposits one
bounded stream. The backend pulls one admitted job at a time and continues to
use the normal AsaDB execution and recovery layers.

`src/bridge/karyawan.pl` is the Reservoir's small traffic adviser. It is pure
Prolog, so Linux deployments do not need R. It recommends receive chunk sizes from spool headroom, describes queue and
worker pressure, and bounds result egress pages. It never starts a second
worker and never executes SQL itself.

## Routing

- SQL containing write or DDL commands uses the Reservoir.
- Any SQL payload larger than 250,000 characters uses the Reservoir.
- Small read-only SQL uses `/api/query` directly.
- File import uses the same Reservoir worker and streaming SQL importer.
- The legacy `/api/execute_stream` endpoint remains compatible by submitting a
  Reservoir job and waiting for its terminal result.

This adaptive path avoids adding queue latency to normal interactive reads.

## Lifecycle

```text
receiving -> queued -> processing -> completed -> delivered
     |          |           |
     |          +-> cancelled
     +-> failed             +-> cancelling -> cancelled
                            +-> failed
                            +-> interrupted after restart
```

1. Admission checks active job count and reserved spool bytes.
2. The request body is copied to `.asa.reservoir/spool` in 256 KB chunks.
3. Every chunk updates the reservation under the Reservoir mutex. The byte
   ceiling therefore remains enforced even when a caller lies about size.
4. The completed spool receives a SHA-256 fingerprint.
5. Matching idempotency key and fingerprint pairs reuse a non-failed job.
6. One worker claims the job and calls the existing SQL executor under
   `asadb_execution`.
7. Progress is updated in memory and persisted at bounded byte intervals.
8. Results are written to a temporary file and atomically renamed.
9. Delivered terminal artifacts remain available for a configurable retry
   window and are then cleaned up.

## Durability and Retry Rules

Job snapshots are appended as complete Prolog dict terms to an event file.
That makes the latest complete event recoverable if the process stops during a
later append. Result files are published through temporary-file rename.

After restart:

- a queued job is queued again;
- a processing job with a complete result is recovered as completed;
- a receiving, processing, or cancelling job without a result becomes
  interrupted;
- interrupted work is never replayed automatically.

The final rule is deliberate. AsaDB cannot prove that an interrupted arbitrary
SQL script performed no durable mutation. Automatic replay could execute the
same write twice. The user can inspect the database and submit a new job.

## Pressure and Memory Bounds

Reservoir limits are independent from the 4 KB page buffer pool. The bridge
never stores the complete incoming request as one Prolog term. Its largest
normal receive allocation is one 256 KB chunk plus HTTP/runtime overhead.

```ini
reservoir_max_jobs = 16
reservoir_max_spool_bytes = 536870912
reservoir_job_ttl_seconds = 3600
reservoir_progress_quantum_bytes = 1048576
reservoir_result_page_rows = 250
```

`reservoir_max_jobs` counts receiving, queued, processing, and cancelling jobs.
`reservoir_max_spool_bytes` counts their maximum declared or received size.
Pinned database pages and dirty flushing remain the responsibility of the
buffer pool and pager.

## HTTP API

All endpoints require the existing localhost panel token.

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/reservoir/jobs` | Submit raw SQL and receive a job ID |
| GET | `/api/reservoir/jobs` | Discover active jobs after a panel reload |
| POST | `/api/reservoir/file` | Submit an allowed server-side SQL file |
| GET | `/api/reservoir/job?id=...` | Poll status and progress |
| GET | `/api/reservoir/result?id=...` | Read a bounded result page |
| POST | `/api/reservoir/cancel?id=...` | Request cancellation |
| GET | `/api/reservoir/stats` | Inspect queue and spool pressure |

Interactive read results use the same bounded paging contract. `/api/query`
accepts an optional non-negative `offset`; the panel starts with the configured
500-row display page and asks for the next page only after the user presses
`Show more`. This keeps SQL command output responsive while preserving the
query's ordering and avoids silently dropping rows.

`GET /api/reservoir/jobs` returns the active `receiving`, `queued`,
`processing`, and `cancelling` snapshots, newest update first. Terminal jobs
remain addressable by their ID during the normal retention window but are not
returned by this discovery list.

Raw submissions may send:

- `X-AsaDB-Idempotency-Key`
- `X-AsaDB-Job-Label`
- `X-AsaDB-Stop-On-Error: true|false`

Cancellation is cooperative. A running import checks at block and transaction
boundaries, rolls back, and then reports cancellation. It does not terminate a
thread in the middle of a page write.

## Panel Reload, Cancellation, And Live Metadata

AsAPanel stores a small active-job descriptor in browser storage immediately
after admission. It never stores the SQL payload there. After a panel reload it
first asks for that exact job ID; if browser storage was unavailable or the
reload interrupted the admission response, it falls back to the active-job
discovery endpoint. Monitoring resumes from the durable backend snapshot, so a
reload does not submit the SQL again.

The Import view keeps a native 0-100 progress element and a Cancel button for
the recovered job. Cancel sends the active job ID to the existing cooperative
cancel endpoint. A cancellation while the request body is still arriving
moves `receiving -> cancelling -> cancelled`; the writer closes before its
spool file is removed, and the job is never queued. Repeated cancellation of a
terminal job is safe.

Database metadata uses cache-bypassing, single-flight refreshes. The adaptive
poll interval is 500 ms while a Reservoir job is active, 1.5 seconds while the
metadata panel is open, and 5 seconds while idle. Network refresh is skipped
while the document is hidden and requested immediately when it becomes visible
or focused again. Reservoir metadata reports the complete active count,
including a request that is still receiving bytes, as well as queued work and
reserved spool bytes.

This is monitoring continuity, not automatic write replay. An interrupted
backend execution retains the existing conservative recovery semantics.

## Invariants

- Admission and first persisted state are atomic.
- At most one Reservoir worker invokes the SQL executor at a time.
- The configured byte limit is enforced during receive, not only from headers.
- A page or catalog mutation still goes through normal AsaDB transactions.
- The bridge never auto-replays an ambiguous in-flight write.
- Repeated frontend clicks share one in-flight JavaScript promise.
- One audio channel is paused and rewound before a later run can play.

## Tests

`tests/reservoir_tests.pl` covers lifecycle, result paging, idempotent retry,
active-job discovery ordering, live progress/statistics, cancellation while
receiving, queued, and processing, terminal cancel idempotency, job
backpressure, understated payload size, and restart recovery. The receiving
test also proves that cancellation is counted once, never reaches `queued`,
and leaves no spool file. The normal SQL suite remains separate so bridge
behavior cannot hide an executor regression.

`tests/ui_regression.js` gates reload recovery, cancel wiring, adaptive
metadata polling, the progress UI, and matching modern/legacy bundle markers.
`tests/release_package_regression.sh` additionally compares the Linux archive
to the current backend and web bytes and verifies that the Windows build embeds
the canonical backend and copies the same web tree. Both platform builds run
the shared realtime release-contract preflight, preventing a stale legacy
bundle from being published. After changing `web/assets/app.js`, rebuild the
checked-in compatibility bundle with `./scripts/build_legacy_frontend.sh`
before invoking either release build. On Linux, the Windows portion is a
static check of source and preflight wiring; it does not build or execute the
native `.exe`.

A distribution-path stress run streamed a 3,116,915-byte generated SQL file
through the packaged executable. The Reservoir executed 1,003 statements,
inserted 100,000 rows with zero errors in 48.628 seconds, peaked at 196.5 MB
working set, and returned 100,000 rows again after process restart. These are
measurements from the project test machine, not a performance-parity claim.

```powershell
swipl -q -s tests\run_tests.pl
swipl -q -s tests\reservoir_tests.pl
```

## Current Limits

- The Reservoir is process-local and has one worker.
- It provides local durability, not distributed consensus.
- Arbitrary SQL is not automatically made idempotent; only duplicate transport
  submissions with the same key and fingerprint are suppressed.
- Result paging bounds browser delivery, but complex executor paths may still
  materialize intermediate rows inside the SQL engine.
- Cancelling a single small command may only take effect before execution;
  streaming imports provide finer batch-boundary cancellation.
