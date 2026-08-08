# Validation report

## Distribution validation

- Python source is compile-checked before packaging.
- The pack regression installs a detached AsaDB copy, creates a fresh
  per-user Python runtime using only `flaskserver/wheels/`, then runs the
  launcher doctor. No Python package index is used.
- The real integration test covers Flask → `asadb_web.pl` → `.asa`, login,
  authenticated panel delivery, and proxied SQL.
- Wheelhouse targets: CPython 3.10–3.13 on Linux x86_64 and Windows x64.

## Covered by executed tests

- atomic JSON state files;
- filesystem lease exclusion;
- safe physical database registry;
- logical-database client affinity;
- transactions spanning requests;
- exclusive transaction ownership;
- rollback during session close;
- thread-pool job status and progress;
- File-Based API inbox/outbox;
- same-host Python File API client;
- FTS build and search;
- streaming multipart length;
- Requests preparation with `Content-Length` and without chunked transfer;
- remote-client normalization.

## Running the complete validation

Run the final acceptance test from a complete repository checkout:

```bash
make test-pack
ASADB_HOME="$(mktemp -d)/asadb" \
  swipl -q -s tools/asadb_launcher.pl -- doctor --repair --json

# Developer-only test route; the installed-pack route above needs no pip.
cd flaskserver && python -m pytest -q
ASADB_RUN_REAL_TESTS=1 python -m pytest -q tests/test_engine_integration.py
```

## Compatibility target

The integration targets the current repository contracts:

```text
src/asadb_web.pl
src/asadb.pl
src/asadb_core.pl
src/asadb_backup.pl
src/bridge/reservoir.pl
web/index.html
web/assets/
```

The release engineer should execute the integration test against the exact commit intended
for release, especially after changing API routes or result JSON shapes.
