# AsaDB 1.4.0 Stable Release Notes

Stable release prepared: 2026-07-23
Status: **Stable** for the documented Linux/PCLinuxOS backend and source-package
scope

Publication summary: [RELEASE.md](RELEASE.md)  
Compatibility matrix: [COMPATIBILITY.md](COMPATIBILITY.md)

## 1.3.1 RC to 1.4.0 Stable

| Area | 1.3.1 RC | 1.4.0 Stable | Benefit |
| --- | --- | --- | --- |
| Production export | Export could be assembled from browser state, which might hold only metadata or a loaded subset of a large table. | The backend scans every stored page and creates an `.asb` backup containing schema, records, indexes, and catalog objects. | Backup completeness no longer depends on browser memory or the visible result window. |
| Restore integrity | Generic import could not prove a backup was complete before commit. | Restore verifies the payload and integrity manifest, then confirms rebuilt table and row totals before committing one transaction. | Altered, truncated, and incomplete backup artifacts are rejected. |
| Backup consistency | No explicit production transaction guard protected export and restore. | Create and restore reject an active database transaction; the shared backend execution lock gives the operation one logical view. | Backup data cannot mix with an unrelated in-flight write transaction. |
| Large-data query safety | The RC fixed `ORDER BY *` and bounded browser results. | Stable keeps those fixes and regression-tests backup, paging, bounded results, restart persistence, and a 100,000-row storage scenario together. | Large datasets receive a broader end-to-end release gate. |
| SQL guidance | Schema-aware completion, SQL coloring, aliases, columns, database objects, and supported syntax were introduced in the RC. | Stable retains the same lightweight modern and legacy browser implementations and checks their release contract. | Editor assistance remains available without adding a large editor framework. |
| Compatibility diagnostics | The MySQL 5.5 compatibility manifest was descriptive only. | Parser fallback consumes the manifest and reports the actual status of known unavailable statements. | Planned compatibility syntax is distinguishable from unknown SQL. |
| Operational resilience | The opt-in process companion could mirror source and launcher files. | It can also validate and mirror complete `.asb` artifacts from a separate backup directory. | Backups can enter the integrity-audited retention workflow without entering SQL execution. |

## Production backup design

The online Export control now requests a backend-produced **AsaDB Backup**
(`.asb`) instead of reconstructing a database from browser state. The backend
uses the existing pager and record path to scan all rows while holding the
shared execution lock. The backup envelope records database identity, catalog
objects, payload length, table count, and row count, with SHA-256 checks for
the SQL payload and the complete integrity record.

Restore validates the envelope before opening the normal import transaction.
Before commit, AsaDB re-scans stored rows and checks manifest totals, then
stages views, functions, procedures, and triggers with the table data. Backup
creation and restore reject an already-active database transaction.

The regression suite covers a multi-page 6,141-row backup, Unicode and
multiline values, indexes, column comments, scientific floating-point values,
tampering, authenticated HTTP download and restore, and rollback behavior.

This is a logical database backup, not a storage-level hot-copy format. Normal
writes wait while the backend scans a consistent database view. Operators
should retain multiple verified backup generations, monitor available local
disk space, and regularly test restore procedures.

## 1.3.1 RC capabilities retained

- Schema-aware SQL completion for lexer keywords, supported types,
  scalar/aggregate functions, databases, tables, views, columns, and aliases
  declared in `FROM` and `JOIN`.
- Completion keyboard controls: Up/Down, Enter or Tab, Escape, and
  Ctrl+Space.
- SQL syntax coloring across the supported command surface in both current
  and legacy browser bundles.
- Consistent Noto Sans JP selection for the ID, JP, and EN interfaces.
- `ORDER BY *` treated as the supported historical no-op without sorting a
  full result set.
- Stale semicolon diagnostics invalidated immediately when the SQL text
  changes.
- Opt-in Asa Process Guardian with SHA-256 source mirroring, bounded audit
  retention, heartbeat checks, and bounded external-process recovery.

## PCLinuxOS release audit

The stable audit was exercised on **PCLinuxOS 2026**, Linux
`6.18.37-pclos1`, x86_64, with SWI-Prolog 10.0.2. The following gates passed:

- Linux runtime probe and backend/core suite.
- Reservoir queue, reload, cancellation, and recovery suite.
- JOIN and paging regressions.
- Production backup unit and authenticated HTTP create/restore regressions.
- Process companion, launcher, release contract, and package checks.
- Windows source-package structure and archive-integrity checks.
- 100,000-row storage stress: import, indexed lookup, order/limit, update,
  delete, bounded result, cleanup, and restart assertions. The measured import
  stage was 27,309 ms on the audit host.

Node.js was not installed on the audit host, so the Node-only browser
regression is not claimed as executed there. The checked-in modern and legacy
browser bundles passed the static release-contract gate. Native Windows
execution is also not claimed from this Linux audit; the Windows deliverable
is a source-launcher ZIP requiring a compatible SWI-Prolog on `PATH`.

## Release artifacts

- `AsaDB-1.4.0-linux-x86_64.tar.Z` and SHA-256.
- `AsaDB-1.4.0-windows-source.zip` and SHA-256, including
  `run_asadb.bat` and `run_panel.bat`.
- `AsaDB-1.4.0-main-repo.tar.Z` and SHA-256.
- Unpacked `AsaDB-1.4.0-main-repo` source tree.

All source artifacts contain the SQL engine, paged storage, indexes,
Reservoir, web panel bundles, localization assets, launchers, build scripts,
tests, and GPL notices from the same release tree.

## Stable scope and known limits

- Stable means the documented PCLinuxOS/Linux backend and source-package
  gates passed. It is not a claim that every deployment topology or native
  Windows runtime has been certified.
- The panel binds to localhost by default and is not an internet-facing
  authentication or TLS boundary.
- Production rollout should still use staged deployment, external monitoring,
  least-privilege host controls, verified off-host backup copies, and tested
  disaster-recovery procedures.
- Complex joins may materialize intermediate data; validate workload-specific
  latency and capacity before setting commercial service objectives.
- AsaDB does not claim ARIES, MVCC, or a physical point-in-time recovery log.

## License

AsaDB is distributed under the GNU General Public License v3.0 or later.
