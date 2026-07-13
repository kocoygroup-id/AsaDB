# AsaDB v1.2.1 Release Notes

## Summary

AsaDB v1.2.1 is the largest storage, stability, and data-safety update since
v1.2.0. The Prolog parser and SQL surface remain compatible, while user-table
rows move to a versioned, disk-backed page store designed to keep memory bounded
on larger imports.

This release also fixes the Run SQL double-click delay, overlapping result
sounds, unsafe targeted deletes, and duplicate columns from repeated
`ALTER TABLE ADD COLUMN` statements.

## Major Changes From v1.2.0

### Disk-backed storage

- User-table rows are stored outside the catalog in fixed 4 KB heap pages.
- The small `.asa` file now stores catalog metadata; row pages live under the
  matching `.asa.store` directory.
- Storage format version 3 migrates compatible list-backed v2 tables on boot.
- Each slotted page stores page ID, page type, live-record count, free-space
  boundaries, slot directory, previous/next sibling pointers, and checksum.
- Typed binary records replace canonical Prolog row terms for normal user rows.
- Page scans keep one file stream open instead of reopening the heap file for
  every page.

### Persistent B+Tree indexes

- Indexed equality and range predicates use persistent B+Tree files.
- Leaf pages are linked through sibling pointers for range iteration.
- Indexed `ORDER BY ... LIMIT` reads rows in leaf order and stops at the result
  window instead of sorting the whole table.
- Index construction uses bounded external sorted runs. It no longer creates a
  single 100,000-entry Prolog list before writing the tree.
- Indexed deletes use stable RID tombstones so unrelated rows and existing
  index entries remain safe.
- Writes that cannot safely preserve an index invalidate it; the next indexed
  access rebuilds it from bounded disk runs.

### Buffer pool and page manager

- Configurable bounded page cache with a Clock-style replacement policy.
- Pin/unpin protection prevents an in-use page from being evicted.
- Dirty-page tracking and incremental flushing are enabled.
- Cache statistics expose hits, misses, evictions, dirty pages, pinned pages,
  logical cached bytes, and configured limits.
- Default pool is 64 pages. This is intentionally conservative because a byte
  list in SWI-Prolog has more runtime overhead than its 4 KB disk payload.

### Import and execution pipeline

- Backend SQL import reads 256 KB blocks and executes bounded statement batches.
- Multipart Choose File imports now keep diagnostic timing on the server log so
  the HTTP JSON response cannot be corrupted by debug output.
- Upload error serialization is defined and returns the original failure instead
  of masking it with an HTTP handler exception.
- Import batches periodically run Prolog garbage collection and stack trimming,
  preventing retained parse trees from growing with the complete file.
- Every import runs inside a transaction and reports statement/error progress.
- Multi-row INSERT remains supported from SQL command, uploaded files, and
  server-side files.
- Simple aggregate scans use incremental accumulators.
- Ordered top-N fallback uses bounded chunks instead of retaining every row.
- Web query results are capped by `max_result_rows` and rendered incrementally.

### Integrity and recovery

- Catalog checkpoints use temporary and backup files before replacement.
- Append operations keep an undo record containing the original file size and
  last page.
- UPDATE/DELETE page mutations use transaction snapshots or mutation backups.
- Startup recovery handles interrupted append, mutation, checkpoint, and open
  transaction artifacts.
- A failed import batch rolls back the import transaction instead of accepting a
  partially parsed file.

### Run SQL and AsAPanel

- One click now starts exactly one backend request.
- Rapid repeated clicks reuse the in-flight promise and cannot duplicate writes.
- The Run button is locked only for the active execution and lightweight catalog
  refresh; it no longer downloads the full database state after every command.
- Previous success/failure audio is stopped before a new run.
- Muted audio priming never blocks query execution.
- Success and failure effects share one active channel, preventing stacked sound.
- Large result rendering uses a document fragment and bounded row count.

### SQL correctness fixes

