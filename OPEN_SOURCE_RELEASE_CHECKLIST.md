# Open-Source Release Checklist

Complete this checklist before replacing the public repository contents or
publishing a GPL binary release.

## Rights and Licensing

- [ ] Confirm that the project has the right to relicense every included source
      file under GPL-3.0-only.
- [ ] Confirm ownership or redistribution permission for the AsaDB logo, save
      icon, trash icon, and all eight audio files under `web/assets/Effect/`.
- [ ] Verify the exact SWI-Prolog runtime and optional library licenses included
      in the Windows package.
- [ ] Keep `LICENSE`, `THIRD_PARTY_NOTICES.md`, and the `licenses/` directory in
      the repository.

## Repository

- [ ] Upload the contents of this folder as the repository root, not as an
      additional nested directory.
- [ ] Confirm that GitHub detects `GNU General Public License v3.0`.
- [ ] Enable private vulnerability reporting in repository security settings.
- [ ] Require DCO sign-off for contributions and protect the main branch.
- [ ] Create labels for `bug`, `enhancement`, `documentation`, `good first issue`,
      `help wanted`, `storage`, and `sql-compatibility`.

## Validation

- [ ] Run `swipl -q -s tests/run_tests.pl`.
- [ ] Run the storage benchmark for changes touching pages, records, indexes,
      imports, transactions, or recovery.
- [ ] Build the Windows package from a clean checkout.
- [ ] Test the package on a machine without the development source tree.
- [ ] Check that the panel binds only to localhost.
- [ ] Confirm that no `.asa`, journal, credential, private key, build directory,
      executable, or personal dataset is committed.

## Binary Release

- [ ] Create a version tag from the exact commit used for the binary.
- [ ] Publish the complete corresponding source for that tag alongside the
      binary or through an equally accessible source link.
- [ ] Include `LICENSE`, `README.md`, `SOURCE_CODE.md`,
      `THIRD_PARTY_NOTICES.md`, `TRADEMARKS.md`, and runtime notices in the
      binary package.
- [ ] Verify the source and binary download links in a private browser window.
- [ ] Publish checksums for downloadable archives.
