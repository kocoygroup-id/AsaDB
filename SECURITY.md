# Security Notes

This release package is prepared for public upload without AsaDB engine source.

Included:

- Portable Windows runtime in `app/`
- AsAPanel UI in `app/web/`
- Safe SQL samples in `samples/`
- Local launch scripts

Not included:

- `src/` Prolog engine source
- `tests/`
- `tools/`
- internal architecture/binary-format notes
- private `.asa`, `.journal`, `.current_db`, log, or temp files
- development build scripts

Before uploading to GitHub, keep the repository public folder exactly like this package. Do not add the original project root.

Absolute anti-copy protection does not exist once a binary is public, but this package avoids exposing the readable Prolog source and keeps the public surface focused on local evaluation.