- Fixed targeted `DELETE ... WHERE ID = value` on small and large tables.
- Column and table matching is case-insensitive for `ID`, `id`, and mixed case.
- Repeating `ALTER TABLE ADD COLUMN` with the same name no longer creates a
  duplicate physical column.
- Legacy duplicate columns/row keys are normalized during migration.
- Bare beginner-style INSERT values such as `Denji` remain text instead of
  silently becoming `NULL`.
- Stable sort order preserves duplicate rows with equal sort keys.

## Runtime Configuration

The portable package includes `asadb.conf`:

```ini
page_size = 4096
buffer_pool_pages = 64
import_batch_size = 8
flush_interval = 32
max_result_rows = 500
cache_policy = clock
```

`page_size` is fixed at 4096 for format compatibility. Other values are loaded
at boot and can be tuned without rebuilding the executable.

## Measured Benchmarks

Environment: Windows, SWI-Prolog, release source tree, generated three-column
rows in 100-row multi-value INSERT statements. Peak working set includes the
SWI-Prolog runtime, parser, index builder, page cache, and test process.

| Workload | Result | Import | First indexed lookup including build | Indexed ORDER/LIMIT | UPDATE | DELETE | 500-row result | Peak RAM |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 10,000 rows | PASS | 7.1 s | 6.1 s | 80 ms | 144 ms | 109 ms | 804 ms | not separately sampled |
| 50,000 rows | PASS | 34.7 s | 31.6 s | 46 ms | 234 ms | 213 ms | 948 ms | 229.9 MB |
| 100,000 rows | PASS | 73.9 s | 76.1 s | 19 ms | 519 ms | 401 ms | 654 ms | 229.8 MB |

The 100,000-row test also shuts down, reopens the database, verifies the row
count after UPDATE/DELETE, and validates recovery-visible state. Peak RAM stayed
flat between 50,000 and 100,000 rows in the measured runs.

Earlier v1.2.1 prototype baseline for the same 100,000-row scenario used about
820 MB and took almost 11 minutes. The final path completed in about 247 seconds
with a 229.8 MB peak working set.

Run the benchmark suite with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_storage_benchmarks.ps1
```

## Validation

Regression suite:

```powershell
swipl -q -s tests\run_tests.pl
```

Coverage includes CREATE/INSERT/SELECT/UPDATE/DELETE, ALTER, transactions,
JOINs, GROUP BY and aggregates, subqueries, views, users/grants, delete safety,
duplicate-column handling, persistence, bounded results, and recovery.

Browser-level Run SQL validation measured:

- two rapid clicks: one `/api/query` request;
- next single run: one additional request;
- empty-table backend query: 7 ms in the measured run;
- result/UI cycle after warmup: about 146 ms;
- maximum concurrent result sounds: one;
- Run button enabled again after completion.

## Compatibility And Migration

- Existing SQL commands remain available.
- Compatible v2 user tables migrate to v3 page storage on boot and are saved on
  the next checkpoint.
- Keep the `.asa` file and its `.asa.store` directory together when copying or
  backing up a database.
- Before upgrading important data, retain a backup of the v1.2.0 database.

## Known Limits

- AsaDB is not benchmark-equivalent to CouchDB, PostgreSQL, or MySQL.
- B+Tree creation is persistent and bounded-memory, but some writes currently
  invalidate and lazily rebuild affected index files instead of performing a
  fully incremental split/merge operation.
- Recovery uses undo files, backups, atomic replacement, and the existing
  journal; it is not an ARIES implementation and does not provide MVCC.
- Complex JOIN, GROUP BY, and expression plans may still materialize more data
  than simple indexed queries.
- The local panel is intended for localhost use, not direct public exposure.

## License

This source distribution is licensed under GNU GPL v3.0 only. Distributors of
binaries or modified builds must provide the complete corresponding source
under the same license. Historical copies released under earlier terms retain
the terms that accompanied those copies. See `LICENSE`, `LICENSE_HISTORY.md`,
`TRADEMARKS.md`, and `THIRD_PARTY_NOTICES.md`.
