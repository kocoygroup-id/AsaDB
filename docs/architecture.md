# AsaDB Architecture

AsaDB is a local-first SQL engine whose parser, planner, and execution control
are written in SWI-Prolog. Storage format v3 keeps catalog metadata separate
from disk-backed user rows.

## Data Flow

```text
SQL text / uploaded SQL stream
  -> Reservoir admission, durable spool, and single-writer queue
  -> lexer and parser
  -> Prolog AST
  -> planner and executor
  -> record manager / persistent B+Tree
  -> buffer pool
  -> 4 KB page manager and disk files
```

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

`src/asadb_core.pl` owns tokenization, parsing, AST execution, catalog state,
simple planner decisions, permissions, transactions at SQL level, and legacy
compatibility paths.

### Import manager

`src/asadb_web.pl` owns the HTTP upload path and streaming SQL import loop. It
reads 256 KB blocks, recognizes statement boundaries across blocks, queues a
bounded number of statements, executes each batch transactionally, and reports
progress. It never asks the browser to materialize a selected large SQL file.

### Record manager

`src/asadb_record_manager.pl` owns typed row encoding, heap page append, RID
lookup, page-by-page scan/rewrite, stable tombstone deletion, transaction file
snapshots, append undo records, and mutation backup recovery.

### Persistent B+Tree

`src/asadb_btree.pl` owns persistent leaf/internal index pages. Page zero stores
the root, height, key count, and leaf count. Leaf pages carry previous/next
sibling pointers. Equality descends from the root; range and ordered scans walk
the relevant leaf chain.

The bulk builder uses external sorted runs of 2,048 entries and merges one head
from each run while writing final leaf pages. This prevents a full index entry
list from living in the Prolog heap.

### Buffer pool

`src/asadb_buffer_pool.pl` owns the bounded page cache. It tracks pin count,
dirty state, reference state, logical byte count, hits/misses, and flushing.
Clock-style replacement skips pinned pages.

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

- Single local writer; no MVCC.
- Recovery is undo/backup/journal based, not ARIES.
- Some writes invalidate an affected persistent index and rebuild it lazily
  through bounded external runs.
- Complex optimizer statistics are not implemented; planner statistics are
  currently simple scan/build counters and row counts.
- This is not a full MySQL wire-compatible server.
