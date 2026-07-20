# AsaDB 1.3.1 Release Candidate

Released: 2026-07-21

Status: **Release Candidate**
License: **GPL-3.0-only**

## Publication files

- `AsaDB-1.3.1-linux-x86_64.tar.Z`
- `AsaDB-1.3.1-linux-x86_64.tar.Z.sha256`
- `AsaDB-1.3.1-windows-source.zip`
- `AsaDB-1.3.1-windows-source.zip.sha256`
- `AsaDB-1.3.1-windows-x86.zip` (pending a Windows SWI-Prolog rebuild)
- `AsaDB-1.3.1-main-repo.tar.Z`
- `AsaDB-1.3.1-main-repo.tar.Z.sha256`

The Linux and main-repo archives use the requested gzip-compressed tar stream
under a `.tar.Z` suffix. The Windows source ZIP contains this exact source tree
and batch launchers for an installed SWI-Prolog runtime. The separate portable
32-bit executable is deliberately not substituted with the old 1.3.0 binary,
because that executable embeds the Prolog engine.

## What changed from 1.3.0

- **Write SQL with guidance.** Schema-aware completion proposes the supported
  AsaDB language, local catalog objects, aliases, and columns. Modern and
  Firefox-38-compatible editor bundles share the same token coverage.
- **Get current diagnostics.** Editing invalidates an older asynchronous
  analysis result immediately, so a corrected trailing semicolon is not
  overwritten by a stale warning.
- **Avoid a useless sort.** `ORDER BY *` retains its compatible no-op meaning
  but no longer forces a global sort before a bounded result can be returned.
- **Keep the interface aligned.** ID, JP, and EN use one Noto Sans JP family.
- **Add an operational companion.** Asa Process Guardian is opt-in and
  isolated from SQL execution. It provides a SHA-256 rolling mirror, bounded
  audit log, state record, heartbeat checks, and bounded child recovery.
- **Make current Windows source accessible.** The new Windows source-launcher
  ZIP contains the same source revision and `.bat` launchers for systems with
  SWI-Prolog installed.

These changes are additive maintenance work: the SQL parser, storage format,
and database files retain the 1.3.0 compatibility contract.

## Release Candidate validation profile

The historical 1.3.0 release gates were run on **4MLinux 51.2**, Linux kernel
`6.12.94`, x86_64, with an **Intel Core i5-6300U** and **8 GB RAM**. For this
1.3.1 Release Candidate, the available Linux runtime probe, core, Reservoir,
indexed JOIN, guardian, source-package, Linux-package, and Windows
source-launcher package checks have passed. The Windows source ZIP has ZIP and
SHA-256 integrity coverage; native Windows execution and the portable
executable rebuild remain pending a Windows host with SWI-Prolog.

The archive is a gzip-compressed tar stream kept under the requested legacy
`.tar.Z` suffix. Extract it with `tar -xzf`, not with the historical Unix
`compress` utility.

Verify the download before extracting:

```sh
sha256sum -c AsaDB-1.3.1-linux-x86_64.tar.Z.sha256
tar -xzf AsaDB-1.3.1-linux-x86_64.tar.Z
cd AsaDB-1.3.1-linux-x86_64
```

## What this package is

This is the complete AsaDB 1.3.1 source distribution prepared and validated
for Linux x86_64. It includes the engine, AsAPanel, tests, documentation,
POSIX launchers, build scripts, and complete GPL notices.

It does **not** bundle a native AsaDB executable, a Linux kernel, libc, a web
browser, or SWI-Prolog. The `linux-x86_64` label describes the release target
and validation scope; `swipl` must be supplied separately on the target host.

## Key fixes in this Release Candidate

- Schema-aware SQL completion, comprehensive supported-syntax coloring, and
  consistent ID / JP / EN editor typography.
- `ORDER BY *` avoids needless global sorting while retaining its compatible
  no-op semantics; stale asynchronous semicolon feedback cannot overwrite a
  newly corrected SQL command.

