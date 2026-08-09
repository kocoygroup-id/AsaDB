# Local TVCC

TVCC is part of the 1.5.0 Stable local backend scope. It is not a cross-process
concurrency guarantee.

## What it provides

AsaDB's local three-version concurrency control (TVCC) gives a web `SELECT`
one immutable committed generation of both catalog state and record files.
While that query is reading, a local writer may import, update, checkpoint, or
build the next generation without exposing partially written heap pages.

The policy is deliberately bounded:

- one writer remains authoritative for mutation, transactions, import, backup,
  restore, and catalog administration;
- up to three committed reader generations are retained;
- a reader pins its generation until the request finishes;
- if the oldest generation is still pinned, publication waits rather than
  evicting a live snapshot;
- a `SELECT` released through AsAPanel no longer waits on the global writer
  execution mutex.

TVCC is deliberately bypassed while a SQL transaction is active. A transaction
continues through the primary executor so `BEGIN` → write → `SELECT` reads its
own uncommitted work. The public snapshot API accepts only one or more `SELECT`
statements and rejects mutation, transaction control, and mixed SQL batches.

The result is stable reads during long local writes, while retaining the
existing write-ahead/recovery and single-writer semantics.

## Why this is not an unsafe "three copies" feature

The page store mutates records in place. Holding three catalog terms alone
would let a reader pair old table metadata with new pages. TVCC instead binds:

1. an immutable committed catalog state;
2. a matching immutable heap/index directory; and
3. a reader reference that prevents retirement of that directory.

The publish point moves only after catalog and pager pages have been flushed.
A reader therefore sees either the complete preceding generation or the
complete new generation. A new image is prepared as a private `.tmp` directory;
only after retention has a free committed slot is it atomically renamed,
registered, and made current. Thus the committed-generation count never exceeds
three.

## Write-path performance

Each new generation copies the catalog, but record snapshots are incremental.
The changed table's heap and persistent index files are copied from the durable
primary store. Unchanged files are hard-linked from the previous immutable
generation on Linux and NTFS; if hard links are unavailable, AsaDB falls back
to a regular copy without weakening correctness. This avoids a full database
copy for a small update in a database with many large tables.

Bulk import stays efficient because the importer batches many inserts into one
normal commit and TVCC publishes one generation for that durable batch, rather
than one generation per row.

The publisher reserves its generation metadata briefly, then performs file
copying outside the reader-coordination mutex. New readers continue acquiring
the current committed generation while the next image is built.

## Restart recovery

TVCC images are transient, process-local reader material; they are not the
durable database. Before rebuilding generation one at process startup, AsaDB
removes only managed `generation-<positive integer>` and
`generation-<positive integer>.tmp` entries under the derived `.asa.tvcc`
directory. The normal catalog/WAL/record-store recovery has already completed,
so the new image is rebuilt from durable state. This prevents an interrupted
previous process from leaving a published generation and staging directory that
would otherwise collide with the next atomic rename.

## Scope and boundaries

TVCC is intentionally local to one AsaDB process and localhost AsAPanel. It
does not provide multi-process coordination, network replication, distributed
transactions, arbitrary historical queries, serializable isolation, ARIES, or
full SQL-standard MVCC. Operators should still provision disk space for up to
three generations of changed table files and monitor long-running local reads.

## Validation

`tests/tvcc_regression.pl` holds an old reader generation while a writer tries
to publish a fourth generation. It verifies that the writer waits, the old
reader remains readable, and retention returns to three generations after the
reader releases. It also covers read-your-writes transactions, snapshot API
rejection of mutations, two readers on one generation, selected-database
binding, joins, subqueries, aggregates, indexed predicates, ordering, error
cleanup, a database path containing spaces, and interrupted-generation startup
recovery. The test runs through the
standard `make test` target; CI also executes the core and TVCC suites on
Windows.
