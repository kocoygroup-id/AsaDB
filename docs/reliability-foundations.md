# Reliability foundations (development branch)

This document describes work that is present in the reliability-foundations
branch but is not a retroactive claim about the published 1.5.0 Stable
artifact. A version number and release note will be assigned only after the
full platform/release gates have passed.

## Implemented and regression-tested

- Write-time SQL type validation after `DEFAULT` and `AUTO_INCREMENT`, covering
  signed and unsigned integer ranges, `DECIMAL(p,s)`, text limits,
  date/time values, booleans, and `NOT NULL`.
- Column and composite `PRIMARY KEY`/`UNIQUE` enforcement on both `INSERT` and
  `UPDATE`.
- Column and table `CHECK` constraints.
- Table `FOREIGN KEY ... ON DELETE RESTRICT ON UPDATE RESTRICT`, including
  child writes and parent delete/referenced-key update protection.
- Schema-preserving production backups: parent tables are emitted before their
  foreign-key children, and primary, unique, check, and restrict foreign-key
  constraints are restored with the data.
- MySQL/PostgreSQL interchange emits the same supported constraints and orders
  referenced parents before child definitions.
- `EXPLAIN SELECT` reports the actual catalog choice available to the executor
  (`TABLE SCAN`, unique/index lookup, or index range scan), selected index,
  transparent row heuristic, and sort note.

## Deliberate boundaries

- `CASCADE` and `SET NULL` are rejected rather than stored as no-op metadata.
- `EXPLAIN` is not yet cost-based: no persisted histograms, join reordering,
  hash join, or index-only scan claim is made.
- `SAVEPOINT`, point-in-time recovery, cross-process locking, and a documented
  fsync fault-injection contract remain separate durability work.
- Existing on-disk rows are preserved on open. The stricter type contract is
  applied to subsequent writes, so an operator can inspect/import legacy data
  deliberately instead of having boot silently rewrite it.

## Reproducible gates

```sh
make test
make test-backup
make test-interchange
make test-modules
```

`tests/schema_integrity_backup_regression.pl` specifically creates a composite
schema, makes a production backup, restores it into a fresh database, and
proves invalid type/check/foreign-key writes and parent deletion are rejected.

## Benchmark follow-up

Benchmark results are hardware-sensitive and are intentionally not replaced
with inferred numbers. Re-run the benchmark scripts on the target PCLinuxOS
machine with cold and warm cache notes, then record the exact command, SWI-
Prolog version, hardware, peak RSS, and latency distribution alongside the
result.
