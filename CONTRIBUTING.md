# Contributing to AsaDB

Thank you for helping build AsaDB. Contributions of code, tests,
documentation, reproducible benchmarks, and design review are welcome.

## Before You Start

1. Search existing issues and pull requests.
2. Open an issue before large architectural changes.
3. Keep changes focused and preserve existing SQL behavior unless the issue
   explicitly proposes a compatibility change.
4. Never commit private databases, credentials, personal data, generated
   binaries, or benchmark output containing sensitive information.

## Development Setup

Install SWI-Prolog and ensure `swipl` is available on `PATH`.

```powershell
swipl -q -s tests\run_tests.pl
node tests\ui_regression.js
```

Run the panel from source:

```powershell
swipl -q -s src\asadb_web.pl -- data.asa 8088
```

When changing `web/assets/app.js`, also rebuild and commit the checked-in
browser-compatible runtime bundle before testing or opening a pull request:

```sh
./scripts/build_legacy_frontend.sh
node tests/ui_regression.js
```

`app.js` remains the readable source; `app.legacy.js` is the generated
Firefox-38-compatible runtime served by AsAPanel.

For storage-related changes, also run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_storage_benchmarks.ps1
```

Include the environment, command, row count, elapsed time, and peak memory
when reporting performance changes. Do not describe a change as faster without
reproducible measurements.

## Pull Requests

- Add regression coverage for bug fixes.
- Document user-visible behavior and storage-format changes.
- Keep generated files and unrelated formatting changes out of the commit,
  except the required `web/assets/app.legacy.js` update that accompanies a
  change to `web/assets/app.js`.
- Update `THIRD_PARTY_NOTICES.md` when adding a dependency or media asset.
- Confirm that all tests pass before requesting review.
- Use clear commits that can be reviewed independently.

## Developer Certificate of Origin

AsaDB uses the Developer Certificate of Origin 1.1. Every commit must include a
`Signed-off-by` line certifying that you have the right to submit the work under
the repository license.

```powershell
git commit --signoff -m "Fix indexed range scan"
```

The sign-off is a certification of origin, not a copyright assignment. Read
the complete certificate in [DCO](DCO).

## License of Contributions

By submitting a contribution, you agree that it may be distributed under
GNU GPL v3.0 only, the license used by this repository. You retain copyright
in your contribution.

## Review Priorities

Reviews prioritize data integrity, recovery behavior, bounded memory, test
coverage, compatibility, and understandable implementation over feature count.
