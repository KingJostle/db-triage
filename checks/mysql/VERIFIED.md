# Verification record — checks/mysql

What was actually executed against a live server, what fired, and what was not
exercised. Written so that no claim in this half of the repo has to be taken on
trust.

**Verified:** 2026-09-02.

---

## 1. The server

| | |
|---|---|
| Fork and version | **MariaDB 10.11.14-MariaDB-0ubuntu0.24.04.1-log** (Ubuntu 24.04 package, `mariadbd`) |
| Second instance | a second MariaDB 10.11.14 attached as a **live replica** (`CHANGE MASTER TO … MASTER_USE_GTID=no`, `START SLAVE`, `Slave_IO_Running=Yes`, `Slave_SQL_Running=Yes`) |
| `performance_schema` | ON |
| `sys` schema | present, 100 objects |
| Binary logging | ON, `binlog_format=ROW`, `server_id=1` |
| Fixture | `tests/fixtures/mysql-provoke.sql` applied to the primary |
| Concurrency provoked | three sidecar sessions: an open transaction holding row locks, a queued `ALTER TABLE`, and a `SELECT` queued behind it; separately, an idle-in-transaction session and a session waiting on a row lock |

**No MySQL server was available in this environment.** Only MariaDB packages
could be installed; the Docker repository was unreachable through the proxy, so
the `mysql:8.0` / `mysql:8.4` containers in the design's test matrix could not be
started. Section 4 says exactly what that leaves unverified.

## 2. What was executed

Every one of the following ran to completion with **zero SQL errors**:

| File | Result |
|---|---|
| `01_session.sql` | ran; all `@dbt_*` facts and both bundles populated correctly (verified by reading them back) |
| `00_preflight.sql` | ran; produced the target row and the privilege-gap row |
| all 147 files in `checks/` individually | 0 errors |
| `fast.sql` (124 checks) | 0 errors, 124 `@@CHECK` markers, 89 finding rows |
| `inventory.sql` (21 checks) | 0 errors, 21 markers, 106 finding rows |
| `deep.sql` (2 checks) | 0 errors, 0 rows (correctly degraded — see §4) |
| the same against the **replica** | 0 errors |

The end-to-end invocation used was the one documented in the generated files:

```
cat 01_session.sql 00_preflight.sql fast.sql | mysql --batch --raw --force "$DSN"
```

## 3. Checks that produced a real finding on the live server

55 of the 147 SQL checks fired with dynamic, value-bearing `details`. Every
finding in `examples/report-mysql.md` is verbatim output from this run.

```
MY-BAK-004   MY-CAP-004   MY-CAP-005   MY-CAP-007   MY-CFG-001   MY-CONN-010
MY-DUR-001   MY-DUR-002   MY-DUR-003   MY-DUR-007   MY-IDX-003   MY-INFO-001
MY-INFO-003  MY-INFO-004  MY-INFO-005  MY-INFO-006  MY-INFO-007  MY-INFO-008
MY-INFO-009  MY-MEM-001   MY-MEM-007   MY-QRY-002   MY-QRY-003   MY-QRY-004
MY-QRY-005   MY-QRY-006   MY-QRY-007   MY-QRY-008   MY-QRY-009   MY-QRY-015
MY-QRY-016   MY-REL-005   MY-REL-006   MY-REPL-006  MY-REPL-012  MY-SCHEMA-001
MY-SCHEMA-004 MY-SCHEMA-005 MY-SCHEMA-007 MY-SCHEMA-008 MY-SCHEMA-012
MY-SCHEMA-014 MY-SEC-001   MY-SEC-002   MY-SEC-003   MY-SEC-004   MY-SEC-005
MY-SEC-006   MY-SEC-007   MY-SEC-009   MY-SEC-010   MY-SEC-011   MY-SEC-012
MY-SEC-014   MY-SEC-015
```

### 3a. Additionally fired under provoked conditions

These produced correct findings when the condition was created deliberately, in
runs separate from the report above:

