# Changelog

## Unreleased hardening

- Reader SQL authorization now fails closed: only one top-level SELECT is
  accepted without database.write; multi-statement bypasses are rejected.
- COMMIT and ROLLBACK now change session state only after the Prolog backend
  confirms success. Failed completion retains the lease with commit_failed or
  rollback_failed for explicit recovery.
- Added CI-gated offline wheelhouse, SWI-Prolog pack, and real Server Mode E2E
  coverage on Linux and Windows runners.
- `swipl asadb` now opens the authenticated panel in Server Workspace by
  default, so registered databases use the supervised Prolog backend instead
  of silently starting in the browser sandbox. Local Workspace remains an
  explicit authenticated switch.
- Server Workspace now fails closed when the Prolog health check or a backend
  request is unavailable: SQL, table creation, and browser imports report the
  backend error instead of mutating the browser sandbox.

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
