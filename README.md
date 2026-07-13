# AsaDB

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Runtime: SWI-Prolog](https://img.shields.io/badge/runtime-SWI--Prolog-E61B23.svg)](https://www.swi-prolog.org/)

AsaDB is a local SQL database experiment powered by SWI-Prolog. It ships with
AsAPanel, a small local web workspace for creating databases, running SQL,
importing/exporting data, and inspecting tables without a cloud server.

Current release target: **v1.2.1 Windows portable**.

AsaDB is developed in the open under **GNU GPL v3.0 only**. Bug reports, test
cases, documentation, storage-engine review, and code contributions are
welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) and the
[project governance guide](GOVERNANCE.md).

## What Makes It Different

- Prolog-backed SQL parser, executor, catalog, and storage.
- Local `.asa` database files with journal-style persistence.
- One Windows launcher: `AsaDB.exe` starts the backend and panel together.
- AsAPanel runs on `127.0.0.1` and auto-selects a free port.
- Browser UI stays usable for big SQL files by sending imports to the Prolog backend.

## v1.2.1 Highlights

v1.2.1 is a storage-engine and data-safety release. Compared with v1.2.0:

- Fixed `DELETE ... WHERE ...` safety for small and large tables; a targeted
  delete no longer risks clearing unrelated rows.
- Made table and column matching case-insensitive for safer `ID`/`id` style
  queries.
- Prevented duplicate `ALTER TABLE ADD COLUMN` names from creating duplicate
  storage columns.
- Added boot-time cleanup for older `.asa` files that already contain duplicate
  columns or duplicate row keys.
- Kept inserted bare names such as `Denji` and `Kishibe` as text values instead
  of turning them into `NULL`.
- Moved user rows to versioned, fixed 4 KB slotted pages under `.asa.store`.
- Added persistent B+Tree equality/range indexes with linked leaf pages and a
  bounded external bulk builder.
- Added a configurable Clock buffer pool with pin/unpin, dirty tracking,
  protected eviction, and incremental flush.
- Added streaming file import, bounded batches, periodic heap cleanup, bounded
  result windows, and indexed ORDER/LIMIT iteration.
- Fixed one-click Run SQL, removed the full-state post-run refresh, and limited
  success/failure audio to one active channel.
- Validated 50,000 and 100,000-row workloads with a measured peak working set of
  about 230 MB on the test machine.
- Added regression tests for delete safety, duplicate column handling, and
  beginner-friendly bare identifier inserts.

## v1.2.0 Highlights

v1.2.0 is a UI polish release on top of the v1.0.2 stability base:

- Added random Run SQL sounds: four success variants and four failure variants.
- Replaced save/drop quick-action drawings with the provided PNG icons.
- Kept sound playback fail-safe so blocked audio cannot break SQL execution.
- Rebuilt the Windows package under `Public Release/v1.2.0`.

## v1.0.2 Stability Base

v1.0.2 is a stability and import release. Compared with v1.0.1:

- Added real backend multipart upload for Import > Choose File SQL imports.
- Large selected `.sql` files now stream through Prolog instead of being fully swallowed by browser memory.
- Fixed post-run refresh so sidebar/table catalog updates after backend execution more consistently.
- Added catalog regression coverage for multiple tables in one database.
- Fixed Windows backslash database paths and first-run journal creation inside subfolders.
- Revalidated `public_safety_archive_5500.sql`: 62 statements, 0 errors, 5,500 rows.
- Kept `ORDER BY` stable when duplicate sort values exist.
- Kept numeric text comparisons natural for values such as `'100'`, `'90'`, and `50`.

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
  asadb_core.pl      SQL parser, planner, executor, and catalog
  asadb_page_manager.pl  4 KB slotted-page format
  asadb_pager.pl     Disk page I/O
  asadb_buffer_pool.pl  Bounded page cache
  asadb_record_manager.pl  Heap records and mutation recovery
  asadb_btree.pl     In-memory compatibility tree and persistent B+Tree
  asadb_config.pl    Runtime storage configuration
  asadb_web.pl       Local HTTP API for AsAPanel
  asa_portable.pl    Portable EXE entrypoint
web/
  index.html
  assets/app.js
  assets/style.css
  samples/
tests/
  run_tests.pl
  *.sql
Stress Test/
  public_safety_archive_5500.sql
scripts/
  build_windows_exe.ps1
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
