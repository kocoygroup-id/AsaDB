# Cluster and replication

## Topology

```text
database file: main
primaryNode: node-1
replicaNodes: [node-2]
pool: 0
```

The `pool` field follows the useful SiriDB concept of grouping servers, but is
currently metadata only. AsaDB does not yet distribute one SQL query across
multiple files.

## Add nodes

On node 1:

```bash
curl -X POST https://node-1.example/api/v1/cluster/nodes \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"node-2","url":"https://node-2.example"}'
```

Register the same physical ID on the replica with `primaryNode=node-1` and
`replicaNodes=["node-2"]`.

## Trigger replication

```bash
curl -X POST https://node-1.example/api/v1/replication/main \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"logicalDatabase":"app","targetNode":"node-2"}'
```

Poll the returned job ID.

## Failure behavior

- A primary outage does not automatically promote a replica.
- Operators must verify the latest snapshot and explicitly edit placement.
- A failed snapshot does not mark the replica ready.
- The target restore uses the normal verified `.asb` path.
- Transactions are local to one primary file.


## Scheduled snapshots

Set `replicationLogicalDatabase` on a primary database-file record and set
`ASADB_REPLICATION_INTERVAL_SECONDS` to a positive interval. The maintenance
service schedules one snapshot job per configured replica when no equivalent
job is already queued or running.

Set the interval to `0` to keep replication manual-only.
