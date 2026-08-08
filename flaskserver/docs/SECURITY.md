# Security

## Authentication

- Passwords are stored with Werkzeug's scrypt password hashing.
- Public bearer tokens are random URL-safe values.
- Only SHA-256 token digests are persisted.
- Browser tokens use `HttpOnly` and `SameSite=Lax` cookies.
- Cluster traffic uses a separate cluster secret.

## Authorization

RBAC bindings have a role and scope:

```json
{"role":"writer","scope":"database:main"}
```

`*` applies globally. Permissions are checked at Flask endpoints before a
request is forwarded to Prolog.

The existing AsaDB SQL user/grant catalog remains available inside the engine.
It is a separate SQL authorization surface. Deployments may use both layers,
but Flask RBAC is the mandatory network boundary.

## Filesystem permissions

Protect these paths:

```text
ASADB_DATA_DIR
ASADB_STATE_DIR/users
ASADB_STATE_DIR/tokens
ASADB_STATE_DIR/file-api
ASADB_TEMP_DIR
```

Recommended service account ownership:

```bash
chown -R asadb:asadb /var/lib/asadb
chmod 0700 /var/lib/asadb/server-state
chmod 0700 /var/lib/asadb/databases
```

## Internet deployment

- Bind Flask to localhost.
- Terminate TLS at Nginx/Caddy/another reviewed proxy.
- Set long independent `ASADB_SECRET_KEY` and `ASADB_CLUSTER_KEY` values.
- Never use development defaults.
- Restrict cluster endpoints by firewall in addition to the cluster key.
- Back up both data and state directories.
- Rotate user tokens after suspected disclosure.
- Keep Python, Flask, Requests, Waitress, SWI-Prolog, and AsaDB updated.

## File API

File API request files may include bearer tokens. They must not be placed in a
world-readable directory. Username/password authentication is supported for
manual bootstrap, but token authentication is preferred.

## Panel proxy

The private Prolog panel port is selected from a localhost-only range. Do not
publish that range through a container port mapping or firewall rule. Public
users should access only Flask.