| Check | How it was provoked | Observed |
|---|---|---|
| `MY-LOCK-001` | a second session blocked on `SELECT … FOR UPDATE` | "waiting for a row lock for 20 s", blocking thread identified |
| `MY-LOCK-003` | an open transaction holding 4 row locks | "open for 0.01 h … holds 4 row lock(s)" |
| `MY-LOCK-004` | a session left idle mid-transaction | "IDLE (COMMAND = Sleep for 24 s) but still open" |
| `MY-LOCK-006` | an `ALTER TABLE` queued behind the open transaction, then a `SELECT` queued behind the ALTER | "2 session(s) are waiting for a table metadata lock, the longest for 43 s" — the pile-up this check exists for |
| `MY-LOCK-009` | the same three sessions | one row per long-running thread with its statement text |
| `MY-DUR-008` | run against the replica (`relay_log_recovery=OFF`) | "This instance is a replica and relay_log_recovery = OFF" |
| `MY-REPL-013` | replica configured with `MASTER_CONNECT_RETRY=900` | "retry interval 900 s" |
| `MY-UNDO-001/003/004`, `MY-WAL-001/004/005/006`, `MY-CONN-006`, `MY-IDX-001/005/007/008/009`, `MY-SCHEMA-006` | thresholds lowered via the documented `@key` session variables | each fired with correct, dynamic details |
| `MY-REL-001`, `MY-REL-002` | `@dbt_fork`/`@dbt_vmajor`/`@dbt_vminor` overridden to simulate MySQL 8.0 | "reached end of life on 2026-04-30 — 125 days ago" |
| `MY-REPL-016` | `@dbt_v_gtid_executed` set to a real MySQL-format GTID set with a gap (`uuid:1-5:8-12,uuid2:1-900`) | "3 interval(s) across 2 source UUID(s), so at least 1 gap(s)" |

### 3b. Fallback paths verified, not just the primary path

| Check | Primary path | Fallback exercised |
|---|---|---|
| `MY-IDX-003` | `sys.schema_redundant_indexes` | forced `@dbt_sys_redundant_idx := 0` — the `information_schema.STATISTICS` self-join produced **byte-identical findings** |
| `MY-IDX-001` | `sys.schema_unused_indexes` | forced to the `performance_schema.table_io_waits_summary_by_index_usage` path; ran clean |
| `MY-UNDO-003`, `MY-CAP-008` | `information_schema.FILES` (MySQL) | MariaDB path via `INNODB_SYS_TABLESPACES` — confirmed necessary, because `information_schema.FILES` returns **zero rows** on MariaDB 10.11 and the MySQL query would have silently never fired |
| `MY-CFG-001` | `performance_schema.variables_info` (MySQL) | MariaDB path via `information_schema.SYSTEM_VARIABLES`; 62 non-default variables inventoried with their compiled defaults |
| variables bundle | `performance_schema.global_variables` | MariaDB has no such table; `information_schema.GLOBAL_VARIABLES` selected automatically and all ~65 optional variables read back correctly |

### 3c. Bugs found by verification, and fixed

1. **`MY-SCHEMA-001` / `MY-SCHEMA-002` used an inner join** to
   `information_schema.STATISTICS`. A table with *no indexes at all* has no rows
   there, so the worst case — a table with neither a primary key nor any index —
   was silently dropped from the results. Changed to `LEFT JOIN`; the fixture's
   `no_pk_audit` table then appeared.
2. **Reserved words as column aliases.** `schemas` (MY-INFO-007), `specific`
   (MY-INFO-008) and `ssl` (MY-SEC-005) are reserved in MariaDB and produced
   syntax errors. All count aliases in those aggregates are now prefixed.
3. **`JSON_OBJECT` with a boolean system variable** emitted invalid JSON
   (`"log_bin": ON`, unquoted). Every ON/OFF system variable in an
   `evidence_json` is now wrapped in `CAST(… AS CHAR)`.
4. **`REPLICATION CLIENT` does not exist on MariaDB 10.5+** — it was renamed
   `BINLOG MONITOR`, with `SLAVE MONITOR` split off. `00_preflight.sql` reported a
   false privilege gap for `root` until all four spellings were accepted.
