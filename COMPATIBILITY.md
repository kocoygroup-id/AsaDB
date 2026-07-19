# AsaDB 1.3.0 Compatibility Matrix

This document separates validated behavior from conditional compatibility.
`STABLE` means the documented release gates pass; it does not mean every SQL
dialect, operating system, or third-party runtime is supported.

## Release validation host

The 1.3.0 release gates were executed on 4MLinux 51.2 (Linux 6.12.94,
x86_64), Intel Core i5-6300U, with 8 GB RAM. This records the actual machine
profile used for the release; the capability probe remains the authoritative
check when moving the package to another host.

## Platform matrix

| Area | Status | Scope |
| --- | --- | --- |
| Linux x86_64 package layout | Validated | Clean archive root, executable modes, GPL files, checksum, and extraction are regression-tested. |
| POSIX `/bin/sh` launchers | Validated | Syntax checked with `dash`; quoting and paths containing spaces have a fake-runtime regression; no Bash-only `[[ ]]`, arrays, `pipefail`, or `source`. |
| BusyBox `sh` | CI-covered | GitHub Actions installs BusyBox and checks every shipped shell script. |
| SWI-Prolog core | Validated | Core assertions and the JOIN workload pass on the available SWI-Prolog WASM runtime; native Linux is a CI and target-host gate. |
| Native HTTP/Reservoir backend | Runtime-gated | `check_linux_runtime.sh` loads required HTTP, crypto, UUID, thread, core, Reservoir, and web modules before use. |
| AsAPanel browser bundle | Covered | `app-loader.js` loads a checked-in Firefox 38 syntax-compatible bundle and polyfills `NodeList.forEach`, `Element.append`, and other small APIs needed at boot. It also ships Noto Sans JP in WOFF2 plus WOFF for JP text on browsers without system CJK fonts. Current Firefox is recommended. |
| 4MLinux x86_64 | Validated on release host | Paths and shell syntax were exercised on the recorded 4MLinux host; a compatible feature-complete `swipl` is still required on any other host. |
| Windows x86 portable | Validated under Wine | The bundled 32-bit executable and runtime package use the same 1.3.0 backend/UI sources; native Windows x64 compilation remains a separate target. |
| macOS or non-x86_64 Linux | Not release-tested | Source may be portable, but it is outside this artifact's validation label. |

## Runtime requirements

To run the CLI or panel:

- Linux on x86_64/amd64;
- a writable filesystem for the catalog, `.asa.store`, `.asa.meta`, WAL,
  journal, and Reservoir spool;
- `swipl` on `PATH` with threads and the SWI-Prolog libraries used by
  `assoc`, HTTP, JSON, crypto, UUID, UTF-8, file utilities, and read utilities;
- a browser for AsAPanel.

Node.js is required only for `make test-ui`. Packaging additionally requires
`tar`, `gzip`, and either `sha256sum` or `shasum`.

The release does not assert a version number alone as sufficient. Some minimal
or custom SWI-Prolog builds omit packages needed by AsAPanel or Reservoir, so
the capability probe is authoritative:

```sh
./scripts/check_linux_runtime.sh
```

## Feature matrix

| Feature | Release status | Regression or boundary |
| --- | --- | --- |
| Core DDL/DML and persistence | Covered | `tests/run_tests.pl`, including restart and recovery paths. |
| DROP TABLE cleanup | Covered | Catalog, heap, and persistent B+Tree removal plus restart and `IF EXISTS`. |
| Qualified equality JOIN | Covered | INNER/LEFT/RIGHT behavior and planner counters. |
| 15k + 15k JOIN | Covered | Exact 15,000 matches and indexed planner path with a time bound. |
| v1.2.1 -> v1.3.0 storage stress | Measured | On 4MLinux 6.12.94 / i5-6300U / 8 GB, 10k, 50k, and 100k scenarios passed; 100k completed in 59.21 s wall-clock. |
| Filtered JOIN + VIEW multi-statement query | Covered | Source-local predicate pushdown, unique-key lookup, and two result sets are regression-tested; the 250,000-row Double_Company-shaped repro completed in ~0.36 s on the release host. |
| Complex `ON` expression | Compatible fallback | Nested loop; potentially expensive. |
| ID / JP / EN UI | Covered | All localization keys plus interactive language and dynamic Asa output checks. |
| Long SQL paste | Covered | 6,000-line caret/scroll retention scenario. |
| Startup overlay | Covered | A non-interactive 650 ms visual cue replaces the 3.5-second wait and never repeats backend warmup. |
| Browser bootstrap / buttons | Covered | Loader-to-legacy-bundle interaction test confirms language and database buttons attach even while the backend request is stalled. |
| Reservoir queue/spool | Covered by source tests | Full native execution requires thread, crypto, UUID, and HTTP-capable SWI-Prolog. |
| Reservoir reload/cancel/live metadata | Covered | Active jobs are rediscovered after reload without replay, receiving/queued/processing cancellation is regression-tested, and metadata uses adaptive no-cache polling while visible. Modern and legacy bundles share a build preflight contract. |
| SQL/table paging beyond 500 rows | Covered | `/api/query` serves bounded pages; SQL results, table previews, and the searchable sidebar expose unobtrusive Show-more controls. |
| Karyawan Reservoir adviser | Covered | `src/bridge/karyawan.pl` is pure Prolog, reports single-worker pressure/health, and is exercised through Reservoir snapshots and stats; no R runtime is required. |
| Large SQL paste / stress import | Covered | The line-number gutter remains visible for large scripts; 256-statement import batches use bounded 8,192-row storage chunks and the Linux stress-file resolver is case-tolerant. |
| MySQL 5.5 behavior | Partial compatibility | See `docs/mysql55-compatibility.md`; AsaDB is not wire-compatible with MySQL. |

## Storage compatibility

- Current page-storage format: `3`.
- Page size: fixed at 4,096 bytes for format compatibility.
- Compatible list-backed v2 tables can migrate when opened by v1.3.0.
- Keep the `.asa` catalog with its matching `.asa.store`, `.asa.meta`, WAL,
  journal, and Reservoir directory when moving a database.
- Always copy or snapshot the complete database set before an upgrade.

## 4MLinux acceptance procedure

Run these checks on the actual target machine; passing on another Linux
distribution cannot prove its libc or locally built SWI-Prolog compatibility:

```sh
cd AsaDB-1.3.0-linux-x86_64
./scripts/check_linux_runtime.sh
make test
make test-join
./tests/release_package_regression.sh
./scripts/run_panel.sh /path/to/writable/data.asa 8088
```

`make test-ui` is optional on a minimal installation because it requires
Node.js. If any runtime capability probe fails, the package is not yet ready
for that host even if the shell scripts themselves start.
