# db-triage — MySQL and MariaDB check reference

One section per check, in the fixed template from DESIGN §2.3. Every section
carries an explicit `<a id="...">` anchor equal to the lowercase check ID,
because GitHub's auto-generated heading anchors are not stable across
punctuation; the `ref` column of `checks/registry-mysql.csv` points at these
anchors and the build fails if any is missing.

**Scope.** MySQL 5.7, 8.0, 8.4 and 9.x; Percona Server; MariaDB 10.4 through
11.x. Where the forks diverge, the divergence is stated in the check rather than
papered over — that is the single largest source of wrong answers in this half
of the catalog, and the four places it bites hardest are:

| Divergence | MySQL | MariaDB |
|---|---|---|
| Replica receiver-thread state | `performance_schema.replication_connection_status` | **not readable from SQL at all** — `SHOW SLAVE STATUS` only |
| Replica lag | applier timestamps in `replication_applier_status_by_worker` (8.0+) | **not readable from SQL at all** |
| Global variables source table | `performance_schema.global_variables` (i_s copy removed in 8.0) | `information_schema.GLOBAL_VARIABLES` (no p_s copy) |
| Account catalog | `mysql.user` is a table; `account_locked`, `password_lifetime` are columns | `mysql.user` is a view over `mysql.global_priv`; locking lives in JSON, no `password_lifetime` |

`checks/mysql/01_session.sql` resolves all four once, so individual checks stay
single-statement. Its §6c and §6d comment blocks are the authoritative
description of what each fork actually exposes.

**Reading a section.** *What fires it* is the exact condition, with the default
threshold and its override key. *Why it matters* is the mechanism, taken from the
check's own source, which is verified against a live server. *How to confirm* is
a query you can run by hand — it may be heavier than db-triage is allowed to be.
*How to fix* puts the safest option first. *False positives* is where the check
is known to be wrong.

**Nothing here mutates anything.** Every statement db-triage runs is a `SELECT`,
a `SHOW`-free read of `information_schema` / `performance_schema`, or a
session-scoped `SET`. Confirmation and fix queries in this document are for a
human to run, and the ones that write are labelled as such.


## Index of checks