5. **User-variable row numbering** (`@rn := @rn + 1`) in the QRY top-N checks is
   deprecated in MySQL 8.0.28+ and unavailable in 5.7 without window functions.
   Removed; the percent-of-total conveys rank instead.

## 4. What could NOT be exercised, and why

### 4a. No MySQL server was available

Everything below is written from the MySQL 5.7/8.0/8.4/9.x reference manuals and
is **gated so that it cannot error**, but the MySQL branch of each was not
executed:

| Area | MySQL-only path, unverified |
|---|---|
| `MY-CORR-001`, `MY-CORR-002` | `performance_schema.error_log` (8.0.22+). On MariaDB the gate correctly degraded to `DO 1` and emitted nothing. The regex patterns and the `LOGGED`/`DATA` column names are from the manual. |
| `MY-REPL-001`, `MY-REPL-002` | the `performance_schema.replication_connection_status` half (receiver thread). The applier half ran on the live MariaDB replica. |
| `MY-REPL-003`, `MY-REPL-004` | the whole lag computation: `LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP` and `APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP` do not exist on MariaDB, so `@dbt_has_repl_lag_cols` was 0 and the statement was never prepared. **This is the largest single unverified area.** |
| `MY-REPL-010` | `performance_schema.replication_group_members` (Group Replication). |
| `MY-REPL-015` | the `performance_schema.replication_applier_global_filters` branch; the MariaDB `replicate_*` variable branch ran. |
| `MY-REL-010`, `MY-CFG-002` | `performance_schema.persisted_variables` / `variables_info`. |
| `MY-SEC-013` | `mysql.user.password_lifetime`. |
| `MY-SCHEMA-003` | `sql_require_primary_key`. |
| `MY-SCHEMA-013` | the `information_schema.INNODB_TABLES` name (8.0); the `INNODB_SYS_TABLES` name ran. |
| `MY-SEC-001`, `MY-SEC-002`, `MY-SEC-004`, `MY-SEC-006`, `MY-SEC-007`, `MY-SEC-008`, `MY-SEC-010`, `MY-INFO-008` | the MySQL branch of the normalised account source `@dbt_acct_src` (`mysql.user` as a real table with `account_locked` and `password_lifetime` columns). The MariaDB branch — `mysql.user` as a view over `mysql.global_priv`, with `account_locked` read from JSON — was verified in full, including the `'invalid'` credential marker. |
| `MY-MEM-005`, `MY-MEM-002`, `MY-IDX-006`, `MY-CAP-004/005` | the `information_schema_stats_expiry` and `temptable_max_ram` readings, which exist only on MySQL 8.0. |
| `MY-WAL-001` | the `innodb_redo_log_capacity` branch (MySQL 8.0.30+); the `innodb_log_file_size` branch ran. |
| `MY-WAL-004` | inverse case — this one is *MariaDB/Percona only* and DID run; stock MySQL has no `Innodb_checkpoint_age` status variable and the check correctly emits nothing there. |

Confidence in the unverified MySQL branches is not uniform. The ones built from
plain system variables (`sql_require_primary_key`, `password_lifetime`,
`innodb_redo_log_capacity`) are low-risk: they are read through the bundle and a
wrong name yields NULL, not an error. The ones built from
`performance_schema` table and column names — MY-REPL-003/004 above all — are
the ones a MySQL 8.0 run should check first.

### 4b. Conditions that cannot be created safely or quickly

