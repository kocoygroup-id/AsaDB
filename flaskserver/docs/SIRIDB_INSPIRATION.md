# SiriDB architecture inspiration

This implementation does not copy SiriDB source code and does not implement the
SiriDB protocol. It borrows several useful system-level ideas:

- explicit server identities;
- pool metadata;
- primary/replica placement;
- background replication work;
- operational status visible to administrators;
- authenticated remote access;
- configuration that can be managed without changing database rows.

The reference material is SiriDB's public
[database administration overview](https://docs.siridb.com/database/) and
[server, pool, and replica design](https://docs.siridb.com/overview/server_pool_replica/).
Those sources describe a distributed time-series database; AsaDB deliberately
adapts only the operational vocabulary and safety boundaries below.

The design is intentionally adapted to AsaDB:

| SiriDB-style idea | AsaDB Flask adaptation |
| --- | --- |
| Server | Flask node with one node ID |
| Pool | Metadata field for future physical-file routing |
| Replica | Read-only snapshot target |
| Replication | Official `.asb` backup and verified restore |
| HTTP access | Flask API plus existing AsAPanel proxy |
| Auth | Username/password, bearer tokens, scoped file RBAC |

AsaDB currently has one writer per physical file and local-process TVCC.
Therefore this project does not claim automatic sharding, active-active
replication, synchronous quorum writes, or consensus.
