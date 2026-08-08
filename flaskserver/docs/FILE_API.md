# File-Based API

## Contract

Requests are atomically placed in:

```text
file-api/inbox/REQUEST_ID.request.json
```

The server moves them to `processing`, invokes the action, and writes:

```text
file-api/outbox/REQUEST_ID.response.json
```

## Query request

```json
{
  "id": "optional-client-id",
  "action": "query",
  "payload": {
    "auth": {"token": "remote-bearer-token"},
    "databaseId": "main",
    "logicalDatabase": "app",
    "sql": "SELECT * FROM users;"
  }
}
```

Response:

```json
{
  "id": "file-...",
  "ok": true,
  "result": {},
  "completedAt": "..."
}
```

## Supported actions

- `ping`
- `query`
- `metadata`

`query` and `metadata` require authentication and RBAC.

## Atomic producer rule

Producers must write a temporary file in the inbox filesystem and rename it to
the final `*.request.json` filename. The included CLI follows this rule.

## Scope

This API is filesystem IPC for same-host or shared-volume batch systems. It is
not intended for arbitrary network filesystems with weak rename consistency.
