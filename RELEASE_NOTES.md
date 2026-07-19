# AsaDB v1.3.0 Release Notes

Released: 2026-07-19
Status: **STABLE**

Publication summary: [RELEASE.md](RELEASE.md)  
Compatibility matrix: [COMPATIBILITY.md](COMPATIBILITY.md)

## 1.3.0 cumulative release validation

This is a maintenance and stability release carried forward from v1.2.1 with
no SQL feature-surface break. The cumulative package fixes the Reservoir live
metadata/reload/cancel path, removes the 500-row table/result ceiling, keeps
large SQL gutters populated, adds the single-worker `karyawan.pl` adviser, and
reduces stress-import overhead with bounded batching. The final package set was
validated on 4MLinux 51.2 (Linux 6.12.94, Intel Core i5-6300U, 8 GB RAM).
Linux and source archives were checksum-verified and the Windows portable
archive was rebuilt from the same sources and smoke-tested under Wine.

## v1.2.1 -> v1.3.0 capability jump

The GitHub AsaDB v1.2.1 line is the comparison baseline; no intermediate
release is being claimed. AsaDB 1.3.0 keeps the v1.2.1 SQL/storage contract
while adding the operational pieces needed for large, interactive workloads:

| Area | v1.2.1 baseline | v1.3.0 release strength |
| --- | --- | --- |
| Large imports | Multi-minute scripts and bounded batching | Reservoir admission, live progress, rollback/cancel, 256-statement parsing, and bounded storage appends |
| Reservoir | No durable live-job recovery path | Single-worker queue, spool safety, idempotency, reload recovery, adaptive metadata polling, and Windows-safe cancellation |
| Karyawan | Not present | Pure-Prolog ingress/egress adviser for chunk sizing, pressure, health, and result-page bounds; no R runtime |
| SQL editor | Large paste could lose gutter/scroll state | Virtualized gutter, caret/scroll preservation, legacy Firefox-compatible loader, and full paste visibility |
| Results/catalog | Practical 500-row display ceiling | Paged SQL results, table previews, searchable Show-more table chooser, and metadata-backed COUNT |
| JOIN execution | Qualified JOINs could materialize too much or fall back to quadratic work | AVL equality JOINs plus source predicate pushdown and unique-key lookup for filtered 250k-row joins |
| Release portability | Linux/source workflow only | Linux x86_64 tar.Z, Win32 portable ZIP, main-repo tar.Z, each with SHA-256 and synchronized sources |

### Release-host stress audit

Measured on **4MLinux 6.12.94**, Intel Core i5-6300U @ 2.40 GHz, with
8,022,200 kB RAM visible. A clean 250,000-row audit completed with zero import
errors: the best interactive run reported by the maintainer was
`Double_Company.sql` **04:01.87** and `Double_Company_Status.sql` **00:31.60**;
the cold fresh rerun in this audit measured **06:58.32** and **01:03.45**.
The spread is recorded honestly because disk/cache and panel-vs-direct-stream
conditions materially affect a write-heavy import.

In both runs, the analysis view was created successfully, the filtered
qualified JOIN returned its 20 matching rows, and the view query returned its
20 rows. The maintainer's measured query windows were **83–89 ms** for view
creation, **122–138 ms** for the filtered JOIN, and **320–353 ms** for the
analysis-view SELECT; the cold direct audit measured **91 ms** and **852 ms**
for the two SELECTs.

The repeatable storage stress suite on the same host passed at every size:

| Rows | Wall time | Import | Indexed lookup | ORDER/LIMIT | Update | Delete | Limited result | Peak RSS |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10,000 | 4.59 s | 2.02 s | 1.60 s | 43 ms | 54 ms | 50 ms | 254 ms | 166.1 MiB |
| 50,000 | 33.00 s | 11.93 s | 19.15 s | 48 ms | 346 ms | 330 ms | 622 ms | 387.7 MiB |
| 100,000 | 59.21 s | 32.20 s | 24.31 s | 22 ms | 617 ms | 572 ms | 576 ms | 387.6 MiB |

Against the published v1.2.1 reference of approximately **247 s** for the
100,000-row full scenario, the current 4MLinux run is approximately **76%
faster wall-clock**. The reference was recorded on a different Windows host;
the comparison is directional, while the 1.3.0 numbers above are the actual
release-host measurements. Peak RSS is reported rather than marketed as an
improvement: this native 4MLinux run measured about 387.6 MiB.

