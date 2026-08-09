# AsaDB Architecture

AsaDB is a local-first SQL engine whose parser, planner, and execution control
are written in SWI-Prolog. Storage format v3 keeps catalog metadata separate
from disk-backed user rows.

## Data Flow

```text
SQL text / SQL, CSV, or XLSX upload
  -> Reservoir admission, durable spool, and single-writer queue
  -> bounded Prolog interchange preparation when required
  -> lexer and parser
  -> Prolog AST
  -> planner and executor
  -> record manager / persistent B+Tree
  -> buffer pool
  -> native storage scan batching (cold sequential reads)
  -> 4 KB page manager and disk files
```

For local `SELECT` requests, the HTTP layer acquires an immutable
three-version concurrency-control (TVCC) generation before opening catalog or
heap files. A reader therefore sees one complete committed generation while a
writer is importing, updating, or checkpointing.

## Modules

### Reservoir bridge

`src/bridge/reservoir.pl` owns the bounded JavaScript-to-Prolog handoff for
write commands and large payloads. It receives input in 256 KB chunks, enforces
job and byte capacity while receiving, writes a durable spool, assigns an
idempotency fingerprint, and lets one worker feed the existing SQL executor.

The bridge is pressure control, not a second storage engine. Once admitted,
SQL still passes through the normal parser, transaction, record manager,
B+Tree, buffer pool, pager, and recovery path. See
[`reservoir.md`](reservoir.md) for lifecycle and failure semantics.

### SQL parser and executor

`src/asadb_sql_frontend.pl` owns tokenization, parsing, AST construction, and
syntax diagnostics. It is intentionally side-effect-free and can be exercised
without opening a database file.

`src/asadb_core.pl` owns AST execution, catalog state, planner decisions,
permissions, transactions at SQL level, and legacy compatibility paths. This
separation keeps the stateful engine independent from SQL text handling and
makes parser changes safer to review.

`src/asadb_prolog_jit.pl` adds a bounded specialization layer. Repeated SQL
texts up to 32 KiB reuse immutable parsed ASTs, while supported ground filter
ASTs become dynamically asserted clauses keyed by an integer plan ID.
SWI-Prolog compiles those clauses to its VM instruction form and may add
just-in-time clause indexes (JITI) as call patterns become hot. The compiler
accepts only the engine's expression AST whitelist; SQL text is never executed
as Prolog source. Both caches use collision-safe text/AST matching, refresh
their least-recently-used position on a hit, are capped at 128 entries, and
fall back to the ordinary interpreter for unsupported expressions. This is VM/JITI
specialization, not a claim of native machine-code generation.

### Import manager

`src/asadb_web.pl` owns the HTTP upload path and streaming SQL import loop. It
reads 256 KB blocks, recognizes statement boundaries across blocks, queues a
bounded number of statements, executes each batch transactionally, and reports
progress. It never asks the browser to materialize a selected large SQL file.

`src/asadb_interchange.pl` owns portable backend exchange. Export walks
verified backend row storage under the shared execution lock. Import converts
MySQL/PostgreSQL dump streams, CSV rows, and XLSX worksheet events into bounded
SQL batches before they enter the normal transactional importer. XLSX archive
paths and declared sizes are validated before worksheet parsing. See
[`interchange.md`](interchange.md).

### Record manager

`src/asadb_record_manager.pl` owns typed row encoding, heap page append, RID
lookup, page-by-page scan/rewrite, stable tombstone deletion, transaction file
snapshots, append undo records, and mutation backup recovery.

### Persistent B+Tree

`src/asadb_btree.pl` owns persistent leaf/internal index pages. Page zero stores
the root, height, key count, and leaf count. Leaf pages carry previous/next
sibling pointers. Equality descends from the root; range and ordered scans walk
the relevant leaf chain.

The bulk builder is adaptive: indexes up to 65,536 entries use an in-memory
sort, while larger indexes use bounded external runs of 32,768 entries and
merge one head from each run. Leaf-page packing tracks occupied bytes
incrementally instead of repeatedly measuring the growing page.

Unique point probes use a selective one-column scan immediately after bulk
load, then materialize a durable index after repeated access. This avoids a
large first-query index-build pause while preserving fast recurring workloads.

### Buffer pool

`src/asadb_buffer_pool.pl` owns the bounded page cache. It tracks pin count,
dirty state, reference state, logical byte count, hits/misses, and flushing.
Clock-style replacement skips pinned pages.

### Native storage scan accelerator

`src/kocoy.pl` owns the cold sequential page-read path. It reads a bounded
batch of fixed-size pages with SWI-Prolog's native binary stream primitive and
returns the existing byte representation one page at a time. Cached or dirty
buffer-pool pages still take precedence, and all page validation and row
decoding remain in the normal pager/record-manager path. The module changes no
file format and is intentionally not described as a replacement SQL engine or
a native-code compiler.

### Pager and page layout

`src/asadb_pager.pl` performs fixed-offset disk page I/O and single-stream page
iteration. `src/asadb_page_manager.pl` defines the checksummed 4 KB slotted page
layout.

The 32-byte page header contains:

```text
magic, version, page type, flags
page ID
live record count
free-space start and end
previous and next page IDs
checksum
```

The slot directory grows forward from the header and record payload grows
backward from the end of the page.

### Runtime configuration

`src/asadb_config.pl` reads `asadb.conf` during boot. Page size is fixed at
4,096 bytes for compatibility. Buffer pages, import batch size, flush interval,
result cap, and cache policy are configurable.

Reservoir job count, spool capacity, retention, progress persistence quantum,
and result page size are configurable independently of the database buffer
pool.

## Storage Files

```text
example.asa                 versioned catalog and metadata
example.asa.store/*.heap    table heap pages
example.asa.store/*.btree   persistent index pages
example.asa.journal         logical compatibility journal
example.asa.reservoir/      transient durable bridge jobs, spool, and results
*.undo / *.mutbak / *.txbak temporary recovery artifacts
```

Keep the `.asa` catalog and `.asa.store` directory together. Startup recovery
examines interrupted checkpoint, append, mutation, and transaction artifacts
before serving queries.

## Query Execution

- Simple scans are page iterators.
- Simple aggregates use incremental accumulator state.
- Indexed equality descends the B+Tree.
- Indexed ranges follow leaf siblings.
- Indexed `ORDER BY ... LIMIT` consumes leaf RID groups and stops at the result
  window.
- Non-index top-N sorting keeps bounded chunks.
- Web results are capped by `max_result_rows`.
- Complex JOIN/GROUP/expression compatibility paths can still materialize rows.

## Compatibility

State v2 list-backed user tables are migrated to v3 heap pages on boot. Catalog
tables and a few complex compatibility paths may still use Prolog lists because
they are small or require legacy behavior.

## Current Limits

- One local writer is retained intentionally. Local `SELECT` requests use
  bounded TVCC snapshots and may run while that writer is active; writes,
  explicit SQL transactions, import, restore, and catalog administration do
  not become concurrent writers.
- TVCC retains at most three committed generations. If a reader pins the
  oldest generation, publication waits rather than evicting that snapshot.
  It is local-process concurrency, not a cross-process lock manager, a
  distributed database protocol, or full SQL-standard MVCC.
- Recovery is undo/backup/journal based, not ARIES.
- Some writes invalidate an affected persistent index and rebuild it lazily
  through bounded external runs.
- Complex optimizer statistics are not implemented; planner statistics are
  currently simple scan/build counters and row counts.
- This is not a full MySQL wire-compatible server.
