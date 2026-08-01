# AsaDB 1.5.0 Stable

Stable release prepared: 2026-08-02
Status: **Stable** for the documented Linux/PCLinuxOS backend and source-package scope
License: **GPL-3.0-only**

## Publication files

- `AsaDB-1.5.0-linux-x86_64.tar.Z`
- `AsaDB-1.5.0-linux-x86_64.tar.Z.sha256`
- `AsaDB-1.5.0-windows-source.zip`
- `AsaDB-1.5.0-windows-source.zip.sha256`
- `AsaDB-1.5.0-main-repo.tar.Z`
- `AsaDB-1.5.0-main-repo.tar.Z.sha256`

The Linux and main-repository archives are gzip-compressed tar streams under the
`.tar.Z` suffix. The Windows ZIP contains the same complete source tree and
`run_asadb.bat` / `run_panel.bat` launchers for an installed SWI-Prolog runtime.
It is not a relabelled Windows native executable.

## What changed from 1.4.0 Stable

- **Local consistent reads.** TVCC gives eligible read-only panel `SELECT`
  requests an immutable catalog and storage generation. The single-writer path
  continues to handle writes, transactions, imports, backup, restore, and catalog
  administration.
- **Hardened snapshot lifecycle.** Generations are published only after pager
  state is flushed; old snapshots are not retired until safe; an active SQL
  transaction keeps its primary read-your-writes path.
- **View-aware portable export.** Selected views now appear alongside tables.
  SQL dialect exports preserve their definitions and CSV/XLSX export evaluated
  backend rows.
- **Faster bounded ordering.** The projected-order path caches sort values per
  matching row and merges bounded sorted buffers, preserving stable tie order.
  `ORDER BY *` remains the documented no-op.
- **Re-audited disaster recovery.** Production `.asb` backup remains a backend
  scan with checksum-validating, transactional restore; it never uses browser
  state as the source of truth.
- **Release cohesion.** Engine metadata, version manifests, pack API,
  documentation, source archives, Windows source ZIP, and SHA-256 files all
  report 1.5.0.

## Stable validation profile

The target-host audit is on **PCLinuxOS 2026**, Linux `6.18.37-pclos1`, x86_64,
with SWI-Prolog `10.0.2`. It covers core SQL syntax/execution, local TVCC,
15,000-row indexed JOIN, production backup and authenticated restore,
interchange round trips plus 20,000-row stress, 100,000-row storage stress,
module loading, launchers, Guardian, source packages, and pack installation.

The PCLinuxOS host has no Node.js, so Node-only browser regression is left to
GitHub Actions. The current and legacy browser bundles still pass the static
release contract locally. Native Windows execution must be performed on a Windows
host; the Windows release artifact is source + launchers, not an unverified native
binary claim.

## Verify and extract

```sh
sha256sum -c AsaDB-1.5.0-linux-x86_64.tar.Z.sha256
tar -xzf AsaDB-1.5.0-linux-x86_64.tar.Z
cd AsaDB-1.5.0-linux-x86_64
./scripts/check_linux_runtime.sh
./scripts/run_panel.sh data.asa 8088
```

Open `http://127.0.0.1:8088/`. The panel is localhost-oriented; do not expose it
directly to an untrusted network.

## Production boundaries

- Use `.asb` for complete verified logical backup; use MySQL/PostgreSQL/CSV/XLSX
  for selected-object interchange.
- Retain verified, tested, off-host backup generations and capacity-test real
  workloads before a broad production rollout.
- TVCC is local bounded snapshotting, not distributed concurrency control or full
  SQL-standard MVCC. Recovery is not ARIES.
- Unsupported vendor-specific SQL remains outside the documented portable surface.
  AsaDB is not a drop-in MySQL server or a server-class benchmark substitute.

Read [RELEASE_NOTES.md](RELEASE_NOTES.md) for the detailed 1.4.0-to-1.5.0
comparison and [COMPATIBILITY.md](COMPATIBILITY.md) for exact platform scope.