## Table paging and Karyawan adviser

- Removed the panel's practical 500-row dead end. SQL command results expose a
  `Show more` action that requests the next ordered page from `/api/query`
  using a bounded `LIMIT/OFFSET` path, then appends rows without rerunning the
  first page. Multi-statement commands keep their existing result behavior.
- Table detail previews use the same page loader for large backend tables and
  views. Stale requests are ignored when the user switches tables, and the
  control is disabled while a page is in flight.
- The sidebar table chooser keeps its text filter and now renders a small
  `Show more tables` control at the end. Clicking it or reaching it during
  scrolling reveals another bounded slice, so a large catalog does not build a
  huge DOM all at once.
- Added `src/bridge/karyawan.pl`, a pure-Prolog helper. It advises ingress chunk size, queue
  pressure, backend health, and bounded egress page size while preserving the
  Reservoir's one-worker execution invariant. No R runtime is required.
- Added release/package coverage for the helper and page-aware frontend bytes;
  Linux, Windows portable, and main-repo archives are rebuilt from these
  current sources with separate SHA-256 manifests.

## Large SQL paste and stress-import audit

- Fixed the large-script line-number gutter. Its virtualized top/bottom
  padding now belongs to an inner content layer instead of the clipped gutter
  viewport; pasting thousands of lines no longer leaves the numbers above the
  visible area blank.
- Increased the default import parser batch to 256 statements and bounded
  record appends to 8,192 rows per storage pass. The larger parser batches
  reduce repeated execution overhead, while the storage chunk keeps generated
  `Double_Company` workloads below the Prolog stack limit.
- The allowed Linux stress-file resolver now accepts the checked-in
  `Double_Company.sql` casing even though request paths are normalized for
  safe comparison.

## Stable AsAPanel update

- Added a compact ID / JP / EN language switch alongside Save and Delete. It updates every
  static page, dynamic counters and status text, metadata, confirmations,
  results, diagnostics, execution logs, and Asa success/correction/error copy.
  The choice persists in local browser storage.
- Fixed large SQL paste scroll anchoring. The editor now retains the caret and
  viewport through highlight/gutter rerenders, uses a paste-specific restore,
  disables browser scroll anchoring, contains overscroll, and reserves stable
  scrollbar space.
- Hardened DROP TABLE and DROP DATABASE in AsAPanel: an error result no longer
  removes the item only from the browser sidebar, and a successful backend drop
  is verified with SHOW TABLES / SHOW DATABASES before local catalog removal.
- Added a core DROP TABLE regression that checks SHOW TABLES immediately and
  after restart, accepts repeated IF EXISTS, and confirms that the table heap
  and persistent B+Tree files were physically removed.
- Added dependency-free UI regression checks for duplicate IDs, complete
  three-language key coverage, the language controls, and long-paste scroll
  safeguards.
- Removed stale Windows-case `Test`/`Stress Test` filesystem references from
  the Linux import path. Historical `test/...` input is still accepted but is
  resolved to the canonical case-sensitive `stress tests` directory.
- Removed the fixed 3.5-second AsAPanel startup overlay and the duplicate
  browser-side warmup request. The overlay is now only a 650 ms visual cue and
  is explicitly non-interactive, so it cannot swallow clicks or keyboard focus.
- Added `app-loader.js` plus a checked-in Firefox-38-compatible
  `app.legacy.js` build. The loader adds the small needed polyfills and shows a
  direct diagnostic if the UI bundle cannot boot, instead of leaving a static
  panel whose buttons appear dead.
- Added missing old-Firefox DOM polyfills for `NodeList.forEach` and
  `Element.append`. Both are used while the panel first renders; without them,
  a pre-Firefox-50 browser stopped before attaching every button listener.
- Fixed a 4MLinux/C-locale HTTP 500 when loading `app.legacy.js`: static UI
  assets are read as UTF-8 and streamed once, so Japanese translations cannot
  fail or become double-encoded while the web server formats the response.
- Added a declared PNG favicon and a `/favicon.ico` fallback handler to remove
  the noisy 404 generated by older Firefox releases.
- Bundled Noto Sans JP under the SIL Open Font License 1.1 in WOFF2 and WOFF
  formats. JP now renders on minimal 4MLinux installs even when the operating
  system itself has no Japanese font package.

