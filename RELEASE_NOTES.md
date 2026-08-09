# AsaDB Release Notes

Current release: **1.5.0 Stable**, prepared 2026-08-02

Status: **Stable** for the documented Linux/PCLinuxOS backend and source-package scope

Publication summary: [RELEASE.md](RELEASE.md)  
Compatibility matrix: [COMPATIBILITY.md](COMPATIBILITY.md)

## Unreleased maintenance (next patch)

This section describes merged-source maintenance after the 1.5.0 publication;
it is not a retroactive claim about the 1.5.0 release archives.

- **TVCC restart recovery.** Startup removes only managed transient
  `generation-*` TVCC snapshots left by an interrupted process, then rebuilds
  a reader image from the already recovered catalog, WAL, and record store.
  This prevents a stale `generation-000001.tmp` from blocking the Prolog
  backend at launch.
- **Native storage scan batching.** `src/kocoy.pl` batches cold sequential
  page reads through SWI-Prolog's native binary stream implementation while
  retaining the existing page format, buffer-pool precedence, checksum paths,
  and SQL semantics. It is an I/O-bound scan optimization, not a claim of a
  Rust engine or native-code SQL compiler.
- **Regression coverage.** The core suite verifies multi-page scan results and
  accelerator observability. The TVCC suite recreates interrupted staging and
  published-generation residue before a restart.

## Release order

| Version | Prepared/released | Status | Release focus |
| --- | --- | --- | --- |
| **1.5.0** | 2026-08-02 | **Current Stable** | Local TVCC reads, view-aware interchange, bounded ordering, and complete source distribution. |
| 1.4.0 | 2026-07-23 | Superseded Stable | Backend-produced `.asb` backup/restore and production backup validation. |
| 1.3.1 | 2026-07-21 | Superseded Release Candidate | Schema-aware editor assistance, syntax feedback, and Windows source launchers. |
| 1.3.0 | 2026-07-19 | Historical Stable | Reservoir admission, result paging, and indexed JOIN improvements. |

Only 1.5.0 is the current release line. Earlier entries are retained as an
ordered compatibility and operational-history reference; their original scope
and limitations are not silently reclassified as 1.5.0 guarantees.

## 1.5.0 Stable (current)

### Changes from 1.4.0 Stable

| Area | 1.4.0 Stable | 1.5.0 Stable | Operational benefit |
| --- | --- | --- | --- |
| Concurrent panel reads | One mutable local store was used by every request. | Local TVCC gives read-only panel `SELECT` requests an immutable catalog plus heap/index generation while retaining one authoritative writer. | A reader cannot pair an old catalog with new pages during a committed write. |
| TVCC publication safety | The initial local snapshot path existed on the development branch. | Publication flushes before exposure, builds an unpublished generation before retiring an old one, binds database context with files, and preserves read-your-writes inside transactions. | Snapshot visibility and transaction semantics have explicit regression coverage. |
| Portable view export | Tables were backend-scanned, but saved views were absent from export selection. | MySQL/PostgreSQL export preserves selected view definitions; CSV/XLSX evaluates selected views against backend storage and exports their rows. | The export menu represents tables and views without falling back to browser cache. |
| Large result ordering | `ORDER BY *` was a compatibility no-op, while projected ordered results could repeatedly evaluate sort expressions. | The bounded top-window sorter caches each matching row's order key once and merges sorted buffers deterministically. | Filtered, projected text ordering avoids repeated expression work while preserving stable tie order. |
| Production backup | Backend `.asb` backup and verified restore were introduced in 1.4.0. | The backup route remains backend-owned and is re-audited together with TVCC, portable interchange, and view export. | Complete logical backup never depends on loaded browser rows or visible result pages. |
| Release integrity | Linux/Windows-source package checks existed. | Version, engine metadata, pack manifest, runtime sources, docs, archive checksums, and release artifacts are released as one 1.5.0 set. | Operators can match a package, its checksum, and its reported engine version. |
| Local/server entry point | A source launcher could start the panel, but installed-pack users had to resolve an internal path. | The pack includes SWI-Prolog's native `app/asadb.pl`; `swipl asadb` starts the login-first portal and provisions its offline web gateway. | Linux and Windows users get one documented browser command without `pip install`, while Prolog remains the only SQL/storage engine. |
| Hot query reuse | Bounded parse/filter caches could evict a repeatedly used plan as if it were a one-off entry. | Parse and safe filter-plan caches refresh their LRU position on a collision-safe cache hit. | Repeated query shapes retain compiled work under mixed workloads while cache memory stays bounded. |

### SQL surface and performance

The documented SQL surface remains the supported contract: database and table DDL;
`INSERT`, `SELECT`, `UPDATE`, and `DELETE`; filters; ordering and limits;
INNER/LEFT/RIGHT/CROSS and comma joins; grouping and aggregate functions; basic
scalar/`IN`/`EXISTS` subqueries; `UNION`; `CASE`; views; transaction commands;
and the documented metadata/user catalog commands. The parser and executor suites
exercise aliases, qualified columns, `JOIN ... USING`, `ORDER BY *`, view
selection, restart persistence, recovery, and compatibility diagnostics.

