# AsaDB Install Guide

## Windows

1. Install SWI-Prolog.
2. Pastikan `swipl` masuk PATH.
3. Extract `AsaDB-1.3.1-windows-source.zip`.
4. Buka PowerShell/CMD di folder `AsaDB`.
5. Jalankan demo:

```powershell
scripts\run_asadb.bat data.asa examples\demo.sql
```

6. Jalankan panel:

```powershell
scripts\run_panel.bat data.asa 8088
```

This ZIP contains AsaDB source and Windows batch launchers; it does not bundle
SWI-Prolog or a prebuilt executable.

Buka browser:

```text
http://127.0.0.1:8088
```

## Linux/macOS

Install SWI-Prolog first and ensure `swipl` is available on `PATH`. The Linux
launchers use POSIX `/bin/sh`; Bash is not required.

For the published Linux x86_64 package:

```sh
sha256sum -c AsaDB-1.3.1-linux-x86_64.tar.Z.sha256
tar -xzf AsaDB-1.3.1-linux-x86_64.tar.Z
cd AsaDB-1.3.1-linux-x86_64
```

The `.tar.Z` suffix is retained for release naming compatibility, but the file
is a gzip stream. This source package does not bundle `swipl`.

```bash
chmod +x scripts/*.sh bin/asadb
./scripts/check_linux_runtime.sh
./scripts/run_asadb.sh data.asa examples/demo.sql
./scripts/run_panel.sh data.asa 8088
```

Debian/Ubuntu example:

```bash
sudo apt-get update
sudo apt-get install swi-prolog-nox
```

Fedora example:

```bash
sudo dnf install pl
```

## 4MLinux

4MLinux is a minimalist independent distribution and does not provide a
general package manager. AsaDB therefore cannot install its Prolog runtime
automatically. Prepare a 64-bit SWI-Prolog runtime first—either a compatible
local build or a separately supplied installation—and make `swipl` visible on
`PATH`.

After extracting AsaDB:

```sh
cd AsaDB-1.3.1-linux-x86_64
chmod +x bin/asadb scripts/*.sh
./scripts/check_linux_runtime.sh
./scripts/run_panel.sh data.asa 8088
```

Open `http://127.0.0.1:8088` manually. The launchers do not depend on
`systemd`, `xdg-open`, PowerShell, drive letters, backslash paths, or Bash-only
syntax. Database files and all matching sidecars must be on a writable
filesystem.

For AsAPanel, use current Firefox when possible. The package automatically
loads a Firefox-38-compatible UI bundle; no Node.js or browser build step is
needed on 4MLinux. If a visible "AsAPanel gagal memuat antarmuka" notice ever
appears, first press `Ctrl+Shift+R`; if it remains, open Firefox Console with
`Ctrl+Shift+K` and keep the error text for a bug report.

## Asa Process Guardian

Asa Process Guardian is opt-in: it never changes SQL execution. It keeps a
small rolling mirror of AsaDB source/launcher files and can supervise a child
process with bounded restart and heartbeat auditing.

```sh
# One verified snapshot only
./scripts/asadb_guardian.sh --once

# Supervise the normal panel launcher
./scripts/asadb_guardian.sh --heartbeat-file /tmp/asadb.heartbeat -- \
  ./scripts/run_panel.sh data.asa 8088
```

The default mirror is `.asa-guardian/`; it contains `current/`, a SHA-256
manifest, state JSON, and a bounded log. On Unix, a stalled child may receive
a `CONT` nudge before the configured bounded restart policy applies. On
Windows, that nudge is skipped while snapshotting remains available.

`check_linux_runtime.sh` is a capability check, not only a version check. It
rejects the wrong OS/CPU and verifies the SWI-Prolog HTTP, crypto, UUID, thread,
core, Reservoir, and web modules used by AsaDB.

If `check_linux_runtime.sh` reports that `swipl` is missing, use the official
SWI-Prolog source-build instructions for Linux and build it on a fuller Linux
machine with the same CPU/libc target when the 4MLinux environment does not
contain the necessary compiler toolchain:

https://www.swi-prolog.org/build/unix.md

## Tests

```sh
make test
make test-ui
make test-join
```

`make test-join` creates two temporary 15,000-row tables, verifies an aliased
JOIN, checks all 15,000 matches, and confirms that the indexed JOIN planner path
was used. Test databases and generated SQL are removed afterwards.
`make test-ui` requires Node.js only for source validation; Node.js is not
required to run AsaDB or AsAPanel.

Package integrity and release-manifest test:

```sh
make test-package
```

## VS Code

Buka folder `AsaDB`, lalu jalankan task:

- `AsaDB: Run demo SQL`
- `AsaDB: Start AsAPanel`
- `AsaDB: Smoke test`

## Troubleshooting

### `swipl` tidak dikenali

SWI-Prolog belum terinstall atau PATH belum benar.

### AsAPanel terbuka tapi fallback sandbox

Artinya kamu membuka `web/index.html` langsung atau backend Prolog belum aktif. Jalankan:

```bash
swipl -q -s src/asadb_web.pl -- data.asa 8088
```

### File `.asa` tidak kebaca

Jangan langsung menghapus database. Simpan salinan file `.asa`, direktori
`.asa.store`, `.asa.meta`, dan journal yang menyertainya. AsaDB v1.3.0 dapat memigrasikan
table list-backed v2 yang kompatibel ke page storage v3 saat database dibuka.
Laporkan file yang gagal dimigrasikan beserta log melalui issue baru, tetapi
jangan unggah data sensitif.