Stabilization validation completed on the available SWI-Prolog WASM and DOM
test runtimes: all 15 core assertion groups passed; DROP TABLE removed its
catalog entry plus heap/B+Tree files and stayed removed after restart; 165 UI
translation/runtime keys passed in all three languages; interactive language,
Asa output, 6,000-line paste, failed-drop preservation, and verified-drop
scenarios passed; and the 15,000 + 15,000 aliased JOIN returned all 15,000 rows
through the indexed path.

## Reservoir realtime, reload, and cancellation

- Added `GET /api/reservoir/jobs` for reload recovery. It returns only active
  `receiving`, `queued`, `processing`, and `cancelling` jobs, ordered by newest
  update first; retained terminal jobs remain available through the ID endpoint
  but are excluded from discovery.
- AsAPanel now persists the admitted job ID and a small display descriptor,
  resumes that exact job after reload, and falls back to active-job discovery
  when browser storage or the admission response is unavailable. Recovery
  resumes progress, result, and Cancel monitoring without resubmitting SQL.
- Fixed the Database metadata view so Reservoir status updates live through
  cache-bypassing, single-flight polling: 500 ms during an active job, 1.5
  seconds while the metadata panel is open, and 5 seconds while idle. Hidden
  documents skip network refreshes and refresh immediately on visibility or
  focus.
- Fixed cancellation racing an in-progress upload. The lifecycle is now
  `receiving -> cancelling -> cancelled`; the receiver closes its writer before
  spool deletion, the job never reaches `queued`, and terminal cancellation is
  idempotent. This removes reliance on POSIX unlink-while-open behavior and
  avoids the corresponding Windows open-file deletion failure.
- Reservoir regressions cover active-only newest-first discovery, moving live
  progress/statistics, receiving/queued/processing cancellation, single-count
  cancellation, and spool cleanup. UI regressions cover reload recovery,
  Cancel wiring, adaptive metadata polling, and matching modern/legacy bundles.
  Linux packaging compares the shipped backend/web bytes and statically checks
  that the Windows build uses the same sources and shared realtime preflight.

The Windows x86 portable executable was rebuilt from the same source tree and
validated under Wine with `--help` startup, live Reservoir progress, metadata
polling, active-job discovery, cancellation, and rollback checks. A native
Windows x64 build remains a separate optional target.

## JOIN correctness and performance

- Fixed qualified alias evaluation for queries such as:

  ```sql
  SELECT m.No, m.Depth, m.Water_Cut, z.Zone_Name
  FROM field m
  INNER JOIN zone z ON m.No = z.No
  ORDER BY m.No
  LIMIT 100;
  ```

- Replaced the quadratic nested-loop implementation for simple qualified
  equality joins with an AVL-backed lookup index. The old 15,000 by 15,000 case
  could evaluate 225,000,000 row pairs before filtering; the new path builds
  one lookup index and probes it once per row.
- Enabled the same optimized equality path for INNER, LEFT, and RIGHT joins.
- Pushed source-local `WHERE` conjuncts into paged JOIN inputs before rows are
  materialized. Small filtered left sides now probe a unique right key without
  forcing a fresh persistent index build, so the 250,000-row
  `Double_Company` + `Double_Company_Status` query with `LIMIT 20` remains
  bounded and responsive immediately after import.
- Kept view execution bounded by the existing result window when a view is
  selected with `ORDER BY ... LIMIT`, so a JOIN statement followed by the
  analysis-view statement returns both result sets instead of tripping the
  generic error path.
- Kept nested loops as a compatibility fallback for complex `ON` expressions.
- Added planner counters and the `tests/join_15000_regression.pl` performance
  and correctness regression, including a combined JOIN + VIEW multi-statement
  assertion.

## Linux and 4MLinux

- Replaced Bash-specific launchers with POSIX `/bin/sh` launchers.
- Added explicit runtime errors when `swipl` is unavailable.
- Added `scripts/check_linux_runtime.sh` and dedicated 4MLinux guidance.
- Added GitHub Actions coverage for core, Reservoir, JOIN, dash, and BusyBox
  shell checks.
- Added a Linux x86_64 release packager producing
  `AsaDB-1.3.0-linux-x86_64.tar.Z` plus
  `AsaDB-1.3.0-linux-x86_64.tar.Z.sha256`. The archive is a gzip-compressed tar
  stream retained under the requested `.tar.Z` filename.
