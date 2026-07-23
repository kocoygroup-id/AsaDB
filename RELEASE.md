# AsaDB 1.4.0 Stable

Stable release prepared: 2026-07-23
Status: **Stable** for the documented Linux/PCLinuxOS backend and source-package
scope
License: **GPL-3.0-only**

## Publication files

- `AsaDB-1.4.0-linux-x86_64.tar.Z`
- `AsaDB-1.4.0-linux-x86_64.tar.Z.sha256`
- `AsaDB-1.4.0-windows-source.zip`
- `AsaDB-1.4.0-windows-source.zip.sha256`
- `AsaDB-1.4.0-main-repo.tar.Z`
- `AsaDB-1.4.0-main-repo.tar.Z.sha256`

The Linux and main-repository archives use a gzip-compressed tar stream under
the requested `.tar.Z` suffix. The Windows source ZIP contains the same source
tree and batch launchers for an installed SWI-Prolog runtime. A native Windows
portable executable is not being relabelled or claimed by this release.

## What changed from 1.3.1 RC

- **Production-safe large database export.** The panel now downloads a
  backend-produced `.asb` backup. It scans physical paged records and includes
  schema, every row, indexes, and catalog objects instead of relying on the
  browser's loaded state.
- **Verified transactional restore.** Each `.asb` binds database identity,
  metadata, SQL payload, and row/table totals with SHA-256 integrity fields.
  Restore rejects altered or incomplete artifacts, validates rebuilt totals,
  and stages catalog objects in the same transaction.
- **Consistent backup execution.** Backup create and restore reject an
  already-active database transaction and use the shared backend execution
  lock so unrelated writes cannot mix into the operation.
- **Runtime-wired compatibility diagnostics.** Parser fallback consumes the
  MySQL 5.5 compatibility manifest, so known planned statements receive their
  real support status instead of behaving like dead documentation.
- **Broader operational integrity.** The opt-in Asa Process Guardian can
  verify and mirror complete `.asb` artifacts from a dedicated directory while
  remaining outside SQL execution.
- **RC editor and query fixes retained.** Schema completion, syntax coloring,
  consistent ID/JP/EN typography, bounded results, `ORDER BY *` compatibility,
  and corrected live diagnostics remain covered by release contracts.

The SQL parser and database storage compatibility contract remains additive
from 1.3.1 RC to 1.4.0 Stable.

## Stable validation profile

The target-host audit ran on **PCLinuxOS 2026**, Linux
`6.18.37-pclos1`, x86_64, with SWI-Prolog 10.0.2. Runtime, core, Reservoir,
indexed JOIN, production-backup, authenticated HTTP backup/restore, process
companion, launcher, release-contract, Linux package, main-repository package,
and Windows source-package gates passed.

The 100,000-row storage stress suite completed import, indexed lookup,
order/limit, update, delete, bounded-result, cleanup, and restart assertions.
Its measured import stage was 27,309 ms on the audit host.

Node.js was not installed on that host, so the Node-only browser regression is
not claimed as executed. The checked-in modern and legacy browser bundles
passed the static release-contract gate. Native Windows execution is also not
claimed from Linux; the Windows artifact is a source-launcher ZIP requiring a
compatible SWI-Prolog on `PATH`.

See [COMPATIBILITY.md](COMPATIBILITY.md) for exact platform scope and
[RELEASE_NOTES.md](RELEASE_NOTES.md) for the focused 1.3.1 RC to 1.4.0 Stable
comparison.

## Verify and extract

```sh
sha256sum -c AsaDB-1.4.0-linux-x86_64.tar.Z.sha256
tar -xzf AsaDB-1.4.0-linux-x86_64.tar.Z
cd AsaDB-1.4.0-linux-x86_64
```

The `.tar.Z` files use gzip compression; extract them with `tar -xzf`.

## Package contents

The complete source distribution includes the SQL engine, paged storage,
indexes, Reservoir, AsAPanel modern and legacy bundles, localization assets,
tests, documentation, POSIX launchers, Windows source launchers, build
scripts, and GPL notices. It does not bundle a kernel, libc, browser, or
SWI-Prolog runtime.

## Quick start

```sh
chmod +x bin/asadb scripts/*.sh tests/*.sh
./scripts/check_linux_runtime.sh
./scripts/run_panel.sh data.asa 8088
```

Open `http://127.0.0.1:8088/` in a browser. The panel is localhost-oriented;
do not expose it directly to an untrusted network.

## Production boundaries

- This Stable label is scoped to the documented PCLinuxOS/Linux backend and
  source-package validation. It is not a blanket certification of every
  enterprise deployment topology.
- The `.asb` format is a logical backup. Normal writes wait during its
  consistent scan; retain verified off-host generations and regularly test
  restore procedures.
- Complex JOIN predicates may use the nested-loop compatibility path, and
  large many-to-many results can consume memory before `LIMIT` is applied.
- Recovery is not ARIES, concurrency is not MVCC, and AsaDB is not a drop-in
  MySQL server.
- Production rollout should use staged deployment, least-privilege host
  controls, external monitoring, capacity tests, and a documented rollback
  plan.
