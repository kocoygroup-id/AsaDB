# Architecture

## Goal

Expose the current local-first AsaDB repository as a Python/Flask server without
forking its SQL or storage behavior.

## Process topology

```text
Waitress / Flask process
├── auth and file-based RBAC
├── physical database registry
├── session/transaction leases
├── thread-pool job queue
├── cluster topology
├── replication coordinator
├── Python FTS sidecars
├── File API watcher
└── BackendManager
    ├── data-a.asa -> private src/asadb_web.pl :18088
    ├── data-b.asa -> private src/asadb_web.pl :18089
    └── ...
```

Each private backend:

- binds only to `127.0.0.1`;
- issues its normal random `asadb_token`;
- loads the normal AsaDB core;
- initializes the normal Reservoir;
- serves the normal AsAPanel API;
- owns the physical file and storage directory.

Flask captures the internal token and uses it only for loopback requests.

## Why proxy the existing panel backend

The repository already has production-critical behavior in `asadb_web.pl`:

- TVCC-aware query routing;
- one-writer mutex behavior;
- import stream parsing;
- Reservoir submission and progress;
- production backup and verified restore;
- portable exports;
- result paging;
- exact JSON serialization expected by AsAPanel.

Reimplementing those paths in Python would create two database products with
different behavior. Proxying them preserves one authoritative backend.

## Concurrency

There are two independent pools:

1. Waitress request threads.
2. Flask administrative background-job threads.

The Prolog backend remains responsible for engine concurrency. Read-only
eligible requests may use TVCC snapshots. Writes and explicit transactions
retain the backend's one-writer semantics.

## Transaction sessions

HTTP sessions are mapped to file records. Beginning a transaction:

1. verifies the caller;
2. acquires the physical database transaction lease;
3. sends `BEGIN;` to the selected backend;
4. marks the client session active.

All other public queries to that physical database are rejected while the lease
is held. This avoids leaking global transaction-local state to another client.

## File control plane

Control-plane objects are small JSON documents stored with:

1. write to a unique temporary file;
2. flush and `fsync`;
3. atomic `os.replace`.

This favors inspectability and easy administration. It is not used to store
table rows.

## Cluster

The cluster stores node definitions and physical-file placement. The database
record names a primary node and replica nodes. The primary is the only write
authority. A read may use a local ready replica; otherwise the gateway forwards
to the primary.

## Replication

Replication is a background job:

1. primary requests the official `.asb` backup;
2. Flask streams it to a temporary file while hashing;
3. the target receives it through a cluster-key endpoint;
4. the target calls the official import/restore path;
5. replica metadata becomes ready.

## Full-text search

FTS is deliberately outside the storage engine:

```text
AsaDB SELECT pages -> Python tokenizer -> gzip JSON inverted index
```

It can be rebuilt and discarded. SQL data remains authoritative.
