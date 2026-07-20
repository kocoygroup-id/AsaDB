# AsaDB

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Release: 1.3.1 Release Candidate](https://img.shields.io/badge/release-1.3.1%20Release%20Candidate-e0a400.svg)](RELEASE_NOTES.md)
[![Runtime: SWI-Prolog](https://img.shields.io/badge/runtime-SWI--Prolog-E61B23.svg)](https://www.swi-prolog.org/)

AsaDB is a local SQL database experiment powered by SWI-Prolog. It ships with
AsAPanel, a small local web workspace for creating databases, running SQL,
importing/exporting data, and inspecting tables without a cloud server.

Current release: **v1.3.1 Release Candidate**. The publication artifact
`AsaDB-1.3.1-linux-x86_64.tar.Z` is a complete open-source distribution
validated for Linux x86_64. It does not bundle SWI-Prolog; see
[RELEASE.md](RELEASE.md) and [COMPATIBILITY.md](COMPATIBILITY.md).

AsaDB is developed in the open under **GNU GPL v3.0 only**. Bug reports, test
cases, documentation, storage-engine review, and code contributions are
welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and the
[project governance guide](GOVERNANCE.md).

## What Makes It Different

- Prolog-backed SQL parser, executor, catalog, and storage.
- Local `.asa` database files with journal-style persistence.
- A durable Reservoir bridge spools writes before the backend pulls bounded
  batches, preventing duplicate submissions and unbounded browser pressure.
- Windows source launchers run the same backend through an installed
  SWI-Prolog; the separately embedded portable executable is rebuilt on Windows.
- AsAPanel runs on `127.0.0.1` and auto-selects a free port.
- Browser UI stays usable for big SQL files by sending imports to the Prolog backend.
- Asa Process Guardian is an opt-in source-mirror and process-supervision tool;
  it is isolated from SQL execution and the database storage path.

## v1.3.1 Highlights

v1.3.1 adds editor guidance and removes a costly no-op execution path:

- The SQL editor offers lightweight schema-aware completion for AsaDB keywords,
  supported types and functions, local database/table/view names, declared
  aliases, and table columns. It uses the local catalog and no editor framework.
- SQL coloring recognizes the supported lexer surface consistently in the
  modern and Firefox-38-compatible bundles; ID, JP, and EN now share the same
  Noto Sans JP family for a consistent interface.
- `ORDER BY *` keeps its established no-op meaning without materializing and
  sorting every matching row, so a bounded result query can stop at its result
  window. Semicolon diagnostics are invalidated immediately while a query is
  being edited, preventing stale "missing ;" feedback.
- Asa Process Guardian provides an opt-in, SQL-isolated SHA-256 source mirror
  and bounded process supervision for operators who want launcher health and
  recovery records.
- The release set now includes a checksummed Windows source-launcher ZIP with
  the same source revision and batch launchers for an installed SWI-Prolog.

## 1.3.1 Package Contents

Every 1.3.1 source package includes the SQL engine, page storage, B+Tree and
metadata layers, Reservoir bridge, AsAPanel modern and compatibility bundles,
ID/JP/EN assets, tests, build scripts, Linux/POSIX launchers, Windows batch
launchers, operational guardian, and GPL notices. The Linux and main-source
archives are gzip-compressed tar streams under `.tar.Z`; the Windows
source-launcher is a ZIP with its own SHA-256 file.

The Windows ZIP is a source/runtime-launcher package, not a relabelled native
executable: install SWI-Prolog first. The portable executable remains a
separate Windows-native build target.

## v1.3.0 Highlights

v1.3.0 fixes the aliased JOIN path and makes the source release practical on
Linux systems with minimal shells:

- Qualified aliases such as `field m` and `zone z` now resolve `m.No` and
  `z.No` correctly, including case-insensitive table and column identifiers.
- Qualified equality joins use an AVL-backed lookup index instead of comparing
  every left row with every right row. Two 15,000-row inputs no longer imply
  225 million candidate comparisons.
- `INNER JOIN`, `LEFT JOIN`, and `RIGHT JOIN` share the fast path for simple
  `alias.column = alias.column` conditions; complex predicates retain the
  compatible nested-loop fallback.
- Planner metadata exposes `indexed_joins` and `nested_loop_joins` counters.
- A 15,000 + 15,000 row regression reproduces the `field m` / `zone z` case,
  verifies the alias result, validates all 15,000 matches, and enforces a
  bounded join execution time.
- Linux launchers are POSIX `/bin/sh` scripts and have been syntax-checked with
  `dash`; the same syntax is suitable for BusyBox `sh` used by minimalist
  distributions such as 4MLinux.
- Runtime diagnostics, 4MLinux-specific install notes, source-release tooling,
  `.gitignore`, `.gitattributes`, and Linux GitHub Actions CI are included.
- The Linux package has a clean explicit manifest and a separately published
  `.sha256` file; runtime databases, logs, spools, and Windows binaries are not
  included.
- AsAPanel now switches its complete interface and Asa feedback between
  Indonesian (ID), Japanese (JP), and English (EN), with the selector alongside
  the Save and Delete database buttons and the preference kept in local browser
  storage.
- Long SQL paste keeps its caret and scroll viewport instead of snapping to the
  first line; large scripts retain virtualized line numbers.
- AsAPanel no longer holds every refresh behind a fixed 3.5-second warmup
  screen or sends a second browser-side warmup request. It shows a compact
  650 ms visual cue that never captures clicks or keyboard focus.
- The browser entry point loads a checked-in Firefox-38-compatible UI bundle
  with small API polyfills (including `NodeList.forEach` and `Element.append`),
  so an older DOM cannot leave a static panel with dead buttons.
- DROP TABLE is verified against the backend before the browser catalog is
  changed, while the core regression confirms catalog persistence plus physical
  heap and B+Tree cleanup after restart.
- Static UI localization, SQL syntax, persistence, storage, Reservoir, and the
  15,000-row JOIN path have dedicated regression coverage.

The source distribution requires a feature-complete SWI-Prolog on `PATH`.
4MLinux does not ship a general package manager, so its SWI-Prolog runtime must
be provided separately; this support is conditional until the included runtime
and regression checks pass on the target machine. See [INSTALL.md](INSTALL.md).

## Reservoir System

The v1.3.0 source tree includes `src/bridge/reservoir.pl`, a bounded and durable
adapter between AsAPanel and the SQL executor. It is not another database and
does not replace the page manager, buffer pool, transaction manager, or WAL.
It controls pressure at the JavaScript-to-Prolog boundary:

- write commands and large SQL payloads are spooled to disk in 256 KB chunks;
- admission limits both active jobs and reserved spool bytes;
- one worker serializes mutations through the existing execution mutex;
- idempotency keys plus SHA-256 fingerprints suppress safe retries;
- progress, cancellation, result paging, and queue statistics have dedicated
  localhost API endpoints;
- queued jobs survive restart, while interrupted in-flight writes are not
  replayed automatically because that could duplicate a partially committed
  command;
- job state is append-only and result publication uses temporary-file rename.

Small read-only queries still use the direct low-latency path. See
[docs/reservoir.md](docs/reservoir.md) for the state machine, failure model,
configuration, and API contract.

Historical changes and benchmark context are retained in
[RELEASE_NOTES.md](RELEASE_NOTES.md) and
[BENCHMARK_RESULTS.md](BENCHMARK_RESULTS.md). The v1.3.0 root causes, exact
fixes, validation, and remaining optimizer limits are summarized in
[BUGFIX_REPORT.txt](BUGFIX_REPORT.txt).

## Supported SQL Surface

Stable core:

- `CREATE DATABASE`, `DROP DATABASE`, `USE`
- `CREATE TABLE`, `DROP TABLE`, `TRUNCATE TABLE`
- `INSERT`, `SELECT`, `UPDATE`, `DELETE`
- `SHOW DATABASES`, `SHOW TABLES`, `SHOW INDEX`, `DESCRIBE`
- `ALTER TABLE` for add/drop/modify/change/rename column flows
- `ORDER BY`, `LIMIT`, `LIMIT offset,count`, `LIMIT count OFFSET offset`
- `WHERE` expressions, `LIKE`, `BETWEEN`, `IN`, `IS NULL`
- `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`
- `GROUP BY` with `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
- Basic subqueries: scalar, `IN (SELECT ...)`, `EXISTS`
- `UNION`, `CASE WHEN`, `CONCAT`
- `CREATE VIEW` and selecting from views
- Transaction commands: `BEGIN`, `START TRANSACTION`, `COMMIT`, `ROLLBACK`
- Basic user/grant catalog: `CREATE USER`, `GRANT`, `REVOKE`, `SHOW GRANTS`, `LOGIN`
- Metadata routines: `CREATE/DROP TRIGGER`, `CREATE/DROP PROCEDURE`, `CREATE/DROP FUNCTION`

User rows now live in persistent 4 KB slotted heap pages. Indexed equality,
range, and simple ordered scans use persistent B+Tree files with linked leaf
pages. The bounded buffer pool uses a Clock-style policy with pin/unpin and dirty
tracking. Recovery uses append undo records, page mutation backups, transaction
snapshots, and atomic catalog replacement. This is not yet MVCC or ARIES.

Runtime limits are configured in `asadb.conf`. Keep each `.asa` catalog together
with its matching `.asa.store` directory when moving a database.

## Running The Linux x86_64 Release

Verify and extract the publication files:

```sh
sha256sum -c AsaDB-1.3.1-linux-x86_64.tar.Z.sha256
tar -xzf AsaDB-1.3.1-linux-x86_64.tar.Z
cd AsaDB-1.3.1-linux-x86_64
./scripts/check_linux_runtime.sh
./scripts/run_panel.sh data.asa 8088
```

The `.tar.Z` file is gzip-compressed. `swipl` is a separate runtime dependency.

## Running The Portable Windows Release

Extract the release zip and run:

```powershell
AsaDB.exe
```

Optional:

```powershell
AsaDB.exe panel data\mydb.asa 8088
AsaDB.exe cli data\mydb.asa web\samples\feature-tour.sql
```

The panel URL is written to `asadb.port`.

## Running From Source

Install SWI-Prolog and make sure `swipl` is on `PATH`.

```powershell
swipl -q -s src\asadb_web.pl -- data.asa 8088
```

CLI:

```powershell
swipl -q -s src\asadb.pl -- data.asa examples\demo.sql
```

Tests:

```powershell
swipl -q -s tests\run_tests.pl
swipl -q -s tests\reservoir_tests.pl
swipl -q -s tests\join_15000_regression.pl
node tests\ui_regression.js
```

Storage benchmarks (10k, 50k, and 100k rows):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_storage_benchmarks.ps1
```

Build Windows portable folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows_exe.ps1
```

## Project Layout

```text
src/
  bridge/reservoir.pl  Durable bounded panel-to-engine job bridge
  asadb_core.pl      SQL parser, planner, executor, and catalog
  asadb_page_manager.pl  4 KB slotted-page format
  asadb_pager.pl     Disk page I/O
  asadb_buffer_pool.pl  Bounded page cache
  asadb_record_manager.pl  Heap records and mutation recovery
  asadb_btree.pl     In-memory compatibility tree and persistent B+Tree
  asadb_config.pl    Runtime storage configuration
  asadb_metadata.pl  Atomic persistent database identity and runtime metadata
  asadb_web.pl       Local HTTP API for AsAPanel
  asa_portable.pl    Portable EXE entrypoint
web/
  index.html
  assets/app.js
  assets/style.css
  samples/
tests/
  run_tests.pl
  reservoir_tests.pl
  join_15000_regression.pl
  ui_regression.js
  launcher_regression.sh
  release_package_regression.sh
  *.sql
stress tests/
  public_safety_archive_5500.sql
scripts/
  build_windows_exe.ps1
  build_linux_release.sh
  build_source_release.sh
  check_linux_runtime.sh
```

## Security

AsAPanel binds to localhost only and protects API calls with a per-run local
token cookie/header. It is meant for local development, not public hosting.

Please report security-sensitive findings through the private process in
[SECURITY.md](SECURITY.md), not through a public issue.

## Contributing

Contributions are accepted under GPL-3.0-only and require a Developer
Certificate of Origin sign-off. The sign-off confirms that you have the right
to submit the contribution; it does not transfer your copyright. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the complete workflow.

Good contribution areas include:

- SQL parser and compatibility tests;
- page, buffer-pool, B+Tree, and recovery correctness;
- bounded-memory execution and import performance;
- Windows packaging and Linux/macOS validation;
- documentation, examples, accessibility, and localization.

## License

AsaDB source code and project-owned assets in this repository are licensed
under the **GNU General Public License version 3 only** (`GPL-3.0-only`). See
[LICENSE](LICENSE).

Distributing an AsaDB binary or a modified build requires making the complete
corresponding source available under the same license. The license does not
grant rights to present a modified build as an official AsaDB release. See
[TRADEMARKS.md](TRADEMARKS.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
and [LICENSE_HISTORY.md](LICENSE_HISTORY.md).