- Correct alias resolution for qualified JOIN columns such as `m.No = z.No`.
- AVL-backed lookup execution for simple qualified equality INNER, LEFT, and
  RIGHT joins, including the 15,000 + 15,000 row regression.
- Predicate pushdown for filtered JOIN sources keeps paged tables lazy; a
  unique-key lookup avoids building a 250k-row index just to return twenty
  matching status rows. The combined JOIN + VIEW smoke query now returns both
  result sets without the previous materialization timeout.
- Complete ID / JP / EN AsAPanel switching, including dynamic status and Asa
  feedback text; its selector sits alongside the Save and Delete database
  buttons.
- Long SQL paste keeps the editor caret and scroll viewport.
- Large SQL paste keeps the full line-number gutter visible after the editor
  switches to its virtualized large-script path; gutter padding is isolated
  from the scroll container so rows do not disappear after line 50.
- Generated stress imports use 256-statement parser batches with bounded
  8,192-row storage append chunks. This reduces parser round trips without
  allowing a giant insert batch to exhaust the Prolog stack.
- The release-host stress audit on 4MLinux 6.12.94 / i5-6300U / 8 GB passed
  10k, 50k, and 100k-row scenarios; the 100k full run completed in 59.21 s.
  Against the published GitHub v1.2.1 reference of about 247 s, that is about
  76% lower wall-clock time (cross-platform directional comparison).
- The historical comparison baseline is v1.2.1; the release line jumps
  directly to 1.3.0.
- Startup no longer repeats backend warmup or forces a 3.5-second overlay; a
  650 ms visual cue never captures clicks or keyboard focus.
- A compatibility-safe AsAPanel loader now serves a checked-in Firefox-38
  syntax-compatible UI bundle, so older Firefox parsers do not leave the panel
  looking loaded while its buttons have no listeners; it also supplies the
  older `NodeList.forEach` and `Element.append` DOM APIs needed during boot.
- SQL result grids and table previews now page past the 500-row display
  boundary. A quiet `Show more tables` control appears at the end of the table
  chooser and loads another page on click or when the user reaches it while
  scrolling; the existing table search remains available.
- Added the single-worker `src/bridge/karyawan.pl` Prolog adviser. It sizes
  Reservoir ingress chunks, reports backend pressure/health, and bounds result
  egress pages without requiring an R installation or introducing another
  executor.
- DROP TABLE and DROP DATABASE update the browser catalog only after backend
  success is verified; core DROP TABLE also removes heap and B+Tree files.
- Linux paths use the canonical case-sensitive `stress tests` directory while
  the historical `test/...` input alias remains accepted.
- POSIX `/bin/sh` launchers with space-safe argument forwarding, runtime
  diagnostics, clean source packaging, and a separately published SHA-256
  checksum.

## Compatibility result

The Linux package, shell syntax, source manifest, checksum, core SQL suite,
UI regression, persistent DROP cleanup, and indexed JOIN regression are
release gates. See [COMPATIBILITY.md](COMPATIBILITY.md) for the exact matrix and
[RELEASE_NOTES.md](RELEASE_NOTES.md) for detailed changes and historical notes.

4MLinux support is **conditional**, not a bundled-runtime guarantee. Its
minimal shell/path model is supported, but the machine must provide an x86_64
SWI-Prolog build with HTTP, crypto, UUID, and thread support. Run
`./scripts/check_linux_runtime.sh` and `make test-all` on the actual 4MLinux
host before production use.

## Quick start

```sh
chmod +x bin/asadb scripts/*.sh tests/*.sh
./scripts/check_linux_runtime.sh
./scripts/run_panel.sh data.asa 8088
```

Open `http://127.0.0.1:8088/` in a browser. The panel is for localhost use; do
not expose it directly to an untrusted network.

## Known boundaries

- Complex JOIN predicates still use the nested-loop compatibility path.
- Large many-to-many JOIN output can consume memory before `LIMIT` is applied.
- Recovery is not ARIES, and concurrency is not MVCC.
- AsaDB implements a practical SQL subset; it is not a drop-in MySQL server.
- Back up the `.asa` catalog and all matching sidecars before upgrading.