- Added a package regression that verifies the checksum, archive root,
  executable modes, GPL source files, required engine/UI/tests, and absence of
  runtime databases, logs, spools, build output, and Windows executables.
- Added launcher regression coverage for quoted database/SQL paths containing
  spaces.
- Expanded the runtime probe to verify x86_64 Linux plus SWI-Prolog HTTP,
  crypto, UUID, thread, core, Reservoir, and web capabilities.

## Open-source release hygiene

- Versioned all runtime metadata as 1.3.0.
- Added Git attributes and ignores for runtime databases and build output.
- Fixed the Windows-only `Stress Test`/Linux `stress tests` case mismatch in
  benchmark, web import, and packaging paths, including the last stale server
  import alias.
- Source archives exclude database state, generated SQL, logs, and binary
  build output while retaining source, tests, documentation, license notices,
  and build scripts.

## Historical v1.2.1 baseline and lineage

## Reservoir system included in v1.3.0

The source includes a durable, bounded bridge between AsAPanel and the Prolog
executor. The historical v1.2.1 baseline below is retained for comparison.

### Boundary and reliability changes

- Added `src/bridge/reservoir.pl` with explicit receiving, queued, processing,
  cancelling, completed, delivered, failed, cancelled, and interrupted states.
- Write commands and SQL payloads above 250 KB use a disk spool and one backend
  worker. Small read-only queries retain the direct low-latency path.
- Input is copied in 256 KB chunks. Capacity is checked while bytes arrive, so
  an understated or absent size hint cannot bypass `reservoir_max_spool_bytes`.
- Queue admission and initial job persistence are atomic under one mutex,
  preventing concurrent requests from racing past the configured job limit.
- Idempotency keys and SHA-256 payload fingerprints return an existing safe job
  instead of executing a retry twice.
- Job snapshots use append-only event files; result publication uses a temporary
  file followed by rename.
- Queued jobs can resume after restart. A job interrupted while processing is
  marked `interrupted` and is not automatically replayed, avoiding accidental
  duplicate writes.
- Added polling, cancellation, statistics, and paged-result endpoints under
  `/api/reservoir/*`.
- AsAPanel reports active jobs, queued jobs, and spool bytes in database
  metadata.
- Run SQL remains single-flight from the first click, and its one shared audio
  channel cancels stale playback.

### Validation completed

- Core SQL regression suite: PASS.
- Reservoir lifecycle, paging, retry deduplication, cancellation, restart,
  queue backpressure, and false-size capacity tests: PASS.
- Real browser single-click test: one click produced one inserted row, the
  following read completed in 64 ms, and no JavaScript exception was recorded.
- HTTP retry test: the duplicate admission returned the same job and executed
  one write.
- `public_safety_archive_5500.sql`: 5,500 rows, 62 statements, zero errors,
  287,058 bytes, 15.132 seconds in that measured Reservoir run.
- Portable executable Reservoir test: a 3,116,915-byte SQL stream imported
  100,000 rows through 1,003 statements with zero errors in 48.628 seconds.
  Peak process working set was 196.5 MB, and a restart check returned the same
  100,000 persisted rows.

Detailed behavior and non-goals are documented in
[`docs/reservoir.md`](docs/reservoir.md).

## Summary

The v1.2.1 baseline was a panel-to-storage performance and persistence release. It
keeps the SQL surface introduced by earlier versions while removing the main
causes of multi-minute SQL Command runs: full DOM rendering of very large SQL,
thousands of sequential HTTP requests, repeated column resolution and record
copying, per-batch catalog checkpoints, and list-heavy page cache entries.

The release also adds persistent database metadata, an exact metadata-backed
`COUNT(*)` path, and stricter single-flight Run SQL/audio behavior.

## Root Causes Found

The delay was not one isolated function. It was the combined cost of several
layers:

1. AsAPanel created one line-number element for every line and attempted live
   highlighting/diagnostics for SQL files with tens of thousands of lines.
2. Large pasted write scripts could be split into many sequential requests,
   adding browser/backend synchronization overhead between statements.
3. Archive preview logic repeatedly rescanned the complete SQL editor value.
4. Multi-row INSERT repeatedly matched source columns for each value and copied
   record/page lists more than necessary.
5. A 4 KB page was cached as a 4,096-element Prolog integer list inside dynamic
   facts, which consumed far more heap than the 4 KB disk payload.