| Check | Why not exercised |
|---|---|
| `MY-DUR-004`, `MY-DUR-005`, `MY-DUR-006` | `innodb_doublewrite`, `innodb_force_recovery` and `innodb_checksum_algorithm` are read-only at runtime; they need a restart with different flags. |
| `MY-UNDO-001`, `MY-UNDO-002` | a history list in the millions needs sustained write load against an old read view. The threshold path was verified by lowering the threshold instead. |
| `MY-CORR-001/002` | require genuinely damaged pages. |
| `MY-CONN-001`..`005`, `MY-MEM-004`, `MY-QRY-010`..`013`, `MY-LOCK-007/008` | require real traffic volume; the counters on a 1-hour-old test server are all zero, so the checks correctly emitted nothing. Their arithmetic was reviewed but not observed firing. |
| `MY-REPL-001`..`004`, `MY-REPL-009`, `MY-REPL-011` | need broken or lagging replication, or the semi-sync plugin. The replica in this run was healthy throughout. |
| `MY-SCHEMA-009`, `MY-SCHEMA-010` | need a 200 GB table and a 1,000-partition table. |
| `MY-BAK-002`, `MY-BAK-005`, `MY-CORR-003`, `MY-MEM-011`, `MY-CAP-001`..`003` | `source` is `os`, `interview` or `external`; there is no SQL file to run. |

### 4c. Planned, not implemented

Five registry rows carry `status=planned` and have no `.sql` file. They exist so
the IDs are reserved and the gap is visible in the report rather than silently
absent:

| Check | Why |
|---|---|
| `MY-CAP-003` | needs the snapshot store (`--save` / `--compare`). |
| `MY-CAP-006` | `SHOW BINARY LOGS` produces a result set no `SELECT` can consume. It needs the runner to execute the `SHOW` and parse it, which is outside this file set. |
| `MY-CAP-009` | needs the snapshot store. |
| `MY-REL-004` | needs the latest-minor list from `reference/versions.yml`, which is generated elsewhere in the repo. The EOL half is implemented (`MY-REL-001/002/003`) using a version table embedded in the check with an `as_of` stamp. |
| `MY-CFG-003` | needs baseline-file support in the runner. |

## 5. Read-only contract

Verified by grep over all 150 files in `checks/mysql/`: no `INSERT`, `UPDATE`,
`DELETE`, `TRUNCATE`, `DROP`, `CREATE`, `ALTER`, `GRANT`, `REVOKE`, `SET GLOBAL`,
`SET PERSIST`, `FLUSH`, `RESET`, `OPTIMIZE TABLE`, `ANALYZE TABLE`,
`CHECK TABLE`, `REPAIR TABLE`, `KILL`, `PURGE BINARY LOGS`, `START`/`STOP
REPLICA`, `LOCK TABLES` or `SELECT … FOR UPDATE` appears as a statement. The only
matches are those words inside quoted English text in a finding's `details`.

Every `SET` is either `SET SESSION` (four of them: `TRANSACTION READ ONLY`,
`sql_mode`, `lock_wait_timeout`, `innodb_lock_wait_timeout`, plus the fork-gated
statement timeout) or an assignment to a `@user_variable`. `PREPARE` / `EXECUTE`
/ `DEALLOCATE PREPARE` are used for version gating and only ever prepare a
`SELECT` or `DO 1`.

The one deliberate exception is `tests/fixtures/mysql-provoke.sql`, which is
destructive by design, carries a loud header, and is never run by db-triage.

## 6. Notes for the runner

Two things a caller must handle, both observed during verification:

1. **`mysql --batch` renders a SQL NULL as the literal four characters `NULL`.**
   Several checks emit `object = NULL` deliberately (cluster-scope findings such
   as `MY-DUR-003` and `MY-UNDO-001`), and `evidence_json` can contain the string
   too. The runner must translate a bare `NULL` field back to null rather than
   printing the word; `examples/report-mysql.md` does this.
2. **`--force` (or the equivalent) is required.** Without it a privilege error on
   one check aborts the whole batch. With it, the error text appears adjacent to
   that check's own `@@CHECK` marker and can be attributed to it, which is what
   `XX-META-001` needs.

## 7. Order of execution

`01_session.sql` must be sourced **before** `00_preflight.sql`, contrary to what
the numeric prefixes suggest. The preflight reads the `@dbt_*` facts that the
session file establishes. The numbering follows the design's file-naming
convention; the execution order is session → preflight → pass file, and it is
stated in the header of every one of those files.
