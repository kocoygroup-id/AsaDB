# SWI-Prolog pack installation

AsaDB is prepared as the `asadb` SWI-Prolog pack. It requires SWI-Prolog
9.1.18 or newer, because it uses SWI-Prolog's official pack-app mechanism for
the one-command launcher. It is tested against the current 10.x runtime.

## Command syntax

`swipl install asadb` is not a SWI-Prolog command: use `swipl pack install
asadb`. Once installed, AsaDB is an official pack application, so the normal
cross-platform start command is simply `swipl asadb`.

These command forms are the CLI surface of SWI-Prolog's documented
[`library(prolog_pack)` manager](https://www.swi-prolog.org/pldoc/man?section=prologpack).
For automation, the helper uses the documented
[`pack_install/2`](https://www.swi-prolog.org/pldoc/doc_for?object=pack_install%2F2),
its `upgrade(true)` option, and `pack_remove/2` with non-interactive options.

The same commands work in a Linux terminal and Windows PowerShell/CMD once
`swipl` is on `PATH`; Windows users may write `swipl.exe` equivalently.

## Stable release channel

An installed `asadb` pack contains the complete AsaDB source distribution:
the SQL engine, CLI, AsAPanel backend and web assets, Flask Server source,
offline Python wheelhouse, launchers, interchange and backup support, examples,
documentation, and tests. It is not a reduced API-only package. Python 3.10+
is a runtime prerequisite for Server Mode, but installing Flask, Waitress,
Requests, and their dependencies is automatic and offline from the bundle.

For normal users, use the registered release channel once a stable version has
been published:

```sh
swipl pack install asadb
swipl asadb
```

Check the installed package and its version:

```sh
swipl pack info asadb
swipl pack list --installed
```

This channel resolves the newest published stable pack version. Upgrade an
existing registered installation, or remove it:

```sh
swipl pack install --upgrade asadb
swipl pack remove asadb
```

The registered `asadb` name resolves the newest published stable version. It
becomes available only after the release maintainer runs `swipl pack publish .`
from the exact public release checkout.

## Official repository channel before publication

Before publication, or when deliberately following the official repository,
use the cross-platform helper included in every AsaDB source release or
checkout:

```sh
swipl -q -s tools/asadb_pack.pl -- install
swipl -q -s tools/asadb_pack.pl -- info
swipl -q -s tools/asadb_pack.pl -- version
swipl -q -s tools/asadb_pack.pl -- upgrade
swipl -q -s tools/asadb_pack.pl -- remove
```

The helper follows the official `main` branch by default and uses the canonical
pack name `asadb`. It accepts `--branch BRANCH` for a review/release branch and
`--dir DIRECTORY` for a portable or test pack location. It uses only
`library(prolog_pack)` and therefore has identical behavior on Linux and
Windows. Git must be available for this repository channel.

For an unattended one-command repository installation without first extracting
the source package, use the same canonical options directly:

```sh
swipl -q -g "use_module(library(prolog_pack)), pack_install(asadb, [url('https://github.com/kocoygroup-id/AsaDB.git'), git(true), branch(main), pack(asadb), interactive(false), test(false), register(false)]), halt"
```

Do not use a bare `swipl pack install --git https://github.com/kocoygroup-id/AsaDB.git`
when you need the canonical name: SWI-Prolog derives `AsaDB` from that Git URL
on current runtimes. The helper and explicit API form force `asadb`, so later
inspection, upgrade, and removal use one stable name.

## Running Local and Server Mode from the installed pack

The pack's `app/asadb.pl` is discovered directly by SWI-Prolog. After a normal
pack installation, this is the only browser command needed:

```sh
swipl asadb
```

No `pip install`, `venv`, or exported server secrets are required. The first
run creates the per-user runtime from the bundled offline wheelhouse, prompts
for the administrator, registers the default database, and opens the
login-first portal. Python is a web/control-plane dependency only: the
official Prolog backend retains SQL, storage, transactions, backup, import,
and export authority.

The first start asks for administrator credentials, then opens
`http://127.0.0.1:7879/login`. Login always precedes workspace access.
After login, a registered database opens directly in Server Workspace, which
uses the supervised Prolog backend. Local Workspace is visible only on an
allowed loopback browser and remains an explicit authenticated switch; use the
local CLI below for no-login terminal work.
If the backend health check fails, Server Workspace fails closed instead of
writing to the browser sandbox.
Maintenance commands are also cross-platform:

```sh
swipl asadb doctor --json
swipl asadb python setup
swipl asadb python repair
swipl asadb reset python --yes
```

When a changed pack refreshes the bundled runtime, the launcher keeps a dated
copy of its launcher configuration and secrets under
`server-state/upgrade-backups/`. It never deletes the data directory or `.asa`
files. `reset python --yes` removes only the regenerable virtual environment;
`reset config --yes` moves configuration aside as a dated backup.

`swipl asadb ...` is a native SWI-Prolog pack app, not a wrapper that replaces
the user's executable. It works on Linux and Windows wherever SWI-Prolog 9.1.18
or newer is installed. The `bin/asadb` and `scripts/run_panel.*` launchers are
also retained for extracted source releases.

For a checked-out development tree, test the exact pack installer without
copying source files by running this command from the repository root:

```sh
swipl pack install .
```

To embed the engine in another Prolog program, load its stable pack API:

```prolog
:- use_module(library(asadb)).

?- asadb_version(Version).
Version = '1.5.0'.

?- asadb_boot('company.asa'),
   asadb_exec_sql("CREATE DATABASE company; USE company;", Result),
   asadb_shutdown.
```

The direct CLI remains available for explicit no-login terminal work:

```sh
swipl -q -s src/asadb.pl -- data.asa script.sql
```

## Publishing a new AsaDB pack version

Publishing is a release operation, not a normal development-branch step.
After a version is tagged, its `VERSION` file, root `pack.pl`, and
`pack/pack.pl` must all carry the same version. From that tagged, public
checkout, run:

```sh
swipl pack publish .
```

The pack server validates the manifest and registers the package. Only after
that registration can users rely on `swipl pack install asadb` without a URL.
Do not publish an RC, draft, or unreviewed development commit under the stable
package name.

## References

- [SWI-Prolog pack manager (`library(prolog_pack)`)](https://www.swi-prolog.org/pldoc/man?section=prologpack)
- [SWI-Prolog `pack_install/2` options and CLI mapping](https://www.swi-prolog.org/pldoc/doc_for?object=pack_install%2F2)
- [SWI-Prolog pack format and `pack.pl` metadata](https://www.swi-prolog.org/pldoc/man?section=libpl)
- [SWI-Prolog pack applications](https://www.swi-prolog.org/pldoc/man?section=swipl-app)
