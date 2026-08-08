# Server integration audit

This is an implementation audit, not a marketing claim. “Covered” means there
is an implementation path and automated coverage in this repository; “release
validation” means it needs a clean host or two running nodes and must be re-run
for the exact release commit.

| Checkpoint | Status | Evidence / boundary |
| --- | --- | --- |
| One pack and offline Python setup | Covered | `bootstrap_python.py`, locked wheelhouse, pack regression |
| Single browser entry point | Covered | `start`, `run_panel.sh`, and `run_panel.bat` land at `/login` |
| Local + server contexts | Covered | `/mode` chooses an authenticated Local or Server Workspace in one panel |
| Shared panel design | Covered | Login/Admin load canonical `web/assets/style.css` plus small server additions |
| Local-only safety | Covered with stricter policy | Loopback + `ASADB_ALLOW_LOCAL_ONLY` are required and login is never bypassed |
| Mode indicator and switching | Covered | Injected workspace bar identifies file, user, node, and switch/logout paths |
| Logout and rollback | Covered | Confirmation page, token revocation, user-session close and rollback behavior |
| Official Prolog authority | Covered | Flask supervises only `src/asadb_web.pl`; no Python SQL/storage executor exists |
| Streaming, jobs, import/export, backup | Covered by integration contracts | Flask forwards to the official backend; production backup remains backend-owned |
| Folder naming | Covered for the added server tree | No duplicate panel or Python storage tree was added; a root-wide move is deferred to avoid breaking existing release paths |
| First-run setup and central config | Covered | `start` creates admin/registry; bootstrap config and secret files live outside pack directory |
| Upgrade preservation | Covered | Runtime marker detects changed source, backs up launcher config/secrets, and does not delete data |
| Doctor | Partially covered | Offline runtime/core/assets/paths are checked; deep engine/backup/query probes require SWI-Prolog on the target host |
| Security controls | Covered in code | scrypt, hashed token records, HttpOnly/SameSite cookies, rate limit, RBAC, body limits, path safety, loopback policy, public-bind secret refusal |
| Admin, audit, observability | Covered | Admin APIs, JSONL audit, `/health`, `/readiness`, admin-only `/metrics` |
| Unit and browser-flow tests | Covered | Auth/RBAC/session/job/file/FTS tests plus login-first workspace/logout route coverage |
| Real Flask → Prolog integration | Release validation | Opt-in `test_engine_integration.py` requires `swipl` and a complete checkout |
| Two-node replication and platform matrix | Release validation | Run on two isolated nodes and target Linux/Windows builds; macOS server is not release-tested |
| Documentation and uninstall safety | Covered | Pack/local/server/install docs; reset and pack removal preserve user data |

## Verified in this workspace

- Python source compilation.
- Fresh CPython 3.13 offline runtime creation from bundled wheels.
- Bootstrap doctor JSON report.
- Login-first portal, loopback mode gate, protected pre-login assets, and
  logout/session cleanup using Flask's test client.

## Required before a release claim

Run `make test-pack` and
`ASADB_RUN_REAL_TESTS=1 python -m pytest -q flaskserver/tests/test_engine_integration.py`
on a machine with SWI-Prolog. Then run Windows packaging/CI and the two-node
replication scenario. Do not describe those as passed until their logs exist.