6. Catalog persistence and dirty-page flushing happened too often inside large
   transactional batches.
7. Unfiltered `COUNT(*)` scanned every record even though the catalog already
   maintained the exact row count.

That baseline addressed each layer instead of increasing the RAM limit; 1.3.0
extends the same discipline to Reservoir, JOIN planning, live metadata, and
cross-platform packaging.

## AsAPanel And HTTP Pipeline

- Large SQL mode starts at 180,000 characters or 4,000 lines.
- Large mode renders only the visible line-number window and leaves the
  syntax-highlight overlay empty.
- Live auto-correction, client diagnostics, and backend analysis are skipped for
  large scripts. Normal-sized SQL keeps the existing assistance.
- Large write scripts are sent as one `application/sql` Blob to
  `/api/execute_stream` rather than as thousands of sequential form requests.
- The stream endpoint accepts bounded request bodies up to 512 MB and reports
  progress through `/api/import_progress`.
- SQL Command and file import now share the same 256 KB incremental UTF-8
  reader, statement parser, transaction, bounded batch executor, and rollback
  behavior.
- The browser yields one animation frame after locking Run so the button paints
  `Running...` before backend work starts.
- Post-run catalog and metadata refresh happen in parallel and do not download
  the complete database state.
- Archive preview scans only a bounded tail of the editor instead of the whole
  script on every refresh.
- Web result rows remain bounded by `max_result_rows`.

## One-click Run And Audio

- Run SQL creates one in-flight promise before any asynchronous query work.
- The button is disabled synchronously on the first click.
- Repeated clicks while the request is active reuse the same promise and cannot
  duplicate INSERT, UPDATE, DELETE, or DDL execution.
- Success and failure sounds now use exactly one shared `Audio` element.
- A generation guard invalidates stale prime/play callbacks.
- Starting a run or a new result always pauses and rewinds the previous sound.
- Muted media priming remains non-blocking and cannot delay query execution.

## Storage And Execution Optimizations

- The Clock buffer pool stores page payloads internally as compact SWI-Prolog
  strings instead of integer lists in dynamic facts.
- Public pager interfaces still expose byte lists where required, preserving
  module compatibility.
- Clock hits no longer retract and re-assert an entry when its reference bit is
  already set.
- Pager page counts combine disk and dirty cached pages without forcing a full
  flush.
- Exact 4 KB pages bypass redundant padding/copy paths.
- Slotted-page checksum calculation traverses the page once instead of copying
  a second page with a zeroed checksum field.
- Batch record packing is linear rather than repeated append-based copying.
- INSERT builds one source-column map per batch instead of resolving every cell
  against every destination column.
- The core uses a no-RID-return batch insert path when callers do not consume
  inserted record identifiers.
- Transactional INSERT, UPDATE, and DELETE defer dirty-page flushing to bounded
  transaction/checkpoint boundaries. Rollback remains protected by snapshots
  and mutation recovery data.
- The historical baseline used an import batch of 8; 1.3.0 uses 256 parser
  statements with bounded storage appends while preserving rollback barriers.

## Exact COUNT Fast Path

`SELECT COUNT(*) FROM table` without a filter, grouping, or extra projection
now reads the exact row count stored in `paged_rows` catalog metadata. This
path:

- preserves the requested output alias;
- respects `LIMIT 0` semantics;
- requires normal SELECT privilege;
- records a `metadata_count_scan` planner statistic;
- does not open every heap page.

Filtered counts, grouped counts, `COUNT(column)`, and other aggregates continue
to evaluate records normally.

On the final warm panel check, an exact count over 100,000 persisted rows took
4 ms through the local HTTP API. The same database returned an empty table in
8 ms.

## Persistent Database Metadata

Every database catalog now has a matching atomic `.asa.meta` sidecar containing:

- stable database identity;
- metadata format and storage format versions;
- engine version;
- creation, update, and last checkpoint timestamps;
- checkpoint count;
- last durable summary.

The metadata API and AsAPanel add live information for:

- current database, database/table/view counts, and exact total rows;
- catalog, page-store, and WAL sizes;
- transaction and dirty checkpoint state;
- atomic catalog replacement and page checksum support;
- page size, import batch size, result limit, and cache policy;
- buffer pool pages, bytes, hits, misses, evictions, flushes, dirty pages, and
  pinned pages;
- B+Tree cache entries and planner path counters.

