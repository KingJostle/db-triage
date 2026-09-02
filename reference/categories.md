# Category taxonomy

Category codes appear in check IDs (`PG-WRAP-001`); category names appear in reports. Every
category exists so that the rollup table reads as a *system*: "Backups: 0 findings" is
itself information, which is why `BAK`, `WRAP`, `CORR` and `REPL` are always shown in the
rollup even when they are empty.

| Code | Name | Engines | Why it is its own category |
|---|---|---|---|
| `META` | Run and tool integrity | any | What the run could not see, or should not be trusted on. Must be visually separate from findings *about the database*, because it is a statement about the report. |
| `WRAP` | Wraparound and freeze | PostgreSQL | The PostgreSQL-specific "you get fired" mechanism deserves its own rollup line so a reader sees "Wraparound: clear" at a glance. MySQL has no analogue: InnoDB transaction IDs are 48-bit. |
| `UNDO` | Undo and purge | MySQL | InnoDB's MVCC debt: history list length, undo tablespace growth, long transactions preventing purge. The MySQL sibling of `WRAP` plus `VAC`. |
| `VAC` | Autovacuum and bloat | PostgreSQL | Dead tuples, overdue vacuums, stale planner statistics, table bloat, autovacuum throttling, the xmin horizon. Separate from `WRAP` because bloat is a performance and capacity problem while wraparound is an availability problem, and they get fixed by different people on different timescales. |
| `BAK` | Backup and recovery | both | WAL archiving and binary logging, archive failures, base-backup evidence, retention windows, restore testing. Separate from `REPL` because **a replica is not a backup**: it replicates your `DELETE` faithfully. |
| `DUR` | Durability | both | The settings that decide whether a committed transaction survives a crash: `fsync`, `full_page_writes`, `synchronous_commit`, `innodb_flush_log_at_trx_commit`, `sync_binlog`, doublewrite, unlogged tables. Separate from `CORR` because these are *choices*, not *damage*. |
| `CORR` | Corruption signals | both | Evidence of damage, or of settings that hide damage: checksum failures, `zero_damaged_pages`, `innodb_force_recovery`, log messages, collation version drift, and the absence of any integrity tooling. |
| `REPL` | Replication and HA | both | Streaming and logical replication health, slots, lag, synchronous standbys, GTID, Group Replication, replica crash-safety. |
| `WAL` | Checkpoints and write-ahead log | both | Checkpoint frequency, `max_wal_size`, WAL volume, `pg_wal` size, redo log capacity, binlog cache. Performance and capacity — distinct from durability, which is `DUR`. |
| `MEM` | Memory and caching | both | `shared_buffers`, `work_mem`, `maintenance_work_mem`, `effective_cache_size`, huge pages, temp files, buffer pool sizing, on-disk temp tables, per-connection memory. |
| `CONN` | Connections and pooling | both | Saturation, churn, idle ratio, refused clients, the absence of a pooler. Separate from `LOCK` because saturation is a capacity problem and blocking is a concurrency problem, and they usually have different owners. |
| `LOCK` | Locking and long transactions | both | Blocking chains, idle-in-transaction, long transactions, prepared transactions, metadata locks, deadlock rate. |
| `SEC` | Security | both | Authentication exposure, TLS, privilege sprawl, dangerous grants, deprecated authentication. Dangerous items sit at P1–P50; review lists sit at P230. |
| `IDX` | Indexes | both | Invalid, unused, duplicate, overlapping, bloated, missing (inferred from scan counters), over-indexed write-heavy tables, unindexed foreign keys. |
| `SCHEMA` | Schema design | both | Tables without a primary key, sequence and auto-increment exhaustion, partitioning hygiene, MyISAM, `sql_mode`, triggers on hot tables. |
| `QRY` | Queries and workload visibility | both | Whether `pg_stat_statements` or `performance_schema` is available at all, slow-query logging, dominant statements, plan-hostile patterns, rollback ratio. The top-N lists live here at P240. |
| `CAP` | Capacity and growth | both | Disk usage, projected disk-full, database and relation sizes, WAL/binlog/undo/temp footprint, growth since the last snapshot. |
| `REL` | Reliability and operations | both | Version end-of-life and patch level, restarts, crash evidence, logging configuration, monitoring evidence, pending-restart settings, extension updates. |
| `CFG` | Non-default configuration | both | Pure inventory at P200: server, database/role and relation-level overrides, and their provenance. |
| `INFO` | Environment inventory | both | P250 descriptive rows, so the report doubles as documentation of the estate. |

## Deliberately absent

Carried over from `sp_Blitz`'s finding groups and then dropped, with reasons:

| Not a category | Why |
|---|---|
| Licensing | No analogue: PostgreSQL and MySQL have no per-core licence to get wrong. |
| Features | Folded into `INFO` — extensions and plugins are inventory. |
| File configuration | PostgreSQL has no per-file growth settings; tablespace layout lives in `CAP`. |
| DBCC events | No analogue. `CORR` covers the signals; db-triage never runs a consistency check itself. |
| In-Memory OLTP | No analogue. |
| Query plans | Plan-cache analysis is not available without `auto_explain`; `QRY` covers what is observable from `pg_stat_statements`. |
| Wait stats | PostgreSQL has no cumulative wait-statistics view. A snapshot histogram lives in `QRY` at P240, clearly labelled "at snapshot time". |
