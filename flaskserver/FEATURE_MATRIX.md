# Feature matrix

| Requested capability | Status | Implementation |
| --- | --- | --- |
| Username + password | Implemented | Scrypt hashes, generic login errors, rate limiting |
| File-Based API | Implemented | Atomic JSON inbox/processing/outbox plus Python client |
| Repository support | Integrated by contract | Supervises official `src/asadb_web.pl` and serves existing `web/` |
| Remote client | Implemented | `asadb_server.client.AsaDBClient` |
| Remote CLI | Implemented | Login profiles, shell, query, stream, sessions, jobs, FTS, cluster, backup/restore, Reservoir |
| Database session per client | Implemented | Physical file + logical database affinity |
| Transaction across requests | Implemented | BEGIN/query/COMMIT/ROLLBACK with exclusive file lease |
| Thread pool | Implemented | Waitress request threads + `ThreadPoolExecutor` jobs |
| Cluster mode | Implemented with boundaries | Explicit primary/read replicas, node registry, forwarding, heartbeat |
| Large-result streaming | Implemented | NDJSON pages without complete result materialization |
| Job queue/progress | Implemented | File-persistent Flask jobs plus native Reservoir proxy |
| RBAC multi-user | Implemented | Global/database-scoped role bindings |
| Replication | Implemented with boundaries | Async and scheduled official `.asb` snapshot replication |
| Full-text search | Implemented as sidecar | File-based inverted index rebuilt from paged AsaDB SELECTs |
| AsAPanel server mode | Implemented | Existing panel and APIs hosted/proxied after Flask login |
| AsAPanel admin/config | Implemented | Shared AsAPanel theme, workspace bar, `/admin`, and `/mode` |
| Original CLI | Preserved | `swipl asadb local` remains available for terminal-only work |
| Login-first portal | Implemented | `swipl asadb` / `run_panel` initializes once, opens `/login`, then selects a workspace |
| Local/server workspace choice | Implemented | One authenticated panel; loopback-only Local Workspace is gated by `ASADB_ALLOW_LOCAL_ONLY` |
| One-pack runtime | Implemented | Offline wheelhouse plus per-user Python bootstrap outside the pack directory |
| Health/readiness/metrics | Implemented | Public process/readiness probes and administrator operational snapshot |
| Logout transaction safety | Implemented | User sessions close and active leases roll back before token revocation |

## Deliberate boundaries

- Cluster writes are explicit-primary, not active-active.
- Replication is snapshot-based, not synchronous quorum/log shipping.
- Pool is topology metadata, not automatic distributed query planning.
- Transactions do not survive process restart.
- FTS is eventually consistent and rebuildable.
- One Flask process owns one state/data directory; concurrency is threaded.
- The bundled Server Mode runtime targets CPython 3.10–3.13 on Linux x86_64
  and Windows x64. macOS Server Mode is not release-tested.
- `swipl asadb` requires SWI-Prolog 9.1.18 or newer because it uses the native
  pack-application mechanism; extracted source releases retain explicit
  launchers for hosts that have not installed the local pack.
- The unified browser portal deliberately does not offer an unauthenticated
  Local Only bypass. Its Local Workspace still requires login; direct local
  CLI access remains an explicit terminal operation.
