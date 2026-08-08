# Changelog

## 1.5.0

- Align the Flask server package, CLI, and health response with AsaDB Core
  1.5.0.
- Reuse the supervised internal HTTP session for the official Prolog backend.
- Serialize requests per physical backend so a selected logical database does
  not leak between Flask clients.
- Escape the authenticated server-mode panel banner values before rendering.
- Resolve the adjacent AsaDB checkout independent of the current directory,
  and support `python -m asadb_server` as an installation-free entry point.
- Ship the server as part of the AsaDB pack application: `swipl asadb` creates
  the offline gateway on first use and opens the authenticated portal without
  a user-managed Python environment.

## 0.1.0

- Rebased the integration on the official `src/asadb_web.pl` backend.
- Added username/password authentication and bearer tokens.
- Added file-based RBAC and control-plane persistence.
- Added authenticated AsAPanel hosting and server admin page.
- Added local and server CLI modes.
- Added Python remote client and remote CLI profiles.
- Added logical-database affinity per client.
- Added cross-request transaction sessions.
- Added Waitress and administrative thread pools.
- Added NDJSON result streaming.
- Added Flask job queue plus official Reservoir proxy endpoints.
- Added explicit-primary cluster records and node heartbeats.
- Added streaming `.asb` snapshot replication.
- Added scheduled snapshot orchestration.
- Added Python sidecar full-text search.
- Added literal inbox/outbox File-Based API.
- Added deployment files, examples, tests, and operational documentation.
