# Server administration guide

## Normal first start

For an installed AsaDB pack on SWI-Prolog 9.1.18 or newer, run:

```sh
swipl asadb
```

The one command creates the per-user offline Python gateway when needed,
prompts for the first administrator, registers `data.asa`, and opens the login
page. It does not install a second SQL engine: Flask supervises the bundled
SWI-Prolog web backend and owns only authentication, web delivery, and server
control-plane state.

## Daily use

1. Open the local login page shown by the launcher.
2. Sign in as an authorized user; Server Workspace opens by default and uses
   the supervised Prolog backend.
3. Use **Switch workspace** when an authenticated loopback user deliberately
   needs Local Workspace.
4. Use **Admin** for server configuration, registered physical `.asa` files,
   user roles, jobs, and audit records.
5. Use the workspace bar to return to the mode picker or log out.

## Data and configuration

The launcher stores mutable configuration, secrets, users, and registered
database metadata below the platform user-data directory, outside the pack.
Pack upgrades and removal therefore do not delete `.asa` files.

The admin page changes only safe mutable settings. Host binding, filesystem
paths, and secrets remain launcher/environment configuration so the browser
cannot expose them accidentally.

## Roles

- `reader`: panel, read queries, sessions, and FTS search.
- `writer`: reader plus writes and job submission.
- `operator`: operational database, backup, job, replication, and FTS work.
- `replicator`: snapshot replication service role.
- `admin`: all server permissions.

Prefer database-scoped bindings for non-admin users.

## Troubleshooting

```sh
swipl asadb doctor --json
```

Check the Admin worker view, JSONL audit records under server state, backend
stderr tails in database status, and the database Reservoir directory. A
backend starts lazily on first use; a stopped worker is not automatically an
error.
