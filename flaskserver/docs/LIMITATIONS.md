# Current limitations

These boundaries are intentional and should remain visible in release notes.

1. **One writer per physical `.asa` file.** Flask does not turn AsaDB into a
   multi-writer engine.
2. **Transaction restart behavior.** Cross-request transactions work while the
   same backend process is alive. They are rolled back/marked aborted after a
   server restart.
3. **One public process.** Run one Flask/Waitress process for one state/data
   directory. Multiple WSGI processes are not supported yet.
4. **Snapshot replication.** Replication is asynchronous `.asb` backup/restore,
   not log shipping or synchronous consensus.
5. **No automatic failover.** Replica promotion is an operator action.
6. **No distributed SQL.** Cluster pool metadata does not shard or merge query
   plans.
7. **Eventually consistent FTS.** Rebuild after source-data changes.
8. **File API locality.** It assumes reliable local atomic rename semantics.
9. **Panel transactions.** The panel can execute SQL transactions, but remote
   transaction affinity should use `/api/v1/sessions`.
10. **Large query cancellation.** Flask can cancel queued orchestration jobs;
    cooperative cancellation of a running direct SELECT depends on future core
    hooks. Reservoir imports retain their existing cancellation path.
11. **No claim of SiriDB protocol compatibility.** Only architectural ideas
    such as explicit nodes/pools/replicas influenced the layout.
