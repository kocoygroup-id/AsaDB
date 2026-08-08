# AsaDB Flask Server 1.5.0

Python-first server mode, remote client, remote CLI, file-based control plane,
cluster gateway, and authenticated AsAPanel host for the official
[`kocoygroup-id/AsaDB`](https://github.com/kocoygroup-id/AsaDB) repository.

This directory is designed to live at:

```text
AsaDB/
├── src/
│   ├── asadb.pl
│   ├── asadb_web.pl
│   ├── asadb_core.pl
│   └── ...
├── web/
│   ├── index.html
│   └── assets/
└── flaskserver/
    └── ...
```

The Flask package version is deliberately aligned with AsaDB Core 1.5.0. A
server checkout must use the matching `src/` and `web/` tree; it is not a
separate SQL implementation.

It does **not** replace or reimplement AsaDB storage. Flask is the public server
and Python ecosystem layer. The official SWI-Prolog backend still owns SQL
parsing, execution, transactions, TVCC, Reservoir, backups, import/export,
B+Tree, page storage, and `.asa` files.

When installed as an AsaDB SWI-Prolog pack, this `flaskserver/` source tree,
its locked wheelhouse, and the offline bootstrapper are included with the
engine. Server Mode creates a per-user virtual environment outside the pack
and installs dependencies with `--no-index`; users do not run `pip install`.

## What is included

- Username/password authentication with scrypt password hashes.
- Bearer-token and secure browser-cookie authentication.
- File-based users, tokens, RBAC, database registry, sessions, jobs, cluster
  topology, FTS definitions, configuration, and JSONL audit records.
- Literal File-Based API using atomic inbox/processing/outbox JSON files.
- Public Flask REST API.
- Existing AsAPanel served through Flask after login.
- Existing AsAPanel API proxied to the official `src/asadb_web.pl` backend.
- Local mode and server mode.
- Python remote client.
- Remote CLI and interactive SQL shell.
- Per-client database sessions.
- Transactions spanning multiple HTTP requests.
- Exclusive transaction affinity for AsaDB's current one-writer model.
- Waitress request thread pool.
- Persistent background job metadata and thread-pool execution.
- NDJSON streaming for large SELECT results.
- Explicit-primary cluster topology with read replicas.
- Asynchronous `.asb` snapshot replication.
- Python file-based full-text-search sidecar.
- Admin page for databases, users/RBAC, nodes, workers, jobs, audit, and
  mutable configuration.
- systemd, Nginx, Docker, Compose, Linux and Windows setup examples.
- Tests for the file control plane and stateful orchestration.

## Compatibility with the current AsaDB repository

The integration launches the same command used by the repository's panel
launcher:

```bash
swipl -q -s src/asadb_web.pl -- DATABASE.asa PORT
```

For each registered physical `.asa` file, Flask supervises one private
localhost AsAPanel backend. It performs the official `asadb_token` handshake
and forwards the existing endpoints:

```text
/api/query
/api/analyze
/api/state
/api/catalog
/api/metadata
/api/save
/api/backup
/api/export
/api/import_upload
/api/reservoir/*
```

As a result, the server reuses the repository's backend-owned backup,
transactional restore, Reservoir queue, import/export, result paging, and
TVCC behavior instead of creating incompatible Python copies.

The opt-in integration test `tests/test_engine_integration.py` covers the
actual Flask → `asadb_web.pl` → `.asa` chain, including authenticated AsAPanel
delivery and a proxied SQL request. Run it in an environment with the Python
dependencies and SWI-Prolog installed:

```bash
ASADB_REPO_ROOT="$(cd .. && pwd)" ASADB_RUN_REAL_TESTS=1 pytest -q
```

## One login-first portal, two workspace contexts

For browser use, start one AsaDB portal. On the first run it creates the
offline Python runtime, securely prompts for the first administrator, registers
the database file, then opens `/login`. After authentication the browser picks
its workspace; the same AsAPanel, API proxy, and official SWI-Prolog backend
remain in use.

```bash
swipl asadb
```

This is the normal installed-pack entry point on Linux and Windows with
SWI-Prolog 9.1.18 or newer. It uses the bundled offline wheelhouse; users do
not create a virtual environment or run `pip install`. `scripts/run_panel.sh
data.asa 8088` and `scripts\\run_panel.bat data.asa 8088` remain source-release
wrappers for users who have not installed the local pack.

Local Workspace is shown only to a loopback browser when
`ASADB_ALLOW_LOCAL_ONLY=true`; it is still authenticated. This avoids an
accidental login bypass if a server is later exposed to a network.

## Direct local mode for advanced CLI users

### Local mode

This preserves the repository's original behavior and requires no Flask
server. It is an explicit terminal/development route; `swipl asadb` is the one
browser command for normal use:

```bash
swipl asadb local --database data.asa
```

Data flow:

```text
Original CLI
        |
        v
src/asadb.pl
        |
        v
AsaDB SWI-Prolog core
```

### Server workspace

```bash
swipl asadb start --database data.asa --host 127.0.0.1 --port 7879 --threads 8
```

Data flow:

```text
Browser / Python client / remote CLI / File API
                    |
                    v
            Flask public server
 Auth · RBAC · sessions · cluster · jobs · FTS · admin
                    |
                    v
       private official asadb_web.pl backend
                    |
                    v
            AsaDB SWI-Prolog core
```

## Installation

### Installed AsaDB pack: recommended

Install AsaDB once, then use the bundled pack application. This is the same on
Linux and Windows once `swipl` is on `PATH`.

```bash
swipl pack install asadb
swipl asadb
```

The first start securely prompts for the admin password, creates state below
the platform user-data directory, registers the first `.asa` file, and opens
the login page. Subsequent `start` invocations do not ask for the administrator
again.

The bundled wheelhouse supports CPython 3.10–3.13 on Linux x86_64 and Windows
x64. macOS Server Mode is not release-tested yet; Local Mode remains portable
where SWI-Prolog is supported.

### Source checkout: developer workflow

From the AsaDB repository root, only for development or contributing:

```bash
cd flaskserver
python3 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
```

For a source checkout, the server automatically finds the adjacent AsaDB
`src/` and `web/` directories whether it is started from the repository root
or from `flaskserver/`. Set `ASADB_REPO_ROOT` explicitly for a packaged or
service deployment.

Windows PowerShell:

```powershell
cd flaskserver
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
```

Copy and edit configuration:

```bash
cp .env.example .env
```

The package does not automatically parse `.env`. Export it using your service
manager, shell, Docker Compose, or a tool such as `set -a; . ./.env; set +a`.

For a checkout using the layout above:

```bash
export ASADB_REPO_ROOT="$(cd .. && pwd)"
export ASADB_DATA_DIR="$PWD/var/databases"
export ASADB_STATE_DIR="$PWD/var/server-state"
export ASADB_TEMP_DIR="$PWD/var/tmp"
export ASADB_SECRET_KEY="$(python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export ASADB_CLUSTER_KEY="$(python -c 'import secrets; print(secrets.token_urlsafe(48))')"
```

Validate:

```bash
swipl asadb doctor
```

## Initialize an administrator and first database file manually (optional)

```bash
swipl asadb init \
  --username admin \
  --database-id main \
  --filename data.asa
```

The password is requested without echo. It is stored as a Werkzeug scrypt
password hash, not plaintext.

Start an initialized service without the one-command wizard:

```bash
swipl asadb server --host 127.0.0.1 --port 7879 --threads 8
```

The equivalent command before installing the console script is:

```bash
python -m asadb_server server --host 127.0.0.1 --port 7879 --threads 8
```

Open:

```text
http://127.0.0.1:7879/login
```

After login and workspace selection:

- `/` is the existing AsAPanel in server mode.
- `/admin` is the Flask server administration page.
- `/api/v1/*` is the authenticated server API.

## Remote CLI

Login and save a local profile:

```bash
asadb remote login \
  --url https://db.example.com \
  --username admin \
  --profile production
```

List physical database files:

```bash
asadb remote databases --profile production
```

Query:

```bash
asadb remote query main "SHOW DATABASES;" --profile production
```

Interactive shell:

```bash
asadb remote shell main --profile production
```

Backup, restore, and durable Reservoir upload:

```bash
asadb remote backup main app ./app.asb --profile production
asadb remote restore main ./app.asb --profile production

asadb remote reservoir submit main ./bulk.sql \
  --logical-database app \
  --idempotency-key bulk-2026-08-04 \
  --profile production
```

Large-result NDJSON:

```bash
asadb remote stream main \
  "SELECT * FROM production ORDER BY id;" \
  --logical-database migas \
  --page-size 500 \
  --profile production
```

## Physical file vs logical database

`databaseId` identifies a registered physical `.asa` file. `logicalDatabase`
identifies a SQL database inside that file.

For stable multi-client behavior:

- streaming requires `logicalDatabase`;
- FTS definitions require `logicalDatabase`;
- remote transaction sessions require `logicalDatabase`;
- stateless administrative SQL such as `SHOW DATABASES` may omit it;
- stateless table queries should pass it or include an explicit `USE` in the
  same SQL request.

AsAPanel server mode tracks the selected logical database per browser session
and applies a protected backend context around its existing API calls.

## Transactions across requests

Create a client session:

```bash
asadb remote session create main --logical-database app
```

Use the returned session ID:

```bash
asadb remote session begin SESSION_ID
asadb remote session query SESSION_ID \
  "UPDATE accounts SET balance = balance - 10 WHERE id = 1;"
asadb remote session query SESSION_ID \
  "UPDATE accounts SET balance = balance + 10 WHERE id = 2;"
asadb remote session commit SESSION_ID
```

A transaction owns an exclusive lease for its physical `.asa` file. Requests
from other clients are rejected with `423 DATABASE_TRANSACTION_BUSY` until
commit, rollback, close, expiry, or server recovery. This is deliberately
conservative because AsaDB currently has one writer and transaction state is
owned by one Prolog backend process.

An active transaction is **not** claimed to survive a Flask or Prolog process
restart. Persisted session records are marked `aborted_on_server_restart`.

## Python remote client

```python
from asadb_server.client import AsaDBClient

client = AsaDBClient("https://db.example.com")
client.login("admin", "correct horse battery staple")

result = client.query(
    "main",
    "SELECT * FROM wells LIMIT 100;",
    logical_database="migas",
)
print(result)
```

Transaction session:

```python
session = client.create_session("main", "app")["session"]
session_id = session["id"]

client.begin(session_id)
try:
    client.query("_", "UPDATE counters SET value = value + 1;", session_id=session_id)
    client.commit(session_id)
except Exception:
    client.rollback(session_id)
    raise
```

## REST API highlights

Authentication:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

Users and roles:

```text
GET    /api/v1/roles
GET    /api/v1/users
POST   /api/v1/users
PATCH  /api/v1/users/{id}
DELETE /api/v1/users/{id}
```

Database files:

```text
GET    /api/v1/databases
POST   /api/v1/databases
GET    /api/v1/databases/{id}
PATCH  /api/v1/databases/{id}
DELETE /api/v1/databases/{id}
POST   /api/v1/databases/{id}/query
POST   /api/v1/databases/{id}/stream
POST   /api/v1/databases/{id}/analyze
GET    /api/v1/databases/{id}/metadata
GET    /api/v1/databases/{id}/catalog
POST   /api/v1/databases/{id}/backup
POST   /api/v1/databases/{id}/restore
POST   /api/v1/databases/{id}/reservoir
GET    /api/v1/databases/{id}/reservoir/jobs/{job}
GET    /api/v1/databases/{id}/reservoir/jobs/{job}/result
POST   /api/v1/databases/{id}/reservoir/jobs/{job}/cancel
GET    /api/v1/databases/{id}/reservoir/stats
POST   /api/v1/databases/{id}/save
POST   /api/v1/databases/{id}/restart
```

Sessions:

```text
POST   /api/v1/sessions
GET    /api/v1/sessions
POST   /api/v1/sessions/{id}/begin
POST   /api/v1/sessions/{id}/query
POST   /api/v1/sessions/{id}/commit
POST   /api/v1/sessions/{id}/rollback
DELETE /api/v1/sessions/{id}
```

Jobs:

```text
POST /api/v1/jobs/query
GET  /api/v1/jobs
GET  /api/v1/jobs/{id}
POST /api/v1/jobs/{id}/cancel
```

FTS:

```text
GET  /api/v1/fts
POST /api/v1/fts
POST /api/v1/fts/{database}/{index}/rebuild
GET  /api/v1/fts/{database}/{index}/search?q=...
```

Cluster and replication:

```text
GET    /api/v1/cluster/nodes
POST   /api/v1/cluster/nodes
POST   /api/v1/cluster/nodes/{id}/heartbeat
DELETE /api/v1/cluster/nodes/{id}
POST   /api/v1/replication/{database}
```

## File-Based API

Directories:

```text
server-state/file-api/
├── inbox/
├── processing/
└── outbox/
```

Submit:

```bash
asadb file-api submit query --payload '{
  "auth": {"username": "admin", "password": "replace-me"},
  "databaseId": "main",
  "sql": "SHOW DATABASES;"
}'
```

Wait for its response:

```bash
asadb file-api wait FILE_REQUEST_ID
```

For automation, prefer `auth.token` over embedding a username and password in
the request file. Protect the directory with operating-system permissions.
Requests and responses are JSON files, so do not put secrets there on a
world-readable filesystem.

## Large result streaming

`POST /api/v1/databases/{id}/stream` returns
`application/x-ndjson`. Each line is a complete result page:

```json
{"databaseId":"main","page":0,"offset":0,"columns":["id"],"rows":[[1]],"hasMore":true}
```

The server repeatedly calls AsaDB's existing paged query API. It does not
materialize the complete result in Flask memory.

## Jobs and progress

Flask background jobs use a bounded `ThreadPoolExecutor`. Job metadata and
progress are atomically persisted under `server-state/jobs/`. Interrupted jobs
are marked rather than silently replayed.

The existing Prolog Reservoir remains authoritative for large SQL/import jobs
submitted through AsAPanel. Flask jobs are an orchestration layer for remote
queries, FTS builds, replication, and future administrative workflows.

## Full-text search

FTS is a Python sidecar, not a replacement for AsaDB SQL:

1. Define an index with a source `SELECT`, ID column, and text columns.
2. Submit a rebuild job.
3. Search the gzip-compressed inverted index.

Example:

```bash
curl -X POST https://db.example.com/api/v1/fts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "databaseId":"main",
    "name":"articles",
    "sourceSql":"USE app; SELECT id, title, body FROM articles ORDER BY id;",
    "idColumn":"id",
    "textColumns":["title","body"]
  }'
```

Rebuilds are eventually consistent. AsaDB remains the source of truth.

## Cluster and replication model

The cluster model takes inspiration from SiriDB's explicit servers, pools, and
replicas but respects AsaDB's present engine:

- Every physical database file has exactly one configured primary node.
- Zero or more nodes may be configured as read replicas.
- Writes and transaction sessions are routed to the primary.
- A ready local replica may serve reads.
- Replication creates an official backend-owned `.asb` backup, uploads it to a
  replica, and restores it transactionally.
- Replication is asynchronous snapshot replication.
- Optional scheduled snapshots use `replicationLogicalDatabase` plus
  `ASADB_REPLICATION_INTERVAL_SECONDS`.

This version does **not** claim:

- active-active writes;
- consensus;
- automatic leader election;
- synchronous quorum commits;
- cross-file distributed transactions;
- automatic data sharding across pools.

The `pool` field is topology metadata for future shard routing, not a claim that
the current SQL planner automatically distributes one query across files.

## Production deployment

Keep Flask bound to localhost and terminate TLS at Nginx:

```bash
swipl asadb server --host 127.0.0.1 --port 7879 --threads 8
```

Use the included:

```text
deploy/asadb-flask.service
deploy/nginx.conf.example
deploy/Dockerfile
deploy/compose.yaml
```

Run one Flask process per state/data directory. Waitress threads provide HTTP
concurrency. Multiple WSGI processes would each create competing Prolog
backends unless a future separate backend-daemon lock manager is introduced.

## Testing

```bash
python -m pip install -e ".[dev]"
pytest
```

Real repository integration tests are opt-in:

```bash
ASADB_RUN_REAL_TESTS=1 pytest -m integration
```

## Important limitations

Read `docs/LIMITATIONS.md` before production exposure. The biggest boundaries
are:

- snapshot, not synchronous, replication;
- no automatic cluster failover;
- transaction state does not survive process restart;
- FTS is eventually consistent;
- File API is same-host filesystem IPC, not a network protocol;
- one public Flask process per data/state directory;
- internet exposure requires TLS, firewalling, secure secrets, backups, and
  operational testing.

## License

This module is intended to be distributed with AsaDB under
**GNU GPL v3.0 only**. Keep the repository's complete `LICENSE` and copyright
notices when merging this folder into the project.
