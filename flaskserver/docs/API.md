# HTTP API reference

All public endpoints except health and login accept:

```http
Authorization: Bearer TOKEN
```

Errors:

```json
{
  "error": {
    "code": "DATABASE_TRANSACTION_BUSY",
    "message": "Database is reserved by another transaction session.",
    "details": {}
  },
  "requestId": "..."
}
```

## Login

```http
POST /api/v1/auth/login
Content-Type: application/json

{"username":"admin","password":"..."}
```

## Query

```http
POST /api/v1/databases/main/query
Content-Type: application/json
Authorization: Bearer TOKEN

{
  "logicalDatabase": "app",
  "sql": "SELECT * FROM users LIMIT 100;"
}
```

`databaseId` is a physical `.asa` file. `logicalDatabase` is a SQL database
inside that file.

## NDJSON stream

```http
POST /api/v1/databases/main/stream
Accept: application/x-ndjson
Content-Type: application/json

{
  "logicalDatabase": "app",
  "sql": "SELECT * FROM events ORDER BY id;",
  "pageSize": 500
}
```

## Session transaction

```text
POST /api/v1/sessions
POST /api/v1/sessions/{id}/begin
POST /api/v1/sessions/{id}/query
POST /api/v1/sessions/{id}/commit
POST /api/v1/sessions/{id}/rollback
DELETE /api/v1/sessions/{id}
```

Create body:

```json
{"databaseId":"main","logicalDatabase":"app"}
```

## Reservoir upload

```http
POST /api/v1/databases/main/reservoir
Content-Type: application/octet-stream
Content-Length: ...
X-AsaDB-Logical-Database: app
X-AsaDB-Job-Label: bulk.sql
X-AsaDB-Idempotency-Key: deployment-2026-08-04
X-AsaDB-Stop-On-Error: true
```

The request body is the SQL/import file. Flask streams it to a bounded temporary
file, then submits it to the repository's durable Reservoir.

## Backup

```http
POST /api/v1/databases/main/backup
Content-Type: application/json

{"logicalDatabase":"app"}
```

The response is a streamed `.asb` file.

## Restore

```http
POST /api/v1/databases/main/restore
Content-Type: application/octet-stream
Content-Length: ...

<raw .asb bytes>
```

## Cluster-internal endpoints

```text
GET  /api/v1/cluster/health
POST /api/v1/internal/query/{database}
POST /api/v1/internal/replication/{database}
```

They require:

```http
X-AsaDB-Cluster-Key: CLUSTER_SECRET
```

Do not publish them outside the cluster firewall.
