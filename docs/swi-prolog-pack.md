# SWI-Prolog pack installation

AsaDB is prepared as the `asadb` SWI-Prolog pack. It requires SWI-Prolog
9.0.4 or newer; it is tested with both SWI-Prolog 9.0.4 and 10.0.2.
SWI-Prolog 10 provides the convenient `swipl pack ...` command-line app used
in the examples below. SWI-Prolog 9 remains supported through the equivalent
one-line API commands documented under [SWI-Prolog 9 compatibility](#swi-prolog-9-compatibility).

## Command syntax

`swipl install asadb` is not a SWI-Prolog command: stock SWI-Prolog treats
`install` as a source filename. Do not replace or shadow the user's `swipl`
executable to make that spelling work. The supported, cross-platform commands
are `swipl pack install asadb`, `swipl pack install --upgrade asadb`,
`swipl pack info asadb`, and `swipl pack remove asadb`.

These command forms are the CLI surface of SWI-Prolog's documented
[`library(prolog_pack)` manager](https://www.swi-prolog.org/pldoc/man?section=prologpack).
For automation, the helper uses the documented
[`pack_install/2`](https://www.swi-prolog.org/pldoc/doc_for?object=pack_install%2F2),
its `upgrade(true)` option, and `pack_remove/2` with non-interactive options.

The same commands work in a Linux terminal and Windows PowerShell/CMD once
`swipl` is on `PATH`; Windows users may write `swipl.exe` equivalently.

## Stable release channel

An installed `asadb` pack contains the complete AsaDB source distribution:
the SQL engine, CLI, AsAPanel backend and web assets, launchers, interchange
and backup support, examples, documentation, and tests. It is not a reduced
API-only package.

For normal users, use the registered release channel once a stable version has
been published:

```sh
swipl pack install asadb
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

## SWI-Prolog 9 compatibility

SWI-Prolog 9.0.4 supports the pack manager API, although it does not provide
the `swipl pack` command-line app. These commands are equivalent to install,
inspect, upgrade, and remove on that runtime:

```sh
swipl -q -g "use_module(library(prolog_pack)), pack_install(asadb, [interactive(false)]), halt"
swipl -q -g "use_module(library(prolog_pack)), pack_info(asadb), halt"
swipl -q -g "use_module(library(prolog_pack)), pack_upgrade(asadb), halt"
swipl -q -g "use_module(library(prolog_pack)), pack_remove(asadb), halt"
```

As with SWI-Prolog 10, the short pack name becomes available only after AsaDB
has been published to the public pack registry. Before that, use the direct
Git installation form on SWI-Prolog 10 or install from a checked-out source
directory during development.

## Running the installed CLI and panel

SWI-Prolog keeps packs outside the system `PATH`. This prevents one package
from silently replacing a system command. Resolve the installed directory
once, then run the complete installed CLI or panel directly with SWI-Prolog:

```sh
ASADB_HOME=$(swipl -q -g "use_module(library(prolog_pack)), pack_property(asadb, directory(Dir)), writeln(Dir), halt")
ASADB_DATA="$HOME/AsaDB-data"
mkdir -p "$ASADB_DATA"

(cd "$ASADB_HOME" && swipl -q -s src/asadb.pl -- "$ASADB_DATA/data.asa" examples/demo.sql)
(cd "$ASADB_HOME" && swipl -q -s src/asadb_web.pl -- "$ASADB_DATA/data.asa" 8088)
```

The `bin/asadb`, `scripts/run_asadb.sh`, and `scripts/run_panel.sh` launchers
are included too, matching an extracted release. The direct `swipl -s` form is
the portable recommendation because it does not depend on archive formats
preserving a shell script's executable permission. Keeping database files in
`$HOME/AsaDB-data` is important: `swipl pack install --upgrade asadb` updates
pack code, while user data remains outside the package directory.

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

The CLI and local panel remain source entrypoints because they deliberately
perform process-level setup:

```sh
swipl -q -s src/asadb.pl -- data.asa script.sql
swipl -q -s src/asadb_web.pl -- data.asa 8088
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