For large result sets, 1.5.0 retains the bounded result window and the historical
no-op meaning of `ORDER BY *`. A regular `ORDER BY column` still must inspect and
order qualifying rows when no usable index can provide that order; it is not
represented as an instant indexed lookup. The new bounded sorter avoids
re-evaluating the same order expressions during comparisons and keeps equal sort
keys in scan order.

### SWI-Prolog distribution

The source package includes `tools/asadb_pack.pl`, a cross-platform
repository-channel helper for `install`, `upgrade`, `info`, `version`, and
`remove`. It invokes SWI-Prolog's supported `library(prolog_pack)` API and
forces the canonical `asadb` pack name for Git installs, avoiding the
repository-basename naming difference on current runtimes. The standard
public-registry commands remain `swipl pack install asadb` and `swipl pack
install --upgrade asadb`. On SWI-Prolog 9.1.18 or newer, the installed pack's
native application entry point makes `swipl asadb` the normal one-command
browser start. It does not replace or shadow the user's `swipl` executable.
The command and API behavior follows SWI-Prolog's official
[`library(prolog_pack)` documentation](https://www.swi-prolog.org/pldoc/man?section=prologpack),
[`pack_install/2` reference](https://www.swi-prolog.org/pldoc/doc_for?object=pack_install%2F2),
and [pack-app guide](https://www.swi-prolog.org/pldoc/man?section=swipl-app).

### Production backup and interchange

**Export → AsaDB Backup** creates a backend-produced `.asb` logical backup. The
backend scans paged storage under the execution lock and writes schema, all rows,
indexes, and catalog objects with integrity fields for both payload and manifest.
Restore validates those fields, rebuilds in a transaction, rescans table/row totals
before commit, and rejects restore or creation while another database transaction
is active.

MySQL SQL, PostgreSQL SQL, CSV, and XLSX are selected-object interchange formats,
not substitutes for an `.asb` disaster-recovery backup. They scan the backend rather
than browser state. MySQL/PostgreSQL preserve selected views as definitions;
CSV/XLSX materialize selected views through the normal executor. Unsupported
vendor-specific procedural dump syntax is rejected or remains outside the portable
dialect surface rather than being silently changed.

### Release validation profile

The release audit runs on **PCLinuxOS 2026**, Linux `6.18.37-pclos1`, x86_64, with
SWI-Prolog `10.0.2`. The release gates cover core parser/executor, catalog
persistence, metadata upgrade, recovery, local TVCC, 15,000-row indexed JOIN,
production backup/restore including authenticated HTTP, backend interchange
including selected views and 20,000-row stress, and 100,000-row storage stress.
Module loading, launchers, Guardian, Linux archive, Windows source archive, pack
installation/removal, and SHA-256 verification are also covered.

Node.js is not installed on the PCLinuxOS audit host. The Node-only browser
regression is therefore executed by GitHub Actions, while the checked-in
modern/legacy bundle contract is checked locally. Native Windows execution is not
claimed from Linux; the Windows deliverable is a complete source-launcher ZIP that
requires a compatible SWI-Prolog installation on Windows.

### Release artifacts

- `AsaDB-1.5.0-linux-x86_64.tar.Z` and SHA-256.
- `AsaDB-1.5.0-windows-source.zip` and SHA-256, including `run_asadb.bat` and `run_panel.bat`.
- `AsaDB-1.5.0-main-repo.tar.Z` and SHA-256.
- Unpacked `AsaDB-1.5.0-main-repo` source tree.

Every source artifact is built from the same release tree and contains the engine,
storage modules, TVCC, backup/interchange, AsAPanel bundles, launchers, tests,
documentation, pack manifest/application entry point, and GPL notices.

### Stable scope and known limits

- Stable applies to the documented PCLinuxOS/Linux backend and source-package
  validation scope; it is not a certification for every operating system or
  deployment topology.
- TVCC is local to one AsaDB process and localhost panel. It keeps at most three
  committed generations and is neither distributed concurrency control nor full
  SQL-standard MVCC.
- `.asb` is a verified logical backup, not a filesystem hot-copy or point-in-time
  recovery log. Keep tested, verified off-host generations.
- Complex joins may use a compatible nested-loop path; capacity-test real workloads
  before setting service objectives.
- AsaDB does not claim ARIES, MySQL wire compatibility, or a blanket performance
  comparison with a server-class database.

## Prior release summaries

### 1.4.0 Stable

1.4.0 moved production export and restore fully into the backend: `.asb`
artifacts carry schema, rows, indexes, catalog objects, and integrity metadata.
It also added transaction guards and restore-total validation, establishing the
backup baseline that 1.5.0 retains and re-tests.

### 1.3.1 Release Candidate

1.3.1 introduced local-catalog SQL completion, supported-syntax coloring,
consistent ID/JP/EN typography, the compatible `ORDER BY *` no-op, and the
checksummed Windows source-launcher package. Those editor and packaging
capabilities were stabilized by the subsequent 1.4.0 release.

### 1.3.0 Stable

1.3.0 established the earlier large-workload foundation: Reservoir admission
and recovery, paged result/table presentation, the `karyawan.pl` advisor, and
an indexed path for qualified equality joins. The 1.3.x release line remains
historical context rather than a substitute for the current 1.5.0 scope.

## License

AsaDB is distributed under the GNU General Public License v3.0 only.