Metadata writes use `.tmp` plus `.bak` replacement and startup recovery. Keep
the `.asa`, `.asa.store`, `.asa.meta`, WAL, and journal artifacts together when
moving a database.

## Persistence And Recovery

1.3.0 retains the v1.2.1 recovery design:

- fixed 4 KB slotted heap pages with checksums;
- append undo records;
- page-mutation backups;
- transaction snapshots;
- temporary and backup catalog files;
- atomic catalog replacement;
- startup handling for interrupted append, mutation, checkpoint, and open
  transaction artifacts;
- import rollback when a statement batch fails.

Transactional batching was optimized without removing these recovery barriers.
The engine still does not claim ARIES or MVCC semantics.

## Runtime Configuration

The portable package includes:

```ini
page_size = 4096
buffer_pool_pages = 64
import_batch_size = 256
flush_interval = 32
max_result_rows = 500
cache_policy = clock
```

`page_size` remains fixed for format compatibility. Other values are loaded at
boot and can be tuned without rebuilding the executable.

## Measured 1.3.0 Benchmark

Environment: 4MLinux 6.12.94, Intel Core i5-6300U (2 cores / 4 threads),
8,022,200 kB visible RAM, SWI-Prolog 10.0.2 x86_64. Workloads use 100-row
multi-value INSERT statements and verify exact count, index build/lookup,
indexed ordering, UPDATE, DELETE, bounded results, shutdown, reopen, and
persisted count.

| Rows | Wall time | Import | Indexed lookup | ORDER/LIMIT | UPDATE | DELETE | Limited result | Peak RSS | Result |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| 10,000 | 4.59 s | 2.02 s | 1.60 s | 43 ms | 54 ms | 50 ms | 254 ms | 166.1 MiB | PASS |
| 50,000 | 33.00 s | 11.93 s | 19.15 s | 48 ms | 346 ms | 330 ms | 622 ms | 387.7 MiB | PASS |
| 100,000 | 59.21 s | 32.20 s | 24.31 s | 22 ms | 617 ms | 572 ms | 576 ms | 387.6 MiB | PASS |

The published GitHub v1.2.1 reference for the complete 100,000-row scenario
was approximately 247 seconds and 229.8 MB on a different Windows host. The
1.3.0 release-host run is approximately 76% faster wall-clock; this is a
directional cross-platform comparison, not a claim that peak RSS is lower.
The native 4MLinux run measured about 387.6 MiB peak RSS. Disk/cache state can
move import timings substantially, as documented in the release-host audit
above.

## Validation

Regression suite:

```powershell
swipl -q -s tests\run_tests.pl
```

Storage benchmark:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_storage_benchmarks.ps1
```

Validation completed for:

- CREATE/INSERT/SELECT/UPDATE/DELETE and ALTER flows;
- delete targeting and duplicate-column normalization;
- transactions, rollback, journal/WAL recovery, and restart persistence;
- JOIN, GROUP BY, aggregates, subqueries, views, users, and grants;
- exact metadata count with no sequential scan;
- bounded results and catalog synchronization;
- UTF-8 stream input;
- 10,000, 50,000, and 100,000-row full scenarios;
- AsAPanel boot, metadata rendering, empty SELECT, and 100,000-row COUNT through
  the local HTTP API.

## Compatibility And Migration

- Existing v1.2.1 SQL commands remain available.
- Page storage remains format 3; no row-store rewrite is required when moving
  from v1.2.1.
- A missing `.asa.meta` file is created automatically at boot.
- Compatible v2 list-backed user tables can still migrate to v3 page storage.
- Back up important databases before upgrading.

## Known Limits

- AsaDB is not performance-equivalent to SQLite, CouchDB, PostgreSQL, or MySQL.
- Some mutations invalidate persistent indexes and rebuild them lazily instead
  of applying a fully incremental B+Tree split/merge path.
- Complex JOIN, GROUP BY, and expression plans may materialize more intermediate
  data than simple indexed queries.
- Recovery is not ARIES and does not provide MVCC.
- The optimizer and planner statistics remain intentionally small.
- AsAPanel is intended for localhost use, not direct public exposure.

## License

The source distribution is licensed under GNU GPL v3.0 only. Distributors of
binaries or modified builds must provide complete corresponding source under
the same license. See `LICENSE`, `LICENSE_HISTORY.md`, `TRADEMARKS.md`, and
`THIRD_PARTY_NOTICES.md`.