| P | ID | Category | Title | Engine | Status |
|---|---|---|---|---|---|
| 1 | [MY-BAK-001](#my-bak-001) | BAK | Binary logging disabled — point-in-time recovery impossible | mysql,mariadb | active |
| 1 | [MY-BAK-002](#my-bak-002) | BAK | Last successful backup unknown or older than 7 days | mysql,mariadb | active |
| 1 | [MY-CAP-001](#my-cap-001) | CAP | Data, binary log or temp volume at or above 90 percent full | mysql,mariadb | active |
| 1 | [MY-CORR-001](#my-corr-001) | CORR | InnoDB corruption messages in the error log | mysql | active |
| 1 | [MY-DUR-004](#my-dur-004) | DUR | InnoDB doublewrite buffer disabled | mysql,mariadb | active |
| 1 | [MY-DUR-005](#my-dur-005) | DUR | Server running in innodb_force_recovery mode | mysql,mariadb | active |
| 1 | [MY-REL-002](#my-rel-002) | REL | End-of-life server reachable from any network interface | mysql,mariadb | active |
| 1 | [MY-REPL-001](#my-repl-001) | REPL | Replication stopped with an error | mysql,mariadb | active |
| 1 | [MY-SEC-001](#my-sec-001) | SEC | Accounts with no password | mysql,mariadb | active |
| 1 | [MY-SEC-002](#my-sec-002) | SEC | Superuser-equivalent account reachable from any host | mysql,mariadb | active |
| 5 | [MY-CONN-001](#my-conn-001) | CONN | Connections at or above 90 percent of max_connections | mysql,mariadb | active |
| 5 | [MY-DUR-003](#my-dur-003) | DUR | Crash-unsafe replication source | mysql,mariadb | active |
| 5 | [MY-REPL-003](#my-repl-003) | REPL | Replica lag over 5 minutes | mysql | active |
| 5 | [MY-REPL-010](#my-repl-010) | REPL | Group Replication member not ONLINE | mysql | active |
| 5 | [MY-SCHEMA-005](#my-schema-005) | SCHEMA | AUTO_INCREMENT at or above 90 percent exhausted | mysql,mariadb | active |
| 5 | [MY-SEC-003](#my-sec-003) | SEC | Anonymous accounts present | mysql,mariadb | active |
| 5 | [MY-UNDO-001](#my-undo-001) | UNDO | InnoDB history list length very high | mysql,mariadb | active |
| 10 | [MY-DUR-001](#my-dur-001) | DUR | innodb_flush_log_at_trx_commit not 1 | mysql,mariadb | active |
| 10 | [MY-DUR-002](#my-dur-002) | DUR | sync_binlog not 1 | mysql,mariadb | active |
| 10 | [MY-LOCK-001](#my-lock-001) | LOCK | Transaction waiting on a row lock for over 5 minutes | mysql,mariadb | active |
| 10 | [MY-LOCK-004](#my-lock-004) | LOCK | Idle transaction holding locks for over an hour | mysql,mariadb | active |
| 10 | [MY-REL-005](#my-rel-005) | REL | Server restarted within the last 24 hours | mysql,mariadb | active |
| 10 | [MY-REPL-002](#my-repl-002) | REPL | Replication threads stopped without an error | mysql,mariadb | active |
| 10 | [MY-REPL-005](#my-repl-005) | REPL | Replica is writable | mysql,mariadb | active |
| 20 | [MY-BAK-003](#my-bak-003) | BAK | Binary log retention shorter than one day | mysql,mariadb | active |
| 20 | [MY-CAP-002](#my-cap-002) | CAP | Volume at or above 80 percent full | mysql,mariadb | active |
| 20 | [MY-CAP-003](#my-cap-003) | CAP | Projected disk-full within 30 days | mysql,mariadb | planned |
| 20 | [MY-CONN-003](#my-conn-003) | CONN | Clients refused because max_connections was reached | mysql,mariadb | active |
| 20 | [MY-CORR-002](#my-corr-002) | CORR | Crash-recovery messages in the error log | mysql | active |
| 20 | [MY-LOCK-003](#my-lock-003) | LOCK | Transaction open for over an hour | mysql,mariadb | active |
| 20 | [MY-MEM-001](#my-mem-001) | MEM | InnoDB buffer pool at the shipped default | mysql,mariadb | active |
| 20 | [MY-REL-001](#my-rel-001) | REL | Server version is past end of life | mysql,mariadb | active |
| 20 | [MY-REPL-016](#my-repl-016) | REPL | GTID set has gaps | mysql | active |
| 20 | [MY-SCHEMA-001](#my-schema-001) | SCHEMA | InnoDB tables without a primary key on a replicated source | mysql,mariadb | active |
| 50 | [MY-BAK-004](#my-bak-004) | BAK | Binary logs never expire | mysql,mariadb | active |
| 50 | [MY-BAK-005](#my-bak-005) | BAK | Restore never tested or RPO/RTO undocumented | mysql,mariadb | active |
| 50 | [MY-CAP-006](#my-cap-006) | CAP | Binary logs consuming excessive space | mysql,mariadb | planned |
| 50 | [MY-CAP-007](#my-cap-007) | CAP | General query log enabled | mysql,mariadb | active |
| 50 | [MY-CONN-002](#my-conn-002) | CONN | Connections at or above 70 percent of max_connections | mysql,mariadb | active |
| 50 | [MY-CONN-006](#my-conn-006) | CONN | max_connections very high with no thread pool and no evidence of a pooler | mysql,mariadb | active |
| 50 | [MY-CONN-009](#my-conn-009) | CONN | Server saturated at snapshot time | mysql,mariadb | active |
| 50 | [MY-DUR-006](#my-dur-006) | DUR | InnoDB page checksums disabled | mysql,mariadb | active |
| 50 | [MY-DUR-007](#my-dur-007) | DUR | Non-transactional storage engines in use | mysql,mariadb | active |
| 50 | [MY-IDX-001](#my-idx-001) | IDX | Unused index of 1 GB or more | mysql,mariadb | active |
| 50 | [MY-IDX-003](#my-idx-003) | IDX | Redundant or duplicate indexes | mysql,mariadb | active |
| 50 | [MY-IDX-004](#my-idx-004) | IDX | Large table with heavy full table scans | mysql,mariadb | active |
| 50 | [MY-LOCK-002](#my-lock-002) | LOCK | Transaction waiting on a row lock for over 30 seconds | mysql,mariadb | active |
| 50 | [MY-LOCK-005](#my-lock-005) | LOCK | Idle transaction holding locks for over 5 minutes | mysql,mariadb | active |
| 50 | [MY-LOCK-006](#my-lock-006) | LOCK | Sessions waiting for a metadata lock | mysql,mariadb | active |
| 50 | [MY-MEM-002](#my-mem-002) | MEM | Buffer pool far smaller than the InnoDB working set | mysql,mariadb | active |
| 50 | [MY-MEM-007](#my-mem-007) | MEM | Worst-case memory commitment exceeds host RAM | mysql,mariadb | active |
| 50 | [MY-MEM-009](#my-mem-009) | MEM | Query cache enabled | mariadb | active |
| 50 | [MY-MEM-011](#my-mem-011) | MEM | Host is swapping | mysql,mariadb | active |
| 50 | [MY-REPL-004](#my-repl-004) | REPL | Replica lag over 30 seconds | mysql | active |
| 50 | [MY-REPL-006](#my-repl-006) | REPL | GTID not in use in a replicated topology | mysql,mariadb | active |
| 50 | [MY-REPL-007](#my-repl-007) | REPL | Statement-based binary logging | mysql,mariadb | active |
| 50 | [MY-REPL-008](#my-repl-008) | REPL | Replication errors are being skipped | mysql,mariadb | active |
| 50 | [MY-REPL-009](#my-repl-009) | REPL | Semi-synchronous replication has fallen back to asynchronous | mysql,mariadb | active |
| 50 | [MY-REPL-015](#my-repl-015) | REPL | Replication filters configured | mysql,mariadb | active |
| 50 | [MY-SCHEMA-004](#my-schema-004) | SCHEMA | sql_mode is not strict | mysql,mariadb | active |
| 50 | [MY-SCHEMA-006](#my-schema-006) | SCHEMA | AUTO_INCREMENT at or above 70 percent exhausted | mysql,mariadb | active |
| 50 | [MY-SCHEMA-007](#my-schema-007) | SCHEMA | Integrity checks disabled globally | mysql,mariadb | active |
| 50 | [MY-SCHEMA-013](#my-schema-013) | SCHEMA | Shared InnoDB tablespace in use | mysql,mariadb | active |
| 50 | [MY-SEC-008](#my-sec-008) | SEC | Application connections running as a privileged account | mysql,mariadb | active |
| 50 | [MY-UNDO-002](#my-undo-002) | UNDO | InnoDB history list length elevated | mysql,mariadb | active |
| 50 | [MY-UNDO-003](#my-undo-003) | UNDO | Undo tablespaces large | mysql,mariadb | active |
| 50 | [MY-WAL-001](#my-wal-001) | WAL | Redo log capacity below one hour of writes | mysql,mariadb | active |
| 100 | [MY-BAK-006](#my-bak-006) | BAK | Binary log checksums off | mysql,mariadb | active |
| 100 | [MY-BAK-007](#my-bak-007) | BAK | Managed-platform backups not verifiable from SQL | mysql,mariadb | active |
| 100 | [MY-CAP-008](#my-cap-008) | CAP | InnoDB temporary tablespace large | mysql,mariadb | active |
| 100 | [MY-CONN-004](#my-conn-004) | CONN | Aborted connections high | mysql,mariadb | active |
| 100 | [MY-CONN-005](#my-conn-005) | CONN | Host approaching the connect-error block threshold | mysql,mariadb | active |
| 100 | [MY-CONN-007](#my-conn-007) | CONN | Most connections are sleeping | mysql,mariadb | active |
| 100 | [MY-DUR-008](#my-dur-008) | DUR | Replica not crash-safe | mysql,mariadb | active |
| 100 | [MY-IDX-005](#my-idx-005) | IDX | Write-heavy table carrying many indexes | mysql,mariadb | active |
| 100 | [MY-IDX-006](#my-idx-006) | IDX | Table fragmentation (DATA_FREE) high | mysql,mariadb | active |
| 100 | [MY-LOCK-009](#my-lock-009) | LOCK | Query running for over 10 minutes | mysql,mariadb | active |
| 100 | [MY-MEM-003](#my-mem-003) | MEM | Buffer pool over 80 percent of host RAM | mysql,mariadb | active |
| 100 | [MY-MEM-004](#my-mem-004) | MEM | Buffer pool read miss rate high | mysql,mariadb | active |
| 100 | [MY-MEM-005](#my-mem-005) | MEM | Implicit temporary tables spilling to disk | mysql,mariadb | active |
| 100 | [MY-MEM-006](#my-mem-006) | MEM | Oversized per-session buffers | mysql,mariadb | active |
| 100 | [MY-MEM-008](#my-mem-008) | MEM | Table open cache too small, or open-file limit at risk | mysql,mariadb | active |
| 100 | [MY-QRY-001](#my-qry-001) | QRY | performance_schema disabled | mysql,mariadb | active |
| 100 | [MY-QRY-003](#my-qry-003) | QRY | Slow query log off, or its threshold at the default | mysql,mariadb | active |
| 100 | [MY-QRY-010](#my-qry-010) | QRY | One statement digest dominates total latency | mysql,mariadb | active |
| 100 | [MY-QRY-012](#my-qry-012) | QRY | Join and scan counters high | mysql,mariadb | active |
| 100 | [MY-REL-003](#my-rel-003) | REL | Server version within six months of end of life | mysql,mariadb | active |
| 100 | [MY-REL-004](#my-rel-004) | REL | Patch release behind | mysql,mariadb | planned |
| 100 | [MY-REL-006](#my-rel-006) | REL | No evidence of a monitoring agent | mysql,mariadb | active |
| 100 | [MY-REL-010](#my-rel-010) | REL | Persisted variables override the configuration files | mysql | active |
| 100 | [MY-REPL-011](#my-repl-011) | REPL | Single-threaded replica applier while lagging | mysql,mariadb | active |
| 100 | [MY-REPL-013](#my-repl-013) | REPL | Replication heartbeat or connection retry misconfigured | mysql,mariadb | active |
| 100 | [MY-REPL-014](#my-repl-014) | REPL | binlog_row_image MINIMAL with logical consumers configured | mysql,mariadb | active |
| 100 | [MY-SCHEMA-002](#my-schema-002) | SCHEMA | InnoDB tables without a primary key | mysql,mariadb | active |
| 100 | [MY-SCHEMA-008](#my-schema-008) | SCHEMA | Leftover online-schema-change artefacts | mysql,mariadb | active |
| 100 | [MY-SEC-004](#my-sec-004) | SEC | Application accounts allowed from any host | mysql,mariadb | active |
| 100 | [MY-SEC-005](#my-sec-005) | SEC | TLS not enforced, or largely unused | mysql,mariadb | active |
| 100 | [MY-SEC-009](#my-sec-009) | SEC | LOAD DATA LOCAL enabled | mysql,mariadb | active |
| 100 | [MY-SEC-010](#my-sec-010) | SEC | FILE privilege unrestricted by secure_file_priv | mysql,mariadb | active |
| 100 | [MY-UNDO-004](#my-undo-004) | UNDO | Purge threads at default on a server that is not purging fast enough | mysql,mariadb | active |
| 100 | [MY-WAL-002](#my-wal-002) | WAL | Redo log buffer waits | mysql,mariadb | active |
| 100 | [MY-WAL-004](#my-wal-004) | WAL | Checkpoint age near redo capacity | mariadb | active |
| 150 | [MY-CONN-008](#my-conn-008) | CONN | Thread cache misses | mysql,mariadb | active |
| 150 | [MY-CONN-010](#my-conn-010) | CONN | DNS lookups performed on every connection | mysql,mariadb | active |
| 150 | [MY-CORR-003](#my-corr-003) | CORR | No integrity verification practice | mysql,mariadb | active |
| 150 | [MY-IDX-002](#my-idx-002) | IDX | Unused index (smaller, or statistics window too short) | mysql,mariadb | active |
| 150 | [MY-IDX-007](#my-idx-007) | IDX | Single-column index on a very low-cardinality column | mysql,mariadb | active |
| 150 | [MY-IDX-008](#my-idx-008) | IDX | InnoDB persistent statistics stale | mysql,mariadb | active |
| 150 | [MY-IDX-009](#my-idx-009) | IDX | Wide composite indexes | mysql,mariadb | active |
| 150 | [MY-LOCK-007](#my-lock-007) | LOCK | Deadlocks occurring regularly | mysql,mariadb | active |
| 150 | [MY-LOCK-008](#my-lock-008) | LOCK | Table-level lock waits | mysql,mariadb | active |
| 150 | [MY-MEM-010](#my-mem-010) | MEM | Single buffer pool instance with a large pool | mysql,mariadb | active |
| 150 | [MY-MEM-012](#my-mem-012) | MEM | innodb_flush_method not O_DIRECT on Linux | mysql,mariadb | active |
| 150 | [MY-QRY-002](#my-qry-002) | QRY | Statement digest instrumentation incomplete | mysql,mariadb | active |
| 150 | [MY-QRY-011](#my-qry-011) | QRY | Statements failing or warning frequently | mysql,mariadb | active |
| 150 | [MY-QRY-013](#my-qry-013) | QRY | Sort merge passes high | mysql,mariadb | active |
| 150 | [MY-QRY-014](#my-qry-014) | QRY | Plan-hostile patterns in top statement digests | mysql,mariadb | active |
| 150 | [MY-REL-007](#my-rel-007) | REL | sys schema missing | mysql,mariadb | active |
| 150 | [MY-REL-008](#my-rel-008) | REL | Error log verbosity reduced | mysql,mariadb | active |
| 150 | [MY-SCHEMA-003](#my-schema-003) | SCHEMA | sql_require_primary_key off while primary-key-less tables exist | mysql | active |
| 150 | [MY-SCHEMA-009](#my-schema-009) | SCHEMA | Very large table not partitioned | mysql,mariadb | active |
| 150 | [MY-SCHEMA-010](#my-schema-010) | SCHEMA | Table with more than 1,000 partitions | mysql,mariadb | active |
| 150 | [MY-SCHEMA-011](#my-schema-011) | SCHEMA | Triggers on high-write tables | mysql,mariadb | active |
| 150 | [MY-SCHEMA-014](#my-schema-014) | SCHEMA | Character set or collation inconsistent within a schema | mysql,mariadb | active |
| 150 | [MY-SEC-006](#my-sec-006) | SEC | Deprecated or weak authentication plugins | mysql,mariadb | active |
| 150 | [MY-SEC-011](#my-sec-011) | SEC | No password validation policy | mysql,mariadb | active |
| 150 | [MY-SEC-012](#my-sec-012) | SEC | Legacy test database or test grants present | mysql,mariadb | active |
| 150 | [MY-WAL-003](#my-wal-003) | WAL | Binary log cache spilling to disk | mysql,mariadb | active |
| 150 | [MY-WAL-005](#my-wal-005) | WAL | innodb_io_capacity at its rotational-disk default on solid-state storage | mysql,mariadb | active |
| 150 | [MY-WAL-006](#my-wal-006) | WAL | Buffer pool dirty page ratio high | mysql,mariadb | active |
| 200 | [MY-CFG-001](#my-cfg-001) | CFG | Non-default global variables | mysql,mariadb | active |
| 200 | [MY-CFG-002](#my-cfg-002) | CFG | Persisted variables (inventory) | mysql | active |
| 200 | [MY-CFG-003](#my-cfg-003) | CFG | Variables differing from the supplied baseline | mysql,mariadb | planned |
| 200 | [MY-REL-009](#my-rel-009) | REL | Buffer pool warm-up not configured (review) | mysql,mariadb | active |
| 200 | [MY-REPL-012](#my-repl-012) | REPL | server_id left at its default in a replicated topology | mysql,mariadb | active |
| 200 | [MY-SCHEMA-012](#my-schema-012) | SCHEMA | Legacy character sets and row formats (inventory) | mysql,mariadb | active |
| 200 | [MY-SEC-013](#my-sec-013) | SEC | Accounts without password expiry (review) | mysql | active |
| 200 | [MY-SEC-014](#my-sec-014) | SEC | Listening on all interfaces (review) | mysql,mariadb | active |
| 200 | [MY-SEC-015](#my-sec-015) | SEC | No audit logging (review) | mysql,mariadb | active |
| 230 | [MY-SEC-007](#my-sec-007) | SEC | Privileged accounts (review list) | mysql,mariadb | active |
| 240 | [MY-QRY-004](#my-qry-004) | QRY | Top 10 statements by total latency | mysql,mariadb | active |
| 240 | [MY-QRY-005](#my-qry-005) | QRY | Top 10 statements by average latency | mysql,mariadb | active |
| 240 | [MY-QRY-006](#my-qry-006) | QRY | Top 10 statements by rows examined per row sent | mysql,mariadb | active |
| 240 | [MY-QRY-007](#my-qry-007) | QRY | Top 10 statements creating disk temporary tables | mysql,mariadb | active |
| 240 | [MY-QRY-008](#my-qry-008) | QRY | Top 10 statements with full table scans | mysql,mariadb | active |
| 240 | [MY-QRY-009](#my-qry-009) | QRY | Top 10 statements by execution count | mysql,mariadb | active |
| 240 | [MY-QRY-015](#my-qry-015) | QRY | Status snapshot | mysql,mariadb | active |
| 240 | [MY-QRY-016](#my-qry-016) | QRY | Per-account workload profile (MariaDB user statistics) | mariadb | active |
| 250 | [MY-CAP-004](#my-cap-004) | CAP | Schema sizes | mysql,mariadb | active |
| 250 | [MY-CAP-005](#my-cap-005) | CAP | Largest 20 tables | mysql,mariadb | active |
| 250 | [MY-CAP-009](#my-cap-009) | CAP | Growth since last snapshot | mysql,mariadb | planned |
| 250 | [MY-INFO-001](#my-info-001) | INFO | Server identity | mysql,mariadb | active |
| 250 | [MY-INFO-002](#my-info-002) | INFO | Host resources | mysql,mariadb | active |
| 250 | [MY-INFO-003](#my-info-003) | INFO | Plugins and components | mysql,mariadb | active |
| 250 | [MY-INFO-004](#my-info-004) | INFO | Replication topology | mysql,mariadb | active |
| 250 | [MY-INFO-005](#my-info-005) | INFO | Connection summary | mysql,mariadb | active |
| 250 | [MY-INFO-006](#my-info-006) | INFO | InnoDB summary | mysql,mariadb | active |
| 250 | [MY-INFO-007](#my-info-007) | INFO | Object counts | mysql,mariadb | active |
| 250 | [MY-INFO-008](#my-info-008) | INFO | Accounts summary | mysql,mariadb | active |
| 250 | [MY-INFO-009](#my-info-009) | INFO | Statistics window | mysql,mariadb | active |


---

## UNDO — Undo & purge

<a id="my-undo-001"></a>
### MY-UNDO-001 — InnoDB history list length very high

**Priority 5 (One step from fired) · Undo & purge · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** InnoDB history list length >= 1,000,000 undo records. Overridable thresholds: `hll_critical=1000000`.

**Why it matters.** The history list is the queue of undo records the purge threads have not yet reclaimed. It grows when purge cannot keep up — almost always because one old read view (a long or forgotten transaction, MY-LOCK-003) pins it. Every consistent read then walks a longer version chain, undo tablespaces grow and never shrink without truncation, and the server slows toward a stall. Column-name divergence between forks (STATUS vs ENABLED) is resolved once in 01_session.sql. @dbt_metrics_enabled = 0 means the metric is off and COUNT is a meaningless zero, so this check stays silent rather than reporting all-clear.

**How to confirm.**

`SELECT NAME, COUNT FROM information_schema.INNODB_METRICS WHERE NAME='trx_rseg_history_len';` (MariaDB adds an `ENABLED` column; MySQL calls it `STATUS`.) Then find the transaction pinning it: `SELECT trx_id, trx_started, TIMESTAMPDIFF(SECOND,trx_started,NOW()) AS age_s, trx_mysql_thread_id, trx_query FROM information_schema.INNODB_TRX ORDER BY trx_started;`

**How to fix.** 1. Find and end the oldest transaction — that is almost always the whole cause. It is usually an application session that opened a transaction and then made a network call, or a `mysqldump` without `--single-transaction` running longer than expected. 2. Watch the history list fall on its own once the read view is released; purge catches up at tens of thousands of records a second on idle hardware. 3. Only if it does not fall, raise `innodb_purge_threads` (restart) and consider `innodb_max_purge_lag` to throttle writers. Do not restart the server to 'clear' it: purge resumes from the same undo on startup and the restart also destroys every counter this report is based on.

**False positives / caveats.** A long-running backup or a legitimate analytical transaction produces exactly this signature and is not a defect. The metric is also a point-in-time reading: a batch job that runs hourly will show a high history list for a few minutes each hour and that is normal.

**Reads.** `information_schema.INNODB_METRICS trx_rseg_history_len (via @dbt_hll)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-purge-configuration.html) · Effort M / risk med

<a id="my-undo-002"></a>
### MY-UNDO-002 — InnoDB history list length elevated

**Priority 50 (Daily-briefing ceiling) · Undo & purge · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** InnoDB history list length >= 100,000 and < 1,000,000. Overridable thresholds: `hll_elevated=100000;hll_critical=1000000`.

**Why it matters.** Magnitude tier below MY-UNDO-001, with its own ID so suppressing the noisy tier can never hide the severe one (DESIGN §2.2). 100,000 is roughly where purge lag becomes visible as extra read latency on a busy OLTP server; below that a healthy server routinely sits in the thousands.

**How to confirm.**

Same query as MY-UNDO-001.

**How to fix.** Treat as an early warning: identify the workload pattern producing it before it reaches the P5 tier. If it correlates with a scheduled job, that job is the thing to change.

**False positives / caveats.** A healthy busy OLTP server routinely sits in the tens of thousands; 100,000 is a judgement call and is the first threshold worth calibrating against your own baseline.

**Reads.** `information_schema.INNODB_METRICS trx_rseg_history_len (via @dbt_hll)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-purge-configuration.html) · Effort M / risk low

<a id="my-undo-003"></a>
### MY-UNDO-003 — Undo tablespaces large

**Priority 50 (Daily-briefing ceiling) · Undo & purge · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Undo storage >= 10 GB, or >= 2 GB with innodb_undo_log_truncate OFF. Overridable thresholds: `undo_bytes=10737418240;undo_bytes_no_truncate=2147483648`.

**Why it matters.** Fork divergence, verified on MariaDB 10.11: information_schema.FILES returns ZERO rows there (it is an NDB-era table MariaDB does not populate for InnoDB), so the MySQL query would silently never fire. MariaDB therefore reads INNODB_SYS_TABLESPACES.FILE_SIZE for the separate undo tablespaces, and when innodb_undo_tablespaces = 0 (the MariaDB default) undo lives inside ibdata1 and cannot be sized separately at all — that case is reported at low confidence against the system tablespace rather than guessed at. Undo space is never returned to the filesystem unless innodb_undo_log_truncate is ON and the tablespaces are separate, which is why OFF halves the threshold.

**How to confirm.**

MySQL 8.0: `SELECT FILE_NAME, TOTAL_EXTENTS*EXTENT_SIZE AS bytes FROM information_schema.FILES WHERE FILE_TYPE='UNDO LOG';` MariaDB: `SELECT NAME, FILE_SIZE FROM information_schema.INNODB_SYS_TABLESPACES WHERE NAME LIKE 'innodb_undo%';`

**How to fix.** 1. Fix the cause first (MY-UNDO-001) — truncation cannot reclaim undo that is still needed. 2. Ensure `innodb_undo_log_truncate=ON` and at least two undo tablespaces, so InnoDB can take one offline to truncate it. 3. On MariaDB with `innodb_undo_tablespaces=0` the undo lives inside `ibdata1` and can never be reclaimed online; moving to separate undo tablespaces requires a dump and reload.

**False positives / caveats.** Freshly grown undo after a one-off bulk operation will shrink by itself once purge catches up and truncation runs. The `innodb_system` fallback figure on MariaDB includes non-undo data and is reported at low confidence for exactly that reason.

**Reads.** `information_schema.FILES (MySQL 8.0, FILE_TYPE='UNDO LOG'); information_schema.INNODB_SYS_TABLESPACES (MariaDB, NAME LIKE 'innodb_undo%'); @@GLOBAL.innodb_undo_tablespaces, @@GLOBAL.innodb_undo_log_truncate`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-undo-tablespaces.html) · Effort M / risk med

<a id="my-undo-004"></a>
### MY-UNDO-004 — Purge threads at default on a server that is not purging fast enough

**Priority 100 (Tuning & configuration detail) · Undo & purge · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** MY-UNDO-002 fired and innodb_purge_threads <= 4. Overridable thresholds: `hll_elevated=100000;purge_threads=4`.

**Why it matters.** Derived: only meaningful once the history list is already elevated, so it never fires on a healthy server that happens to run the default. MySQL 8.0 defaults innodb_purge_threads to 4, MariaDB to 4 as well; on a write-heavy server with a growing history list more threads is the first lever, and it needs a restart, which is why this is P100 and not P50.

**How to confirm.**

`SELECT @@GLOBAL.innodb_purge_threads, @@GLOBAL.innodb_max_purge_lag, @@GLOBAL.innodb_max_purge_lag_delay;`

**How to fix.** Raise `innodb_purge_threads` (4 to 8 on a write-heavy server with spare cores). It requires a restart. Only do this after confirming no single old transaction is the real cause — more purge threads cannot purge undo that a read view still needs.

**False positives / caveats.** Purge threads are almost never the true bottleneck. If MY-UNDO-001 also fired, fix that first and re-measure.

**Reads.** `@@GLOBAL.innodb_purge_threads, @dbt_hll`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-purge-configuration.html) · Effort M / risk low


---

## BAK — Backup & recovery

<a id="my-bak-001"></a>
### MY-BAK-001 — Binary logging disabled — point-in-time recovery impossible

**Priority 1 (You get fired) · Backup & recovery · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** log_bin = OFF on a self-managed primary.

**Why it matters.** server; MY-BAK-007 fires there instead) Default divergence: MySQL 8.0+ ships log_bin=ON; MySQL 5.7 and every MariaDB release ship it OFF. A MariaDB server with no explicit log_bin therefore has no PITR and no ability to add a replica, and nobody chose that. Without binary logs the recoverable window is exactly "the last full backup", whatever the backup schedule claims. Skipped on a replica: a replica's own binlog is optional unless it is also a source (log_slave_updates).

**How to confirm.**

`SELECT @@GLOBAL.log_bin, @@GLOBAL.log_bin_basename;` and confirm with `SHOW BINARY LOGS;` (needs REPLICATION CLIENT, or BINLOG MONITOR on MariaDB 10.5+).

**How to fix.** 1. Decide the recovery objective first: without binary logs the best possible RPO is the age of the newest full backup, so if that is acceptable, record the decision and suppress this check. 2. Otherwise set `log_bin`, `server_id` and `binlog_expire_logs_seconds` in the configuration file and restart — binary logging cannot be enabled dynamically on either fork. 3. Take a fresh full backup immediately afterwards: binary logs are only useful from a backup that predates them.

**False positives / caveats.** A read replica does not need its own binary log unless it is also a source or you take backups from it. Managed platforms archive outside the server, which is why this check is skipped there and MY-BAK-007 fires instead.

**Reads.** `@@GLOBAL.log_bin, @dbt_platform, @dbt_is_replica`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/binary-log.html) · Effort M / risk med

<a id="my-bak-002"></a>
### MY-BAK-002 — Last successful backup unknown or older than 7 days

**Priority 1 (You get fired) · Backup & recovery · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** No backup tool output found, or newest backup >= 7 days old. Requires: `os;interview`.

**Why it matters.** Nothing inside MySQL or MariaDB records whether the server has ever been backed up. There is no backup history table, no equivalent of `msdb.dbo.backupset`, and no status variable. The only evidence available from SQL is negative. So this check is answered from outside the server — the output of `xtrabackup` / `mariabackup`, a snapshot schedule, or a human — and until it is answered the honest report says "backup posture unverified" rather than silently omitting the most important question in the catalog.

**How to confirm.**

Look for `xtrabackup_info` or `mariadb_backup_info` under the backup directory, or ask. There is no server-side backup history table in MySQL or MariaDB — nothing in the server knows whether it has ever been backed up.

**How to fix.** Answer the question and record it in `.db-triage.yml` under `interview:` so it stops being asked. Then verify the answer by restoring, because an unverified backup is a belief rather than a backup.

**False positives / caveats.** Reported at low confidence and worded 'unverified' whenever no evidence was found. Absence of a backup tool on this host is not absence of backups — a snapshot-based strategy leaves no trace inside the server.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/backup-methods.html) · Effort M / risk low

<a id="my-bak-003"></a>
### MY-BAK-003 — Binary log retention shorter than one day

**Priority 20 (Known-dangerous, not yet hurting) · Backup & recovery · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Effective binary log retention < 86,400 s. Overridable thresholds: `min_retention_seconds=86400`.

**Why it matters.** Variable divergence, all four combinations occur in the field: MySQL 5.7            expire_logs_days only (days, integer) MySQL 8.0            binlog_expire_logs_seconds (default 2592000) AND the deprecated expire_logs_days; the seconds one wins MySQL 8.4            expire_logs_days removed MariaDB 10.6+        both exist; expire_logs_days accepts fractions Both are read from the bundle so a fork that lacks one yields NULL instead of an "Unknown system variable" error. Effective retention = the seconds setting when it is non-zero, else days x 86400. Retention shorter than the backup interval means PITR has holes: a restore of last night's full backup has no binlogs to roll forward from.

**How to confirm.**

`SELECT @@GLOBAL.binlog_expire_logs_seconds;` on MySQL 8.0+/MariaDB 10.6+, `SELECT @@GLOBAL.expire_logs_days;` elsewhere. Then `SHOW BINARY LOGS;` to see what actually remains.

**How to fix.** Set retention to at least the full-backup interval plus a safety margin — typically 3 to 7 days. Both variables are dynamic, so this needs no restart, but also set it in the configuration file so it survives one. Check disk headroom first (MY-CAP-001/002): longer retention means more disk.

**False positives / caveats.** A server whose binary logs are consumed and archived by an external tool within minutes may deliberately keep a short retention. Confirm what consumes them before extending.

**Reads.** `@dbt_v_binlog_expire_logs_seconds, @dbt_v_expire_logs_days, @@GLOBAL.log_bin`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_binlog_expire_logs_seconds) · Effort S / risk low

<a id="my-bak-004"></a>
### MY-BAK-004 — Binary logs never expire

**Priority 50 (Daily-briefing ceiling) · Backup & recovery · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** log_bin ON and both retention variables are 0.

**Why it matters.** Both retention variables zero means PURGE BINARY LOGS is the only thing that ever removes a binlog file. That is a disk-full outage with a long fuse, and the fuse burns faster the busier the server gets. Pairs with MY-CAP-006 (binlog volume) and MY-CAP-001/002 (filesystem headroom). MariaDB 10.6+ and MySQL 5.7 both default expire_logs_days to 0; MySQL 8.0 defaults binlog_expire_logs_seconds to 2592000 (30 days), so a zero there was set on purpose.

**How to confirm.**

As MY-BAK-003. Also check the volume: `SHOW BINARY LOGS;` sums the sizes.

**How to fix.** Set `binlog_expire_logs_seconds` to a real value. Do NOT run `PURGE BINARY LOGS` before confirming that every replica has consumed the logs you are about to remove — a replica still reading a purged log needs a full rebuild.

**False positives / caveats.** Some topologies deliberately keep every binary log as the archive of record. If so, the disk-space check (MY-CAP-006) is the one that matters, not this one.

**Reads.** `@dbt_v_binlog_expire_logs_seconds, @dbt_v_expire_logs_days, @@GLOBAL.log_bin`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_binlog_expire_logs_seconds) · Effort S / risk low

<a id="my-bak-005"></a>
### MY-BAK-005 — Restore never tested or RPO/RTO undocumented

**Priority 50 (Daily-briefing ceiling) · Backup & recovery · scope: interview · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Last restore test > 90 days, never, or unknown. Requires: `interview`.

**Why it matters.** A backup that has never been restored is a belief, not a backup. The restore test is also the only way to learn the real RTO: the elapsed time of a full restore plus binary log replay is invariably longer than the number in the runbook, and the difference is discovered either in a drill or in an incident.

**How to confirm.**

Ask: when did a restore last complete successfully, into what, and how long did it take?

**How to fix.** Schedule a restore test. Restore to a scratch host, start the server, and run a query that proves the data is there. Record the date and the elapsed time — the elapsed time is your real RTO, and it is usually longer than anyone expects.

**False positives / caveats.** None: this is an interview answer, not a measurement.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/backup-and-recovery.html) · Effort M / risk low

<a id="my-bak-006"></a>
### MY-BAK-006 — Binary log checksums off

**Priority 100 (Tuning & configuration detail) · Backup & recovery · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** binlog_checksum = NONE with log_bin ON.

**Why it matters.** binlog_checksum=NONE means a truncated or bit-rotted binlog event is replayed rather than rejected. Both forks default to CRC32; NONE is only needed for replicas older than MySQL 5.6, which no supported topology has.

**How to confirm.**

`SELECT @@GLOBAL.binlog_checksum;`

**How to fix.** `SET GLOBAL binlog_checksum = CRC32;` — dynamic on both forks, and also set it in the configuration file. The change takes effect at the next binary log rotation.

**False positives / caveats.** NONE is required only for replicas older than MySQL 5.6, which no supported topology has.

**Reads.** `@@GLOBAL.binlog_checksum, @@GLOBAL.master_verify_checksum equivalents`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_binlog_checksum) · Effort S / risk low

<a id="my-bak-007"></a>
### MY-BAK-007 — Managed-platform backups not verifiable from SQL

**Priority 100 (Tuning & configuration detail) · Backup & recovery · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A managed platform was fingerprinted.

**Why it matters.** On RDS, Aurora, Cloud SQL and Azure Flexible Server the backup mechanism lives outside the server, so MY-BAK-001 is skipped and nothing readable from SQL can confirm that backups exist. The specific trap worth naming: on RDS a backup retention period of 0 disables automated backups AND point-in-time recovery entirely, and it is a single number in a console that anyone with permissions can change.

**How to confirm.**

Open the platform console and read the automated-backup retention and point-in-time-recovery settings.

**How to fix.** Confirm retention is greater than zero — on RDS, a retention period of 0 disables automated backups AND point-in-time recovery entirely — and that the retention window covers your recovery objective. Then test a restore, because platform backups fail silently too.

**False positives / caveats.** None: this is a pointer, not a measurement. It fires whenever a managed platform is fingerprinted.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/backup-methods.html) · Effort S / risk low


---

## DUR — Durability

<a id="my-dur-001"></a>
### MY-DUR-001 — innodb_flush_log_at_trx_commit not 1

**Priority 10 (Active harm / serious foot-gun) · Durability · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_flush_log_at_trx_commit is 0 or 2.

**Why it matters.** Universal: the variable exists in every MySQL 5.x-9.x and MariaDB 10.x-11.x. Value 1 = flush+fsync the redo log at every commit (the only durable setting). Value 2 = write to the OS page cache, fsync once per second: an OS crash or power loss loses up to innodb_flush_log_at_timeout seconds of commits. Value 0 = write AND fsync once per second: a mysqld crash alone loses them.

**How to confirm.**

`SELECT @@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.innodb_flush_log_at_timeout;`

**How to fix.** `SET GLOBAL innodb_flush_log_at_trx_commit = 1;` — dynamic on both forks — and set it in the configuration file. Expect a throughput cost on commit-heavy workloads; if that cost is unacceptable, the correct answer is usually a battery-backed or NVMe write cache and group commit tuning, not a weaker durability setting. If the relaxed value is deliberate, record the decision and the accepted loss window.

**False positives / caveats.** Entirely legitimate on a cache, a queue, a CI database, or a replica whose source is authoritative. The finding is P10 rather than P1 precisely because the loss is bounded and often accepted on purpose.

**Reads.** `@@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.innodb_flush_log_at_timeout`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html#sysvar_innodb_flush_log_at_trx_commit) · Effort S / risk med

<a id="my-dur-002"></a>
### MY-DUR-002 — sync_binlog not 1

**Priority 10 (Active harm / serious foot-gun) · Durability · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** log_bin ON and sync_binlog <> 1.

**Why it matters.** Only meaningful when binary logging is on. sync_binlog=1 fsyncs the binlog at every commit group; anything else lets the binlog fall behind the redo log, so after a crash the server has transactions its own binlog never recorded — replicas and any PITR restore silently diverge from the source of truth. sync_binlog=0 means "never fsync, leave it to the OS".

**How to confirm.**

`SELECT @@GLOBAL.sync_binlog, @@GLOBAL.log_bin;`

**How to fix.** `SET GLOBAL sync_binlog = 1;` and persist it in the configuration file. On modern storage the cost is small because MySQL groups commits; measure before assuming otherwise. Setting it to 1 alongside `innodb_flush_log_at_trx_commit=1` is what makes the binary log and the redo log agree after a crash.

**False positives / caveats.** Same as MY-DUR-001: deliberate on a non-authoritative server. The severity comes from the combination, which MY-DUR-003 reports separately.

**Reads.** `@@GLOBAL.sync_binlog, @@GLOBAL.log_bin`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_sync_binlog) · Effort S / risk med

<a id="my-dur-003"></a>
### MY-DUR-003 — Crash-unsafe replication source

**Priority 5 (One step from fired) · Durability · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** MY-DUR-001 and MY-DUR-002 both true and replicas are connected. Requires: `PROCESS`.

**Why it matters.** Derived from MY-DUR-001 and MY-DUR-002. Neither alone justifies P5; together, on a server that other servers replicate from, they do: after a crash the source rolls back transactions it already shipped, so every replica is ahead of its source and the topology can only be repaired by rebuilding replicas. "Has replicas" is proved by a live Binlog Dump thread, which needs PROCESS. Without PROCESS the count reads 0 here and the check stays silent rather than guessing; MY-DUR-001/002 still fire on their own.

**How to confirm.**

Confirm replicas exist: `SHOW REPLICAS;` (`SHOW SLAVE HOSTS;` before MySQL 8.0.22 and on MariaDB), or `SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE COMMAND LIKE 'Binlog Dump%';`

**How to fix.** Set both `innodb_flush_log_at_trx_commit=1` and `sync_binlog=1` on the source. If throughput will not allow it, use semi-synchronous replication so at least one replica acknowledges before commit — and then watch MY-REPL-009, because semi-sync degrades to asynchronous silently.

**False positives / caveats.** A source whose replicas are disposable read caches, rebuilt from scratch on any failure, can accept this. Say so explicitly rather than leaving it as an unexamined default.

**Reads.** `@@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.sync_binlog, @@GLOBAL.log_bin, information_schema.PROCESSLIST (Binlog Dump threads, via @dbt_binlog_dump_threads)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-solutions-performance.html) · Effort S / risk med

<a id="my-dur-004"></a>
### MY-DUR-004 — InnoDB doublewrite buffer disabled

**Priority 1 (You get fired) · Durability · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_doublewrite is OFF or DETECT_ONLY.

**Why it matters.** Type divergence: MariaDB and MySQL < 8.0.30 expose this as a boolean (1/0); MySQL 8.0.30+ made it an enum (ON | OFF | DETECT_ONLY | DETECT_AND_RECOVER). Casting to CHAR and comparing against a set covers both. DETECT_ONLY writes only page metadata, so torn pages are detected but not repairable — that is still a loss of the crash-recovery guarantee, so it fires too.

**How to confirm.**

`SELECT @@GLOBAL.innodb_doublewrite;` — a boolean on MariaDB and MySQL before 8.0.30, an enum after.

**How to fix.** Set `innodb_doublewrite=ON` in the configuration file and restart. The only defensible exception is storage that guarantees atomic writes at `innodb_page_size` — ZFS with matched recordsize, or hardware with a documented atomic-write guarantee. Verify that guarantee in writing before relying on it; a filesystem that merely *usually* writes atomically is not a guarantee.

**False positives / caveats.** On ZFS the doublewrite buffer is genuinely redundant. `DETECT_ONLY` (MySQL 8.0.30+) is a deliberate middle ground for exactly that case: it detects torn pages without paying for the recovery copy.

**Reads.** `@@GLOBAL.innodb_doublewrite, @@GLOBAL.innodb_page_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-doublewrite-buffer.html) · Effort M / risk high

<a id="my-dur-005"></a>
### MY-DUR-005 — Server running in innodb_force_recovery mode

**Priority 1 (You get fired) · Durability · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_force_recovery > 0.

**Why it matters.** Universal, read-only variable. 1-3 disable parts of recovery; from 4 upward InnoDB is explicitly allowed to corrupt data structures to stay up, and from 4 (MySQL 8.0 / MariaDB 10.x) the server refuses writes. Anything above 0 is a rescue mode nobody should still be in.

**How to confirm.**

`SELECT @@GLOBAL.innodb_force_recovery;` and read the error log for why it was set.

**How to fix.** 1. Get a consistent logical dump out NOW, while the server still starts: `mysqldump`/`mydumper` of everything you need. 2. Build a clean instance and load the dump into it. 3. Do NOT simply remove the setting and restart in place — at levels 4 and above InnoDB has been permitted to leave data structures inconsistent, and the damage does not announce itself.

**False positives / caveats.** None. This is never a running configuration; it is a rescue mode someone forgot to leave.

**Reads.** `@@GLOBAL.innodb_force_recovery`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/forcing-innodb-recovery.html) · Effort L / risk high

<a id="my-dur-006"></a>
### MY-DUR-006 — InnoDB page checksums disabled

**Priority 50 (Daily-briefing ceiling) · Durability · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_checksum_algorithm = none.

**Why it matters.** 'none' means InnoDB writes a constant instead of a checksum and never verifies it. Silent bit rot in the storage stack then reaches the buffer pool as if it were good data. The PostgreSQL analogue is PG-CORR-004 (data checksums off).

**How to confirm.**

`SELECT @@GLOBAL.innodb_checksum_algorithm;`

**How to fix.** Set it to `crc32` (hardware-accelerated on any modern CPU, so the cost is negligible) in the configuration file and restart. Existing pages are re-checksummed as they are written; there is no offline conversion step.

**False positives / caveats.** The `none` setting was a performance workaround from an era before CRC32 was hardware-accelerated. There is no current reason for it.

**Reads.** `@dbt_v_innodb_checksum_algorithm (bundle: present in MySQL 5.6+ and MariaDB 10.x, but read through the bundle so a fork that drops it yields NULL and this check stays silent instead of erroring)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html#sysvar_innodb_checksum_algorithm) · Effort L / risk med

<a id="my-dur-007"></a>
### MY-DUR-007 — Non-transactional storage engines in use

**Priority 50 (Daily-briefing ceiling) · Durability · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Any user table uses a non-transactional storage engine. Overridable thresholds: `max_rows=20`.

**Why it matters.** MyISAM and Aria(transactional=0) have no crash recovery for data, take table-level locks for every write, and cannot participate in a transaction — so a statement that fails halfway leaves the table half-updated and the binary log records it as if it succeeded. MEMORY/CSV/ARCHIVE/BLACKHOLE are called out separately because their non-durability is usually the point. Emission shape (b) per DESIGN §2.1: one summary row per engine with a top-N list, so a 4,000-table legacy schema does not produce 4,000 findings. MariaDB note: mysql.* system tables are Aria and are excluded, as is the MariaDB-specific `sys` schema copy.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, ENGINE, ROUND((DATA_LENGTH+INDEX_LENGTH)/1048576,1) AS mb FROM information_schema.TABLES WHERE ENGINE NOT IN ('InnoDB') AND TABLE_TYPE='BASE TABLE' AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') ORDER BY mb DESC;`

**How to fix.** Convert with `ALTER TABLE ... ENGINE=InnoDB`, on a live server through `pt-online-schema-change` or `gh-ost`. Two things to check first: MyISAM `FULLTEXT` and spatial indexes behave differently under InnoDB, and MyISAM allows an `AUTO_INCREMENT` as a non-leading column of a composite key while InnoDB does not. Convert one table, verify, then batch the rest.

**False positives / caveats.** MEMORY tables used as deliberate scratch space, and CSV tables used as an export target, are working as intended. The `mysql` system schema is Aria on MariaDB by design and is excluded.

**Reads.** `information_schema.TABLES`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/storage-engines.html) · Effort L / risk med

<a id="my-dur-008"></a>
### MY-DUR-008 — Replica not crash-safe

**Priority 100 (Tuning & configuration detail) · Durability · scope: replica · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Replica with relay_log_recovery OFF, or FILE-based position repositories.

**Why it matters.** Only meaningful on a replica (@dbt_is_replica comes from performance_schema.replication_connection_configuration, which exists on both forks and is empty on a non-replica). Version divergence: master_info_repository / relay_log_info_repository were removed in MySQL 8.4 (positions are always in InnoDB tables there) and never existed under those names on MariaDB, which uses relay_log_recovery plus crash-safe rpl.* tables. NULL from the bundle therefore means "this fork does not have the FILE-vs-TABLE hazard", and only relay_log_recovery is judged.

**How to confirm.**

`SELECT @@GLOBAL.relay_log_recovery;` and, on MySQL before 8.4, `SELECT @@GLOBAL.master_info_repository, @@GLOBAL.relay_log_info_repository;`

**How to fix.** Set `relay_log_recovery=ON` in the configuration file and restart the replica. On MySQL before 8.4 also set both repositories to `TABLE` so the applied position is committed in the same InnoDB transaction as the data. MySQL 8.4 removed the choice and always uses tables.

**False positives / caveats.** A replica that is rebuilt from a backup after every incident does not need crash safety; everything else does.

**Reads.** `@dbt_v_relay_log_recovery, @dbt_v_master_info_repository, @dbt_v_relay_log_info_repository, @dbt_is_replica`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replica-logs.html) · Effort S / risk low


---

## CORR — Corruption signals

<a id="my-corr-001"></a>
### MY-CORR-001 — InnoDB corruption messages in the error log

**Priority 1 (You get fired) · Corruption signals · scope: host · cost 2 · deep pass · engine: mysql · since 0.1.0**

**What fires it.** InnoDB integrity messages in performance_schema.error_log within the lookback window. Overridable thresholds: `lookback_hours=168`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Availability, verified: performance_schema.error_log exists only in MySQL 8.0.22 and later. MariaDB 10.11 has no equivalent table at all — the error log is a file and nothing but the OS can read it — so on MariaDB this check emits nothing and the runner records it as skipped with reason `version`. The file path for a manual read is @@GLOBAL.log_error, reported by MY-INFO-001. The wording is deliberately "reported", never "corrupt": these strings are InnoDB telling you it could not trust a page, which is also what a failing disk controller or a bad backup restore looks like.

**How to confirm.**

MySQL 8.0.22+: `SELECT LOGGED, PRIO, ERROR_CODE, DATA FROM performance_schema.error_log WHERE DATA LIKE '%corrupt%' ORDER BY LOGGED DESC LIMIT 50;` MariaDB and older MySQL: read the file at `SELECT @@GLOBAL.log_error;` — there is no SQL interface. Then identify the object with `innochecksum` on the offline datafile, or `CHECK TABLE ... EXTENDED` in a maintenance window (both are writes or heavy reads, so db-triage never runs them).

**How to fix.** 1. Stop writing to the affected object. 2. Take a fresh backup of what is still readable before doing anything else — recovery attempts can make things worse. 3. Restore the object from a known-good backup and replay binary logs, or rebuild it from a replica. 4. Then find the cause: this is usually failing storage, and the same hardware will do it again.

**False positives / caveats.** The wording is deliberately 'reported', not 'corrupt'. These messages also appear after a bad restore, after a filesystem-level copy of a running server, and on storage that lied about a flush. They are a signal to investigate, not a diagnosis.

**Reads.** `performance_schema.error_log`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/error-log.html) · Effort L / risk high

<a id="my-corr-002"></a>
### MY-CORR-002 — Crash-recovery messages in the error log

**Priority 20 (Known-dangerous, not yet hurting) · Corruption signals · scope: host · cost 2 · deep pass · engine: mysql · since 0.1.0**

**What fires it.** Crash or unclean-shutdown messages in performance_schema.error_log. Overridable thresholds: `lookback_hours=168`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Same availability gate as MY-CORR-001 (MySQL 8.0.22+ only; MariaDB has no SQL-readable error log). Separated from MY-CORR-001 at P20 because a crash is evidence of an event, not of damage: InnoDB recovering cleanly is the system working. What it changes is the meaning of every counter-based finding in the report, which is why the restart itself is also reported by MY-REL-005.

**How to confirm.**

As MY-CORR-001, searching for `Starting crash recovery` and `mysqld got signal`. Correlate with `SELECT @@GLOBAL.hostname;` uptime and with MY-REL-005.

**How to fix.** Establish why the server stopped: OOM killer (check `dmesg` and MY-MEM-007), a signal, a hardware fault, or an orchestrated restart. A crash-recovered server is consistent — InnoDB's job is to make it so — but the cause will recur.

**False positives / caveats.** A planned restart also logs recovery messages on some builds. The presence of recovery is not itself a problem; the absence of an explanation is.

**Reads.** `performance_schema.error_log`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/error-log.html) · Effort M / risk low

<a id="my-corr-003"></a>
### MY-CORR-003 — No integrity verification practice

**Priority 150 (Hygiene & low-confidence heuristics) · Corruption signals · scope: interview · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** No integrity verification practice reported in the interview. Requires: `interview`.

**Why it matters.** MySQL has no `DBCC CHECKDB` and no scheduled equivalent. `CHECK TABLE` is a heavy read that locks, `innochecksum` requires the file to be offline, and neither runs by itself. The practical substitute is verifying backups — a restore that succeeds and passes a query is evidence about both the backup and the data. If nothing does that, silent corruption is discovered by a user.

**How to confirm.**

Ask: what verifies that the data on disk is readable, and when did it last run?

**How to fix.** Schedule something: `innochecksum` against a backup copy, a restore test that runs `CHECK TABLE`, or a `pt-table-checksum` run against replicas. Verifying a backup does double duty — it tests both the backup and the data.

**False positives / caveats.** None: an interview answer.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/check-table.html) · Effort M / risk low


---

## REPL — Replication & HA

<a id="my-repl-001"></a>
### MY-REPL-001 — Replication stopped with an error

**Priority 1 (You get fired) · Replication & HA · scope: replica · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A replication thread is not running and an error is recorded. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Fork divergence is resolved in 01_session.sql. On MariaDB the receiver (I/O) thread state is not readable from SQL at all, so @dbt_repl_io_state is NULL and the details say which threads were actually observed rather than implying a clean receiver. The applier state and its last error ARE readable on both. A replica stopped with an error is a failover target that is silently stale: the monitoring dashboards still show the host up, and the data is frozen at the moment the error hit.

**How to confirm.**

MySQL: `SHOW REPLICA STATUS\G` (`SHOW SLAVE STATUS\G` before 8.0.22) and read `Last_IO_Error` / `Last_SQL_Error`. From SQL: `SELECT * FROM performance_schema.replication_applier_status_by_worker\G` and `SELECT * FROM performance_schema.replication_connection_status\G`. MariaDB: `SHOW ALL SLAVES STATUS\G` — there is no SQL-readable receiver-thread state on MariaDB at all.

**How to fix.** 1. Read the error before restarting anything: the error text names the failing transaction and usually the table. 2. For a duplicate-key or row-not-found error, find out WHY the replica diverged rather than skipping the event — `pt-table-checksum` will tell you how much else is already different. 3. Skipping with `sql_slave_skip_counter` or `SET GLOBAL gtid_next` makes the symptom go away and the divergence permanent; it is a deliberate decision, not a fix, and it leaves the GTID gap that MY-REPL-016 reports.

**False positives / caveats.** A replica stopped deliberately for maintenance shows as MY-REPL-002, not this. On MariaDB only the applier half is visible, so a stopped receiver with a running applier is NOT detected — run SHOW SLAVE STATUS by hand.

**Reads.** `@dbt_repl_io_state / @dbt_repl_sql_state / @dbt_repl_err_* (01_session.sql §6c)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-administration-status.html) · Effort M / risk med

<a id="my-repl-002"></a>
### MY-REPL-002 — Replication threads stopped without an error

**Priority 10 (Active harm / serious foot-gun) · Replication & HA · scope: replica · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A replication thread is not running and no error is recorded. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** No error recorded means somebody ran STOP REPLICA (STOP SLAVE) and did not start it again — a maintenance window that was never closed, or a script that exited early. Separated from MY-REPL-001 because the fix is different: there is nothing to diagnose, only something to restart, after confirming why. MariaDB caveat as in MY-REPL-001: the receiver thread is invisible to SQL, so a MariaDB replica whose applier is running but whose receiver is stopped will NOT fire here. That gap is listed in reference/checks-mysql.md.

**How to confirm.**

As MY-REPL-001. `SELECT SERVICE_STATE FROM performance_schema.replication_applier_status;`

**How to fix.** Establish why it was stopped before starting it: a stopped replica is sometimes deliberate (a schema change being applied out of band, a point-in-time position being held). Then `START REPLICA;` and watch the lag drain. If the source has already purged the binary logs this replica needs, it must be rebuilt.

**False positives / caveats.** Same MariaDB blind spot as MY-REPL-001.

**Reads.** `@dbt_repl_io_state / @dbt_repl_sql_state / @dbt_repl_err_no`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-administration-status.html) · Effort S / risk med

<a id="my-repl-003"></a>
### MY-REPL-003 — Replica lag over 5 minutes

**Priority 5 (One step from fired) · Replication & HA · scope: replica · cost 0 · fast pass · engine: mysql · since 0.1.0**

**What fires it.** Applier lag >= 300 s. Overridable thresholds: `lag_critical_seconds=300;lag_warn_seconds=30`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Lag source, in the design's preference order: the applier's APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP when a transaction is in flight, otherwise LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP. Those columns exist only in MySQL 8.0+; MariaDB has no SQL-readable lag at all, so on MariaDB @dbt_repl_lag_s is NULL and this check emits nothing rather than a false all-clear. Seconds_Behind_Source is deliberately not used even where it exists: it reads 0 while the receiver thread is far behind, and NULL when replication is stopped. Confidence is medium, never high: on an idle source the last-applied timestamp measures how long the source has been quiet, not how far behind this replica is. The details say which of the two readings was used.

**How to confirm.**

`SELECT * FROM performance_schema.replication_applier_status_by_worker\G` and compare `APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP` with `NOW()`. Do not trust `Seconds_Behind_Source`: it reports 0 whenever the applier has caught up with a relay log that the receiver has not finished fetching, and NULL whenever replication is stopped. On MariaDB there is no SQL-readable lag at all — use `SHOW ALL SLAVES STATUS` or a `pt-heartbeat` table.

**How to fix.** 1. Determine whether the applier or the receiver is behind — they have different fixes. 2. An applier behind is usually single-threaded (MY-REPL-011), blocked on a table with no primary key (MY-SCHEMA-001), or competing with local queries. 3. A receiver behind is network or source-side. 4. A large single transaction on the source serialises everything behind it regardless of parallel workers.

**False positives / caveats.** Lag measured from the last-applied timestamp reads as elapsed idle time on a quiet source, which is why this check is medium confidence and names the reading it used.

**Reads.** `@dbt_repl_lag_s / @dbt_repl_lag_src (01_session.sql §6c)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-administration-status.html) · Effort M / risk low

<a id="my-repl-004"></a>
### MY-REPL-004 — Replica lag over 30 seconds

**Priority 50 (Daily-briefing ceiling) · Replication & HA · scope: replica · cost 0 · fast pass · engine: mysql · since 0.1.0**

**What fires it.** Applier lag >= 30 s and < 300 s. Overridable thresholds: `lag_warn_seconds=30;lag_critical_seconds=300`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Magnitude tier below MY-REPL-003, own ID so the tiers suppress independently. Same MariaDB limitation: no SQL-readable lag, so this never fires there.

**How to confirm.**

As MY-REPL-003.

**How to fix.** As MY-REPL-003, with less urgency. Thirty seconds matters mainly for read-your-writes traffic routed to replicas; if none is, the threshold is worth raising in `.db-triage.yml`.

**False positives / caveats.** As MY-REPL-003.

**Reads.** `@dbt_repl_lag_s / @dbt_repl_lag_src`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-administration-status.html) · Effort M / risk low

<a id="my-repl-005"></a>
### MY-REPL-005 — Replica is writable

**Priority 10 (Active harm / serious foot-gun) · Replication & HA · scope: replica · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Replica with read_only OFF or super_read_only OFF.

**Why it matters.** Fork divergence: super_read_only exists in MySQL 5.7+ but NOT in MariaDB (verified absent on 10.11). It is read from the bundle, so on MariaDB it is NULL and only read_only is judged — with the details saying so, because on MariaDB an account holding SUPER can still write to a read_only replica and there is no second lock to close that hole. A writable replica is one typo or one misrouted connection away from a split brain that replication will not detect and cannot merge.

**How to confirm.**

`SELECT @@GLOBAL.read_only, @@GLOBAL.super_read_only;` (MariaDB has no `super_read_only`).

**How to fix.** `SET GLOBAL super_read_only = ON;` on MySQL — it implies `read_only` and also blocks accounts holding SUPER, which plain `read_only` does not. Persist both in the configuration file. On MariaDB, `read_only=ON` plus tightly held SUPER / READ_ONLY ADMIN is the strongest available guard, and there is no second lock.

**False positives / caveats.** A replica that is deliberately writable — a reporting instance with its own scratch tables, a delayed replica used for recovery drills — is a real pattern. Record it so this stops firing.

**Reads.** `@@GLOBAL.read_only, @dbt_v_super_read_only, @dbt_is_replica`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_super_read_only) · Effort S / risk med

<a id="my-repl-006"></a>
### MY-REPL-006 — GTID not in use in a replicated topology

**Priority 50 (Daily-briefing ceiling) · Replication & HA · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Replication configured and GTID not in use.

**Why it matters.** Fork divergence: MySQL has a server-wide @@gtid_mode. MariaDB has no such variable at all — GTID is chosen per replication connection (MASTER_USE_GTID = slave_pos | current_pos | no), which is why the authoritative reading on MariaDB is USING_GTID from performance_schema.replication_connection_configuration, captured in 01_session.sql §6c. Without GTID, re-pointing a replica at a new source means computing a binlog file and offset by hand under time pressure, which is where failovers go wrong. gtid_strict_mode/ASSIGN_GTIDS_TO_ANONYMOUS_TRANSACTIONS are the follow-on hardening, not the headline.

**How to confirm.**

MySQL: `SELECT @@GLOBAL.gtid_mode, @@GLOBAL.enforce_gtid_consistency;` MariaDB: `SELECT USING_GTID FROM performance_schema.replication_connection_configuration;` and `SHOW ALL SLAVES STATUS\G` (`Using_Gtid`).

**How to fix.** MySQL: enable GTID with the documented online rollout — `enforce_gtid_consistency=WARN`, then `ON`, then `gtid_mode` through `OFF_PERMISSIVE` and `ON_PERMISSIVE` to `ON`, on every server in the topology, in order. Do not jump straight to ON. MariaDB: `STOP SLAVE; CHANGE MASTER TO MASTER_USE_GTID=slave_pos; START SLAVE;` on each replica, and consider `gtid_strict_mode=ON` afterwards.

**False positives / caveats.** A single-source topology that is never failed over survives without GTID. The cost is paid only during an unplanned failover, which is exactly when nobody has time to compute binary log positions by hand.

**Reads.** `@dbt_v_gtid_mode (MySQL), @dbt_repl_using_gtid (both), @dbt_v_gtid_strict_mode / @dbt_v_gtid_binlog_pos (MariaDB)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids.html) · Effort L / risk med

<a id="my-repl-007"></a>
### MY-REPL-007 — Statement-based binary logging

**Priority 50 (Daily-briefing ceiling) · Replication & HA · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** log_bin ON and binlog_format = STATEMENT.

**Why it matters.** Universal variable. STATEMENT replicates the SQL text, so anything non-deterministic (UUID(), NOW() in some contexts, LIMIT without ORDER BY, UDFs, triggers with side effects, INSERT ... SELECT on a table with an AUTO_INCREMENT and a unique key) produces different rows on the replica, and nothing detects the divergence. Both forks default to ROW on current releases; MariaDB historically defaulted to MIXED. MIXED is not flagged here: it is only unsafe for statements the server itself cannot classify, which is not observable from the catalog. That caveat is in the reference doc rather than being asserted as a finding.

**How to confirm.**

`SELECT @@GLOBAL.binlog_format;`

**How to fix.** `SET GLOBAL binlog_format = ROW;` takes effect for new sessions; existing connections keep the old value until they reconnect, so plan a rolling application restart. Set `binlog_row_image=FULL` unless something downstream specifically wants MINIMAL. Check disk headroom first: ROW events are larger than statements.

**False positives / caveats.** STATEMENT produces much smaller binary logs for bulk updates, which is occasionally a deliberate trade on a workload known to be fully deterministic. 'Known to be deterministic' is a strong claim; verify it.

**Reads.** `@@GLOBAL.binlog_format, @@GLOBAL.log_bin`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/binary-log-formats.html) · Effort M / risk med

<a id="my-repl-008"></a>
### MY-REPL-008 — Replication errors are being skipped

**Priority 50 (Daily-briefing ceiling) · Replication & HA · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** skip_errors is set, or exec_mode is IDEMPOTENT.

**Why it matters.** Name divergence: MySQL 8.0.26+ renamed slave_skip_errors to replica_skip_errors and slave_exec_mode to replica_exec_mode, keeping the old names as deprecated aliases until 8.4 removed them. MariaDB keeps only the slave_* spelling. Both spellings are read from the bundle and COALESCEd, so the check works on 5.7, 8.0, 8.4, 9.x and every MariaDB. Either setting makes replication continue past an error instead of stopping, which converts a loud failure into silent, permanent divergence. IDEMPOTENT exec mode turns duplicate-key and not-found row events into no-ops.

**How to confirm.**

`SELECT @@GLOBAL.replica_skip_errors, @@GLOBAL.replica_exec_mode;` (MariaDB and older MySQL: `slave_skip_errors`, `slave_exec_mode`).

**How to fix.** 1. Assume the replica has already diverged and measure it with `pt-table-checksum` before changing anything. 2. Remove the setting so future errors stop replication loudly. 3. Repair the divergence — `pt-table-sync`, or a rebuild. Removing the skip without repairing simply means the next error surfaces on top of unknown existing damage.

**False positives / caveats.** `IDEMPOTENT` is legitimate and required in some multi-source and conflict-tolerant topologies. If yours is one, record it; if it is not, this is silent data divergence.

**Reads.** `@dbt_v_replica_skip_errors / @dbt_v_slave_skip_errors, @dbt_v_replica_exec_mode / @dbt_v_slave_exec_mode`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-replica.html#sysvar_replica_skip_errors) · Effort S / risk high

<a id="my-repl-009"></a>
### MY-REPL-009 — Semi-synchronous replication has fallen back to asynchronous

**Priority 50 (Daily-briefing ceiling) · Replication & HA · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Semi-sync enabled but its status variable reads OFF.

**Why it matters.** Name divergence: MySQL 8.0.26 renamed every rpl_semi_sync_master_* to rpl_semi_sync_source_* (and 8.4 moved the plugin to a component with rpl_semi_sync_source_* only); MariaDB keeps the master spelling. Both are read and COALESCEd, and both are absent unless the plugin is installed, in which case this check is silent. The hazard is specific to semi-sync: when no replica acknowledges within rpl_semi_sync_source_timeout the source does not block — it silently reverts to asynchronous and keeps committing. The durability guarantee people believe they bought is gone and nothing raises an alarm. This is the MySQL analogue of PG-REPL-001, except Postgres hangs and MySQL lies.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Rpl_semi_sync%';` — compare `..._status` (ON/OFF) with the `rpl_semi_sync_source_enabled` variable, and watch `..._no_tx` grow.

**How to fix.** 1. Find why acknowledgements timed out: replica down, network latency above `rpl_semi_sync_source_timeout`, or a replica too slow to write its relay log. 2. Fix that. 3. Semi-sync re-enables itself automatically once a replica acknowledges again, so the fix is upstream of the setting. 4. Add monitoring on `Rpl_semi_sync_source_status` — this is precisely the failure that is invisible without it.

**False positives / caveats.** A brief fallback during a replica restart is expected. A persistent OFF with a growing `no_tx` counter is not.

**Reads.** `@dbt_v_rpl_semi_sync_source_enabled / @dbt_v_rpl_semi_sync_master_enabled, @dbt_s_rpl_semi_sync_source_status / @dbt_s_rpl_semi_sync_master_status, @dbt_s_rpl_semi_sync_*_no_tx`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-semisync.html) · Effort M / risk med

<a id="my-repl-010"></a>
### MY-REPL-010 — Group Replication member not ONLINE

**Priority 5 (One step from fired) · Replication & HA · scope: cluster · cost 0 · fast pass · engine: mysql · since 0.1.0**

**What fires it.** A group member is not ONLINE, or the group has fewer than 3 members. Overridable thresholds: `min_members=3`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** MySQL only. MariaDB has no Group Replication and no such table (verified absent on 10.11) — Galera is its cluster technology and exposes wsrep_* status variables instead, which is a different check not in this catalog. The table-existence gate keeps MariaDB from erroring. A member in RECOVERING, UNREACHABLE or ERROR state is not carrying traffic and is not counted toward quorum; a group that drops below a majority stops accepting writes entirely.

**How to confirm.**

`SELECT MEMBER_HOST, MEMBER_PORT, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;`

**How to fix.** A member in RECOVERING is applying its backlog and will join; one in ERROR or UNREACHABLE will not. Read that member's error log. A group below a majority stops accepting writes entirely and needs `group_replication_force_members` to recover — a destructive last resort that must be run on exactly one node.

**False positives / caveats.** MySQL only. MariaDB's cluster technology is Galera, which exposes `wsrep_*` status variables and is not covered by this catalog.

**Reads.** `performance_schema.replication_group_members`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/group-replication-monitoring.html) · Effort M / risk high

<a id="my-repl-011"></a>
### MY-REPL-011 — Single-threaded replica applier while lagging

**Priority 100 (Tuning & configuration detail) · Replication & HA · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Replica lagging with <= 1 applier worker. Overridable thresholds: `lag_warn_seconds=30`.

**Why it matters.** Name divergence: MySQL 8.0.26+ replica_parallel_workers (default 4 from 8.0.27), older MySQL and all MariaDB slave_parallel_workers (default 0). Both spellings are COALESCEd from the bundle. Derived: only fires when lag is already measurable, so a healthy replica that happens to run one applier thread is not nagged. Where lag is unreadable (MariaDB, see MY-REPL-003) this check cannot fire either — that gap is documented rather than worked around with a guess.

**How to confirm.**

`SELECT @@GLOBAL.replica_parallel_workers, @@GLOBAL.replica_parallel_type;` (MariaDB: `slave_parallel_workers`, `slave_parallel_mode`).

**How to fix.** Set 4 to 8 workers and, on MySQL, `replica_parallel_type=LOGICAL_CLOCK` with `replica_preserve_commit_order=ON`. The bigger lever is on the SOURCE: `binlog_transaction_dependency_tracking=WRITESET` lets replicas parallelise far more aggressively.

**False positives / caveats.** Parallel appliers cannot help when one large transaction dominates, or when the bottleneck is a table with no primary key (MY-SCHEMA-001).

**Reads.** `@dbt_v_replica_parallel_workers / @dbt_v_slave_parallel_workers, @dbt_repl_lag_s`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-replica.html#sysvar_replica_parallel_workers) · Effort S / risk low

<a id="my-repl-012"></a>
### MY-REPL-012 — server_id left at its default in a replicated topology

**Priority 200 (Non-default configuration) · Replication & HA · scope: setting · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** server_id is 0 or 1 in a replicated topology.

**Why it matters.** Inventory, not a fault: nothing readable from one node can prove another node shares this id. It is recorded because duplicate server_ids are a classic cause of replicas that connect, disconnect and reconnect in a loop, and the symptom (I/O thread flapping) rarely points at the cause. Fork divergence: MySQL has @@server_uuid, which is generated per data directory and is genuinely unique; MariaDB has no server_uuid at all, so the numeric server_id is the only identity it has.

**How to confirm.**

`SELECT @@GLOBAL.server_id, @@GLOBAL.server_uuid;` and compare across the fleet — it cannot be done from one node.

**How to fix.** Give each server a unique non-zero `server_id`. Changing it requires a restart and, on file-and-position replication, care about what the replicas are tracking.

**False positives / caveats.** Inventory only. A duplicate `server_id` cannot be detected from a single node, which is why this is P200 and low confidence.

**Reads.** `@@GLOBAL.server_id, @dbt_v_server_uuid`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options.html#sysvar_server_id) · Effort S / risk low

<a id="my-repl-013"></a>
### MY-REPL-013 — Replication heartbeat or connection retry misconfigured

**Priority 100 (Tuning & configuration detail) · Replication & HA · scope: replica · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Retry interval >= 600 s, retry count 0, or heartbeat interval 0. Overridable thresholds: `max_retry_interval=600;min_heartbeat_seconds=0`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** These three columns exist under the same names on MySQL 5.7+ and MariaDB 10.5+ (verified on 10.11), so no branch is needed — unlike SHOW REPLICA STATUS's Connect_Retry / Source_Retry_Count, which cannot be selected from. A long retry interval means a dead source goes unnoticed for that long; a zero heartbeat interval means the receiver only discovers a silently dropped connection when slave_net_timeout expires, which defaults to 60 s and is often raised to an hour.

**How to confirm.**

`SELECT * FROM performance_schema.replication_connection_configuration\G`

**How to fix.** `CHANGE REPLICATION SOURCE TO SOURCE_CONNECT_RETRY=10, SOURCE_RETRY_COUNT=86400, SOURCE_HEARTBEAT_PERIOD=10;` (MariaDB: `CHANGE MASTER TO MASTER_CONNECT_RETRY=..., MASTER_HEARTBEAT_PERIOD=...`). A heartbeat shorter than `slave_net_timeout`/2 is what makes a silently dropped connection detectable in seconds rather than minutes.

**False positives / caveats.** A deliberately long retry interval is occasionally used to avoid hammering a source that is known to be down for a scheduled window.

**Reads.** `performance_schema.replication_connection_configuration (CONNECTION_RETRY_INTERVAL, CONNECTION_RETRY_COUNT, HEARTBEAT_INTERVAL) via @dbt_repl_retry_* / @dbt_repl_heartbeat, set in 01_session.sql §6c`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-administration-status.html) · Effort S / risk low

<a id="my-repl-014"></a>
### MY-REPL-014 — binlog_row_image MINIMAL with logical consumers configured

**Priority 100 (Tuning & configuration detail) · Replication & HA · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** binlog_row_image = MINIMAL with logical consumers declared. Requires: `interview`.

**Why it matters.** Requires the .db-triage.yml baseline to declare CDC consumers (Debezium, Maxwell, Canal, a data-lake sink). Without that declaration the runner does not surface this row, because MINIMAL is a perfectly good setting for a topology whose only consumers are MySQL replicas — it is only wrong when something downstream needs the unchanged columns of an UPDATE. binlog_row_metadata (MySQL 8.0+; NULL on MariaDB) decides whether column names and types travel with the events, which most CDC tools need to avoid reconstructing the schema from a side channel.

**How to confirm.**

`SELECT @@GLOBAL.binlog_row_image, @@GLOBAL.binlog_row_metadata;`

**How to fix.** Set `binlog_row_image=FULL` and, on MySQL 8.0+, `binlog_row_metadata=FULL`, so downstream consumers receive complete before- and after-images with column names. Binary logs get larger; check MY-CAP-006 first.

**False positives / caveats.** MINIMAL is the right setting when the only consumers are MySQL replicas. This check only surfaces when the baseline declares logical consumers.

**Reads.** `@@GLOBAL.binlog_row_image, @dbt_v_binlog_row_metadata`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_binlog_row_image) · Effort S / risk low

<a id="my-repl-015"></a>
### MY-REPL-015 — Replication filters configured

**Priority 50 (Daily-briefing ceiling) · Replication & HA · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Any replication filter is configured.

**Why it matters.** NOT in the design's §5.2 table; added because filters are one of the few MySQL replication settings that silently make a replica a non-backup and a non-failover-target, and requirement lists them explicitly. Why it matters: a filtered replica is missing data by design, so it can never be promoted and a restore from it is incomplete. Worse, replicate_ignore_db and replicate_do_db act on the *default database of the statement*, not on the tables it touches, so a cross-schema statement issued with the wrong USE is filtered or not filtered contrary to intent — that is a documented behaviour, not a bug, and it is why the *_wild_*_table forms are the safer spelling. Reported at P50 rather than higher because a filter is usually deliberate; what is almost never deliberate is the failover plan that forgot about it.

**How to confirm.**

MySQL 8.0: `SELECT * FROM performance_schema.replication_applier_global_filters;` and `replication_applier_filters`. MariaDB: `SHOW ALL SLAVES STATUS\G` and the `replicate_*` variables.

**How to fix.** Decide deliberately whether this replica is a failover target. If it is, remove the filters and re-seed it. If it is not, document that — and make sure the failover runbook and the backup policy both know it. Prefer `replicate_wild_do_table` / `replicate_wild_ignore_table` over the `_db` forms, which test the statement's default database rather than the tables it touches.

**False positives / caveats.** Filters are usually deliberate. What is usually not deliberate is a filtered replica being listed as a failover candidate or a backup source.

**Reads.** `performance_schema.replication_applier_filters / replication_applier_global_filters (MySQL 8.0.1+); @dbt_v_replicate_* bundle variables (MariaDB, and MySQL where the performance_schema tables are unavailable)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-rules.html) · Effort M / risk med

<a id="my-repl-016"></a>
### MY-REPL-016 — GTID set has gaps

**Priority 20 (Known-dangerous, not yet hurting) · Replication & HA · scope: cluster · cost 0 · fast pass · engine: mysql · since 0.1.0**

**What fires it.** gtid_executed contains more intervals than source UUIDs.

**Why it matters.** NOT in the design's §5.2 table; added because requirement lists GTID gaps explicitly and nothing else in the catalog detects them. MySQL's gtid_executed is a set of UUID:interval entries, e.g. 3E11FA47-...:1-5:8-12,8C4C4D0F-...:1-900 A UUID with MORE THAN ONE interval means transactions in between were never executed here: skipped with sql_slave_skip_counter, injected empty with gtid_next, or lost. Those numbers can never be filled in, so a replica built from this server inherits the hole, and AUTO_POSITION will not re-fetch them. Detection is textual and deliberately conservative: total colons across the whole set versus the number of UUID entries (commas + 1). More colons than UUIDs means at least one UUID carries a second interval. Confidence is medium because it identifies that a gap exists, not which transactions are missing. MariaDB is excluded: its GTID format is domain-server-sequence (0-1-4711) with no interval notation, so a gap is not expressible in the variable and this test would be meaningless there.

**How to confirm.**

`SELECT @@GLOBAL.gtid_executed, @@GLOBAL.gtid_purged;` — look for a UUID with more than one interval, e.g. `uuid:1-5:8-12`.

**How to fix.** The missing transactions cannot be re-fetched: `AUTO_POSITION` treats the executed set as authoritative and will not ask for them again. 1. Determine what was skipped and whether it mattered — the binary logs on the source, if still present, will tell you. 2. If the data matters, reconcile with `pt-table-checksum` and `pt-table-sync`, or re-seed this server from a backup. 3. Prevent recurrence: enable `gtid_strict_mode` (MariaDB) or stop using `sql_slave_skip_counter` (MySQL).

**False positives / caveats.** Gaps are also created deliberately by injecting empty transactions to skip a known-bad event, so an expected gap is not a defect. Detection is textual: it establishes that a gap exists, not which transactions are missing. MariaDB's GTID format cannot express intervals, so this check is MySQL-only.

**Reads.** `@dbt_v_gtid_executed, @dbt_v_gtid_purged`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids-concepts.html) · Effort L / risk high


---

## WAL — Redo log & binary log

<a id="my-wal-001"></a>
### MY-WAL-001 — Redo log capacity below one hour of writes

**Priority 50 (Daily-briefing ceiling) · Redo log & binary log · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Redo capacity holds less than one hour of the observed redo write rate. Overridable thresholds: `redo_hours=1;min_write_rate_bytes_per_hour=10485760;small_capacity_bytes=104857600`.

**Why it matters.** Version divergence: MySQL 8.0.30 introduced innodb_redo_log_capacity (default 100 MB) and deprecated the file-size x file-count arithmetic. MariaDB 10.5 REMOVED innodb_log_files_in_group entirely (there is one file), so on MariaDB capacity is innodb_log_file_size alone. Both readings come from the bundle and the fallback chain covers 5.7, 8.0 pre-.30, 8.0.30+, 8.4, 9.x and MariaDB. Sizing rule (Percona's): the redo log should hold roughly an hour of writes. When it cannot, checkpoints become continuous, InnoDB switches to aggressive adaptive flushing, and throughput collapses in bursts rather than degrading smoothly. Rate is bytes written since restart divided by uptime, so its confidence follows the counter window (@dbt_counter_conf).

**How to confirm.**

`SELECT @@GLOBAL.innodb_redo_log_capacity;` (MySQL 8.0.30+) or `@@GLOBAL.innodb_log_file_size`. Measure the rate: `SHOW GLOBAL STATUS LIKE 'Innodb_os_log_written';` twice, one hour apart.

**How to fix.** MySQL 8.0.30+: `SET GLOBAL innodb_redo_log_capacity = <bytes>;` — online, no restart. Earlier MySQL and MariaDB: set `innodb_log_file_size` in the configuration file and restart (a clean shutdown is required; InnoDB resizes the log files at startup). Size it for one to two hours of the observed write rate. Larger redo means longer crash recovery, which is the trade.

**False positives / caveats.** A server that is idle most of the day and writes hard for one hour will show a low average rate and a real peak problem; the average hides it. Measure the peak hour, not the mean.

**Reads.** `@dbt_v_innodb_redo_log_capacity (MySQL 8.0.30+), @dbt_v_innodb_log_file_size x @dbt_v_innodb_log_files_in_group (older MySQL, MariaDB), @dbt_s_innodb_os_log_written, @dbt_uptime_s`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-redo-log.html) · Effort M / risk med

<a id="my-wal-002"></a>
### MY-WAL-002 — Redo log buffer waits

**Priority 100 (Tuning & configuration detail) · Redo log & binary log · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Innodb_log_waits > 0 and >= 1/hour. Overridable thresholds: `log_waits_per_hour=1`.

**Why it matters.** Innodb_log_waits counts the times a transaction had to wait for the redo log buffer to be flushed because it was full. Every one of those is a writer stalled on a resource that costs nothing but memory to enlarge. Both forks expose the counter identically.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Innodb_log_waits';`

**How to fix.** Raise `innodb_log_buffer_size` (64 MB is generous). Dynamic on MySQL 8.0+; needs a restart on MariaDB.

**False positives / caveats.** A handful of waits after a bulk load is not a pattern.

**Reads.** `@dbt_s_innodb_log_waits, @@GLOBAL.innodb_log_buffer_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html#sysvar_innodb_log_buffer_size) · Effort S / risk low

<a id="my-wal-003"></a>
### MY-WAL-003 — Binary log cache spilling to disk

**Priority 150 (Hygiene & low-confidence heuristics) · Redo log & binary log · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Binlog cache disk-use ratio >= 1% with >= 10,000 uses. Overridable thresholds: `spill_ratio=0.01;min_cache_uses=10000`.

**Why it matters.** Every transaction buffers its row events in binlog_cache_size of memory before commit; anything larger spills to a temporary file on disk and is read back at commit time. A high spill ratio means large transactions, which are also the transactions that block purge (MY-UNDO-001) and serialise replica appliers. Raising binlog_cache_size is per-session memory, so it multiplies by concurrency — the better fix is usually smaller transactions.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Binlog_cache%';`

**How to fix.** Prefer smaller transactions. Only if that is not possible, raise `binlog_cache_size` — remembering it is allocated per session, so it multiplies by concurrency.

**False positives / caveats.** A nightly bulk job legitimately spills. Look at the ratio during normal hours.

**Reads.** `@dbt_s_binlog_cache_use, @dbt_s_binlog_cache_disk_use, @@GLOBAL.binlog_cache_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_binlog_cache_size) · Effort M / risk low

<a id="my-wal-004"></a>
### MY-WAL-004 — Checkpoint age near redo capacity

**Priority 100 (Tuning & configuration detail) · Redo log & binary log · scope: cluster · cost 0 · fast pass · engine: mariadb · since 0.1.0**

**What fires it.** Checkpoint age >= 75% of its maximum. Overridable thresholds: `checkpoint_age_ratio=0.75`.

**Why it matters.** Fork divergence, and a deliberate narrowing of the design's row: the design specifies parsing "Log sequence number" minus "Last checkpoint at" out of SHOW ENGINE INNODB STATUS, which cannot be done from SQL (a SHOW cannot be selected from) and needs PROCESS. MariaDB and Percona Server expose the same figure directly as the status variables Innodb_checkpoint_age and Innodb_checkpoint_max_age, so this check reads those and emits nothing on stock MySQL, where the runner records it as skipped with reason `version`. Checkpoint age approaching its maximum is the state immediately before InnoDB starts blocking writers to force flushing — the stall that MY-WAL-001 predicts from sizing, observed directly.

**How to confirm.**

MariaDB/Percona: `SHOW GLOBAL STATUS LIKE 'Innodb_checkpoint%';`. MySQL: parse `SHOW ENGINE INNODB STATUS` for `Log sequence number` minus `Last checkpoint at` — there is no status variable for it.

**How to fix.** Increase redo capacity (MY-WAL-001) and raise `innodb_io_capacity_max` so flushing can drain faster (MY-WAL-005).

**False positives / caveats.** A momentary peak during a bulk load is expected. Sustained values near the maximum are not.

**Reads.** `@dbt_s_innodb_checkpoint_age, @dbt_s_innodb_checkpoint_max_age`

**Further reading.** [Official documentation](https://mariadb.com/kb/en/innodb-status-variables/) · Effort M / risk med

<a id="my-wal-005"></a>
### MY-WAL-005 — innodb_io_capacity at its rotational-disk default on solid-state storage

**Priority 150 (Hygiene & low-confidence heuristics) · Redo log & binary log · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** io_capacity at defaults with baseline.storage declared as ssd, nvme or cloud. Overridable thresholds: `io_capacity_default=200;io_capacity_max_default=2000`. Requires: `interview`.

**Why it matters.** Requires .db-triage.yml baseline.storage to say ssd, nvme or cloud. Without that the runner does not surface this row, because 200 IOPS is the right answer on a spinning disk and there is no way to tell from inside the server what the storage actually is. This is the MySQL sibling of PostgreSQL's random_page_cost=4 finding, and it carries the same caveat. The number bounds background flushing, so leaving it at 200 on an NVMe device means InnoDB deliberately uses a fraction of the device and lets checkpoint age climb (MY-WAL-004) under load it could easily absorb.

**How to confirm.**

`SELECT @@GLOBAL.innodb_io_capacity, @@GLOBAL.innodb_io_capacity_max;` and measure the device.

**How to fix.** Set `innodb_io_capacity` to roughly the device's sustained random write IOPS and `innodb_io_capacity_max` to two to four times that. Both are dynamic. Measure the device rather than trusting the datasheet.

**False positives / caveats.** Setting these too high makes InnoDB flush aggressively and compete with foreground work. This check requires a declared storage type precisely because guessing is worse than leaving the default.

**Reads.** `@@GLOBAL.innodb_io_capacity, @@GLOBAL.innodb_io_capacity_max, @dbt_storage`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-configuring-io-capacity.html) · Effort S / risk low

<a id="my-wal-006"></a>
### MY-WAL-006 — Buffer pool dirty page ratio high

**Priority 150 (Hygiene & low-confidence heuristics) · Redo log & binary log · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Dirty page ratio >= 75% at snapshot. Overridable thresholds: `dirty_ratio=0.75`.

**Why it matters.** A snapshot, not a rate: this is the state at the moment the check ran, which is why the details say so. Dirty pages above innodb_max_dirty_pages_pct mean the page cleaners are behind the write rate; InnoDB responds by flushing synchronously in the foreground, which users feel as latency spikes. Both forks expose these counters identically.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_%';`

**How to fix.** This is a symptom: address MY-WAL-001 (redo capacity) and MY-WAL-005 (flush rate cap) rather than adjusting `innodb_max_dirty_pages_pct`, which changes when flushing starts, not how fast it goes.

**False positives / caveats.** A snapshot during a write burst. Re-sample before acting.

**Reads.** `@dbt_s_innodb_buffer_pool_pages_dirty, @dbt_s_innodb_buffer_pool_pages_total, @@GLOBAL.innodb_max_dirty_pages_pct`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool-flushing.html) · Effort M / risk low


---

## MEM — Memory & caching

<a id="my-mem-001"></a>
### MY-MEM-001 — InnoDB buffer pool at the shipped default

**Priority 20 (Known-dangerous, not yet hurting) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_buffer_pool_size <= 128 MB with innodb_dedicated_server OFF. Overridable thresholds: `default_pool_bytes=134217728`.

**Why it matters.** 128 MB is the shipped default on both forks and it is sized for a laptop. Version divergence: MySQL 8.0 added innodb_dedicated_server, which sizes the pool from detected RAM at startup; when that is ON the 128 MB reading means the host really has under ~1 GB of RAM, so the check is suppressed and the host-sizing question belongs to MY-MEM-002 instead. MariaDB has no such variable (verified absent on 10.11), so the bundle returns NULL there and the suppression never applies. Managed platforms always size the pool from the instance class, so seeing this almost always means an unreviewed self-managed install.

**How to confirm.**

`SELECT @@GLOBAL.innodb_buffer_pool_size/1048576 AS mb, @@GLOBAL.innodb_dedicated_server;`

**How to fix.** Size the pool to hold the working set, commonly 50-70% of RAM on a dedicated host. It is dynamic on MySQL 5.7+ and MariaDB 10.2+ but resizes in `innodb_buffer_pool_chunk_size` steps and briefly holds a global mutex, so change it in a quiet period and set it in the configuration file too. Check MY-MEM-007 first so the new value plus the per-session commitment still fits in RAM.

**False positives / caveats.** 128 MB is correct on a container with 512 MB of memory. The check is suppressed when `innodb_dedicated_server=ON`, because MySQL 8.0 then sizes the pool from detected RAM.

**Reads.** `@@GLOBAL.innodb_buffer_pool_size, @dbt_v_innodb_dedicated_server`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool-resize.html) · Effort S / risk low

<a id="my-mem-002"></a>
### MY-MEM-002 — Buffer pool far smaller than the InnoDB working set

**Priority 50 (Daily-briefing ceiling) · Memory & caching · scope: setting · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Buffer pool < 25% of InnoDB data and < 50% of RAM where RAM is known. Overridable thresholds: `pool_to_data_ratio=0.25;pool_to_ram_ratio=0.50`.

**Why it matters.** CAVEAT that belongs in the finding, not a footnote: on MySQL 8.0 information_schema.TABLES sizes are served from a cache refreshed at most every information_schema_stats_expiry seconds (default 86400), so the data size can be up to a day stale. db-triage never runs ANALYZE TABLE to refresh it. MariaDB reads the sizes live from the storage engine, so there the figure is current. The details name which behaviour applies. Only fires when the pool is ALSO not simply capped by host memory: if RAM is known and the pool already holds half of it, the constraint is the host, and MY-MEM-003/007 are the relevant findings instead.

**How to confirm.**

`SELECT ROUND(SUM(DATA_LENGTH+INDEX_LENGTH)/1073741824,2) AS gb FROM information_schema.TABLES WHERE ENGINE='InnoDB';` against `@@GLOBAL.innodb_buffer_pool_size`, then look at the miss rate in MY-MEM-004.

**How to fix.** Raise the pool toward the working set — which is usually much smaller than the total data size, so the miss rate (MY-MEM-004) is the better guide than the ratio alone. If RAM is the constraint, the alternatives are a bigger host, archiving cold data, or accepting the miss rate.

**False positives / caveats.** A 5 TB archive table nobody queries inflates the data size and makes this ratio meaningless. On MySQL 8.0 the sizes come from a cache that may be a day old.

**Reads.** `@@GLOBAL.innodb_buffer_pool_size, information_schema.TABLES, @dbt_ram_bytes`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool-resize.html) · Effort M / risk low

<a id="my-mem-003"></a>
### MY-MEM-003 — Buffer pool over 80 percent of host RAM

**Priority 100 (Tuning & configuration detail) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Buffer pool >= 80% of host RAM. Overridable thresholds: `pool_ram_ceiling=0.80`. Requires: `os`.

**Why it matters.** Requires RAM, which no MySQL variable reports. The runner supplies it from /proc/meminfo or .db-triage.yml baseline.ram_gb; without it this check emits nothing rather than guessing, and the runner records it skipped with reason `os`. MY-MEM-007 computes the full worst-case commitment, of which the pool is only the fixed part. The buffer pool is not the server's whole footprint: add the log buffer, the per-connection buffers, the temptable pool and the OS page cache the redo and binary logs need. Crossing 80% of RAM is where hosts start swapping, and a swapping buffer pool is slower than no buffer pool.

**How to confirm.**

Compare `@@GLOBAL.innodb_buffer_pool_size` against `/proc/meminfo` MemTotal.

**How to fix.** Reduce the pool, or move other workloads off the host. Read MY-MEM-007 for the full commitment: the pool is only the fixed part, and per-session buffers multiplied by `max_connections` are often larger than people expect. A swapping buffer pool performs worse than a smaller one that fits.

**False positives / caveats.** A host dedicated to MySQL with a small `max_connections` and modest per-session buffers can safely run a pool above 80%. The number is a heuristic; MY-MEM-007 is the arithmetic.

**Reads.** `@@GLOBAL.innodb_buffer_pool_size, @dbt_ram_bytes`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool-resize.html) · Effort M / risk med

<a id="my-mem-004"></a>
### MY-MEM-004 — Buffer pool read miss rate high

**Priority 100 (Tuning & configuration detail) · Memory & caching · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Buffer pool miss rate >= 5% over >= 10 M read requests. Overridable thresholds: `miss_ratio=0.05;min_read_requests=10000000`.

**Why it matters.** Innodb_buffer_pool_reads counts logical reads that had to go to disk; read_requests counts all logical reads. The ratio is a since-restart average, so it hides both the warm-up after a restart and any recent change — hence the confidence tracking the counter window and the explicit window in the text. The 10 M request floor keeps a freshly started server from firing on a handful of reads that were all misses.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';`

**How to fix.** This is a symptom of MY-MEM-001/002 (pool too small) or of queries reading far more than they return (MY-QRY-006). Fix the query side first: it is usually cheaper than buying memory.

**False positives / caveats.** An average since restart hides recent change and includes the post-restart warm-up. On a server restarted today (MY-REL-005) it means nothing.

**Reads.** `@dbt_s_innodb_buffer_pool_reads, @dbt_s_innodb_buffer_pool_read_requests`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool.html) · Effort M / risk low

<a id="my-mem-005"></a>
### MY-MEM-005 — Implicit temporary tables spilling to disk

**Priority 100 (Tuning & configuration detail) · Memory & caching · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Disk temp table ratio >= 25% and >= 1,000/hour. Overridable thresholds: `disk_tmp_ratio=0.25;disk_tmp_per_hour=1000`.

**Why it matters.** MySQL-specific hazard with no PostgreSQL analogue: Postgres spills per operator against work_mem, MySQL materialises whole intermediate results as tables and moves them to disk wholesale when they exceed the limit. Version divergence: MySQL 8.0 replaced the MEMORY engine for internal temp tables with TempTable, governed by temptable_max_ram (default 1 GB) rather than tmp_table_size, and spills to mmapped files or InnoDB; MariaDB still uses max_heap_table_size / tmp_table_size and aria/innodb on disk. Both limits are reported so the right lever is obvious. The usual real cause is a TEXT/BLOB column in a GROUP BY or ORDER BY, which forces on-disk regardless of size on MySQL 5.7 and MariaDB.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Created_tmp%';` then MY-QRY-007 for the statements responsible.

**How to fix.** 1. Fix the statements — a `GROUP BY` or `ORDER BY` served by an index creates no temporary table at all. 2. Remove TEXT/BLOB columns from `GROUP BY`/`ORDER BY`: on MySQL 5.7 and MariaDB those force disk regardless of size. 3. Only then raise `tmp_table_size` and `max_heap_table_size` together (the smaller wins), or `temptable_max_ram` on MySQL 8.0.

**False positives / caveats.** A nightly reporting job legitimately spills. Look at the rate during normal hours, not the total.

**Reads.** `@dbt_s_created_tmp_tables, @dbt_s_created_tmp_disk_tables, @@GLOBAL.tmp_table_size, @@GLOBAL.max_heap_table_size, @dbt_v_temptable_max_ram`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/internal-temporary-tables.html) · Effort M / risk low

<a id="my-mem-006"></a>
### MY-MEM-006 — Oversized per-session buffers

**Priority 100 (Tuning & configuration detail) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Any per-session buffer >= 8 MB globally. Overridable thresholds: `session_buffer_bytes=8388608`.

**Why it matters.** All four are universal and all four are allocated PER SESSION, and for sort_buffer_size and join_buffer_size potentially more than once per query. At 8 MB and 500 connections that is 4 GB of commitment that does not appear in the buffer pool figure. Worse, a large sort_buffer_size is actively slower: MySQL allocates and touches the whole buffer for sorts that need a fraction of it, so raising it globally to fix one query penalises every other query. The right fix is nearly always to set it per session for the one statement that needs it, which is why this is P100 and not a tuning suggestion.

**How to confirm.**

`SELECT @@GLOBAL.sort_buffer_size, @@GLOBAL.join_buffer_size, @@GLOBAL.read_buffer_size, @@GLOBAL.read_rnd_buffer_size;`

**How to fix.** Return the globals to their defaults (256 KB - 2 MB) and set a larger value per session only for the statement that needs it: `SET SESSION sort_buffer_size = 32*1024*1024;` before that query. A large global `sort_buffer_size` makes every small sort slower because MySQL allocates and touches the whole buffer.

**False positives / caveats.** A dedicated batch server with very low concurrency can carry large globals. Check `max_connections` before assuming the multiplication matters.

**Reads.** `@@GLOBAL.sort_buffer_size, join_buffer_size, read_buffer_size, read_rnd_buffer_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_sort_buffer_size) · Effort S / risk med

<a id="my-mem-007"></a>
### MY-MEM-007 — Worst-case memory commitment exceeds host RAM

**Priority 50 (Daily-briefing ceiling) · Memory & caching · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Worst-case memory commitment >= host RAM, or RAM unknown. Overridable thresholds: `commitment_ratio=1.0`.

**Why it matters.** The arithmetic MySQL never does for you: a fixed global part plus a per-session part multiplied by max_connections. It is a genuine WORST case — most sessions never allocate their sort or join buffer, and MySQL 8.0's TempTable pool is shared rather than per session — so it overstates typical usage on purpose. Priority follows what is known: P50 when RAM was supplied and the number really does exceed it, P100 when RAM is unknown and the figure is reported for the operator to compare. The registry carries both rows via platform_priority; the confidence field carries the same distinction.

**How to confirm.**

Compute it by hand from the variables in the finding's evidence, and compare against MemTotal.

**How to fix.** Reduce whichever term dominates — usually `max_connections` multiplied by the per-session buffers, not the buffer pool. Lowering `max_connections` and putting a connection pooler in front is generally better than shrinking the pool.

**False positives / caveats.** A genuine worst case that almost never occurs: most sessions never allocate their sort or join buffer, and MySQL 8.0's TempTable pool is shared rather than per session. It overstates on purpose.

**Reads.** `@@GLOBAL.innodb_buffer_pool_size, innodb_log_buffer_size, key_buffer_size, max_connections, sort/join/read/read_rnd buffers, binlog_cache_size, thread_stack, tmp_table_size, @dbt_ram_bytes`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/memory-use.html) · Effort M / risk med

<a id="my-mem-008"></a>
### MY-MEM-008 — Table open cache too small, or open-file limit at risk

**Priority 100 (Tuning & configuration detail) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Table cache overflows >= 1/min, Opened_tables >= 10/s, or open files >= 80% of the limit. Overridable thresholds: `overflows_per_minute=1;opened_tables_per_second=10;open_files_ratio=0.80`.

**Why it matters.** Covers both halves of the design's row: cache pressure and the file-descriptor ceiling behind it. Table_open_cache_overflows exists in MySQL 5.6.6+ and MariaDB 10.1+; where it is missing the Opened_tables rate carries the check. Every cache miss reopens a table: a file descriptor, a metadata lock and a .frm/data-dictionary read. At tens per second that is pure overhead, and it also multiplies the open-file count, which is capped by open_files_limit and ultimately by the OS.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Table_open_cache%'; SHOW GLOBAL STATUS LIKE 'Opened_tables'; SHOW GLOBAL STATUS LIKE 'Open_files';`

**How to fix.** Raise `table_open_cache` (dynamic) and `table_definition_cache`. Raise `open_files_limit` alongside it — each cached table needs file descriptors, and `open_files_limit` is itself capped by the OS and by the systemd unit's `LimitNOFILE`, so raising it in my.cnf alone may silently do nothing.

**False positives / caveats.** A server with tens of thousands of tables or many partitions will always churn this cache somewhat.

**Reads.** `@dbt_s_table_open_cache_overflows, @dbt_s_opened_tables, @dbt_s_open_files, @@GLOBAL.table_open_cache, @@GLOBAL.open_files_limit, @dbt_v_table_definition_cache`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/table-cache.html) · Effort S / risk low

<a id="my-mem-009"></a>
### MY-MEM-009 — Query cache enabled

**Priority 50 (Daily-briefing ceiling) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mariadb · since 0.1.0**

**What fires it.** query_cache_type not OFF with a non-zero query_cache_size. Overridable thresholds: `threads_running=8`.

**Why it matters.** Version divergence: the query cache was deprecated in MySQL 5.7.20 and REMOVED in MySQL 8.0, so both variables are absent there and the bundle returns NULL — this check then emits nothing. It remains present and OFF-by-default in MariaDB, which is the only fork where it can still be found switched on. The mechanism is a single global mutex: every read consults it and every write to any table invalidates every cached result for that table. On a server with real concurrency it converts parallel work into a queue, and the effect grows with core count. There is no PostgreSQL analogue.

**How to confirm.**

`SELECT @@GLOBAL.query_cache_type, @@GLOBAL.query_cache_size;` (MariaDB only).

**How to fix.** `SET GLOBAL query_cache_type = OFF; SET GLOBAL query_cache_size = 0;` and remove both from the configuration file. On a read-mostly server with very low concurrency it can help; on anything with real concurrency the global mutex costs more than the cache saves.

**False positives / caveats.** A read-only reporting replica with a handful of concurrent sessions and highly repetitive queries is the one case where it genuinely helps. Measure `Qcache_hits` against `Qcache_lowmem_prunes` before removing it there.

**Reads.** `@dbt_v_query_cache_type, @dbt_v_query_cache_size, @dbt_s_threads_running`

**Further reading.** [Official documentation](https://mariadb.com/kb/en/query-cache/) · Effort S / risk low

<a id="my-mem-010"></a>
### MY-MEM-010 — Single buffer pool instance with a large pool

**Priority 150 (Hygiene & low-confidence heuristics) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Pool >= 8 GB with innodb_buffer_pool_instances = 1. Overridable thresholds: `large_pool_bytes=8589934592`.

**Why it matters.** Version divergence, and the reason this must come from the bundle: MariaDB 10.6 REMOVED innodb_buffer_pool_instances entirely (verified absent on 10.11) because its buffer pool no longer partitions that way, and MySQL 8.0 auto-sizes it from the pool size. So this can only fire on MySQL 5.7, on MariaDB 10.5 and earlier, or where someone pinned it to 1 by hand. With one instance, every page lookup contends on one buffer pool mutex; the classic guidance is one instance per GB up to the core count.

**How to confirm.**

`SELECT @@GLOBAL.innodb_buffer_pool_instances, @@GLOBAL.innodb_buffer_pool_size;`

**How to fix.** Set one instance per gigabyte of pool, capped at the core count, and restart. MySQL 8.0 does this automatically and MariaDB 10.6+ removed the setting, so this only applies to older servers.

**False positives / caveats.** The contention this addresses is only measurable at high concurrency.

**Reads.** `@dbt_v_innodb_buffer_pool_instances, @@GLOBAL.innodb_buffer_pool_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-multiple-buffer-pools.html) · Effort M / risk low

<a id="my-mem-011"></a>
### MY-MEM-011 — Host is swapping

**Priority 50 (Daily-briefing ceiling) · Memory & caching · scope: host · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Swap in use >= 1 GB, or non-zero swap-in/swap-out. Requires: `os`.

**Why it matters.** A swapping buffer pool is slower than a smaller buffer pool that fits in RAM: every page fault turns a memory access into disk I/O that InnoDB does not know it is doing, so it does not appear in any InnoDB counter. The symptom is latency that has no explanation inside the database. Not readable from SQL on any fork; the runner supplies it from /proc/meminfo.

**How to confirm.**

`free -m`, `vmstat 1 5` (si/so columns), and `cat /proc/<mysqld-pid>/status | grep VmSwap`.

**How to fix.** Reduce the memory commitment (MY-MEM-007) rather than disabling swap. Lowering `vm.swappiness` to 1 helps but does not fix an over-commitment. Never set `innodb_flush_method=O_DIRECT` as a swap remedy — it addresses double-buffering, which is a different problem (MY-MEM-012).

**False positives / caveats.** A small amount of swap used by long-idle pages is normal and harmless; active swap-in/swap-out is not.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/memory-use.html) · Effort M / risk med

<a id="my-mem-012"></a>
### MY-MEM-012 — innodb_flush_method not O_DIRECT on Linux

**Priority 150 (Hygiene & low-confidence heuristics) · Memory & caching · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_flush_method not O_DIRECT on Linux with a pool >= 4 GB. Overridable thresholds: `large_pool_bytes=4294967296`.

**Why it matters.** Read from the bundle because the variable does not exist on Windows builds and its accepted values differ by fork: MySQL 8.0.14+ adds O_DIRECT_NO_FSYNC and 8.0.26 makes it the default on Linux; MariaDB keeps O_DIRECT as the practical choice and adds fsync/littlesync/nosync variants. Without O_DIRECT every InnoDB page lives twice: once in the buffer pool and once in the OS page cache. On a host where the pool is already several GB that is a straight waste of RAM, and it makes MY-MEM-003/007 understate real usage. Only judged on Linux, because O_DIRECT is a no-op or unavailable elsewhere.

**How to confirm.**

`SELECT @@GLOBAL.innodb_flush_method;` and `SELECT @@GLOBAL.version_compile_os;`

**How to fix.** Set `innodb_flush_method=O_DIRECT` in the configuration file and restart. On MySQL 8.0.14+ with a filesystem that supports it, `O_DIRECT_NO_FSYNC` avoids a redundant fsync — but only where the filesystem guarantees metadata durability, which ext4 and XFS do for existing files.

**False positives / caveats.** O_DIRECT is a no-op or unavailable on some filesystems and on Windows. On ZFS, O_DIRECT is not recommended because ZFS's own ARC is the cache.

**Reads.** `@dbt_v_innodb_flush_method, @@GLOBAL.version_compile_os, @@GLOBAL.innodb_buffer_pool_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html#sysvar_innodb_flush_method) · Effort M / risk low


---

## CONN — Connections & pooling

<a id="my-conn-001"></a>
### MY-CONN-001 — Connections at or above 90 percent of max_connections

**Priority 5 (One step from fired) · Connections & pooling · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Threads_connected or Max_used_connections >= 90% of max_connections. Overridable thresholds: `conn_critical_ratio=0.90`.

**Why it matters.** Two readings with different meanings, both reported: Threads_connected is a snapshot and can miss a spike entirely; Max_used_connections is the high-water mark since restart and cannot tell you when it happened. Either crossing 90% fires, because the consequence is the same — the next connection attempt is refused with ER_CON_COUNT_ERROR and the application sees an outage, not a slowdown. MySQL reserves exactly one extra slot for a SUPER account, which is what lets a DBA still get in.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Threads_connected'; SHOW GLOBAL STATUS LIKE 'Max_used_connections'; SELECT @@GLOBAL.max_connections;`

**How to fix.** 1. Immediately: raise `max_connections` (dynamic on both forks) to buy room — but check MY-MEM-007 first, because each connection carries per-session buffers. 2. Then find the cause: a connection leak, a pool sized larger than the database, or a retry storm. 3. The structural answer is a connection pooler (ProxySQL, RDS Proxy) so the application's pool size and the server's limit are decoupled.

**False positives / caveats.** A pooler-fronted server deliberately runs near a low `max_connections`. What matters is whether `Connection_errors_max_connections` is growing (MY-CONN-003).

**Reads.** `@dbt_s_threads_connected (now), @dbt_s_max_used_connections (since restart), @@GLOBAL.max_connections`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/too-many-connections.html) · Effort S / risk med

<a id="my-conn-002"></a>
### MY-CONN-002 — Connections at or above 70 percent of max_connections

**Priority 50 (Daily-briefing ceiling) · Connections & pooling · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Threads_connected or Max_used_connections >= 70% and < 90%. Overridable thresholds: `conn_warn_ratio=0.70;conn_critical_ratio=0.90`.

**Why it matters.** Magnitude tier below MY-CONN-001, separate ID so the tiers suppress independently. 70% is the point at which a normal daily peak plus one application restart storm reaches the ceiling.

**How to confirm.**

As MY-CONN-001.

**How to fix.** As MY-CONN-001, with time to plan rather than react.

**False positives / caveats.** `Max_used_connections` records a peak that may have happened weeks ago; `Threads_connected` is now. The finding reports both for that reason.

**Reads.** `as MY-CONN-001`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/too-many-connections.html) · Effort S / risk low

<a id="my-conn-003"></a>
### MY-CONN-003 — Clients refused because max_connections was reached

**Priority 20 (Known-dangerous, not yet hurting) · Connections & pooling · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Connection_errors_max_connections > 0.

**Why it matters.** This counter is not a risk indicator, it is a record of an outage that already happened: every increment is a client that got ER_CON_COUNT_ERROR instead of a connection. It is not reset except by restart or FLUSH STATUS, so the details state the window explicitly. Available from MySQL 5.6.5 and MariaDB 10.0; where absent the bundle returns NULL and the check is silent.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Connection_errors_%';`

**How to fix.** This is a record of an outage, so treat it as an incident to explain, not a threshold to tune. Correlate the count with application error logs to find when it happened. Then fix the capacity (MY-CONN-001).

**False positives / caveats.** Not reset except by restart or `FLUSH STATUS`, so a large number on a long-lived server may be entirely historic. The finding gives the rate per day so the age is visible.

**Reads.** `@dbt_s_connection_errors_max_connections`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html#statvar_Connection_errors_xxx) · Effort S / risk med

<a id="my-conn-004"></a>
### MY-CONN-004 — Aborted connections high

**Priority 100 (Tuning & configuration detail) · Connections & pooling · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Aborted_connects or Aborted_clients >= 1% of Connections. Overridable thresholds: `aborted_ratio=0.01;min_connections=10000`.

**Why it matters.** Two different failures with one threshold, distinguished in the text: Aborted_connects counts handshakes that never completed (bad credentials, a host blocked by max_connect_errors, connect_timeout, TLS negotiation failure); Aborted_clients counts established connections the client dropped without a clean COM_QUIT (application crash, pool eviction, wait_timeout, an oversized packet). The first is a security or configuration signal, the second is an application-lifecycle signal, and confusing them wastes an afternoon.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Aborted_%'; SHOW GLOBAL STATUS LIKE 'Connections';`

**How to fix.** Aborted_connects: check credentials, TLS negotiation, `connect_timeout`, and whether a host is blocked (MY-CONN-005). Aborted_clients: check whether the application closes connections cleanly, whether `wait_timeout` is shorter than the pool's idle time, and whether `max_allowed_packet` is large enough for the biggest row or BLOB in use.

**False positives / caveats.** A serverless or short-lived-worker architecture produces Aborted_clients as a matter of course.

**Reads.** `@dbt_s_aborted_connects, @dbt_s_aborted_clients, @dbt_s_connections`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/communication-errors.html) · Effort M / risk low

<a id="my-conn-005"></a>
### MY-CONN-005 — Host approaching the connect-error block threshold

**Priority 100 (Tuning & configuration detail) · Connections & pooling · scope: host · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A host has reached 50% of max_connect_errors. Overridable thresholds: `connect_error_ratio=0.50`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** MySQL-specific failure mode with no PostgreSQL analogue: when a host accumulates max_connect_errors failed handshakes, the server blocks it ENTIRELY — every subsequent connection from that IP is refused with ER_HOST_IS_BLOCKED until someone runs FLUSH HOSTS. The block survives the original problem being fixed, and nothing logs a warning as the count climbs. The design scopes this to MySQL; performance_schema.host_cache is in fact present on MariaDB 10.11 as well (verified), so it is gated on the table rather than on the fork, and the registry row records both engines. Note that skip_name_resolve=OFF makes DNS failures count toward this, which is how a DNS blip turns into a permanently blocked application host (MY-CONN-010).

**How to confirm.**

`SELECT IP, HOST, SUM_CONNECT_ERRORS, COUNT_AUTHENTICATION_ERRORS, COUNT_HANDSHAKE_ERRORS FROM performance_schema.host_cache ORDER BY SUM_CONNECT_ERRORS DESC;`

**How to fix.** 1. Find why that host is failing to connect — bad credentials, a TLS mismatch, or DNS. 2. `FLUSH HOSTS` clears the counters (it is a write, so db-triage never runs it). 3. Set `skip_name_resolve=ON` so DNS failures stop counting toward the block (MY-CONN-010). 4. Raising `max_connect_errors` hides the symptom.

**False positives / caveats.** A monitoring probe that deliberately tests a bad login will accumulate these.

**Reads.** `performance_schema.host_cache (SUM_CONNECT_ERRORS), @@GLOBAL.max_connect_errors`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/host-cache.html) · Effort S / risk low

<a id="my-conn-006"></a>
### MY-CONN-006 — max_connections very high with no thread pool and no evidence of a pooler

**Priority 50 (Daily-briefing ceiling) · Connections & pooling · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** max_connections >= 1000, no thread pool, and connections are not concentrated. Overridable thresholds: `high_max_connections=1000;pooler_host_concentration=0.80;pooler_max_hosts=3`. Requires: `PROCESS`.

**Why it matters.** Fork divergence: MariaDB and Percona Server implement the thread pool in the server and expose thread_handling = 'pool-of-threads'; MySQL Community has no thread pool at all (it is an Enterprise plugin, visible in information_schema.PLUGINS as thread_pool). Both are checked, and thread_handling comes from the bundle because stock MySQL lacks the variable. The heuristic: a genuine pooler (ProxySQL, RDS Proxy, HAProxy, pgbouncer's MySQL equivalents) concentrates connections into a handful of source hosts. Many source hosts plus a four-figure max_connections means every application process connects directly, and MySQL's one-thread-per-connection model turns a connection storm into a scheduling collapse. Confidence is medium: an application fleet on a small number of hosts looks identical to a pooler.

**How to confirm.**

`SELECT @@GLOBAL.max_connections, @@GLOBAL.thread_handling;` and look at the host distribution in `SELECT SUBSTRING_INDEX(HOST,':',1) h, COUNT(*) FROM information_schema.PROCESSLIST GROUP BY h ORDER BY 2 DESC;`

**How to fix.** Put a connection pooler in front, or on MariaDB/Percona enable the in-server thread pool (`thread_handling=pool-of-threads`). MySQL Community has no thread pool, so a pooler is the only option there. A four-figure `max_connections` without either is a scheduling collapse waiting for a traffic spike.

**False positives / caveats.** An application fleet running on three hosts looks exactly like a pooler to this heuristic, and a pooler running on twenty hosts looks exactly like a fleet. Confidence is medium for that reason.

**Reads.** `@@GLOBAL.max_connections, @dbt_v_thread_handling, information_schema.PLUGINS (thread_pool), information_schema.PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/connection-interfaces.html) · Effort L / risk med

<a id="my-conn-007"></a>
### MY-CONN-007 — Most connections are sleeping

**Priority 100 (Tuning & configuration detail) · Connections & pooling · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** >= 80% of >= 100 connections idle with wait_timeout >= 28,800 s. Overridable thresholds: `sleep_ratio=0.80;min_conns=100;long_wait_timeout=28800`. Requires: `PROCESS`.

**Why it matters.** Snapshot, and the details say so. A high sleeping ratio is normal for a pooled application and is only reported when it combines with a long wait_timeout, because that is the combination where an abandoned connection occupies a slot (and its per-session buffers, MY-MEM-006/007) for up to eight hours after the client forgot about it. Requires PROCESS to see other accounts' threads; without it PROCESSLIST shows only this session and the min_conns floor keeps the check silent.

**How to confirm.**

`SELECT COMMAND, COUNT(*), MAX(TIME) FROM information_schema.PROCESSLIST GROUP BY COMMAND;`

**How to fix.** Lower `wait_timeout` so abandoned connections are reclaimed, and make sure the application's pool validates connections before use so a reclaimed one does not surface as an error. `interactive_timeout` governs interactive clients separately.

**False positives / caveats.** A correctly sized pool is mostly idle by design. This only fires when a long `wait_timeout` combines with it, which is the case where an abandoned connection holds a slot for hours.

**Reads.** `information_schema.PROCESSLIST, @@GLOBAL.wait_timeout`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_wait_timeout) · Effort M / risk low

<a id="my-conn-008"></a>
### MY-CONN-008 — Thread cache misses

**Priority 150 (Hygiene & low-confidence heuristics) · Connections & pooling · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Threads_created >= 1% of Connections over >= 100,000 connections. Overridable thresholds: `thread_miss_ratio=0.01;min_connections=100000`.

**Why it matters.** Threads_created / Connections is the fraction of connections that needed a new OS thread rather than a cached one. MySQL 8.0 auto-sizes thread_cache_size from max_connections, so this rarely fires there; MariaDB's default formula is more conservative and a connection-per-request application can outrun it. The 100,000-connection floor exists because on a low-traffic server every connection legitimately creates a thread and the ratio means nothing.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Threads_created'; SHOW GLOBAL STATUS LIKE 'Connections';`

**How to fix.** Raise `thread_cache_size` (dynamic). The real fix is connection pooling in the application: a cached thread still costs a full connection handshake and authentication.

**False positives / caveats.** MySQL 8.0 auto-sizes the cache, so this rarely fires there. On a low-traffic server the ratio is meaningless, which is why the check requires 100,000 connections.

**Reads.** `@dbt_s_threads_created, @dbt_s_connections, @@GLOBAL.thread_cache_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_thread_cache_size) · Effort S / risk low

<a id="my-conn-009"></a>
### MY-CONN-009 — Server saturated at snapshot time

**Priority 50 (Daily-briefing ceiling) · Connections & pooling · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Threads_running >= 2 per core, or >= 64 when cores are unknown. Overridable thresholds: `running_per_core=2;running_absolute=64`.

**Why it matters.** Threads_running is the number of threads not idle right now — the closest MySQL gets to a run queue. Above roughly two per core, threads are waiting on each other rather than on work, and latency rises much faster than throughput falls. Core count is not readable from any MySQL variable; the runner supplies it from .db-triage.yml baseline.cpus or nproc. Without it the check falls back to an absolute figure of 64, which is deliberately conservative, and says so. One sample can catch a one-off spike or miss a storm entirely; deep mode re-samples, and the details label this as a snapshot either way.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Threads_running';` sampled several times, and `nproc`.

**How to fix.** Establish what the threads are waiting on before adding capacity: MY-LOCK-001/002 (row locks), MY-LOCK-006 (metadata locks) and MY-QRY-004 (dominant statements) partition the possibilities. Adding CPU to a lock-bound server changes nothing.

**False positives / caveats.** One sample. A spike lasting 200 ms and a sustained saturation look identical here; deep mode re-samples.

**Reads.** `@dbt_s_threads_running, @dbt_cpu_count`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html#statvar_Threads_running) · Effort M / risk low

<a id="my-conn-010"></a>
### MY-CONN-010 — DNS lookups performed on every connection

**Priority 150 (Hygiene & low-confidence heuristics) · Connections & pooling · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** skip_name_resolve = OFF.

**Why it matters.** With skip_name_resolve OFF, every incoming connection triggers a reverse DNS lookup and then a forward lookup to confirm it. Three consequences, all real: connection latency depends on a DNS server, a DNS outage looks like a database outage, and failed lookups count toward max_connect_errors and can get a host permanently blocked (MY-CONN-005). It is also a security surface: host-based grants written against names rather than addresses are only as trustworthy as reverse DNS. Turning it on requires that every grant use an IP or a wildcard, which is why this is P150 with the count of name-based grants included rather than a bare recommendation.

**How to confirm.**

`SELECT @@GLOBAL.skip_name_resolve;`

**How to fix.** Set `skip_name_resolve=ON` in the configuration file and restart — it is read-only at runtime on both forks. BEFORE doing so, rewrite every account whose host part is a hostname to use an IP address or a wildcard, because those grants stop matching the moment name resolution is disabled. MY-INFO-008 lists the host patterns in use.

**False positives / caveats.** None, other than the grant migration, which is the whole reason this is P150 and not higher.

**Reads.** `@@GLOBAL.skip_name_resolve, mysql.user host patterns`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/host-cache.html#host-cache-dns) · Effort S / risk med


---

## LOCK — Locking & long transactions

<a id="my-lock-001"></a>
### MY-LOCK-001 — Transaction waiting on a row lock for over 5 minutes

**Priority 10 (Active harm / serious foot-gun) · Locking & long transactions · scope: session · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A transaction has waited >= 300 s for a row lock. Overridable thresholds: `lock_wait_critical_seconds=300;lock_wait_warn_seconds=30`. Requires: `PROCESS`.

**Why it matters.** Deliberately built on INNODB_TRX rather than on the lock-waits view, because that view is where the forks diverge hardest: MySQL 8.0 replaced information_schema.INNODB_LOCK_WAITS with performance_schema.data_lock_waits, MariaDB kept INNODB_LOCK_WAITS (verified present on 10.11), and sys.innodb_lock_waits exists on both but with different underlying columns. INNODB_TRX.trx_wait_started exists identically on MySQL 5.6-9.x and every MariaDB, so the waiting side is always visible. The blocking side is identified where the fork allows; MY-LOCK-002 is the lower tier. Five minutes of waiting means innodb_lock_wait_timeout (default 50 s) was raised, so somebody has already decided to wait rather than fail.

**How to confirm.**

`SELECT * FROM information_schema.INNODB_TRX WHERE trx_state='LOCK WAIT'\G` and, for the blocking side, `SELECT * FROM sys.innodb_lock_waits\G` (MySQL 8.0 uses `performance_schema.data_lock_waits`, MariaDB uses `information_schema.INNODB_LOCK_WAITS`).

**How to fix.** 1. Identify the blocking transaction, not just the waiting one — `sys.innodb_lock_waits` gives both, including a ready-made `KILL` statement. 2. Decide whether to kill it. 3. Then fix the cause: a transaction long enough to block others for five minutes is nearly always doing application work inside a transaction, or updating rows in an inconsistent order across code paths.

**False positives / caveats.** A deliberate maintenance operation holding locks in a window. Also note that five minutes of waiting means `innodb_lock_wait_timeout` was raised well above its 50-second default, which was itself a decision.

**Reads.** `information_schema.INNODB_TRX (trx_wait_started, trx_state), PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking.html) · Effort S / risk med

<a id="my-lock-002"></a>
### MY-LOCK-002 — Transaction waiting on a row lock for over 30 seconds

**Priority 50 (Daily-briefing ceiling) · Locking & long transactions · scope: session · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A transaction has waited >= 30 s and < 300 s for a row lock. Overridable thresholds: `lock_wait_warn_seconds=30;lock_wait_critical_seconds=300`. Requires: `PROCESS`.

**Why it matters.** Magnitude tier below MY-LOCK-001, separate ID so the tiers suppress independently. 30 s is below the 50 s innodb_lock_wait_timeout default, so a transaction seen here on a default-configured server is within seconds of being rolled back with ER_LOCK_WAIT_TIMEOUT.

**How to confirm.**

As MY-LOCK-001.

**How to fix.** As MY-LOCK-001. At 30 seconds with the default timeout, the waiter is about to be rolled back with ER_LOCK_WAIT_TIMEOUT; the application will see that as an error, so the fix is upstream.

**False positives / caveats.** As MY-LOCK-001.

**Reads.** `information_schema.INNODB_TRX, PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking.html) · Effort S / risk low

<a id="my-lock-003"></a>
### MY-LOCK-003 — Transaction open for over an hour

**Priority 20 (Known-dangerous, not yet hurting) · Locking & long transactions · scope: session · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A transaction has been open >= 1 h. Overridable thresholds: `long_txn_seconds=3600`. Requires: `PROCESS`.

**Why it matters.** INNODB_TRX exists with these column names on every supported MySQL and MariaDB, so no version gate is needed. A long transaction is the usual root cause of MY-UNDO-001/002: its read view pins the history list, so purge cannot reclaim ANY undo newer than it, no matter how much has since been committed and deleted. It also holds every lock it has taken, and on MySQL it blocks the metadata-lock queue behind any DDL (MY-LOCK-006). Transactions that merely sit idle are MY-LOCK-004/005.

**How to confirm.**

`SELECT trx_id, trx_started, trx_state, trx_rows_locked, trx_rows_modified, trx_query FROM information_schema.INNODB_TRX ORDER BY trx_started;`

**How to fix.** 1. Find the session and the code path. 2. The usual causes are an application that opens a transaction and then calls an external service, an ORM leaving a transaction open on an idle connection, or a `mysqldump` without `--single-transaction` on a large database. 3. Nothing in MySQL will clean it up; MariaDB offers `idle_transaction_timeout` as a guard.

**False positives / caveats.** A long-running batch job or a consistent-snapshot backup is exactly this shape and is intended. What it still does, intended or not, is pin the history list (MY-UNDO-001).

**Reads.** `information_schema.INNODB_TRX (trx_started), PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-transaction-model.html) · Effort S / risk med

<a id="my-lock-004"></a>
### MY-LOCK-004 — Idle transaction holding locks for over an hour

**Priority 10 (Active harm / serious foot-gun) · Locking & long transactions · scope: session · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An idle transaction has held row locks >= 1 h. Overridable thresholds: `idle_txn_critical_seconds=3600;idle_txn_warn_seconds=300`. Requires: `PROCESS`.

**Why it matters.** The MySQL analogue of PostgreSQL's idle-in-transaction backend, and worse in one respect: MySQL has no idle_in_transaction_session_timeout equivalent before MySQL 8.0's innodb_lock_wait_timeout-unrelated `wait_timeout` (which does not apply mid-transaction), so nothing reclaims it. MariaDB has idle_transaction_timeout / idle_write_transaction_timeout, which is why the details name them when the fork supports them. An idle transaction holding row locks is strictly worse than a busy one: it is doing no work, blocking others, and pinning purge. The usual cause is an application that opened a transaction, made a network call, and never came back.

**How to confirm.**

As MY-LOCK-003, joined to `information_schema.PROCESSLIST` on `trx_mysql_thread_id` where `COMMAND='Sleep'`.

**How to fix.** Kill it, then fix the application: an idle transaction holding locks is doing no work and blocking others. On MariaDB set `idle_transaction_timeout` / `idle_write_transaction_timeout` as a backstop. MySQL has no equivalent, so the application must close its transactions.

**False positives / caveats.** An interactive DBA session left open in a terminal produces this and is harmless once noticed.

**Reads.** `information_schema.INNODB_TRX joined to PROCESSLIST (COMMAND='Sleep')`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking.html) · Effort S / risk med

<a id="my-lock-005"></a>
### MY-LOCK-005 — Idle transaction holding locks for over 5 minutes

**Priority 50 (Daily-briefing ceiling) · Locking & long transactions · scope: session · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An idle transaction has held row locks >= 5 min and < 1 h. Overridable thresholds: `idle_txn_warn_seconds=300;idle_txn_critical_seconds=3600`. Requires: `PROCESS`.

**Why it matters.** Magnitude tier below MY-LOCK-004, separate ID for independent suppression.

**How to confirm.**

As MY-LOCK-004.

**How to fix.** As MY-LOCK-004.

**False positives / caveats.** As MY-LOCK-004.

**Reads.** `information_schema.INNODB_TRX joined to PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking.html) · Effort S / risk low

<a id="my-lock-006"></a>
### MY-LOCK-006 — Sessions waiting for a metadata lock

**Priority 50 (Daily-briefing ceiling) · Locking & long transactions · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A session has waited >= 30 s for a table metadata lock. Overridable thresholds: `mdl_wait_seconds=30`. Requires: `PROCESS`.

**Why it matters.** MySQL-specific pile-up with no PostgreSQL analogue in this shape. The mechanism: an ALTER TABLE needs an exclusive metadata lock; a long-running transaction that merely SELECTed from the table holds a shared one and will not release it until it commits. The ALTER queues — and because MDL requests are served in order, EVERY subsequent query on that table queues behind the ALTER, including plain SELECTs that would otherwise have run fine. The result is a table that goes from healthy to completely unavailable in one step, with no lock wait timeout firing (lock_wait_timeout defaults to 1 year (31536000 s) on both forks). The PROCESSLIST STATE string is identical on MySQL 5.6-9.x and MariaDB, which is why this is portable without a version gate; performance_schema.metadata_locks (MySQL 5.7+, present on MariaDB 10.11) gives the blocking side and is used by the reference doc's confirmation query.

**How to confirm.**

`SELECT ID, USER, TIME, STATE, INFO FROM information_schema.PROCESSLIST WHERE STATE='Waiting for table metadata lock';` and, for the holder, `SELECT * FROM performance_schema.metadata_locks WHERE LOCK_STATUS='GRANTED';` (needs the `global_instrumentation` and `wait/lock/metadata/sql/mdl` instruments enabled).

**How to fix.** 1. Find the transaction HOLDING the shared metadata lock — it is usually an old or idle transaction that merely read the table (MY-LOCK-003/004), not the DDL itself. 2. Kill the holder, or kill the queued DDL; killing the DDL releases everything queued behind it immediately, which is usually the faster way to restore service. 3. In future, run DDL through `gh-ost` or `pt-online-schema-change`, and set a short `lock_wait_timeout` in the DDL session so it fails fast instead of building a queue.

**False positives / caveats.** None worth noting: a metadata-lock queue on a busy table is always an incident. Note that `lock_wait_timeout` defaults to one year on both forks, so this does not clear itself.

**Reads.** `information_schema.PROCESSLIST (STATE = 'Waiting for table metadata lock')`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/metadata-locking.html) · Effort S / risk high

<a id="my-lock-007"></a>
### MY-LOCK-007 — Deadlocks occurring regularly

**Priority 150 (Hygiene & low-confidence heuristics) · Locking & long transactions · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** >= 1 deadlock/day with >= 7 total. Overridable thresholds: `deadlocks_per_day=1;min_deadlocks=7`.

**Why it matters.** Two sources because the forks differ: MySQL exposes deadlocks only through INNODB_METRICS.lock_deadlocks; MariaDB exposes both that and the Innodb_deadlocks status variable. The metric's enable-flag column also differs (STATUS vs ENABLED), which 01_session.sql resolves. Deadlocks are not corruption and not necessarily a bug: InnoDB detects the cycle and rolls back the cheaper transaction, which the application should retry. They are reported at P150 because a rising rate signals an access-order problem, and because most applications do not actually retry. innodb_print_all_deadlocks=OFF means only the most recent one is inspectable via SHOW ENGINE INNODB STATUS, so diagnosis requires waiting for the next one.

**How to confirm.**

`SELECT NAME, COUNT FROM information_schema.INNODB_METRICS WHERE NAME='lock_deadlocks';` and `SHOW ENGINE INNODB STATUS\G` for the most recent one.

**How to fix.** 1. Set `innodb_print_all_deadlocks=ON` so every deadlock is logged, not just the last. 2. Read the graphs: they name both transactions and the index each was waiting on. 3. The fix is almost always to make the application touch rows in a consistent order, and to retry on deadlock — InnoDB rolls back the cheaper transaction and expects the application to try again.

**False positives / caveats.** Deadlocks are normal in a concurrent system and InnoDB resolves them by design. The rate matters, not the existence.

**Reads.** `information_schema.INNODB_METRICS lock_deadlocks (via @dbt_lock_deadlocks), @dbt_s_innodb_deadlocks (MariaDB status variable), @@GLOBAL.innodb_print_all_deadlocks`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-deadlocks.html) · Effort M / risk low

<a id="my-lock-008"></a>
### MY-LOCK-008 — Table-level lock waits

**Priority 150 (Hygiene & low-confidence heuristics) · Locking & long transactions · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Table lock waits >= 1% of table lock requests. Overridable thresholds: `table_lock_wait_ratio=0.01;min_table_locks=10000`.

**Why it matters.** These counters only move for storage engines that take table-level locks — in practice MyISAM, Aria and MEMORY — because InnoDB uses row locks and does not increment them. A non-zero ratio is therefore a symptom whose cause is MY-DUR-007 (non-transactional engines still in use), and the finding says so rather than suggesting a lock-tuning fix that does not exist. Both forks expose the counters identically.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Table_locks_%';`

**How to fix.** Convert the remaining non-InnoDB tables (MY-DUR-007). There is no lock-tuning fix: table-level locking is what those engines do.

**False positives / caveats.** Zero on an all-InnoDB server, because InnoDB does not increment these counters.

**Reads.** `@dbt_s_table_locks_waited, @dbt_s_table_locks_immediate`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/internal-locking.html) · Effort L / risk med

<a id="my-lock-009"></a>
### MY-LOCK-009 — Query running for over 10 minutes

**Priority 100 (Tuning & configuration detail) · Locking & long transactions · scope: session · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A non-replication query has run >= 600 s. Overridable thresholds: `long_query_seconds=600`. Requires: `PROCESS`.

**Why it matters.** Excludes the threads that are legitimately long-lived: replication receivers and appliers (Binlog Dump, Connect, Slave/Replica threads), the event scheduler, and this session itself. Backup tools are excluded by name where they are recognisable, and the details name the account so an unrecognised one is easy to classify. A ten-minute query is not automatically wrong — a nightly report is fine — but on an OLTP server it is usually a missing index (MY-IDX-004, MY-QRY-006/008) or a query that should not be running there at all. It is P100 because the fix is rarely urgent, and it is scoped per session so each one is separately suppressible.

**How to confirm.**

`SELECT ID, USER, HOST, DB, TIME, STATE, INFO FROM information_schema.PROCESSLIST WHERE COMMAND='Query' AND TIME > 600 ORDER BY TIME DESC;`

**How to fix.** Read the statement and the state. `Sending data` means it is reading rows; `Copying to tmp table` means MY-MEM-005; `Waiting for table metadata lock` means MY-LOCK-006. If it should not be running on this server, route it to a replica; if it should, index it (MY-QRY-006).

**False positives / caveats.** Scheduled reports, backups and ETL legitimately run for a long time. The check excludes replication and system threads but cannot know which of your accounts is a batch job.

**Reads.** `information_schema.PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/show-processlist.html) · Effort S / risk low


---

## SEC — Security

<a id="my-sec-001"></a>
### MY-SEC-001 — Accounts with no password

**Priority 1 (You get fired) · Security · scope: role · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An unlocked, non-external-auth account has an empty credential. Requires: `SELECT ON mysql.*`.

**Why it matters.** PRIVACY: this check tests only whether the credential is empty. No hash value is read, compared, echoed or stored, on either fork. Excluded, because an empty credential is correct for them: * external/socket authentication plugins (unix_socket, auth_socket, PAM, LDAP, Kerberos, GSSAPI, AWS IAM) — the credential lives elsewhere; * locked accounts; * MariaDB roles (is_role), which never authenticate; * MariaDB's literal 'invalid' credential marker, which means "this method is deliberately unusable" and implies another auth_or method exists — the default MariaDB root@localhost is exactly this and is not a finding. What remains is an account anyone who can reach the port can log in as.

**How to confirm.**

MySQL: `SELECT User, Host, plugin, account_locked FROM mysql.user WHERE authentication_string='';` MariaDB: `SELECT User, Host, plugin FROM mysql.user WHERE authentication_string IN ('','invalid') AND Password IN ('','invalid');` Never select the hash value itself.

**How to fix.** 1. If the account is unused, `DROP USER`. 2. If it is used, `ALTER USER ... IDENTIFIED BY '<password>'` — and find every application that connects as it first, because they will all break at once. 3. If it should use external authentication, set the plugin explicitly rather than leaving the credential empty. On MariaDB, `ALTER USER ... ACCOUNT LOCK` is a fast way to stop the bleeding without deleting anything.

**False positives / caveats.** An account whose plugin is `unix_socket`, `auth_pam`, LDAP, Kerberos or AWS IAM legitimately has an empty credential and is excluded. MariaDB's default `root@localhost` stores the literal string `invalid` and authenticates through `unix_socket`; that is excluded too and is not a finding.

**Reads.** `normalised account source @dbt_acct_src (01_session.sql §6d)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/assigning-passwords.html) · Effort S / risk med

<a id="my-sec-002"></a>
### MY-SEC-002 — Superuser-equivalent account reachable from any host

**Priority 1 (You get fired) · Security · scope: role · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An account with SUPER or all privileges has a wildcard host pattern. Requires: `SELECT ON mysql.*`.

**Why it matters.** The classic root@'%'. Two conditions must both hold: the account holds SUPER or the full global privilege set, AND its host pattern is a wildcard rather than a specific address. Either alone is defensible; together they mean a single leaked or guessed credential is complete control of the server, from anywhere the network allows. Host patterns treated as unrestricted: '%', '', '%.%', and wildcards that cover whole public ranges. A bare IP or a fully qualified name is not flagged here — MY-SEC-007 lists all privileged accounts for review regardless. Platform-managed accounts (rdsadmin, cloudsqladmin, mysql.sys, mariadb.sys...) are excluded; they are created by the vendor and cannot be removed.

**How to confirm.**

`SELECT User, Host FROM mysql.user WHERE Super_priv='Y' AND Host IN ('%','') ;` and `SHOW GRANTS FOR '<user>'@'%';`

**How to fix.** 1. Replace the wildcard host with the specific addresses or subnet that actually connect — `RENAME USER 'root'@'%' TO 'root'@'10.0.1.%';` preserves the grants. 2. Or drop the account if it duplicates a localhost one. 3. Then reduce the privileges: an application never needs SUPER. Do this in a window: any application currently using the account stops working the moment the host changes.

**False positives / caveats.** A bastion or admin subnet may legitimately need broad reach; a specific CIDR is still better than `%`. Platform-managed accounts (rdsadmin, cloudsqladmin, azure_superuser) are excluded because they cannot be changed.

**Reads.** `normalised account source @dbt_acct_src`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/privileges-provided.html) · Effort S / risk med

<a id="my-sec-003"></a>
### MY-SEC-003 — Anonymous accounts present

**Priority 5 (One step from fired) · Security · scope: role · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An account with an empty username exists. Requires: `SELECT ON mysql.*`.

**Why it matters.** An account with an empty User matches ANY username at authentication time. Two consequences people are routinely surprised by: anyone can connect without supplying a valid username, and — because MySQL sorts the user table most-specific-host-first — an anonymous ''@'localhost' entry is matched BEFORE a real 'app'@'%' entry for a connection from localhost, so a legitimate user silently authenticates as the anonymous one and loses their privileges. MariaDB's mariadb-install-db still creates these on some packagings; MySQL 5.7+ does not, and mysql_secure_installation removes them.

**How to confirm.**

`SELECT User, Host FROM mysql.user WHERE User='';`

**How to fix.** `DROP USER ''@'localhost'; DROP USER ''@'<hostname>';` — or run `mysql_secure_installation`, which removes them along with the `test` schema. Check first whether anything connects anonymously; because of MySQL's most-specific-host-first matching, an application may be silently authenticating as the anonymous account today and will start failing when it is removed.

**False positives / caveats.** None. Anonymous accounts are a pre-2000 default with no modern use.

**Reads.** `normalised account source @dbt_acct_src`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/default-privileges.html) · Effort S / risk med

<a id="my-sec-004"></a>
### MY-SEC-004 — Application accounts allowed from any host

**Priority 100 (Tuning & configuration detail) · Security · scope: role · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A non-privileged account has a wildcard host pattern. Requires: `SELECT ON mysql.*`.

**Why it matters.** Summary shape (DESIGN §2.1 form b): one finding with a count and the list, because a fleet legitimately has many such accounts and one row each would bury the report. Confidence is LOW on purpose: a wildcard host is normal when a security group, VPC or firewall already constrains who can reach the port, and db-triage cannot see any of that. This is a review item, not a defect — which is exactly how the design says absence-of-evidence checks must be phrased. Accounts already reported by MY-SEC-002 (privileged AND wildcard) are excluded so the P1 finding is not diluted by being restated at P100.

**How to confirm.**

`SELECT User, Host FROM mysql.user WHERE Host IN ('%','') OR Host LIKE '%\%%';`

**How to fix.** Narrow each host pattern to the network that actually connects. Where the application runs on ephemeral addresses, a CIDR wildcard (`10.2.%`) is still far better than `%`.

**False positives / caveats.** Low confidence by design: a wildcard host is normal behind a firewall, a security group or a private network, and db-triage can see none of those. This is a review item, not a defect.

**Reads.** `normalised account source @dbt_acct_src`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/account-names.html) · Effort M / risk med

<a id="my-sec-005"></a>
### MY-SEC-005 — TLS not enforced, or largely unused

**Priority 100 (Tuning & configuration detail) · Security · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** require_secure_transport OFF and TLS used by < 50% of connections. Overridable thresholds: `tls_usage_ratio=0.50`.

**Why it matters.** Version divergence handled through the bundle: have_ssl was deprecated in MySQL 8.0.26 and REMOVED in 8.4 (replaced by the performance_schema tls_channel_status table); require_secure_transport arrived in MySQL 5.7.8 and MariaDB 10.5. A NULL from the bundle means "this fork/version does not have the variable", not "off". Two separate statements, reported together because the fix differs: * require_secure_transport OFF means an unencrypted connection is ACCEPTED, even if most clients happen to use TLS; * a low Ssl_accepts / Connections ratio means clients are in fact connecting in the clear right now. Per-account REQUIRE SSL clauses are not visible here, so a server that enforces TLS through grants rather than globally will still fire — hence medium confidence and the wording.

**How to confirm.**

`SELECT @@GLOBAL.require_secure_transport, @@GLOBAL.tls_version;` and `SHOW GLOBAL STATUS LIKE 'Ssl_accepts';` against `Connections`. Per-session: `SELECT * FROM performance_schema.session_ssl_status;`

**How to fix.** 1. Confirm the server has a usable certificate (MySQL 5.7+ and MariaDB 10.4+ auto-generate one at first start). 2. Move clients to TLS and verify with `Ssl_accepts`. 3. Only then `SET GLOBAL require_secure_transport = ON` — doing it before the clients are ready locks them out immediately. Per-account `REQUIRE SSL` is the incremental path.

**False positives / caveats.** Per-account `REQUIRE SSL` clauses are not visible to this check, so a server that enforces TLS through grants rather than globally will still fire. Connections over a Unix socket do not need TLS and count against the ratio.

**Reads.** `@dbt_v_require_secure_transport, @dbt_v_have_ssl, @dbt_v_tls_version, @dbt_s_ssl_accepts, @dbt_s_connections`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/using-encrypted-connections.html) · Effort M / risk med

<a id="my-sec-006"></a>
### MY-SEC-006 — Deprecated or weak authentication plugins

**Priority 150 (Hygiene & low-confidence heuristics) · Security · scope: role · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An account uses mysql_native_password, mysql_old_password or sha256_password. Requires: `SELECT ON mysql.*`.

**Why it matters.** Version divergence that turns this from hygiene into a migration deadline: MySQL 8.0     mysql_native_password deprecated, still enabled by default MySQL 8.4     DISABLED by default (--mysql-native-password=OFF); accounts using it cannot authenticate until it is explicitly re-enabled MySQL 9.0     REMOVED entirely; those accounts must be re-created MariaDB       mysql_native_password remains supported and is still the default for many packagings, so there is no deadline there — only the cryptographic argument Why it is weak regardless of deadline: mysql_native_password is unsalted SHA1(SHA1(password)). The stored hash is password-equivalent for the challenge-response handshake, so an attacker who reads mysql.user does not need to crack anything. sha256_password (as distinct from caching_sha2_password) additionally requires TLS or RSA key exchange to be safe and is deprecated in 8.0.16+. Summary shape: one row per plugin with a count, not one row per account.

**How to confirm.**

`SELECT plugin, COUNT(*) FROM mysql.user GROUP BY plugin;`

**How to fix.** MySQL: `ALTER USER ... IDENTIFIED WITH caching_sha2_password BY '<password>';` — verify every client library supports it first (very old connectors do not, and `caching_sha2_password` requires TLS or an RSA key exchange for the first authentication). MariaDB: `ed25519` or PAM. This is a coordinated change, because each account stops working for clients that cannot negotiate the new plugin.

**False positives / caveats.** On MariaDB there is no removal deadline — `mysql_native_password` remains supported — so the argument there is cryptographic rather than a migration cliff. On MySQL 8.4 and 9.0 it is a cliff: those accounts stop being able to authenticate on upgrade.

**Reads.** `normalised account source @dbt_acct_src`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/pluggable-authentication.html) · Effort M / risk med

<a id="my-sec-007"></a>
### MY-SEC-007 — Privileged accounts (review list)

**Priority 230 (Security review) · Security · scope: role · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An account holds any global privilege that escapes its own scope. Requires: `SELECT ON mysql.*`.

**Why it matters.** Not a problem: the list a security reviewer signs off on, in the P230 review band. One row per account so each can be individually accepted or challenged. Covers the global privileges that let an account escape its own scope: SUPER (and its MySQL 8.0 replacements, which are dynamic privileges not visible in mysql.user — noted in the details rather than silently missed), FILE (read and write any file the server user can), PROCESS (see every other session's SQL), GRANT OPTION (privilege escalation), SHUTDOWN, RELOAD, CREATE USER, REPLICATION SLAVE (read the entire change stream). Platform-managed accounts are excluded.

**How to confirm.**

`SELECT * FROM information_schema.USER_PRIVILEGES ORDER BY GRANTEE;` and, on MySQL 8.0, `SELECT * FROM mysql.global_grants;` for the dynamic privileges this list cannot show.

**How to fix.** For each account, confirm it is still needed and still needs what it holds. Move applications to least-privilege grants scoped to their own schema. On MySQL 8.0 use the dynamic privileges (`BACKUP_ADMIN`, `REPLICATION_APPLIER`, `SYSTEM_VARIABLES_ADMIN`) instead of SUPER; on MariaDB use the split privileges (`BINLOG MONITOR`, `CONNECTION ADMIN`, `READ_ONLY ADMIN`).

**False positives / caveats.** A review list, not a finding. MySQL 8.0 dynamic privileges live in `mysql.global_grants` and MariaDB's split privileges live in `mysql.global_priv` JSON; neither appears in the `mysql.user` columns this check reads, so the list is a floor, not a ceiling.

**Reads.** `normalised account source @dbt_acct_src`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/privileges-provided.html) · Effort S / risk low

<a id="my-sec-008"></a>
### MY-SEC-008 — Application connections running as a privileged account

**Priority 50 (Daily-briefing ceiling) · Security · scope: role · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** >= 5 concurrent non-local connections from a privileged account. Overridable thresholds: `privileged_conn_count=5`. Requires: `PROCESS;SELECT ON mysql.*`.

**Why it matters.** The difference between "a privileged account exists" (MY-SEC-007, a review item) and "the application is using one right now" (this, a finding). Five or more concurrent non-local connections from an account holding SUPER or the full privilege set is an application connecting as an administrator: every SQL injection is then a server compromise rather than a data leak, and no least-privilege boundary exists to contain a bad deployment. Localhost connections are excluded — that is where a DBA and the backup tool legitimately live.

**How to confirm.**

`SELECT USER, HOST, COUNT(*) FROM information_schema.PROCESSLIST GROUP BY USER, HOST;` joined against the privileged accounts from MY-SEC-007.

**How to fix.** Create a least-privilege account for the application, grant it only what its schema needs, change the application's configuration, and then remove the privileged account's remote access. Do it in that order: revoking first causes an outage.

**False positives / caveats.** A migration tool or a schema-management service legitimately connects with elevated privileges — but usually briefly, not with five concurrent connections.

**Reads.** `information_schema.PROCESSLIST joined to the normalised account source`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/privileges-provided.html) · Effort M / risk med

<a id="my-sec-009"></a>
### MY-SEC-009 — LOAD DATA LOCAL enabled

**Priority 100 (Tuning & configuration detail) · Security · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** local_infile = ON.

**Why it matters.** The threat runs the wrong way round from what the name suggests. With local_infile ON, a malicious or compromised SERVER can answer any client query with a request for a local file, and a client library that honours it will upload that file — /etc/passwd, an SSH key, an application config — without the user doing anything. The database is the attacker and the client is the victim, which is why it is a server-side setting worth turning off even though the exposure is client-side. MySQL 8.0 and MariaDB 10.x both default it to OFF; finding it ON means an import job needed it once. Universal variable, no version gate needed.

**How to confirm.**

`SELECT @@GLOBAL.local_infile;`

**How to fix.** `SET GLOBAL local_infile = OFF;` — dynamic on both forks — and set it in the configuration file. If an import job needs it, enable it for the duration of the job rather than permanently, or use `LOAD DATA INFILE` from a server-side path constrained by `secure_file_priv`.

**False positives / caveats.** A data-loading pipeline that genuinely uses `LOAD DATA LOCAL` needs it on. Note the client side can also refuse, which is the more robust place to enforce it.

**Reads.** `@@GLOBAL.local_infile`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/load-data-local-security.html) · Effort S / risk low

<a id="my-sec-010"></a>
### MY-SEC-010 — FILE privilege unrestricted by secure_file_priv

**Priority 100 (Tuning & configuration detail) · Security · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** secure_file_priv empty and at least one account holds FILE. Requires: `SELECT ON mysql.*`.

**Why it matters.** Derived: neither half is a finding alone. secure_file_priv empty means SELECT ... INTO OUTFILE and LOAD_FILE() may read and write ANY path the mysqld OS user can reach; that only matters if some account actually holds FILE. Together they mean any of those accounts can read the server's private key, /etc/shadow if mysqld runs as root, or any other database's data files, and can write files into directories the OS user owns. Empty string and NULL mean different things: NULL/absent (MySQL 5.7 default on some builds) also disables the restriction; a path restricts to that directory; the literal string 'NULL' disables the feature entirely, which is the secure setting and is deliberately NOT flagged.

**How to confirm.**

`SELECT @@GLOBAL.secure_file_priv;` and `SELECT User, Host FROM mysql.user WHERE File_priv='Y';`

**How to fix.** 1. `REVOKE FILE ON *.* FROM ...` for every account that does not demonstrably need it — which is nearly all of them. 2. Set `secure_file_priv` to a dedicated directory, or to the literal `NULL` to disable server-side file access entirely. It is read-only at runtime, so this needs a restart.

**False positives / caveats.** A documented ETL process that exports through `SELECT ... INTO OUTFILE` needs both; point `secure_file_priv` at its directory rather than leaving it empty.

**Reads.** `@dbt_v_secure_file_priv, normalised account source (FILE holders)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_secure_file_priv) · Effort S / risk med

<a id="my-sec-011"></a>
### MY-SEC-011 — No password validation policy

**Priority 150 (Hygiene & low-confidence heuristics) · Security · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** No password validation plugin or component is active.

**Why it matters.** Fork divergence in both the mechanism and the name: MySQL 5.7        validate_password PLUGIN MySQL 8.0+       validate_password COMPONENT, registered in mysql.component (the plugin form still loads but is deprecated) MariaDB          simple_password_check and/or cracklib_password_check plugins; there is no validate_password at all All three are probed; the component table is only consulted where it exists. Without any of them the server accepts a one-character password, which matters most for the accounts MY-SEC-002/004 says are reachable from anywhere. Password EXPIRY is deliberately not part of this finding: forced rotation is reported as a review row at P200 (MY-SEC-013) rather than as a defect, because current guidance does not treat expiry as a control.

**How to confirm.**

`SELECT PLUGIN_NAME, PLUGIN_STATUS FROM information_schema.PLUGINS WHERE PLUGIN_NAME LIKE '%password%';` and, on MySQL 8.0, `SELECT * FROM mysql.component;`

**How to fix.** MySQL 8.0: `INSTALL COMPONENT 'file://component_validate_password';` then set `validate_password.policy` and `validate_password.length`. MySQL 5.7: `INSTALL PLUGIN validate_password SONAME 'validate_password.so';` MariaDB: `INSTALL SONAME 'simple_password_check';` and optionally `cracklib_password_check`. Note that installing it does not retroactively check existing passwords.

**False positives / caveats.** A server where every account authenticates externally (PAM, LDAP, IAM, unix_socket) has no passwords to validate, and the policy is enforced upstream.

**Reads.** `information_schema.PLUGINS, mysql.component (MySQL 8.0+)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/validate-password.html) · Effort M / risk med

<a id="my-sec-012"></a>
### MY-SEC-012 — Legacy test database or test grants present

**Priority 150 (Hygiene & low-confidence heuristics) · Security · scope: schema · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** The legacy test schema exists.

**Why it matters.** Historic MySQL packaging created a `test` schema plus rows in mysql.db that grant every privilege on `test` and `test\_%` to ANY user, including the anonymous ones (MY-SEC-003). The combination gives an unauthenticated connection a writable schema on the server — useful for staging an INTO OUTFILE attack or simply for filling the disk. MariaDB's mariadb-install-db still creates it on several packagings (verified present on a stock MariaDB 10.11 install); MySQL 5.7+ does not, and mysql_secure_installation removes it. Read through information_schema.SCHEMA_PRIVILEGES rather than mysql.db so the check works without SELECT on the mysql schema.

**How to confirm.**

`SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='test';` and `SELECT * FROM information_schema.SCHEMA_PRIVILEGES WHERE TABLE_SCHEMA LIKE 'test%';`

**How to fix.** `DROP DATABASE test;` and remove the wildcard grants (`DELETE FROM mysql.db WHERE Db LIKE 'test%'` followed by `FLUSH PRIVILEGES`, or `REVOKE` the grants properly). `mysql_secure_installation` does both. Confirm nothing actually uses the schema first — it is occasionally repurposed.

**False positives / caveats.** A `test` schema created deliberately for scratch work is a different thing from the packaged one; what makes the packaged one dangerous is the accompanying wildcard grant.

**Reads.** `information_schema.SCHEMATA, information_schema.SCHEMA_PRIVILEGES`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/default-privileges.html) · Effort S / risk low

<a id="my-sec-013"></a>
### MY-SEC-013 — Accounts without password expiry (review)

**Priority 200 (Non-default configuration) · Security · scope: role · cost 0 · inventory pass · engine: mysql · since 0.1.0**

**What fires it.** Accounts inherit an unlimited default_password_lifetime. Requires: `SELECT ON mysql.*`.

**Why it matters.** Reported as a P200 review row, NOT as a problem. Forced rotation is no longer recommended by NIST SP 800-63B or by most corporate standards, so db-triage states the position rather than asserting a defect — which is what the design asks for. Fork divergence: mysql.user.password_lifetime is a MySQL column. MariaDB's mysql.user view does not have it (verified absent on 10.11) — MariaDB does support ALTER USER ... PASSWORD EXPIRE INTERVAL but stores it in the global_priv JSON under a different key — so the normalised source returns NULL there and this check emits nothing on MariaDB.

**How to confirm.**

`SELECT @@GLOBAL.default_password_lifetime;` and `SELECT User, Host, password_lifetime FROM mysql.user;` (MySQL only).

**How to fix.** No action is recommended. Current guidance (NIST SP 800-63B) treats scheduled rotation as harmful rather than protective. If a compliance regime requires expiry, set `default_password_lifetime` and make sure every application can rotate without downtime first — an expired application password is an outage.

**False positives / caveats.** Reported at P200 as a review row precisely because expiry is not a control db-triage recommends. MariaDB has no `password_lifetime` column, so this check does not run there.

**Reads.** `normalised account source (password_lifetime), @dbt_v_default_password_lifetime`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/password-management.html) · Effort S / risk low

<a id="my-sec-014"></a>
### MY-SEC-014 — Listening on all interfaces (review)

**Priority 200 (Non-default configuration) · Security · scope: setting · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** bind_address is unrestricted and skip_networking is OFF.

**Why it matters.** Inventory, at P200, because a database on a private network legitimately binds to every interface and db-triage cannot see the firewall. It is recorded because it is the context in which MY-SEC-002 and MY-SEC-004 are read: a wildcard-host superuser account matters far more when the port answers on every interface than when it answers only on loopback. MySQL 8.0.13+ accepts a comma-separated list and the special values '*', '0.0.0.0' and '::'; MariaDB accepts '*' and a single address. All the unrestricted spellings are matched.

**How to confirm.**

`SELECT @@GLOBAL.bind_address, @@GLOBAL.port, @@GLOBAL.skip_networking;` and, from the OS, `ss -tlnp | grep mysqld`.

**How to fix.** If only local applications connect, bind to a specific private address or to `127.0.0.1`. Otherwise rely on the firewall and record that decision. It is read-only at runtime, so changing it needs a restart.

**False positives / caveats.** Inventory at P200: binding to all interfaces on a private network with a security group in front is normal. It is listed because it is the context for MY-SEC-002 and MY-SEC-004.

**Reads.** `@@GLOBAL.bind_address, @@GLOBAL.port, @@GLOBAL.skip_networking`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_bind_address) · Effort M / risk med

<a id="my-sec-015"></a>
### MY-SEC-015 — No audit logging (review)

**Priority 200 (Non-default configuration) · Security · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** No audit plugin or component is active.

**Why it matters.** Fork and edition divergence, all four cases probed: MySQL Enterprise   audit_log plugin (component form in 8.0.30+) Percona Server     audit_log plugin (free) MariaDB            server_audit plugin (free) MySQL Community    no audit facility at all; the general log (MY-CAP-007) is the only alternative and is not an audit trail Inventory at P200: whether an audit trail is required is a compliance question, not a database one. What db-triage supplies is the fact, so the reviewer does not have to ask.

**How to confirm.**

`SELECT PLUGIN_NAME, PLUGIN_STATUS FROM information_schema.PLUGINS WHERE PLUGIN_TYPE='AUDIT' OR PLUGIN_NAME LIKE '%audit%';`

**How to fix.** MariaDB: `INSTALL SONAME 'server_audit';` then configure `server_audit_events` and `server_audit_logging`. Percona Server ships a free `audit_log`. Oracle MySQL Community has no audit facility — the options there are Enterprise, a proxy that logs (ProxySQL), or accepting the gap. Do not substitute the general query log: it records statements but not outcomes, costs 10-20% throughput, and fills disks (MY-CAP-007).

**False positives / caveats.** Whether an audit trail is required is a compliance question, which is why this is a P200 review row rather than a finding.

**Reads.** `information_schema.PLUGINS, mysql.component`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/audit-log.html) · Effort M / risk low


---

## IDX — Indexes

<a id="my-idx-001"></a>
### MY-IDX-001 — Unused index of 1 GB or more

**Priority 50 (Daily-briefing ceiling) · Indexes · scope: index · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An index >= 1 GB has zero reads since restart. Overridable thresholds: `unused_index_bytes=1073741824;min_uptime_days=30`. Requires: `SELECT ON performance_schema.*;SELECT ON mysql.*`.

**Why it matters.** Availability, verified: sys.schema_unused_indexes exists on MySQL 5.7+ and MariaDB 10.6+ with the same three columns (object_schema, object_name, index_name). Where sys is absent the check reads performance_schema.table_io_waits_summary_by_index_usage itself, which is what the view is built on, so the result is identical. Index SIZE is the harder half: information_schema has no per-index size at all. mysql.innodb_index_stats carries a 'size' row per index measured in PAGES, so bytes = size x innodb_page_size. That table is written by InnoDB's persistent statistics and exists on both forks. THE CAVEAT THAT MUST TRAVEL WITH THIS FINDING: index usage is counted PER INSTANCE and only since the last restart. An index unused on this server may be the one the reporting replica depends on. Never drop on this evidence alone — check every replica, and check that uptime covers a full business cycle including month-end. That is why min_uptime_days defaults to 30.

**How to confirm.**

`SELECT * FROM sys.schema_unused_indexes;` and for size `SELECT database_name, table_name, index_name, stat_value*@@innodb_page_size AS bytes FROM mysql.innodb_index_stats WHERE stat_name='size' ORDER BY bytes DESC;`

**How to fix.** 1. Check EVERY replica before dropping: run the same query there. An index unused on the primary is routinely the one the reporting replica depends on. 2. Check that uptime spans a full business cycle including month-end and quarter-end. 3. Make it invisible first rather than dropping it: `ALTER TABLE ... ALTER INDEX <name> INVISIBLE` (MySQL 8.0) or `ALTER TABLE ... ALTER INDEX <name> IGNORED` (MariaDB 10.6+) — the optimizer stops using it while the index is still maintained, so reverting is instant instead of a rebuild. 4. Drop it a week later if nothing broke.

**False positives / caveats.** The single largest false-positive source in this catalog: usage counters are per instance and reset on restart. The check refuses to raise confidence above medium until uptime exceeds 30 days for that reason.

**Reads.** `sys.schema_unused_indexes, or performance_schema.table_io_waits_summary_by_index_usage directly; mysql.innodb_index_stats (stat_name='size') x @@innodb_page_size for size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/sys-schema-unused-indexes.html) · Effort S / risk med

<a id="my-idx-002"></a>
### MY-IDX-002 — Unused index (smaller, or statistics window too short)

**Priority 150 (Hygiene & low-confidence heuristics) · Indexes · scope: index · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An index >= 50 MB and < 1 GB has zero reads since restart. Overridable thresholds: `small_unused_index_bytes=52428800;unused_index_bytes=1073741824;min_uptime_days=30`. Requires: `SELECT ON performance_schema.*;SELECT ON mysql.*`.

**Why it matters.** Availability, verified: sys.schema_unused_indexes exists on MySQL 5.7+ and MariaDB 10.6+ with the same three columns (object_schema, object_name, index_name). Where sys is absent the check reads performance_schema.table_io_waits_summary_by_index_usage itself, which is what the view is built on, so the result is identical. Index SIZE is the harder half: information_schema has no per-index size at all. mysql.innodb_index_stats carries a 'size' row per index measured in PAGES, so bytes = size x innodb_page_size. That table is written by InnoDB's persistent statistics and exists on both forks. THE CAVEAT THAT MUST TRAVEL WITH THIS FINDING: index usage is counted PER INSTANCE and only since the last restart. An index unused on this server may be the one the reporting replica depends on. Never drop on this evidence alone — check every replica, and check that uptime covers a full business cycle including month-end. That is why min_uptime_days defaults to 30.

**How to confirm.**

As MY-IDX-001.

**How to fix.** As MY-IDX-001, but the space saved is negligible at this size — the only real argument is write cost. Treat it as a review list and batch the invisibility experiment.

**False positives / caveats.** As MY-IDX-001, and more so: the smaller the index, the weaker the case for taking any risk.

**Reads.** `sys.schema_unused_indexes, or performance_schema.table_io_waits_summary_by_index_usage directly; mysql.innodb_index_stats (stat_name='size') x @@innodb_page_size for size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/sys-schema-unused-indexes.html) · Effort S / risk med

<a id="my-idx-003"></a>
### MY-IDX-003 — Redundant or duplicate indexes

**Priority 50 (Daily-briefing ceiling) · Indexes · scope: index · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An index is a leftmost prefix of, or identical to, another index.

**Why it matters.** Availability, verified on MariaDB 10.11: sys.schema_redundant_indexes exists on MySQL 5.7+ and MariaDB 10.6+ with identical columns, including the ready-made sql_drop_index text. The fallback reproduces the leftmost-prefix comparison directly from information_schema.STATISTICS by building each index's ordered column list and testing prefix containment. Unlike MY-IDX-001 this needs no usage statistics and carries no per-instance caveat: an index that is a strict leftmost prefix of another is redundant as a matter of B-tree structure, on every replica, forever. Any query the prefix index can serve, the longer index can serve at the same cost. The exception the check respects: a UNIQUE index is never redundant to a non-unique one, because it also enforces a constraint.

**How to confirm.**

`SELECT * FROM sys.schema_redundant_indexes;` — it includes a ready-made `sql_drop_index` column.

**How to fix.** Drop the redundant index. Unlike MY-IDX-001 this needs no per-replica verification: a strict leftmost prefix is redundant as a matter of B-tree structure, everywhere, always. Two exceptions to check by hand: a UNIQUE index is never redundant to a non-unique one because it also enforces a constraint, and an index with a column prefix (`KEY (col(20))`) is not necessarily covered by one without.

**False positives / caveats.** The prefix-index case is flagged in the finding via `subpart_exists`. A foreign key also requires an index on its referencing columns; dropping that index can fail or silently keep an auto-created replacement.

**Reads.** `sys.schema_redundant_indexes, or an information_schema.STATISTICS self-join where sys is absent`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/sys-schema-redundant-indexes.html) · Effort S / risk low

<a id="my-idx-004"></a>
### MY-IDX-004 — Large table with heavy full table scans

**Priority 50 (Daily-briefing ceiling) · Indexes · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A table >= 1 GB has >= 10 M rows read without an index. Overridable thresholds: `scan_table_bytes=1073741824;rows_full_scanned=10000000`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Availability, verified: the view exists on MySQL 5.7+ and MariaDB 10.6+ with the same columns. It is derived from performance_schema.table_io_waits_summary_by_index_usage where INDEX_NAME IS NULL — that is, reads that used no index at all. Confidence is medium and the wording is careful, because a full scan is not automatically wrong: on a small table it is the cheapest plan, and an analytical query over a large table may legitimately scan it. What the numbers here establish is volume — ten million rows read without an index on a table over a gigabyte is a workload characteristic, not a one-off report. The finding deliberately does NOT propose an index: db-triage points at the table and at the statements (MY-QRY-006/008) and stops there, because inventing an index definition from a scan count is how bad indexes get made.

**How to confirm.**

`SELECT * FROM sys.schema_tables_with_full_table_scans ORDER BY rows_full_scanned DESC;`

**How to fix.** Read MY-QRY-006 and MY-QRY-008 to find the statements, then `EXPLAIN` them. db-triage deliberately does not propose an index: an index invented from a scan count is how servers end up with the over-indexed tables MY-IDX-005 reports.

**False positives / caveats.** Medium confidence: a full scan is the cheapest plan on a small table and is legitimate for analytics. The volume and table size thresholds exist to filter those out, imperfectly.

**Reads.** `sys.schema_tables_with_full_table_scans (object_schema, object_name, rows_full_scanned), information_schema.TABLES for size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/sys-schema-tables-with-full-table-scans.html) · Effort M / risk low

<a id="my-idx-005"></a>
### MY-IDX-005 — Write-heavy table carrying many indexes

**Priority 100 (Tuning & configuration detail) · Indexes · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A table with >= 10 indexes has taken >= 1 M row writes. Overridable thresholds: `many_indexes=10;min_writes=1000000`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Availability: sys.schema_table_statistics exists on MySQL 5.7+ and MariaDB 10.6+ (verified) with these column names. Without sys the check emits nothing, because an index count with no write volume behind it is not a finding. Every secondary index is a second B-tree that every INSERT must add to, every DELETE must remove from, and every UPDATE of an indexed column must maintain — plus a change-buffer entry or a random read if the index page is not in the buffer pool. Ten indexes on a table taking a million writes means ten times the write amplification of the table itself. This is the input to an index review, not a verdict: MY-IDX-001/002 say which of them are unused and MY-IDX-003 says which are redundant. Read all three together before dropping anything.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS GROUP BY 1,2 ORDER BY 3 DESC;` and `SELECT * FROM sys.schema_table_statistics;`

**How to fix.** Use this as the input to an index review, not as an instruction: cross-reference MY-IDX-001/002 (unused) and MY-IDX-003 (redundant) and drop from those lists. Ten indexes on a write-heavy table is a symptom of indexes being added per query without anyone removing the ones they superseded.

**False positives / caveats.** A table serving many distinct access patterns may genuinely need many indexes. The check reports write volume so the cost is visible alongside the count.

**Reads.** `information_schema.STATISTICS (index count), sys.schema_table_statistics (rows_inserted + rows_updated + rows_deleted)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/optimization-indexes.html) · Effort M / risk med

<a id="my-idx-006"></a>
### MY-IDX-006 — Table fragmentation (DATA_FREE) high

**Priority 100 (Tuning & configuration detail) · Indexes · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** DATA_FREE >= 30% of data plus index on a table >= 1 GB. Overridable thresholds: `fragmented_table_bytes=1073741824;data_free_ratio=0.30`.

**Why it matters.** CONFIDENCE IS LOW AND THAT IS NOT A HEDGE. DATA_FREE is coarse: it counts fully free EXTENTS (1 MB units), not free space inside partly used pages, so it understates real fragmentation on a table with many half-empty pages and overstates it right after a bulk delete that has not been purged. It is also meaningless unless innodb_file_per_table is ON: for a table inside the shared tablespace, DATA_FREE reports the free space of the ENTIRE ibdata1 file, repeated identically for every such table. The check therefore requires per-table tablespaces and says so (MY-SCHEMA-013 covers the other case). On MySQL 8.0 the value additionally comes from the information_schema cache and can be a day old. The remedy — OPTIMIZE TABLE, or ALTER TABLE ... ENGINE=InnoDB — rebuilds the table. db-triage never runs it, and on a live server it should be done through pt-online-schema-change or gh-ost rather than in place.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, DATA_FREE, DATA_LENGTH, INDEX_LENGTH FROM information_schema.TABLES WHERE DATA_FREE > 0 ORDER BY DATA_FREE DESC;` For a real measurement, compare the `.ibd` file size on disk against `DATA_LENGTH+INDEX_LENGTH`.

**How to fix.** `ALTER TABLE ... ENGINE=InnoDB` (or `OPTIMIZE TABLE`, which does the same for InnoDB) rebuilds and compacts it. On a live server run it through `pt-online-schema-change` or `gh-ost`; in place it takes a metadata lock and needs free disk equal to the table size. db-triage never runs any of them.

**False positives / caveats.** Low confidence and deliberately so: DATA_FREE counts whole free 1 MB extents, not free space inside partly filled pages, so it understates fragmentation after many small deletes and overstates it right after a bulk delete purge has not processed. It is meaningless without `innodb_file_per_table`.

**Reads.** `information_schema.TABLES (DATA_FREE, DATA_LENGTH, INDEX_LENGTH), @@GLOBAL.innodb_file_per_table`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/optimize-table.html) · Effort L / risk med

<a id="my-idx-007"></a>
### MY-IDX-007 — Single-column index on a very low-cardinality column

**Priority 150 (Hygiene & low-confidence heuristics) · Indexes · scope: index · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A single-column index has cardinality <= 3 on a table >= 100 MB. Overridable thresholds: `low_cardinality=3;idx_table_bytes=104857600`.

**Why it matters.** CARDINALITY is an ESTIMATE produced by InnoDB's index dives (innodb_stats_persistent_sample_pages, default 20), not a count, and it is stale until statistics are recalculated — which is why this is P150 with medium confidence rather than a firm recommendation, and why MY-IDX-008 checks whether those statistics are stale at all. The mechanism: an index on a column with three distinct values over a million rows selects a third of the table per lookup. The optimizer costs that as worse than a table scan — because with InnoDB's clustered layout every secondary-index hit is a second lookup into the primary key — so the index is never chosen, yet it is still maintained on every write. Two legitimate exceptions the finding names rather than assumes away: a skewed distribution where the rare value is the one queried, and use as the leading column of a composite index (excluded here by construction).

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, COLUMN_NAME, CARDINALITY FROM information_schema.STATISTICS WHERE SEQ_IN_INDEX=1 ORDER BY CARDINALITY;` Confirm the real distribution with a `GROUP BY` on the column — that is a table scan, so do it on a replica.

**How to fix.** Usually drop it. Before doing so, check whether the distribution is skewed: an index on a `status` column with three values is useless for the common value and excellent for the rare one, and the optimizer will use it for the rare one. If that is the access pattern, keep it.

**False positives / caveats.** CARDINALITY is an estimate from InnoDB index dives and is stale until statistics are recalculated — see MY-IDX-008. It is also per-index-prefix, so a low value on a composite index's first column says nothing about the index as a whole (composites are excluded here).

**Reads.** `information_schema.STATISTICS (CARDINALITY), information_schema.TABLES`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/mysql-indexes.html) · Effort S / risk med

<a id="my-idx-008"></a>
### MY-IDX-008 — InnoDB persistent statistics stale

**Priority 150 (Hygiene & low-confidence heuristics) · Indexes · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** InnoDB statistics >= 30 days old, or innodb_stats_persistent OFF. Overridable thresholds: `stats_age_days=30;stats_table_bytes=1073741824`. Requires: `SELECT ON mysql.*`.

**Why it matters.** mysql.innodb_table_stats exists on both forks (MySQL 5.6+, MariaDB 10.0+) with the same last_update column. Two distinct causes, distinguished in the text because the fixes differ: innodb_stats_persistent = OFF — statistics are recomputed by sampling on every server restart and on some metadata operations, so they are both unstable and never durable. Plans change after a restart for no reason. innodb_stats_auto_recalc = ON but last_update is old — automatic recalculation only triggers when more than 10% of the rows have changed. A large append-only table never reaches 10% in any reasonable time, so its statistics silently describe the table as it was months ago. Stale statistics are what makes the optimizer choose the wrong index on a table that has grown, and they are the input to MY-IDX-007's cardinality figures — which is why that check is medium confidence. The fix (ANALYZE TABLE) is a write operation and is on db-triage's forbidden list; the human runs it.

**How to confirm.**

`SELECT database_name, table_name, last_update, n_rows FROM mysql.innodb_table_stats ORDER BY last_update;` and `SELECT @@GLOBAL.innodb_stats_persistent, @@GLOBAL.innodb_stats_auto_recalc;`

**How to fix.** `ANALYZE TABLE <table>;` — a write, so db-triage never runs it. On a large table under MySQL 8.0 it is fast because it only re-samples, but it does invalidate the table's cached plans. Set `innodb_stats_persistent=ON` (the default since 5.6.6) and consider raising `innodb_stats_persistent_sample_pages` from 20 for tables with skewed data.

**False positives / caveats.** A table that genuinely has not changed does not need new statistics. The check pairs age with size for that reason. Note `innodb_stats_on_metadata` causes statistics to be recalculated by information_schema queries on old versions, which makes `last_update` misleading.

**Reads.** `mysql.innodb_table_stats (last_update), @@GLOBAL.innodb_stats_persistent, @@GLOBAL.innodb_stats_auto_recalc`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-persistent-stats.html) · Effort S / risk low

<a id="my-idx-009"></a>
### MY-IDX-009 — Wide composite indexes

**Priority 150 (Hygiene & low-confidence heuristics) · Indexes · scope: index · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An index spans >= 6 columns on a table >= 100 MB. Overridable thresholds: `wide_index_columns=6;idx_table_bytes=104857600`.

**Why it matters.** Hygiene, reported with the numbers that decide whether it matters. In InnoDB every secondary index entry also carries the full primary key, so a six-column index on a table with a composite primary key is wider still. Three consequences: fewer entries per 16 KB page so more pages to read, more buffer pool consumed by the index, and more work on every write. The leftmost-prefix rule also means a six-column index can only be used by a query that constrains the first column, so the trailing columns earn their width only if queries actually reach them — which the catalog cannot tell you. Hard limits worth knowing and reported alongside: 16 columns per index and 3072 bytes of key length on both forks (767 bytes with COMPACT/REDUNDANT row format, see MY-SCHEMA-012).

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS GROUP BY 1,2,3 HAVING COUNT(*) >= 6;`

**How to fix.** Check what actually queries it (MY-QRY-004) and trim the trailing columns that no query constrains or returns. Remember that InnoDB appends the primary key to every secondary index entry, so the stored width is larger than the declared width.

**False positives / caveats.** A deliberately covering index that lets a hot query avoid touching the table at all is worth its width. The check reports the declared key bytes so that trade is visible.

**Reads.** `information_schema.STATISTICS (SEQ_IN_INDEX, SUB_PART), information_schema.COLUMNS for the declared widths`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/multiple-column-indexes.html) · Effort M / risk med


---

## SCHEMA — Schema design

<a id="my-schema-001"></a>
### MY-SCHEMA-001 — InnoDB tables without a primary key on a replicated source

**Priority 20 (Known-dangerous, not yet hurting) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An InnoDB table has no primary key and row-based binary logging is in use. Overridable thresholds: `max_listed=20`.

**Why it matters.** THE genuinely MySQL-specific hazard, and the reason it outranks its no-replication sibling MY-SCHEMA-002 by 80 priority points: under row-based replication a replica applying an UPDATE or DELETE looks the row up by primary key. With no primary key and no unique NOT NULL index there is nothing to look it up by, so the applier falls back to a FULL TABLE SCAN PER ROW EVENT. A single 100,000-row DELETE on a million-row table becomes 100,000 full scans, and the replica goes from seconds behind to hours behind while the source shows nothing wrong at all. Secondary costs, mentioned because they justify the fix on their own: InnoDB adds a hidden 6-byte row id that all secondary indexes carry, rows have no useful clustering order, and several online-DDL paths are unavailable. Detection is via information_schema.STATISTICS rather than TABLE_CONSTRAINTS because it also reveals whether a usable unique NOT NULL index exists, which is what the replication applier actually looks for.

**How to confirm.**

`SELECT t.TABLE_SCHEMA, t.TABLE_NAME FROM information_schema.TABLES t LEFT JOIN information_schema.STATISTICS s ON s.TABLE_SCHEMA=t.TABLE_SCHEMA AND s.TABLE_NAME=t.TABLE_NAME AND s.INDEX_NAME='PRIMARY' WHERE t.ENGINE='InnoDB' AND t.TABLE_TYPE='BASE TABLE' AND s.INDEX_NAME IS NULL;` On a replica, watch the applier: a row event against a primary-key-less table shows as a long `Applying batch of row changes` state.

**How to fix.** 1. Add a primary key. If a natural one exists and is stable, use it. If not, add `id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY`. 2. On a large table do it with `pt-online-schema-change` or `gh-ost` — an in-place `ALTER` rebuilds the table and takes a metadata lock (MY-LOCK-006). 3. A UNIQUE NOT NULL index is an acceptable substitute for replication purposes but does not give you the clustering benefits. 4. Afterwards, set `sql_require_primary_key=ON` (MY-SCHEMA-003) so it cannot recur.

**False positives / caveats.** A tiny lookup table of a dozen rows that is never updated has none of these problems in practice — the replica full scan is over a dozen rows. Size is reported in the finding so that judgement is possible. MyISAM tables are excluded because they have larger problems (MY-DUR-007).

**Reads.** `information_schema.TABLES, information_schema.STATISTICS (PRIMARY), @@GLOBAL.binlog_format, @@GLOBAL.log_bin, @dbt_binlog_dump_threads`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-features-differing-tables.html) · Effort L / risk med

<a id="my-schema-002"></a>
### MY-SCHEMA-002 — InnoDB tables without a primary key

**Priority 100 (Tuning & configuration detail) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** An InnoDB table has no primary key and row-based binary logging is not in use. Overridable thresholds: `max_listed=20`.

**Why it matters.** The lower-priority sibling of MY-SCHEMA-001: same defect, but binary logging is off or set to STATEMENT, so the row-based-replication disaster (a full table scan per row event on the replica) does not apply today. It applies the moment anyone enables binary logging or attaches a replica, which is why this is still reported rather than ignored. The costs that apply regardless of replication: InnoDB assigns a hidden 6-byte row id that every secondary index carries, rows have no useful clustering order so range scans are random I/O, and several ALGORITHM=INPLACE online-DDL paths are unavailable. Detection is via information_schema.STATISTICS rather than TABLE_CONSTRAINTS because it also reveals whether a usable unique NOT NULL index exists, which is what the replication applier actually looks for.

**How to confirm.**

As MY-SCHEMA-001.

**How to fix.** As MY-SCHEMA-001, with less urgency: the replica full-scan hazard does not apply until binary logging is enabled or a replica is attached. The clustering and online-DDL costs apply now.

**False positives / caveats.** As MY-SCHEMA-001.

**Reads.** `information_schema.TABLES, information_schema.STATISTICS (PRIMARY), @@GLOBAL.binlog_format, @@GLOBAL.log_bin, @dbt_binlog_dump_threads`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-index-types.html) · Effort L / risk med

<a id="my-schema-003"></a>
### MY-SCHEMA-003 — sql_require_primary_key off while primary-key-less tables exist

**Priority 150 (Hygiene & low-confidence heuristics) · Schema design · scope: setting · cost 1 · fast pass · engine: mysql · since 0.1.0**

**What fires it.** sql_require_primary_key OFF while primary-key-less tables exist.

**Why it matters.** Availability: introduced in MySQL 8.0.13. MariaDB has no such variable at all (verified absent on 10.11), so the bundle returns NULL there and this check emits nothing rather than recommending something that cannot be done. Derived: only fires when MY-SCHEMA-001 or MY-SCHEMA-002 already found primary-key-less tables. Turning the variable on does not fix the existing ones — it prevents the next one, which is why it is P150 hygiene rather than part of the fix for the P20 finding. Note it also blocks CREATE TABLE without a PK for every account including migrations and ORMs, so it is a change that needs coordinating.

**How to confirm.**

`SELECT @@GLOBAL.sql_require_primary_key;` (MySQL 8.0.13+ only).

**How to fix.** `SET GLOBAL sql_require_primary_key = ON;` after fixing the existing tables — it does not affect them. Coordinate with whoever ships schema changes: it applies to every session including migrations and ORM-generated DDL, and a migration that creates a table without a primary key will fail.

**False positives / caveats.** It also blocks replicated DDL from a source that does not enforce it, which will stop replication. Enable it on the source first.

**Reads.** `@dbt_v_sql_require_primary_key, information_schema.TABLES/STATISTICS`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_sql_require_primary_key) · Effort S / risk med

<a id="my-schema-004"></a>
### MY-SCHEMA-004 — sql_mode is not strict

**Priority 50 (Daily-briefing ceiling) · Schema design · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Global sql_mode lacks a STRICT mode or a zero-date restriction.

**Why it matters.** IMPORTANT: this check must never read @@sql_mode or @@SESSION.sql_mode. 01_session.sql deliberately sets a fixed SESSION sql_mode so the dynamic SQL elsewhere parses identically on every fork, which would make a session-scoped reading of this check report db-triage's own setting. @dbt_global_sql_mode is the server's real GLOBAL value, snapshotted before that change. Default divergence: MySQL 5.7+ and 8.x ship STRICT_TRANS_TABLES, ERROR_FOR_DIVISION_BY_ZERO, NO_ZERO_DATE and NO_ZERO_IN_DATE on by default. MariaDB 10.2.4+ ships STRICT_TRANS_TABLES and ERROR_FOR_DIVISION_BY_ZERO but NOT NO_ZERO_DATE/NO_ZERO_IN_DATE, so a MariaDB server missing only those two is at its documented default — the finding says which modes are missing and distinguishes truncation (data loss) from zero dates (data that no client library can represent). Without STRICT_*, an INSERT of 300 into a TINYINT stores 127 and returns a warning nobody reads; a 300-character string into VARCHAR(255) is silently cut.

**How to confirm.**

`SELECT @@GLOBAL.sql_mode;` — read the GLOBAL value explicitly. db-triage sets its own session sql_mode, so `SELECT @@sql_mode` inside a db-triage session reports db-triage's value, not the server's.

**How to fix.** 1. Test first: with STRICT enabled, statements that used to succeed with a warning now fail with an error, and that is the point — but it will surface application bugs. 2. Set it per session in a staging environment and run the test suite. 3. Then `SET GLOBAL sql_mode='STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_ENGINE_SUBSTITUTION';` and persist it. New sessions pick it up; existing connections keep the old value until they reconnect.

**False positives / caveats.** A legacy application that relies on silent truncation will break, loudly, which is a discovery and not a regression. MariaDB does not include NO_ZERO_DATE/NO_ZERO_IN_DATE in its default, so a MariaDB server missing only those two is at its documented default.

**Reads.** `@dbt_global_sql_mode (the GLOBAL value captured in 01_session.sql BEFORE this session changed its own sql_mode)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/sql-mode.html#sql-mode-strict) · Effort M / risk high

<a id="my-schema-005"></a>
### MY-SCHEMA-005 — AUTO_INCREMENT at or above 90 percent exhausted

**Priority 5 (One step from fired) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** AUTO_INCREMENT >= 90% of the column type maximum. Overridable thresholds: `autoinc_critical_ratio=0.90;autoinc_warn_ratio=0.70`.

**Why it matters.** Verified present with identical columns on MySQL 5.7+/8.x and MariaDB 10.6+ (sys.schema_auto_increment_columns: max_value, auto_increment, auto_increment_ratio). The fallback computes the same figures from information_schema.COLUMNS + TABLES for servers with no sys schema. The failure mode is the reason this is P5 and not P50: when the counter reaches the column type's maximum, MySQL does NOT wrap and does NOT raise an overflow error. It hands out the maximum value again, so the insert fails with ER_DUP_ENTRY — a duplicate-key error on a surrogate key, which reads like an application bug and is routinely misdiagnosed for hours. The fix (ALTER to a wider type) rewrites the whole table, so a 90%-full 500 GB table needs a maintenance window planned now, not when it fills.

**How to confirm.**

`SELECT * FROM sys.schema_auto_increment_columns WHERE auto_increment_ratio > 0.7 ORDER BY auto_increment_ratio DESC;`

**How to fix.** 1. Widen the column: `ALTER TABLE ... MODIFY id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT;`. This rewrites the whole table, so use `pt-online-schema-change` or `gh-ost` on anything large, and plan the window now rather than at 99%. 2. Every foreign key referencing the column must be widened in the same operation. 3. `INT UNSIGNED` (4.3 billion) buys time; `BIGINT UNSIGNED` ends the problem permanently. 4. If the values are sparse because of rollbacks rather than rows, the table may hold far fewer rows than the counter suggests — but the counter is what runs out, not the row count.

**False positives / caveats.** A table that is periodically truncated resets the counter. `AUTO_INCREMENT` in information_schema is also cached on MySQL 8.0 and can lag; the sys view reads the same cached column.

**Reads.** `sys.schema_auto_increment_columns, with an information_schema fallback`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/example-auto-increment.html) · Effort L / risk high

<a id="my-schema-006"></a>
### MY-SCHEMA-006 — AUTO_INCREMENT at or above 70 percent exhausted

**Priority 50 (Daily-briefing ceiling) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** AUTO_INCREMENT >= 70% and < 90% of the column type maximum. Overridable thresholds: `autoinc_critical_ratio=0.90;autoinc_warn_ratio=0.70`.

**Why it matters.** Verified present with identical columns on MySQL 5.7+/8.x and MariaDB 10.6+ (sys.schema_auto_increment_columns: max_value, auto_increment, auto_increment_ratio). The fallback computes the same figures from information_schema.COLUMNS + TABLES for servers with no sys schema. Magnitude tier below MY-SCHEMA-005, with its own ID so suppressing the noisy tier can never hide the urgent one. The failure mode: when the counter reaches the column type's maximum, MySQL does NOT wrap and does NOT raise an overflow error. It hands out the maximum value again, so the insert fails with ER_DUP_ENTRY — a duplicate-key error on a surrogate key, which reads like an application bug and is routinely misdiagnosed for hours. The fix (ALTER to a wider type) rewrites the whole table, so a 90%-full 500 GB table needs a maintenance window planned now, not when it fills.

**How to confirm.**

As MY-SCHEMA-005.

**How to fix.** As MY-SCHEMA-005 — the point of the lower tier is to give you the maintenance window while it is still cheap.

**False positives / caveats.** As MY-SCHEMA-005.

**Reads.** `sys.schema_auto_increment_columns, with an information_schema fallback`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/example-auto-increment.html) · Effort L / risk high

<a id="my-schema-007"></a>
### MY-SCHEMA-007 — Integrity checks disabled globally

**Priority 50 (Daily-briefing ceiling) · Schema design · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** foreign_key_checks or unique_checks is OFF at global scope.

**Why it matters.** Both are SESSION variables with a GLOBAL default, and both are legitimately set to OFF for the duration of a bulk import — that is what mysqldump output does, in the session, and it is fine. Setting them OFF GLOBALLY is different: every future session inherits it, so foreign keys stop being enforced and unique indexes stop being checked on insert for the whole server. InnoDB does not re-validate afterwards, so rows that violate a constraint are simply in the table, and the first time anyone notices is when a JOIN returns orphans or a unique index reports duplicates during a rebuild. @@GLOBAL is read explicitly, never @@SESSION, so an import running right now in another session cannot produce a false positive.

**How to confirm.**

`SELECT @@GLOBAL.foreign_key_checks, @@GLOBAL.unique_checks;` — GLOBAL specifically.

**How to fix.** 1. Assume violations already exist and find them before re-enabling: for each foreign key, a LEFT JOIN looking for orphans; for each unique index, a GROUP BY looking for duplicates. Both are table scans, so run them on a replica. 2. Fix the data. 3. `SET GLOBAL foreign_key_checks=ON; SET GLOBAL unique_checks=ON;` and persist. Re-enabling does NOT revalidate existing rows. 4. Bulk imports should set these OFF per session, which is what mysqldump output does and is fine.

**False positives / caveats.** None at global scope. Per-session is normal and this check reads only the global value.

**Reads.** `@@GLOBAL.foreign_key_checks, @@GLOBAL.unique_checks`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_foreign_key_checks) · Effort S / risk high

<a id="my-schema-008"></a>
### MY-SCHEMA-008 — Leftover online-schema-change artefacts

**Priority 100 (Tuning & configuration detail) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A shadow table or pt-osc trigger from an interrupted schema change remains.

**Why it matters.** pt-online-schema-change and gh-ost both work by building a shadow copy of the table and swapping it in. If the tool is killed — a lost SSH session is the usual cause — the shadow table and, for pt-osc, THREE TRIGGERS on the original table are left behind. The triggers are the expensive part and the reason this is not just clutter: every INSERT, UPDATE and DELETE on the production table continues to be mirrored into an abandoned copy forever, roughly doubling write cost and silently growing the shadow table until the disk notices. Naming conventions matched: pt-osc uses _<table>_new and _<table>_old plus pt_osc_%_{ins,upd,del} triggers; gh-ost uses _<table>_gho, _<table>_ghc and _<table>_del. MySQL's own failed ALTER leaves #sql-* tables, also matched.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_TIME FROM information_schema.TABLES WHERE TABLE_NAME REGEXP '^_.*_(new|old|gho|ghc|del)$' OR TABLE_NAME LIKE '#sql%';` and `SELECT TRIGGER_SCHEMA, TRIGGER_NAME, EVENT_OBJECT_TABLE FROM information_schema.TRIGGERS WHERE TRIGGER_NAME LIKE 'pt\_osc\_%';`

**How to fix.** 1. Confirm no schema change is actually in flight — check for running `pt-osc`/`gh-ost` processes and for recent writes to the shadow table. 2. Drop the triggers FIRST (`DROP TRIGGER pt_osc_...`), because they are the ongoing cost. 3. Then drop the shadow table. 4. A `_<table>_old` table is the ORIGINAL after a completed swap and may be the only copy of data the new table lost — inspect it before dropping.

**False positives / caveats.** A schema change running right now produces exactly this. Check `CREATE_TIME` and the process list before dropping anything. `#sql-*` tables can also be an in-progress ALTER.

**Reads.** `information_schema.TABLES, information_schema.TRIGGERS`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl.html) · Effort S / risk med

<a id="my-schema-009"></a>
### MY-SCHEMA-009 — Very large table not partitioned

**Priority 150 (Hygiene & low-confidence heuristics) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A single-partition table is >= 200 GB. Overridable thresholds: `large_table_bytes=214748364800`.

**Why it matters.** Advisory, and deliberately at P150: partitioning is not a performance feature and applying it to the wrong table makes things worse. What it does buy is O(1) deletion of old data — DROP PARTITION instead of a DELETE that generates undo, bloats the history list (MY-UNDO-001) and never returns the space. On a 200 GB table with a retention policy that is a large difference; on a 200 GB table that is all live data it is not, which is why the finding asks rather than tells, and why it reports whether the table has an obvious time-based partition key candidate. Caveat carried in the text: on MySQL 8.0 these sizes come from the information_schema cache and may be up to information_schema_stats_expiry old.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, ROUND((DATA_LENGTH+INDEX_LENGTH)/1073741824,1) gb FROM information_schema.TABLES ORDER BY DATA_LENGTH+INDEX_LENGTH DESC LIMIT 20;`

**How to fix.** Only partition if the table has a retention policy: the benefit is `DROP PARTITION` instead of a bulk DELETE that generates undo (MY-UNDO-001) and never returns the space. Partition by RANGE on a time column, and note that the partitioning column MUST be part of every unique key including the primary key — which usually means changing the primary key, and that rewrites the table.

**False positives / caveats.** Advisory at P150. Partitioning a table that has no retention policy adds complexity and can make queries slower when they cannot prune.

**Reads.** `information_schema.TABLES, information_schema.PARTITIONS`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/partitioning.html) · Effort L / risk med

<a id="my-schema-010"></a>
### MY-SCHEMA-010 — Table with more than 1,000 partitions

**Priority 150 (Hygiene & low-confidence heuristics) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A table has >= 1,000 partitions. Overridable thresholds: `max_partitions=1000`.

**Why it matters.** The opposite failure to MY-SCHEMA-009. Every partition is a separate InnoDB table internally: its own file descriptor, its own entry in the table cache (MY-MEM-008), and its own row in the data dictionary. A query that cannot prune partitions opens all of them, and even one that can prune pays the planning cost of considering them. The hard limit is 8,192 partitions per table on both forks, so a table at 1,000 is not near the ceiling but is well past the point where the table cache and open-file limit start to matter, especially with several such tables.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(*) FROM information_schema.PARTITIONS WHERE PARTITION_NAME IS NOT NULL GROUP BY 1,2 ORDER BY 3 DESC;`

**How to fix.** Consolidate older partitions into coarser ranges (monthly instead of daily beyond 90 days), or drop them if retention allows. Raise `table_open_cache` and `open_files_limit` in the meantime (MY-MEM-008).

**False positives / caveats.** A time-series table with daily partitions and three years of retention legitimately reaches 1,000. The hard limit is 8,192, so it is not near failure — but the table cache and file descriptor cost is real.

**Reads.** `information_schema.PARTITIONS`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/partitioning-limitations.html) · Effort L / risk med

<a id="my-schema-011"></a>
### MY-SCHEMA-011 — Triggers on high-write tables

**Priority 150 (Hygiene & low-confidence heuristics) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A table with >= 1 trigger has taken >= 1 M writes. Overridable thresholds: `min_writes=1000000`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Requires the sys schema for the write counts (present on MySQL 5.7+ and MariaDB 10.6+, verified); without it the check emits nothing rather than listing every trigger regardless of traffic, which would be noise. Triggers in MySQL run row-by-row inside the writing transaction: they extend its duration (MY-LOCK-003), take their own locks in a different order than the statement did (MY-LOCK-007), and are invisible in the statement digest, so the statement that appears to take 5 ms in MY-QRY-004 may actually be doing far more work. On a table taking a million writes that cost is structural.

**How to confirm.**

`SELECT TRIGGER_SCHEMA, TRIGGER_NAME, EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION FROM information_schema.TRIGGERS;` and `SELECT * FROM sys.schema_table_statistics WHERE table_name='...';`

**How to fix.** Read each trigger body and ask whether the work belongs in the application or in an asynchronous consumer of the binary log. Triggers that maintain a denormalised counter are the common case and are usually better done with a periodic aggregate. If the trigger must stay, make sure whatever it writes to is indexed for the lookup it performs.

**False positives / caveats.** A trigger enforcing an invariant that cannot be expressed as a constraint is doing necessary work. The finding reports write volume so the cost is visible.

**Reads.** `information_schema.TRIGGERS, sys.schema_table_statistics`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/triggers.html) · Effort M / risk med

<a id="my-schema-012"></a>
### MY-SCHEMA-012 — Legacy character sets and row formats (inventory)

**Priority 200 (Non-default configuration) · Schema design · scope: schema · cost 1 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Tables use a legacy character set or a pre-Barracuda row format.

**Why it matters.** Inventory at P200: none of this is broken, but all of it constrains what can be done later, and it is the context in which MY-SCHEMA-014 (collation mismatch) is read. latin1        cannot store most of the world's text; a later conversion rewrites every table and can change index sizes and sort order utf8 / utf8mb3 MySQL's three-byte "utf8" cannot store emoji or many CJK characters; MySQL 8.0 renamed it utf8mb3 and deprecated it, MariaDB 10.6+ likewise COMPACT/REDUNDANT  the pre-Barracuda row formats: no large-prefix indexes (767-byte limit rather than 3072), no per-table compression, and off-page BLOB storage behaves differently Summary shape: one row per schema, since these are almost always uniform within a schema and per-table rows would be pure noise.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_COLLATION, ROW_FORMAT, COUNT(*) FROM information_schema.TABLES WHERE TABLE_TYPE='BASE TABLE' GROUP BY 1,2,3;`

**How to fix.** Convert to `utf8mb4` with a modern collation (`utf8mb4_0900_ai_ci` on MySQL 8.0, `utf8mb4_uca1400_ai_ci` on MariaDB 11.4+, `utf8mb4_unicode_ci` as a portable choice) and `ROW_FORMAT=DYNAMIC`. Three things to check first: index key length (utf8mb4 uses up to 4 bytes per character, so a 255-character indexed column goes from 765 to 1020 bytes), any application that computed byte lengths, and sort order changes that affect existing unique constraints.

**False positives / caveats.** Inventory at P200, not a defect. latin1 is correct for a column that genuinely holds only ASCII and is compared byte-wise.

**Reads.** `information_schema.TABLES (TABLE_COLLATION, ROW_FORMAT)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/charset-unicode-conversion.html) · Effort L / risk med

<a id="my-schema-013"></a>
### MY-SCHEMA-013 — Shared InnoDB tablespace in use

**Priority 50 (Daily-briefing ceiling) · Schema design · scope: relation · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** innodb_file_per_table OFF, or tables remain in the system tablespace.

**Why it matters.** Catalog rename, verified: MySQL 8.0 renamed every INNODB_SYS_* table to INNODB_* (INNODB_SYS_TABLES became INNODB_TABLES). MariaDB 10.11 kept the INNODB_SYS_* names (verified present). The check probes for whichever exists and emits nothing if neither does. Why it matters: ibdata1 only ever grows. Dropping a table stored inside it returns the space to InnoDB's free list, never to the filesystem, and the only way to shrink it is a full logical dump and reload of the entire instance. Per-table tablespaces also unlock transportable tablespaces, per-table compression, and TRUNCATE actually freeing space.

**How to confirm.**

`SELECT @@GLOBAL.innodb_file_per_table;` and `SELECT NAME, SPACE FROM information_schema.INNODB_TABLES WHERE SPACE=0;` (MariaDB and MySQL 5.7: `INNODB_SYS_TABLES`).

**How to fix.** 1. `SET GLOBAL innodb_file_per_table=ON;` so new tables get their own tablespace. 2. Move existing tables out with `ALTER TABLE ... ENGINE=InnoDB` (through pt-osc/gh-ost on a live server). 3. This does NOT shrink `ibdata1` — that space is returned to InnoDB's free list, not the filesystem. The only way to reclaim it is a full logical dump, remove the data directory, and reload. Plan that separately.

**False positives / caveats.** InnoDB's own internal tables legitimately live in the system tablespace and are excluded. The system tablespace also always holds the doublewrite buffer (before MySQL 8.0.20) and the change buffer.

**Reads.** `@@GLOBAL.innodb_file_per_table, information_schema.INNODB_TABLES (MySQL 8.0) or information_schema.INNODB_SYS_TABLES (MySQL 5.7 / MariaDB)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-file-per-table-tablespaces.html) · Effort L / risk high

<a id="my-schema-014"></a>
### MY-SCHEMA-014 — Character set or collation inconsistent within a schema

**Priority 150 (Hygiene & low-confidence heuristics) · Schema design · scope: schema · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A schema contains more than one table collation.

**Why it matters.** NOT in the design's §5.2 table. Added as the next free number in the category because collation drift is a correctness and performance defect in its own right, distinct from MY-SCHEMA-012's "these are legacy" inventory. The mechanism, which is the part that surprises people: joining or comparing two string columns with different collations forces MySQL to convert one side at runtime. A converted column is a function of a column, so ANY INDEX ON IT IS UNUSABLE. A join that has always used an index starts full-scanning the moment one table is converted to utf8mb4 and the other is not — and EXPLAIN shows the scan without ever saying why. The second effect is correctness: two rows equal under utf8mb4_general_ci can be unequal under utf8mb4_0900_ai_ci, so a UNIQUE constraint means different things on different tables in the same schema. Reported per schema, with the dominant collation and the exceptions named, so the fix list is immediately actionable.

**How to confirm.**

`SELECT TABLE_SCHEMA, TABLE_COLLATION, COUNT(*) FROM information_schema.TABLES WHERE TABLE_TYPE='BASE TABLE' GROUP BY 1,2 ORDER BY 1,3 DESC;` and, at column level, `SELECT TABLE_SCHEMA, COLLATION_NAME, COUNT(*) FROM information_schema.COLUMNS WHERE COLLATION_NAME IS NOT NULL GROUP BY 1,2;` Then prove the impact: `EXPLAIN` a join across the boundary and look for the index disappearing from the plan.

**How to fix.** 1. Pick one target collation for the whole schema. 2. Convert the exception tables with `ALTER TABLE ... CONVERT TO CHARACTER SET utf8mb4 COLLATE <target>` — through pt-osc/gh-ost on anything large. 3. Convert the joined columns in the same maintenance window: a half-converted schema has MORE mixed joins than before, not fewer. 4. Also set `character_set_server` and `collation_server` so new tables inherit the right default. 5. Re-check any UNIQUE constraint on a converted text column — a different collation can make previously distinct rows collide.

**False positives / caveats.** A schema that deliberately keeps one binary-collation table for case-sensitive lookups is doing so on purpose. The finding names the exceptions rather than the whole schema so that case is easy to dismiss.

**Reads.** `information_schema.SCHEMATA, information_schema.TABLES, information_schema.COLUMNS`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/charset-collation-charset.html) · Effort L / risk med


---

## QRY — Queries & workload visibility

<a id="my-qry-001"></a>
### MY-QRY-001 — performance_schema disabled

**Priority 100 (Tuning & configuration detail) · Queries & workload visibility · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** performance_schema = OFF.

**Why it matters.** A META-shaped finding that lives in QRY because it is about workload visibility: with performance_schema OFF there are no statement digests, no index usage counters and no replication applier tables, so MY-QRY-002 and 004..011, MY-IDX-001..005, MY-REPL-001..004/010/013 and MY-CONN-005 cannot run at all. The runner records every one of them in XX-META-001 with reason `privilege`, and this row explains why. Default divergence: MySQL 5.6+ ships performance_schema ON. MariaDB ships it OFF by default to this day (10.11 included) — so on MariaDB this is usually an unreviewed default rather than a decision, and the details say so. It cannot be turned on without a restart on either fork. The cost of turning it on is real but modest with the default instrumentation: a few hundred MB of memory and single-digit percent overhead. The cost of leaving it off is that roughly a quarter of this catalog is blind.

**How to confirm.**

`SELECT @@GLOBAL.performance_schema;`

**How to fix.** Set `performance_schema=ON` in the configuration file and restart — it cannot be enabled dynamically. With the default instrumentation it costs a few hundred MB of memory and low single-digit percent overhead. On a memory-tight host, enable it with a reduced `performance_schema_max_*` set rather than leaving it off.

**False positives / caveats.** A deliberately minimal container may leave it off. The cost of doing so is that roughly a quarter of this catalog cannot run, which the finding enumerates.

**Reads.** `@@GLOBAL.performance_schema`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-quick-start.html) · Effort M / risk low

<a id="my-qry-002"></a>
### MY-QRY-002 — Statement digest instrumentation incomplete

**Priority 150 (Hygiene & low-confidence heuristics) · Queries & workload visibility · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** statements_digest consumer disabled, or digests lost > 0. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Two independent ways the digest table lies, both reported here because both silently degrade MY-QRY-004..011 without any error: 1. the statements_digest consumer is disabled, so nothing is aggregated at all and the top-N lists are simply empty; 2. the consumer is on but performance_schema_digests_size (default 5000 on MySQL 8.0, 200 on MariaDB) is too small, so digests beyond the limit are collapsed into a single NULL-digest row and Performance_schema_digest_lost counts them. Any "% of total time" figure computed from the table is then understated by an unknown amount. Verified on MariaDB 10.11: setup_consumers has the statements_digest row and the same NAME/ENABLED columns as MySQL.

**How to confirm.**

`SELECT NAME, ENABLED FROM performance_schema.setup_consumers;` and `SHOW GLOBAL STATUS LIKE 'Performance_schema_%_lost';`

**How to fix.** Enable the consumer: `UPDATE performance_schema.setup_consumers SET ENABLED='YES' WHERE NAME='statements_digest';` (a write, so db-triage never does it). For lost digests, raise `performance_schema_digests_size` — a restart on MySQL, and it costs memory proportional to the value.

**False positives / caveats.** A server with a very large number of distinct statement shapes (an ORM generating unparameterised SQL) will always lose digests; that is itself worth knowing.

**Reads.** `performance_schema.setup_consumers (statements_digest), @dbt_s_performance_schema_digest_lost, @dbt_v_performance_schema_digests_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-digests.html) · Effort S / risk low

<a id="my-qry-003"></a>
### MY-QRY-003 — Slow query log off, or its threshold at the default

**Priority 100 (Tuning & configuration detail) · Queries & workload visibility · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** slow_query_log OFF, or long_query_time >= 10 s. Overridable thresholds: `long_query_seconds=10;recommended_long_query_seconds=1`.

**Why it matters.** Complements rather than duplicates performance_schema: the digest table gives aggregates but no individual execution, no parameter values and no timestamp. The slow log gives the actual statement text of the actual slow execution, which is what pt-query-digest consumes and what you need to reproduce a problem that happened at 03:00. The default long_query_time of 10 s is the real finding on most servers: a statement has to take ten seconds to be recorded, so the 200 ms statement executed forty thousand times an hour — which is where the load actually is — never appears. 0.5 to 1 s is the usual working setting. Fork divergence in the extra-detail variable: MySQL 8.0.14+ has log_slow_extra (adds rows examined, tmp tables, etc. to each entry); MariaDB has log_slow_verbosity with a different value syntax. Both read from the bundle.

**How to confirm.**

`SELECT @@GLOBAL.slow_query_log, @@GLOBAL.long_query_time, @@GLOBAL.log_output;`

**How to fix.** `SET GLOBAL slow_query_log=ON; SET GLOBAL long_query_time=1;` — both dynamic — and persist them. On MySQL 8.0.14+ add `log_slow_extra=ON` for rows-examined and temp-table detail per entry; on MariaDB set `log_slow_verbosity='query_plan,explain'`. Feed the file to `pt-query-digest`. Leave `log_queries_not_using_indexes` OFF on a busy server: it logs every small unindexed lookup and fills disks.

**False positives / caveats.** On a very busy server a threshold below ~0.1 s can itself become an I/O problem. Start at 1 s and lower it while watching the file growth.

**Reads.** `@@GLOBAL.slow_query_log, @@GLOBAL.long_query_time, @dbt_v_log_slow_extra (MySQL 8.0.14+) / @dbt_v_log_slow_verbosity (MariaDB)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/slow-query-log.html) · Effort S / risk low

<a id="my-qry-004"></a>
### MY-QRY-004 — Top 10 statements by total latency

**Priority 240 (Workload profile) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted when digests are available. Overridable thresholds: `top_n=10`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** P240 workload profile: not a problem, the raw material for the next step. Ranked by total time, which is the only ranking that answers 'where does this server spend its day'. A 1 ms statement run ten million times outranks a 30 s report run once, and it should: fixing the first is worth ten thousand times more. Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS, FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+. MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are deliberately not used so one query serves both forks. Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds. WINDOW: everything here is cumulative since the last server restart or TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding. Percentages are understated whenever MY-QRY-002 reports lost digests.

**How to confirm.**

`SELECT * FROM sys.statement_analysis ORDER BY total_latency DESC LIMIT 10;`

**How to fix.** Not a finding — it is the input to query tuning. Work down the list: `EXPLAIN ANALYZE` each statement (db-triage never runs it against production), look at the rows-examined-per-row-sent ratio first, and index or rewrite. Total time is the right ranking because it is what the server actually spends.

**False positives / caveats.** Percentages are understated whenever MY-QRY-002 reports lost digests. The window is since restart, so a recently restarted server (MY-REL-005) gives an unrepresentative list.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort S / risk low

<a id="my-qry-005"></a>
### MY-QRY-005 — Top 10 statements by average latency

**Priority 240 (Workload profile) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted when digests are available. Overridable thresholds: `top_n=10`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** P240 workload profile: not a problem, the raw material for the next step. Ranked by average time with a 100-execution floor, so a single unlucky execution cannot top the list. This is the list a user complaint maps onto: the statements that are individually slow, as opposed to MY-QRY-004's statements that are collectively expensive. Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS, FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+. MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are deliberately not used so one query serves both forks. Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds. WINDOW: everything here is cumulative since the last server restart or TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding. Percentages are understated whenever MY-QRY-002 reports lost digests.

**How to confirm.**

`SELECT * FROM sys.statement_analysis WHERE exec_count >= 100 ORDER BY avg_latency DESC LIMIT 10;`

**How to fix.** This is the list a user complaint maps onto. Individually slow statements are usually a missing index, a large sort, or a lock wait; check MY-QRY-006 and MY-QRY-007 for which.

**False positives / caveats.** As MY-QRY-004.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort S / risk low

<a id="my-qry-006"></a>
### MY-QRY-006 — Top 10 statements by rows examined per row sent

**Priority 240 (Workload profile) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Rows examined per row sent >= 100 with >= 100 executions. Overridable thresholds: `top_n=10`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** P240 workload profile: not a problem, the raw material for the next step. Rows examined divided by rows sent is the index-miss signature: a ratio of 1 means every row read was returned, a ratio of 10,000 means the server read ten thousand rows to return one. It finds missing indexes far more reliably than latency does, because a bad plan on a small table is fast today and catastrophic after the table grows. Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS, FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+. MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are deliberately not used so one query serves both forks. Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds. WINDOW: everything here is cumulative since the last server restart or TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding. Percentages are understated whenever MY-QRY-002 reports lost digests.

**How to confirm.**

`SELECT DIGEST_TEXT, COUNT_STAR, SUM_ROWS_EXAMINED, SUM_ROWS_SENT, SUM_ROWS_EXAMINED/SUM_ROWS_SENT AS ratio FROM performance_schema.events_statements_summary_by_digest WHERE SUM_ROWS_SENT > 0 ORDER BY ratio DESC LIMIT 10;`

**How to fix.** This is the most reliable missing-index signal in the catalog. `EXPLAIN` each statement and look at the `rows` estimate against what it returns. A ratio in the thousands with a small result is a WHERE clause that no index serves, or an index the optimizer rejected because of stale statistics (MY-IDX-008).

**False positives / caveats.** An aggregate query legitimately examines many rows to return one. The ratio finds the query; judgement decides whether it is wrong.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort M / risk low

<a id="my-qry-007"></a>
### MY-QRY-007 — Top 10 statements creating disk temporary tables

**Priority 240 (Workload profile) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Statements with disk temporary tables exist. Overridable thresholds: `top_n=10`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** P240 workload profile: not a problem, the raw material for the next step. The statements behind MY-MEM-005. A disk temp table is usually a GROUP BY or ORDER BY that exceeded tmp_table_size, or — regardless of size — one that touches a TEXT or BLOB column, which forces disk on MySQL 5.7 and MariaDB no matter how small the result is. Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS, FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+. MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are deliberately not used so one query serves both forks. Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds. WINDOW: everything here is cumulative since the last server restart or TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding. Percentages are understated whenever MY-QRY-002 reports lost digests.

**How to confirm.**

`SELECT * FROM sys.statements_with_temp_tables ORDER BY disk_tmp_tables DESC LIMIT 10;`

**How to fix.** Index the `GROUP BY`/`ORDER BY` so no temporary table is needed at all. Failing that, remove TEXT/BLOB columns from the grouping or ordering — on MySQL 5.7 and MariaDB those force disk regardless of size. Raising `tmp_table_size` is the last resort (MY-MEM-005).

**False positives / caveats.** A reporting query that legitimately materialises a large intermediate result will always spill.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/internal-temporary-tables.html) · Effort M / risk low

<a id="my-qry-008"></a>
### MY-QRY-008 — Top 10 statements with full table scans

**Priority 240 (Workload profile) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Statements that executed with no index exist. Overridable thresholds: `top_n=10`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** P240 workload profile: not a problem, the raw material for the next step. Statements that executed at least once with no index at all. SUM_NO_GOOD_INDEX_USED, reported alongside where present, counts the subtler case: an index existed and was rejected as worse than a scan. Read together with MY-IDX-004, which names the tables on the receiving end. Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS, FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+. MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are deliberately not used so one query serves both forks. Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds. WINDOW: everything here is cumulative since the last server restart or TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding. Percentages are understated whenever MY-QRY-002 reports lost digests.

**How to confirm.**

`SELECT * FROM sys.statements_with_full_table_scans ORDER BY no_index_used_count DESC LIMIT 10;`

**How to fix.** Read with MY-IDX-004, which names the tables. `EXPLAIN` before indexing: sometimes the scan is correct and the fix is to stop running the query on this server.

**False positives / caveats.** `SUM_NO_INDEX_USED` counts executions with no index at all; a query that used a bad index does not appear here but does appear in MY-QRY-006.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort M / risk low

<a id="my-qry-009"></a>
### MY-QRY-009 — Top 10 statements by execution count

**Priority 240 (Workload profile) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted when digests are available. Overridable thresholds: `top_n=10`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** P240 workload profile: not a problem, the raw material for the next step. Ranked by raw frequency. This is the list that reveals an N+1 query pattern, a missing application cache, or a health check running every 200 ms — none of which show up as slow, and all of which set the floor on how much other work the server can do. Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT, SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS, FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+. MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are deliberately not used so one query serves both forks. Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds. WINDOW: everything here is cumulative since the last server restart or TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding. Percentages are understated whenever MY-QRY-002 reports lost digests.

**How to confirm.**

`SELECT DIGEST_TEXT, COUNT_STAR FROM performance_schema.events_statements_summary_by_digest ORDER BY COUNT_STAR DESC LIMIT 10;`

**How to fix.** Look for the N+1 pattern (a query executed once per row of a previous result), a missing application-side cache, and health checks running far more often than anyone intended. None of these are slow; all of them set the floor on how much other work the server can do.

**False positives / caveats.** A high-throughput OLTP server legitimately runs its hottest statement millions of times.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort S / risk low

<a id="my-qry-010"></a>
### MY-QRY-010 — One statement digest dominates total latency

**Priority 100 (Tuning & configuration detail) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** One digest holds >= 25% of total statement time with >= 1,000 executions. Overridable thresholds: `dominance_ratio=0.25;min_executions=1000`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Derived from the same data as MY-QRY-004 but stated as a finding rather than a list, because a single digest taking a quarter of all statement time is a structural fact about the workload: it means one query is the server's capacity limit, and tuning anything else first is wasted effort. The percentage is understated whenever MY-QRY-002 reports lost digests, and the window is since restart, so both are named in the details.

**How to confirm.**

As MY-QRY-004; the dominant digest is the first row.

**How to fix.** Tune this statement before anything else in the report's workload section: it is the server's capacity limit, and the ceiling on improving anything else is smaller than the ceiling on improving this.

**False positives / caveats.** As MY-QRY-004: the percentage is understated if digests were lost, and the window is since restart.

**Reads.** `performance_schema.events_statements_summary_by_digest`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort M / risk low

<a id="my-qry-011"></a>
### MY-QRY-011 — Statements failing or warning frequently

**Priority 150 (Hygiene & low-confidence heuristics) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A digest errors on >= 5% of >= 1,000 executions. Overridable thresholds: `error_ratio=0.05;min_executions=1000`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Read directly from the digest table rather than from sys.statements_with_errors_or_warnings so the threshold is explicit and the fork/version differences in that view do not matter. A statement erroring five percent of the time is doing real work and throwing it away: the server pays the full parse, plan and partial execution cost and the application gets an exception. Duplicate-key errors used as an upsert idiom are the common benign case and are named in the finding so the reviewer can dismiss them quickly. WARNINGS matter more than they look on a server that failed MY-SCHEMA-004: without strict SQL mode, silent truncation IS a warning, so a high warning count there is data loss being reported and ignored.

**How to confirm.**

`SELECT * FROM sys.statements_with_errors_or_warnings ORDER BY errors DESC LIMIT 10;`

**How to fix.** Read the statement. A duplicate-key error rate on an INSERT is often a deliberate insert-or-update idiom and can be dismissed — though `INSERT ... ON DUPLICATE KEY UPDATE` is cheaper. Anything else is work being done and thrown away. If the server is not in strict mode (MY-SCHEMA-004), a high WARNING count is silent truncation being reported and ignored.

**False positives / caveats.** Applications that use exceptions for control flow generate these deliberately.

**Reads.** `performance_schema.events_statements_summary_by_digest (SUM_ERRORS, SUM_WARNINGS)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html) · Effort M / risk low

<a id="my-qry-012"></a>
### MY-QRY-012 — Join and scan counters high

**Priority 100 (Tuning & configuration detail) · Queries & workload visibility · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Select_full_join >= 1% or Select_scan >= 20% of Questions. Overridable thresholds: `full_join_ratio=0.01;scan_ratio=0.20;min_questions=100000`.

**Why it matters.** Server-wide counters, available identically on both forks and — unlike the digest table — not dependent on performance_schema. That makes this the fallback signal when MY-QRY-001 has fired. Select_full_join counts joins performed with NO index on the joined table. These are the expensive ones: MySQL's block nested loop reads the whole inner table for each batch of outer rows, so cost grows with the product of the table sizes. Even 1% of statements doing this is usually one query in a hot path. MySQL 8.0.20+ replaced BNL with hash join for many of these, which makes them faster but no less a sign of a missing index. Select_scan counts full scans of the FIRST table in a join, which is far more often legitimate — a small lookup table, a deliberate report — hence the much higher 20% threshold and the softer wording.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Select_%';` against `Questions`.

**How to fix.** `Select_full_join` is the one to act on: those are joins with no index on the joined table. Find them with MY-QRY-006 and MY-QRY-008. `Select_scan` counts scans of the first table in a join and is far more often legitimate.

**False positives / caveats.** These counters do not need performance_schema, which makes them the fallback when MY-QRY-001 has fired — but they also cannot name the statement responsible.

**Reads.** `@dbt_s_select_full_join, @dbt_s_select_scan, @dbt_s_select_range_check, @dbt_s_questions`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html#statvar_Select_full_join) · Effort M / risk low

<a id="my-qry-013"></a>
### MY-QRY-013 — Sort merge passes high

**Priority 150 (Hygiene & low-confidence heuristics) · Queries & workload visibility · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Sort_merge_passes >= 10/s. Overridable thresholds: `merge_passes_per_second=10`.

**Why it matters.** A merge pass happens when a sort does not fit in sort_buffer_size and has to be written out and merged from disk. The counter is server-wide and available on both forks without performance_schema. The trap this finding exists to prevent: the obvious response is to raise sort_buffer_size globally, and that is usually wrong twice over. It is allocated per session per sort, so it multiplies by concurrency (MY-MEM-006 and MY-MEM-007 quantify that); and MySQL allocates and touches the whole buffer regardless of how much of it the sort needs, so a large global value makes every small sort slower. The right responses, in order: an index that provides the sort order so no sort happens; a smaller result set; and only then a per-session SET sort_buffer_size for the one statement that needs it.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Sort_merge_passes';`

**How to fix.** In order: add an index that supplies the ORDER BY so no sort happens at all; return fewer rows; and only then set `sort_buffer_size` per session for the one statement that needs it. Do NOT raise it globally — see MY-MEM-006 for why that makes small sorts slower.

**False positives / caveats.** A nightly reporting job legitimately merges. The rate over the whole window flattens that.

**Reads.** `@dbt_s_sort_merge_passes, @@GLOBAL.sort_buffer_size`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html#statvar_Sort_merge_passes) · Effort M / risk low

<a id="my-qry-014"></a>
### MY-QRY-014 — Plan-hostile patterns in top statement digests

**Priority 150 (Hygiene & low-confidence heuristics) · Queries & workload visibility · scope: query · cost 1 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A top digest matches a plan-hostile text pattern. Overridable thresholds: `top_digests=200;min_executions=100`. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** CONFIDENCE IS LOW BY CONSTRUCTION AND THIS CHECK IS NEVER PROMOTED INTO "Fix first". It is a regular-expression match on normalised statement text, which means it can be wrong in both directions: a leading-wildcard LIKE against a 50-row table is fine, and a plan-hostile query written in a way the pattern does not match is missed entirely. Treat every row as a question. Patterns and why each defeats an index: LIKE '%...'         a B-tree can only seek on a known prefix, so a leading wildcard forces a scan of the whole index or table ORDER BY RAND()     assigns a random value to every candidate row, then sorts all of them, to return one function(column)    any expression around an indexed column makes the index unusable, unless it exactly matches a functional index (MySQL 8.0.13+; MariaDB has no functional indexes) LIMIT n OFFSET big  MySQL reads and discards every skipped row; keyset pagination reads only what it returns NOT IN (subquery)   historically materialised and re-evaluated per row OR across columns   often prevents a single index from being used DIGEST_TEXT is already normalised (literals replaced by ?), so no user data is read or echoed by these patterns.

**How to confirm.**

`EXPLAIN` the statement. That is the only way to know.

**How to fix.** Treat each row as a question, never as an instruction. Leading-wildcard LIKE on a large table wants a full-text or trigram index; `ORDER BY RAND()` wants a different sampling approach; deep OFFSET pagination wants keyset pagination; a function around an indexed column wants either a rewrite or a functional index (MySQL 8.0.13+; MariaDB has none).

**False positives / caveats.** Low confidence by construction and never promoted into 'Fix first'. It is a regular expression over normalised statement text: it produces false positives (a leading-wildcard LIKE on a 50-row table is fine) and false negatives (a plan-hostile query written differently is missed).

**Reads.** `performance_schema.events_statements_summary_by_digest (DIGEST_TEXT)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/select-optimization.html) · Effort M / risk low

<a id="my-qry-015"></a>
### MY-QRY-015 — Status snapshot

**Priority 240 (Workload profile) · Queries & workload visibility · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted. Not a problem: the numbers a practitioner would ask for first, in one row, so the rest of the report can be read in context. Two kinds of number, deliberately labelled differently: the instantaneous ones (Threads_running, current row-lock waits) are a SNAPSHOT and can miss a storm entirely; the rates are averages SINCE RESTART and hide any recent change. Neither is a substitute for monitoring, which is why MY-REL-006 checks whether any exists.

**How to confirm.**

`SHOW GLOBAL STATUS;`

**How to fix.** Nothing to fix. Use it as the orientation figures for the rest of the report.

**False positives / caveats.** The instantaneous figures are one sample; the rates are averages since restart. Neither replaces monitoring.

**Reads.** `the @dbt_s_* status bundle (01_session.sql §6)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html) · Effort S / risk low

<a id="my-qry-016"></a>
### MY-QRY-016 — Per-account workload profile (MariaDB user statistics)

**Priority 240 (Workload profile) · Queries & workload visibility · scope: role · cost 1 · inventory pass · engine: mariadb · since 0.1.0**

**What fires it.** Always emitted when userstat is ON. Overridable thresholds: `top_n=15`.

**Why it matters.** NOT in the design's §5.2 table. Added because MariaDB's userstat feature has no MySQL or PostgreSQL equivalent and answers a question the digest tables cannot: WHICH ACCOUNT is responsible for the load. The digest table aggregates by statement text across all accounts, so a shared application user and a runaway reporting job are indistinguishable there. Availability: information_schema.USER_STATISTICS exists on MariaDB 10.x (verified on 10.11) and on Percona Server. It is EMPTY unless the userstat variable is ON, which it is not by default — hence the gate on @dbt_v_userstat as well as on the table, and the note in the finding when it is off. Oracle MySQL has no equivalent at all, so the check is engine=mariadb. CPU_TIME and BUSY_TIME are in seconds and are cumulative since the counters were last flushed, which on a server nobody has flushed means since restart.

**How to confirm.**

`SELECT * FROM information_schema.USER_STATISTICS ORDER BY BUSY_TIME DESC;` (requires `userstat=ON`; MariaDB and Percona only).

**How to fix.** Nothing to fix. Use it to attribute load to an account, which the statement digest cannot do: digests aggregate by statement text across every account, so a shared application user and a runaway report look identical there. `FLUSH USER_STATISTICS` resets the counters.

**False positives / caveats.** Empty unless `userstat=ON`, which is not the default. Oracle MySQL has no equivalent.

**Reads.** `information_schema.USER_STATISTICS, @dbt_v_userstat`

**Further reading.** [Official documentation](https://mariadb.com/kb/en/user-statistics/) · Effort S / risk low


---

## CAP — Capacity & growth

<a id="my-cap-001"></a>
### MY-CAP-001 — Data, binary log or temp volume at or above 90 percent full

**Priority 1 (You get fired) · Capacity & growth · scope: host · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A MySQL volume is >= 90% full. Requires: `os`.

**Why it matters.** A full data volume stops writes and can prevent the server from starting. InnoDB does not corrupt itself, but a full volume during a page-split or a redo write is an availability outage that ends only when someone frees space. MySQL has no view of the filesystem, so this comes from the runner.

**How to confirm.**

`df -h $(mysql -Nse 'SELECT @@datadir')` and the same for `@@tmpdir`, the binary log directory and `@@innodb_undo_directory` — they are frequently different volumes.

**How to fix.** 1. Buy time: purge binary logs that every replica has consumed, drop the `test` schema, remove old backups from the data volume. 2. A full data volume does not corrupt InnoDB but does stop writes and can prevent the server from starting. 3. Then address the growth: MY-CAP-006 (binary logs), MY-CAP-008 (temporary tablespace), MY-UNDO-003 (undo) and MY-IDX-006 (fragmentation) are the usual consumers.

**False positives / caveats.** A volume shared with something else may be full for reasons unrelated to MySQL.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/disk-issues.html) · Effort M / risk high

<a id="my-cap-002"></a>
### MY-CAP-002 — Volume at or above 80 percent full

**Priority 20 (Known-dangerous, not yet hurting) · Capacity & growth · scope: host · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** A MySQL volume is >= 80% full. Requires: `os`.

**Why it matters.** Eighty percent is the point at which a single large `ALTER TABLE` — which needs free space equal to the table it rebuilds — may no longer fit, so the fixes for several other findings in this report become unavailable before the disk is actually full.

**How to confirm.**

As MY-CAP-001.

**How to fix.** As MY-CAP-001, with time to plan. 80% is the point at which a single large ALTER TABLE — which needs free space equal to the table — may no longer fit.

**False positives / caveats.** As MY-CAP-001.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/disk-issues.html) · Effort M / risk med

<a id="my-cap-003"></a>
### MY-CAP-003 — Projected disk-full within 30 days

**Priority 20 (Known-dangerous, not yet hurting) · Capacity & growth · scope: host · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0 · **status: planned****

> **Not implemented in 0.1.0.** The registry row exists so the ID is reserved and the gap is visible in the report rather than silently absent. See *False positives / caveats* below for what is missing.

**What fires it.** Projected disk-full within 30 days from snapshot growth. Requires: `os`.

**Why it matters.** Extrapolating disk growth from two snapshots is crude, but it converts "the disk is 70% full" into "the disk is full in eleven days", which is the form a decision can be made from.

**How to confirm.**

Compare two db-triage snapshots: `db-triage --compare LAST`.

**How to fix.** Extrapolation from two points is crude; use it to decide whether to look, not what to do.

**False positives / caveats.** Planned as of 0.1.0: it needs the snapshot store, which is not yet implemented for MySQL.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/disk-issues.html) · Effort M / risk med

<a id="my-cap-004"></a>
### MY-CAP-004 — Schema sizes

**Priority 250 (Environment inventory) · Capacity & growth · scope: schema · cost 1 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted. Environment inventory, so the report doubles as documentation of what this instance actually holds. CACHE CAVEAT, carried in every finding that uses these numbers: on MySQL 8.0 the DATA_LENGTH, INDEX_LENGTH, DATA_FREE and TABLE_ROWS columns are served from a cache refreshed at most every information_schema_stats_expiry seconds (default 86400), so they can be a day stale. MariaDB reads them live from the storage engine. db-triage never runs ANALYZE TABLE to refresh them, because that is a write. TABLE_ROWS is an InnoDB ESTIMATE from index dives in all cases, not a count, and can be off by a large factor on a table with wide rows.

**How to confirm.**

`SELECT TABLE_SCHEMA, ROUND(SUM(DATA_LENGTH+INDEX_LENGTH)/1073741824,2) gb FROM information_schema.TABLES GROUP BY 1 ORDER BY 2 DESC;`

**How to fix.** Nothing to fix; inventory.

**False positives / caveats.** On MySQL 8.0 these figures come from a cache up to `information_schema_stats_expiry` seconds old (86,400 by default) and row counts are InnoDB estimates in all cases. MariaDB reads them live.

**Reads.** `information_schema.TABLES grouped by schema`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/information-schema-tables-table.html) · Effort S / risk low

<a id="my-cap-005"></a>
### MY-CAP-005 — Largest 20 tables

**Priority 250 (Environment inventory) · Capacity & growth · scope: relation · cost 1 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted. Overridable thresholds: `top_n=20`.

**Why it matters.** Always emitted. Same cache and estimate caveats as MY-CAP-004, restated because these rows are read on their own. Index-to-data ratio is included because it is the cheapest signal of an over-indexed table: above roughly 1.0 the indexes cost more space than the rows do, which is worth reading next to MY-IDX-001/003/005.

**How to confirm.**

As MY-CAP-004, without the GROUP BY.

**How to fix.** Nothing to fix; inventory. An index-to-data ratio above 1.0 is the cheapest signal of an over-indexed table and is worth reading next to MY-IDX-001/003/005.

**False positives / caveats.** As MY-CAP-004.

**Reads.** `information_schema.TABLES`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/information-schema-tables-table.html) · Effort S / risk low

<a id="my-cap-006"></a>
### MY-CAP-006 — Binary logs consuming excessive space

**Priority 50 (Daily-briefing ceiling) · Capacity & growth · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0 · **status: planned****

> **Not implemented in 0.1.0.** The registry row exists so the ID is reserved and the gap is visible in the report rather than silently absent. See *False positives / caveats* below for what is missing.

**What fires it.** Binary logs occupy >= 100 GB or >= 25% of data size. Requires: `REPLICATION CLIENT`.

**Why it matters.** Binary logs accumulate at the write rate and are removed only by retention or by hand. On a busy source they are frequently the largest single consumer of the data volume after the tables themselves, and unlike the tables they grow whether or not the data does.

**How to confirm.**

`SHOW BINARY LOGS;` — it cannot be selected from, which is why this check is not implemented as SQL. Sum the `File_size` column.

**How to fix.** Set a retention (MY-BAK-003/004) and confirm every replica has consumed the logs before purging.

**False positives / caveats.** Planned as of 0.1.0: `SHOW BINARY LOGS` produces a result set that no SELECT can consume, so this needs the runner to execute the SHOW and parse it. The registry row exists so the ID is reserved and the gap is visible.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/purge-binary-logs.html) · Effort S / risk low

<a id="my-cap-007"></a>
### MY-CAP-007 — General query log enabled

**Priority 50 (Daily-briefing ceiling) · Capacity & growth · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** general_log = ON.

**Why it matters.** The general log records EVERY statement, including every SELECT, with no threshold and no sampling. Three consequences worth stating with numbers: it costs roughly ten to twenty percent of throughput; at the current statement rate it produces an estimable volume per day; and when log_output=TABLE it writes into mysql.general_log, which is a CSV-engine table that grows inside the data directory and cannot be rotated by logrotate. It is almost never intentional in production — it is normally switched on to debug something and never switched off. It is dynamic on both forks, so turning it off needs no restart. Note it is also NOT an audit log: it records statements but not their results or their success, and any account can be granted enough to read it. MY-SEC-015 covers actual audit facilities.

**How to confirm.**

`SELECT @@GLOBAL.general_log, @@GLOBAL.log_output, @@GLOBAL.general_log_file;`

**How to fix.** `SET GLOBAL general_log = OFF;` — dynamic on both forks — and remove it from the configuration file. If statement-level visibility is what is wanted, use the slow query log with a low `long_query_time` (MY-QRY-003) or the performance_schema digests, both of which cost far less.

**False positives / caveats.** A debugging session in progress. Check with whoever turned it on before turning it off.

**Reads.** `@@GLOBAL.general_log, @@GLOBAL.log_output, @dbt_s_questions`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/query-log.html) · Effort S / risk low

<a id="my-cap-008"></a>
### MY-CAP-008 — InnoDB temporary tablespace large

**Priority 100 (Tuning & configuration detail) · Capacity & growth · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** The InnoDB temporary tablespace is >= 10 GB. Overridable thresholds: `temp_tablespace_bytes=10737418240`.

**Why it matters.** Same fork split as MY-UNDO-003 and for the same verified reason: information_schema.FILES returns ZERO rows on MariaDB 10.11, so the MySQL query would silently never fire there. MariaDB's size comes from INNODB_SYS_TABLESPACES.FILE_SIZE for the innodb_temporary space. The trap: ibtmp1 autoextends by default (innodb_temp_data_file_path is `ibtmp1:12M:autoextend` on both forks) and IS NEVER SHRUNK WHILE THE SERVER RUNS. One badly written report that spills a huge sort or GROUP BY can grow it to tens of gigabytes, and that space stays allocated until the next restart — there is no online way to reclaim it. Setting a max in innodb_temp_data_file_path (e.g. `ibtmp1:12M:autoextend:max:8G`) converts an unbounded disk-full risk into a failed query, which is the right trade on most servers. MySQL 8.0.16+ additionally has session temporary tablespaces, which are reclaimed when the session ends.

**How to confirm.**

MySQL 8.0: `SELECT FILE_NAME, TOTAL_EXTENTS*EXTENT_SIZE FROM information_schema.FILES WHERE FILE_TYPE='TEMPORARY';` MariaDB: `SELECT NAME, FILE_SIZE FROM information_schema.INNODB_SYS_TABLESPACES WHERE NAME='innodb_temporary';` and `ls -l <datadir>/ibtmp1`.

**How to fix.** 1. The only way to shrink `ibtmp1` is to restart the server — there is no online reclaim. 2. Prevent recurrence by capping it: `innodb_temp_data_file_path=ibtmp1:12M:autoextend:max:8G` in the configuration file, which turns an unbounded disk-full risk into a failed query. 3. Fix what is spilling (MY-MEM-005, MY-QRY-007). MySQL 8.0.16+ also has session temporary tablespaces, which are reclaimed when the session ends.

**False positives / caveats.** A one-off large report will have grown it; the size persists but the cause may not recur.

**Reads.** `information_schema.FILES (MySQL 8.0, FILE_TYPE='TEMPORARY') or information_schema.INNODB_SYS_TABLESPACES (MariaDB, NAME='innodb_temporary'); @dbt_v_innodb_temp_data_file_path`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-temporary-tablespace.html) · Effort M / risk med

<a id="my-cap-009"></a>
### MY-CAP-009 — Growth since last snapshot

**Priority 250 (Environment inventory) · Capacity & growth · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0 · **status: planned****

> **Not implemented in 0.1.0.** The registry row exists so the ID is reserved and the gap is visible in the report rather than silently absent. See *False positives / caveats* below for what is missing.

**What fires it.** A previous snapshot exists to compare against.

**Why it matters.** A size today is a fact; a size compared to last month is a trend, and a trend is what capacity decisions are made from.

**How to confirm.**

`db-triage --compare LAST`.

**How to fix.** Nothing to fix; inventory.

**False positives / caveats.** Planned as of 0.1.0: requires the snapshot store.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/information-schema-tables-table.html) · Effort S / risk low


---

## REL — Reliability & operations

<a id="my-rel-001"></a>
### MY-REL-001 — Server version is past end of life

**Priority 20 (Known-dangerous, not yet hurting) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** The server's release branch is past its end-of-life date. Overridable thresholds: `eol_as_of=2026-09-02`.

**Why it matters.** SOURCE OF THE DATES. The design puts EOL dates in reference/versions.yml with an `as_of` stamp. That file is generated elsewhere in the repo, so this check embeds the same table as a UNION ALL of literals and stamps it with @dbt_eol_as_of. The runner SHOULD overwrite @dbt_eol_as_of and the branch rows from versions.yml when it has them; when it does not, XX-META-004 fires if the embedded stamp is more than a year old and every REL finding drops to low confidence, exactly as the design specifies. Working values as of 2026-09-02, from dev.mysql.com and mariadb.org: MySQL   5.7  EOL 2023-10-31   8.0 EOL 2026-04-30   8.4 LTS EOL 2032-04-30 9.x  innovation releases: supported only until the next one ships MariaDB 10.4 EOL 2024-06-18   10.5 EOL 2025-06-24  10.6 EOL 2026-07-06 10.11 EOL 2028-02-16  11.4 EOL 2029-05-29  11.8 EOL 2030-06-04 Note that MySQL 8.0 reached EOL in April 2026, so most fleets trip this. Past EOL means no security patches at all: a CVE published tomorrow has no fix for this server, and the only remedy is the major upgrade that was already due.

**How to confirm.**

`SELECT @@GLOBAL.version;` and check the vendor page: https://endoflife.date/mysql or https://endoflife.date/mariadb.

**How to fix.** 1. Plan a major upgrade to the next LTS — MySQL 8.4 or MariaDB 11.4 as of this writing. 2. Rehearse it: restore a backup onto a scratch host, upgrade it, run the application test suite. 3. Roll out replica-first so the source can still serve if the replica fails to start. 4. Read the vendor's incompatible-changes list; MySQL 8.4 removed `mysql_native_password` (MY-SEC-006), the `slave_*` variable spellings and `master_info_repository`, all of which appear elsewhere in this report.

**False positives / caveats.** The EOL dates are embedded in the check with an `as_of` stamp. If that stamp is more than a year old the finding drops to low confidence and the vendor page is authoritative.

**Reads.** `@@GLOBAL.version, @dbt_fork, and the embedded release table below`

**Further reading.** [Official documentation](https://endoflife.date/mysql) · Effort L / risk med

<a id="my-rel-002"></a>
### MY-REL-002 — End-of-life server reachable from any network interface

**Priority 1 (You get fired) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** MY-REL-001 fired, the server listens on all interfaces, and wildcard-host accounts exist. Overridable thresholds: `eol_as_of=2026-09-02`. Requires: `SELECT ON mysql.*`.

**Why it matters.** Derived: MY-REL-001 (no more security patches) AND MY-SEC-014 (listening on every interface) AND at least one account reachable from any host. Each alone is a P20 or a P200 review row; together they are the sp_Blitz "you get fired" shape — a server with known-unpatchable vulnerabilities and an open front door. The combination is what raises it to P1, so suppressing MY-REL-001 for a deliberate upgrade freeze does not also suppress this.

**How to confirm.**

As MY-REL-001, plus `SELECT @@GLOBAL.bind_address;` and the wildcard-host account list from MY-SEC-004.

**How to fix.** The fastest mitigation is not the upgrade: restrict network reachability today (security group, firewall, bind_address) and narrow the wildcard-host accounts. That buys the weeks the upgrade needs. Then upgrade.

**False positives / caveats.** If a firewall already restricts reachability — which db-triage cannot see — record it in `.db-triage.yml` and this drops back to MY-REL-001 at P20.

**Reads.** `as MY-REL-001, plus @@GLOBAL.bind_address, @@GLOBAL.skip_networking, and the wildcard-host account count`

**Further reading.** [Official documentation](https://endoflife.date/mysql) · Effort L / risk high

<a id="my-rel-003"></a>
### MY-REL-003 — Server version within six months of end of life

**Priority 100 (Tuning & configuration detail) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** The server's release branch reaches end of life within 180 days. Overridable thresholds: `eol_warning_days=180;eol_as_of=2026-09-02`.

**Why it matters.** The lead time this finding exists to protect: a major-version upgrade on a production database is a rehearsal, an application compatibility pass, a replica-first rollout and a rollback plan. Six months is roughly the minimum for that to happen calmly rather than as an incident, which is why the warning comes here rather than at MY-REL-001 when the date has already passed.

**How to confirm.**

As MY-REL-001.

**How to fix.** Start the upgrade work now. Six months is roughly the minimum for a rehearsal, an application compatibility pass, a replica-first rollout and a rollback plan to happen calmly rather than as an incident.

**False positives / caveats.** As MY-REL-001.

**Reads.** `as MY-REL-001`

**Further reading.** [Official documentation](https://endoflife.date/mysql) · Effort L / risk med

<a id="my-rel-004"></a>
### MY-REL-004 — Patch release behind

**Priority 100 (Tuning & configuration detail) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0 · **status: planned****

> **Not implemented in 0.1.0.** The registry row exists so the ID is reserved and the gap is visible in the report rather than silently absent. See *False positives / caveats* below for what is missing.

**What fires it.** The server is >= 2 patch releases behind its branch.

**Why it matters.** Patch releases within a branch are compatible by policy and carry security fixes. Being two or more behind means known, published, fixed vulnerabilities are present on this server, and the upgrade is a normal maintenance-window operation rather than the major-version project that MY-REL-001 implies.

**How to confirm.**

`SELECT @@GLOBAL.version;` against the vendor's release list.

**How to fix.** Apply the patch release in a normal maintenance window. Patch releases within a branch are compatible by policy, but read the release notes: InnoDB behaviour changes do occasionally ship in them.

**False positives / caveats.** Planned as of 0.1.0: it needs the latest-minor list from `reference/versions.yml`, which is generated elsewhere in the repo. MY-REL-001/002/003 cover the EOL half using an embedded table.

**Further reading.** [Official documentation](https://endoflife.date/mysql) · Effort M / risk low

<a id="my-rel-005"></a>
### MY-REL-005 — Server restarted within the last 24 hours

**Priority 10 (Active harm / serious foot-gun) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Uptime < 86,400 s. Overridable thresholds: `recent_restart_seconds=86400`.

**Why it matters.** This is a META-shaped finding at P10 rather than P0 because it is a fact about the SERVER, not about the run: something restarted this database recently and that is worth knowing on its own. Its effect on the report is the larger point. MySQL and MariaDB have no equivalent of PostgreSQL's per-view stats_reset timestamp: every status counter, every performance_schema aggregate and every InnoDB metric starts from zero at startup and there is no record of when a previous window ended. So a short uptime does not merely reduce confidence in the rate-based findings — it means the buffer pool is still cold, the digest table is nearly empty, and index usage counters (MY-IDX-001/002) show almost everything as unused. Acting on any of those now would be wrong. Whether the restart was clean is a separate question: MY-CORR-002 reads the error log for crash-recovery messages where the fork allows it.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Uptime';`

**How to fix.** Nothing to fix if the restart was planned. If it was not, find out why: MY-CORR-002 reads the error log for crash-recovery messages on MySQL 8.0.22+, and `dmesg` will show an OOM kill. Then re-run db-triage after the server has been up for a week, because until then most rate-based findings are not meaningful.

**False positives / caveats.** None: it is a fact, not a judgement. What it changes is the confidence of everything else.

**Reads.** `@dbt_s_uptime`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html#statvar_Uptime) · Effort S / risk low

<a id="my-rel-006"></a>
### MY-REL-006 — No evidence of a monitoring agent

**Priority 100 (Tuning & configuration detail) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** No account or session name matches a known monitoring agent. Requires: `PROCESS;SELECT ON mysql.*`.

**Why it matters.** CONFIDENCE IS LOW AND THE WORDING IS "NO EVIDENCE OF", NOT "NO MONITORING". This is the design's absence-of-evidence rule applied literally: an agent that polls once a minute is almost never connected at the instant of the snapshot, an agent may connect as a generically named account, and a metrics exporter may scrape through a proxy. All three produce a false positive here. What the check actually establishes is that no account and no connected session carries a recognisable monitoring name, which is worth one question. Recognised names cover the common agents: Percona PMM, Datadog, New Relic, Zabbix, Nagios, Prometheus/mysqld_exporter, Grafana, Dynatrace, SolarWinds, AppDynamics, Netdata, VividCortex/SolarWinds DPM, and Telegraf.

**How to confirm.**

`SELECT DISTINCT USER FROM information_schema.PROCESSLIST;` and `SELECT DISTINCT GRANTEE FROM information_schema.USER_PRIVILEGES;` — then ask.

**How to fix.** Answer the question: what watches this database, and would it have paged someone for the P1 and P5 findings in this report? Record the answer in `.db-triage.yml` so this stops firing. If the answer is 'nothing', that is the finding.

**False positives / caveats.** Low confidence and worded 'no evidence of'. An agent polling once a minute is usually not connected at the instant of a snapshot, an agent may use a generic account name, and an exporter may scrape through a proxy — any of which produces this finding on a well-monitored server.

**Reads.** `information_schema.PROCESSLIST (USER, HOST), information_schema.USER_PRIVILEGES`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema.html) · Effort M / risk low

<a id="my-rel-007"></a>
### MY-REL-007 — sys schema missing

**Priority 150 (Hygiene & low-confidence heuristics) · Reliability & operations · scope: cluster · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** The sys schema has no views.

**Why it matters.** Availability, verified: MySQL ships sys from 5.7.7 and installs it by default. MariaDB ships it from 10.6 (a MariaDB 10.11 install has 100 sys objects, verified). Below those versions, or after someone dropped the schema, it is absent. Its absence is not a fault — every check that uses a sys view has an information_schema or performance_schema fallback, and MY-IDX-003's fallback was verified to produce byte-identical findings. What is lost is the convenience for the human doing the follow-up work: the confirmation queries in reference/checks-mysql.md are written against sys views because they are an order of magnitude shorter and easier to read. Reported at P150 with the list of which checks took a fallback path, so the reader knows the findings are complete but derived differently.

**How to confirm.**

`SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA='sys';`

**How to fix.** MySQL: the sys schema ships with the server; if it is missing, load it from the `sys` package or the mysql-sys repository. MariaDB 10.6+: `mariadb-sys` or run the bundled `mysql_sys_schema.sql`. It needs no restart and creates only views, functions and procedures.

**False positives / caveats.** No finding is lost by its absence: every check that uses a sys view has an information_schema or performance_schema fallback, verified to produce identical results for MY-IDX-003. What is lost is the short confirmation queries in this document.

**Reads.** `information_schema.VIEWS in schema sys (via @dbt_sys_view_count)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/sys-schema.html) · Effort S / risk low

<a id="my-rel-008"></a>
### MY-REL-008 — Error log verbosity reduced

**Priority 150 (Hygiene & low-confidence heuristics) · Reliability & operations · scope: setting · cost 0 · fast pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Error log verbosity is below its default. Overridable thresholds: `min_verbosity=2`.

**Why it matters.** Fork divergence in both name and scale, which is why both come from the bundle: MySQL 5.7+   log_error_verbosity: 1 = errors only, 2 = errors + warnings (the default), 3 = + notes MariaDB      log_warnings: 0 = errors only, 1 = + a few warnings (the default), 2 = + aborted connections and access-denied, 3+ = more The two scales are not comparable, so each is judged against its own default and the finding says which variable it read. At the lowest setting the error log records almost nothing: no aborted connection detail (MY-CONN-004 then has counters with no explanation), no InnoDB warnings short of a hard error, and on MySQL none of the messages MY-CORR-001 and MY-CORR-002 look for. The log is the only record that survives a restart, and turning it down is usually done to quieten disk noise from something that deserved fixing instead.

**How to confirm.**

MySQL: `SELECT @@GLOBAL.log_error_verbosity;` MariaDB: `SELECT @@GLOBAL.log_warnings;`

**How to fix.** MySQL: `SET GLOBAL log_error_verbosity = 2;` (or 3 while diagnosing). MariaDB: `SET GLOBAL log_warnings = 2;` so aborted connections and access-denied events are recorded. Both are dynamic. If log volume was the reason it was turned down, rotate the file instead.

**False positives / caveats.** The two scales are not comparable between forks and each is judged against its own default.

**Reads.** `@dbt_v_log_error_verbosity (MySQL 5.7+), @dbt_v_log_warnings (MariaDB)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_log_error_verbosity) · Effort S / risk low

<a id="my-rel-009"></a>
### MY-REL-009 — Buffer pool warm-up not configured (review)

**Priority 200 (Non-default configuration) · Reliability & operations · scope: setting · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Buffer pool dump-at-shutdown or load-at-startup is OFF.

**Why it matters.** Both variables exist on MySQL 5.6+ and MariaDB 10.0+ and both default to ON, so finding either OFF means someone turned it off. Reported at P200 as a review row, not a defect: it changes only how long a restart takes to return to normal performance, and on a server with a small pool or infrequent restarts that may not matter. On a server with a large pool it matters a great deal — a cold pool means every query is reading from disk, and a planned two-minute restart becomes an hour of degraded service while the pool refills organically. What is saved and restored is the LIST OF PAGE IDENTIFIERS, not the pages, so the dump file is small and shutdown is not meaningfully delayed.

**How to confirm.**

`SELECT @@GLOBAL.innodb_buffer_pool_dump_at_shutdown, @@GLOBAL.innodb_buffer_pool_load_at_startup, @@GLOBAL.innodb_buffer_pool_dump_pct;`

**How to fix.** `SET GLOBAL innodb_buffer_pool_dump_at_shutdown=ON; SET GLOBAL innodb_buffer_pool_load_at_startup=ON;` — the second only takes effect at the next start, so also set both in the configuration file. What is saved is the list of page identifiers, not the pages, so the file is small and shutdown is not meaningfully delayed.

**False positives / caveats.** Review row at P200. On a small pool or a server that never restarts it does not matter; on a large pool it is the difference between a two-minute restart and an hour of degraded service.

**Reads.** `@@GLOBAL.innodb_buffer_pool_dump_at_shutdown, @@GLOBAL.innodb_buffer_pool_load_at_startup, @@GLOBAL.innodb_buffer_pool_dump_pct`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-preload-buffer-pool.html) · Effort S / risk low

<a id="my-rel-010"></a>
### MY-REL-010 — Persisted variables override the configuration files

**Priority 100 (Tuning & configuration detail) · Reliability & operations · scope: setting · cost 0 · fast pass · engine: mysql · since 0.1.0**

**What fires it.** A persisted variable overrides a file-sourced value. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** MySQL 8.0 only. SET PERSIST writes to mysqld-auto.cnf in the data directory, which is read AFTER every other configuration file — so a persisted value silently wins over my.cnf, over the packaging defaults and over whatever the configuration-management system believes it applied. MariaDB has no SET PERSIST and no persisted_variables table (verified absent on 10.11), so the check emits nothing there. The failure this catches: someone fixes an incident at 03:00 with SET PERSIST, the change is invisible in every file under version control, and six months later a rebuilt server behaves differently from its predecessor for reasons nobody can find. VARIABLE_SOURCE in variables_info distinguishes PERSISTED from EXPLICIT (a file) and shows which file and line a file-sourced value came from.

**How to confirm.**

`SELECT * FROM performance_schema.persisted_variables;` and `SELECT VARIABLE_NAME, VARIABLE_SOURCE, VARIABLE_PATH FROM performance_schema.variables_info WHERE VARIABLE_SOURCE <> 'COMPILED';`

**How to fix.** Decide where configuration lives. If it is the files: `RESET PERSIST <name>` for each variable and put the value in my.cnf. If it is `SET PERSIST`: make sure `mysqld-auto.cnf` is backed up and understood, because it lives in the data directory and is easy to lose in a rebuild. Either way, do not leave both.

**False positives / caveats.** MySQL 8.0 only. `SET PERSIST_ONLY` is a legitimate way to set read-only variables without editing files, and shows up here the same way.

**Reads.** `performance_schema.persisted_variables, performance_schema.variables_info`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/persisted-system-variables.html) · Effort S / risk med


---

## CFG — Non-default configuration

<a id="my-cfg-001"></a>
### MY-CFG-001 — Non-default global variables

**Priority 200 (Non-default configuration) · Non-default configuration · scope: setting · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted; one row per non-default global variable. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** THE fork divergence for configuration inventory, and there is no common path: MySQL 5.7.9+  performance_schema.variables_info gives VARIABLE_SOURCE (COMPILED / GLOBAL / SERVER / EXPLICIT / PERSISTED / DYNAMIC / COMMAND_LINE / LOGIN / USER) plus VARIABLE_PATH and the file line number, but NOT the compiled default value. MariaDB       has no variables_info at all (verified absent on 10.11) but information_schema.SYSTEM_VARIABLES carries DEFAULT_VALUE and GLOBAL_VALUE_ORIGIN, which is the better shape for this check. So MySQL answers "where did this come from" and MariaDB answers "what was it before" — the finding says which question it could answer. This is P200 inventory, not a problem list: it is what a reader consults AFTER the findings, to understand why the server behaves as it does. The noise list below removes the values that differ on every server by construction (hostnames, paths, ports, UUIDs, locale and timezone).

**How to confirm.**

MySQL: `SELECT VARIABLE_NAME, VARIABLE_SOURCE, VARIABLE_PATH FROM performance_schema.variables_info WHERE VARIABLE_SOURCE <> 'COMPILED';` MariaDB: `SELECT VARIABLE_NAME, GLOBAL_VALUE, DEFAULT_VALUE, GLOBAL_VALUE_ORIGIN FROM information_schema.SYSTEM_VARIABLES WHERE GLOBAL_VALUE <> DEFAULT_VALUE;`

**How to fix.** Nothing to fix; this is what you read after the findings, to understand why the server behaves as it does. Compare it against what your configuration management believes it applied.

**False positives / caveats.** The two forks answer different questions: MySQL's `variables_info` says where a value came from but not what the default was; MariaDB's `SYSTEM_VARIABLES` says what the default was but gives coarser provenance. The finding names which one it read. Noise variables (hostnames, paths, ports, UUIDs) are excluded.

**Reads.** `MySQL: performance_schema.variables_info joined to global_variables; MariaDB: information_schema.SYSTEM_VARIABLES (GLOBAL_VALUE vs DEFAULT_VALUE)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html) · Effort S / risk low

<a id="my-cfg-002"></a>
### MY-CFG-002 — Persisted variables (inventory)

**Priority 200 (Non-default configuration) · Non-default configuration · scope: setting · cost 0 · inventory pass · engine: mysql · since 0.1.0**

**What fires it.** Always emitted when persisted variables exist. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** MySQL 8.0 only; MariaDB has no SET PERSIST and no such table (verified absent on 10.11), so this emits nothing there. The plain inventory of what is in mysqld-auto.cnf. MY-REL-010 is the FINDING for the subset that conflicts with a file-sourced value; this row lists every persisted variable regardless, because a reviewer comparing a server against its configuration repository needs the whole list, not just the conflicts.

**How to confirm.**

`SELECT * FROM performance_schema.persisted_variables;`

**How to fix.** Nothing to fix; inventory. MY-REL-010 is the finding for the subset that conflicts with a file-sourced value.

**False positives / caveats.** MySQL 8.0 only.

**Reads.** `performance_schema.persisted_variables`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/persisted-system-variables.html) · Effort S / risk low

<a id="my-cfg-003"></a>
### MY-CFG-003 — Variables differing from the supplied baseline

**Priority 200 (Non-default configuration) · Non-default configuration · scope: setting · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0 · **status: planned****

> **Not implemented in 0.1.0.** The registry row exists so the ID is reserved and the gap is visible in the report rather than silently absent. See *False positives / caveats* below for what is missing.

**What fires it.** A supplied baseline differs from the running configuration.

**Why it matters.** Configuration drift between what the configuration-management repository believes and what the server is actually running is how two supposedly identical servers behave differently. Comparing against a declared baseline is the only way to see it.

**How to confirm.**

Compare against the baseline file supplied with `--baseline`.

**How to fix.** Nothing to fix; inventory.

**False positives / caveats.** Planned as of 0.1.0: requires baseline-file support in the runner.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html) · Effort S / risk low


---

## INFO — Environment inventory

<a id="my-info-001"></a>
### MY-INFO-001 — Server identity

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted. The row a reader looks at first and the one that makes the rest of the report interpretable: which fork, which version, which role in the topology, and the handful of settings that change the meaning of every other finding. Fork-specific values that do not exist everywhere (server_uuid, gtid_mode, super_read_only) are printed as their bundle value or 'n/a', never invented.

**How to confirm.**

`SELECT @@GLOBAL.version, @@GLOBAL.version_comment, @@GLOBAL.hostname;` and the settings listed in the finding.

**How to fix.** Nothing to fix; this is the row that makes the rest of the report interpretable.

**False positives / caveats.** Values that do not exist on a fork (`server_uuid`, `gtid_mode`, `super_read_only` on MariaDB) print as `n/a` rather than being invented.

**Reads.** `version and fork facts from 01_session.sql plus the universal settings`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html) · Effort S / risk low

<a id="my-info-002"></a>
### MY-INFO-002 — Host resources

**Priority 250 (Environment inventory) · Environment inventory · scope: host · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted when host resources are supplied. Requires: `os`.

**Why it matters.** RAM, core count, storage type and disk capacity are not readable from any MySQL or MariaDB variable, yet four checks need them: MY-MEM-003 and MY-MEM-007 (memory), MY-CONN-009 (cores) and MY-WAL-005 (storage). Without them those checks either do not fire or fall back to a deliberately conservative absolute threshold.

**How to confirm.**

`/proc/meminfo`, `nproc`, `df -h`, `lsblk -d -o name,rota`.

**How to fix.** Nothing to fix; inventory. Supply these through `.db-triage.yml` `baseline:` so MY-MEM-003, MY-MEM-007, MY-CONN-009 and MY-WAL-005 can run — without them those checks either do not fire or fall back to an absolute threshold.

**False positives / caveats.** OS-level; not readable from SQL on any fork.

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/optimizing-server.html) · Effort S / risk low

<a id="my-info-003"></a>
### MY-INFO-003 — Plugins and components

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted, grouped by plugin type so the row stays readable. What is loaded determines what several findings mean: an audit plugin answers MY-SEC-015, a password-validation plugin answers MY-SEC-011, the thread pool answers MY-CONN-006, semi-sync answers MY-REPL-009, and a non-default authentication plugin changes how MY-SEC-001 and MY-SEC-006 should be read. mysql.component is MySQL 8.0's separate registry for components (the successor to plugins); MariaDB has no such table, so the component list is omitted there.

**How to confirm.**

`SELECT PLUGIN_NAME, PLUGIN_TYPE, PLUGIN_STATUS, PLUGIN_LIBRARY FROM information_schema.PLUGINS ORDER BY PLUGIN_TYPE, PLUGIN_NAME;` and on MySQL 8.0 `SELECT * FROM mysql.component;`

**How to fix.** Nothing to fix; inventory. What is loaded determines what several findings mean — audit (MY-SEC-015), password validation (MY-SEC-011), thread pool (MY-CONN-006), semi-sync (MY-REPL-009).

**False positives / caveats.** A `*` suffix in the list marks a dynamically loaded plugin as opposed to a compiled-in one.

**Reads.** `information_schema.PLUGINS, mysql.component (MySQL 8.0+)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/information-schema-plugins-table.html) · Effort S / risk low

<a id="my-info-004"></a>
### MY-INFO-004 — Replication topology

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted. Requires: `SELECT ON performance_schema.*`.

**Why it matters.** Always emitted, including when there is no replication at all — "no replication configured" is itself information a reader needs before interpreting the BAK and DUR findings. WHAT CANNOT BE SEEN FROM SQL, stated rather than omitted: * on MariaDB the receiver (I/O) thread state and the replica lag are not exposed to SQL at all — only SHOW SLAVE STATUS has them, and a SHOW cannot be selected from; * on both forks the identity of connected replicas comes from SHOW REPLICAS (SHOW SLAVE HOSTS), which is likewise not selectable, so only the COUNT of Binlog Dump threads is available here. The reference doc gives the SHOW commands to run by hand for those.

**How to confirm.**

`SHOW REPLICA STATUS\G` (MariaDB: `SHOW ALL SLAVES STATUS\G`), `SHOW REPLICAS;` (MariaDB: `SHOW SLAVE HOSTS;`), and `SELECT * FROM performance_schema.replication_group_members;`

**How to fix.** Nothing to fix; inventory.

**False positives / caveats.** Two things are NOT readable from SQL and are reported as such rather than omitted: on MariaDB the receiver (I/O) thread state and the replica lag, and on both forks the identity of connected replicas. Run the SHOW commands above by hand for those.

**Reads.** `the normalised replica status from 01_session.sql §6c, @dbt_binlog_dump_threads, semi-sync status, GTID variables`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/replication.html) · Effort S / risk low

<a id="my-info-005"></a>
### MY-INFO-005 — Connection summary

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted. Requires: `PROCESS`.

**Why it matters.** Always emitted. A SNAPSHOT, stated as such: one sample of who is connected, from where, doing what. Its value is not the numbers but the shape — whether connections arrive from three pooler hosts or three hundred application processes (MY-CONN-006), whether one account holds everything (MY-SEC-008), and whether the population is mostly idle (MY-CONN-007). Requires PROCESS to see other accounts; without it this reports only this session and says so.

**How to confirm.**

`SELECT * FROM information_schema.PROCESSLIST;` or `SELECT * FROM sys.processlist;`

**How to fix.** Nothing to fix; inventory. Its value is the shape: connections from three pooler hosts versus three hundred application processes (MY-CONN-006), one account holding everything (MY-SEC-008), a mostly idle population (MY-CONN-007).

**False positives / caveats.** One snapshot. Without PROCESS this reports only db-triage's own session and says so.

**Reads.** `information_schema.PROCESSLIST`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/information-schema-processlist-table.html) · Effort S / risk low

<a id="my-info-006"></a>
### MY-INFO-006 — InnoDB summary

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted. Every number the MEM, WAL and UNDO findings are computed from, in one place, so a reader can check the arithmetic rather than trust it. Fork-specific values print as their bundle value or 'n/a': innodb_redo_log_capacity is MySQL 8.0.30+, innodb_buffer_pool_instances was removed in MariaDB 10.6, innodb_log_files_in_group was removed in MariaDB 10.5.

**How to confirm.**

The variables listed in the finding, plus `SHOW ENGINE INNODB STATUS\G`.

**How to fix.** Nothing to fix; inventory. These are the numbers the MEM, WAL and UNDO findings are computed from, so the arithmetic in those findings can be checked rather than trusted.

**False positives / caveats.** Fork-specific values print as `n/a`: `innodb_redo_log_capacity` is MySQL 8.0.30+, `innodb_buffer_pool_instances` was removed in MariaDB 10.6, `innodb_log_files_in_group` in MariaDB 10.5.

**Reads.** `InnoDB settings (universal ones inline, fork-specific ones from the bundle), information_schema.TABLES for data size by engine`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html) · Effort S / risk low

<a id="my-info-007"></a>
### MY-INFO-007 — Object counts

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 1 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted, and the storage-engine breakdown here is the inventory half of MY-DUR-007 (which is the finding half): DUR-007 fires only on non-transactional engines, whereas this row shows the whole picture including how many tables are InnoDB, so "all 4,000 tables are InnoDB" is visible as a positive fact. The relation count also drives the design's XX-META-007 sampling rule: above 50,000 relations the per-relation checks are expected to fall back to top-N.

**How to confirm.**

The information_schema counts in the finding.

**How to fix.** Nothing to fix; inventory. The storage-engine breakdown is the inventory half of MY-DUR-007: it shows the whole picture, so 'all 4,000 tables are InnoDB' is visible as a positive fact rather than as silence.

**False positives / caveats.** Counting information_schema on a server with tens of thousands of relations is itself measurable; this is a cost-1 check for that reason.

**Reads.** `information_schema TABLES, VIEWS, ROUTINES, TRIGGERS, EVENTS, PARTITIONS, STATISTICS, TABLE_CONSTRAINTS`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/information-schema.html) · Effort S / risk low

<a id="my-info-008"></a>
### MY-INFO-008 — Accounts summary

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted. Requires: `SELECT ON mysql.*`.

**Why it matters.** Always emitted. Aggregate shape of the account catalog, so the individual SEC findings can be read in proportion: "3 of 400 accounts have a wildcard host" reads very differently from "3 of 4". PRIVACY: counts only. No credential value is read; has_credential is derived from emptiness alone, as documented in 01_session.sql §6d.

**How to confirm.**

`SELECT * FROM information_schema.USER_PRIVILEGES;` and `SELECT User, Host, plugin FROM mysql.user;`

**How to fix.** Nothing to fix; inventory. Read the SEC findings against these totals: three wildcard accounts out of four hundred reads very differently from three out of four.

**False positives / caveats.** Counts only. No credential value is read — `has_credential` is derived from emptiness alone.

**Reads.** `normalised account source @dbt_acct_src (01_session.sql §6d)`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/grant-tables.html) · Effort S / risk low

<a id="my-info-009"></a>
### MY-INFO-009 — Statistics window

**Priority 250 (Environment inventory) · Environment inventory · scope: cluster · cost 0 · inventory pass · engine: mysql,mariadb · since 0.1.0**

**What fires it.** Always emitted.

**Why it matters.** Always emitted, and it is the row that makes every rate in this report interpretable. Neither MySQL nor MariaDB has PostgreSQL's per-view stats_reset timestamp: status counters, performance_schema aggregates and InnoDB metrics all begin at zero on startup, and FLUSH STATUS or a TRUNCATE of a performance_schema summary table resets some of them with no record that it happened. Uptime is therefore an UPPER BOUND on the window, not a measurement of it, and this row says so explicitly. The lost-instrument counters matter for the same reason: when performance_schema runs out of its preallocated memory it silently drops instrumentation, so a digest or index-usage figure can be incomplete without any error being raised.

**How to confirm.**

`SHOW GLOBAL STATUS LIKE 'Uptime'; SHOW GLOBAL STATUS LIKE 'Performance_schema_%_lost';`

**How to fix.** Nothing to fix; inventory. This is the row that makes every rate in the report interpretable.

**False positives / caveats.** Uptime is an UPPER BOUND on the counter window, not a measurement of it: `FLUSH STATUS` and `TRUNCATE` on a performance_schema summary table both reset counters without leaving a trace. Neither fork has PostgreSQL's per-view `stats_reset` timestamp.

**Reads.** `@dbt_uptime_s, @dbt_counter_conf, performance_schema lost-instrument counters`

**Further reading.** [Official documentation](https://dev.mysql.com/doc/refman/8.4/en/server-status-variables.html#statvar_Uptime) · Effort S / risk low

