-- db-triage — checks/mysql/fast.sql
-- GENERATED FILE — do not hand-edit. Regenerated from
-- checks/registry-mysql.csv and checks/mysql/checks/*.sql.
--
-- HOW TO RUN (one session, in this order):
--   mysql --batch --raw --force "$DSN" \
--     -e "source checks/mysql/01_session.sql; \
--         source checks/mysql/00_preflight.sql; \
--         source checks/mysql/fast.sql"
-- or, equivalently, concatenate the three files and pipe them in.
--
-- 01_session.sql MUST run first: it establishes the read-only
-- transaction, the statement and lock timeouts, the run marker, and
-- every @dbt_* fact these checks read. 00_preflight.sql sets the
-- platform fingerprint and privilege flags that gate several checks.
--
-- --force (or ON_ERROR_STOP off) is required so that a privilege error
-- on one check does not abort the batch; each error appears adjacent to
-- its own @@CHECK marker and is attributed to that check.
--
-- Every check emits the fixed column set:
--   check_id, scope, object, details, evidence_json, confidence
-- bracketed by '@@CHECK <id>' and '@@END' marker rows.
--
-- Thresholds: each check reads COALESCE(@<key>, <default>), so the
-- runner overrides one by issuing SET @<key> := <value>; before the
-- batch. The threshold keys are in the registry's `thresholds` column.
--
-- Contents: fast pass, 124 checks, ordered by priority ascending so that
-- if the batch is interrupted the worst findings are already in hand.
-- P1   MY-BAK-001     Binary logging disabled — point-in-time recovery impossible
-- P1   MY-DUR-004     InnoDB doublewrite buffer disabled
-- P1   MY-DUR-005     Server running in innodb_force_recovery mode
-- P1   MY-REL-002     End-of-life server reachable from any network interface
-- P1   MY-REPL-001    Replication stopped with an error
-- P1   MY-SEC-001     Accounts with no password
-- P1   MY-SEC-002     Superuser-equivalent account reachable from any host
-- P5   MY-CONN-001    Connections at or above 90 percent of max_connections
-- P5   MY-DUR-003     Crash-unsafe replication source
-- P5   MY-REPL-003    Replica lag over 5 minutes
-- P5   MY-REPL-010    Group Replication member not ONLINE
-- P5   MY-SCHEMA-005  AUTO_INCREMENT at or above 90 percent exhausted
-- P5   MY-SEC-003     Anonymous accounts present
-- P5   MY-UNDO-001    InnoDB history list length very high
-- P10  MY-DUR-001     innodb_flush_log_at_trx_commit not 1
-- P10  MY-DUR-002     sync_binlog not 1
-- P10  MY-LOCK-001    Transaction waiting on a row lock for over 5 minutes
-- P10  MY-LOCK-004    Idle transaction holding locks for over an hour
-- P10  MY-REL-005     Server restarted within the last 24 hours
-- P10  MY-REPL-002    Replication threads stopped without an error
-- P10  MY-REPL-005    Replica is writable
-- P20  MY-BAK-003     Binary log retention shorter than one day
-- P20  MY-CONN-003    Clients refused because max_connections was reached
-- P20  MY-LOCK-003    Transaction open for over an hour
-- P20  MY-MEM-001     InnoDB buffer pool at the shipped default
-- P20  MY-REL-001     Server version is past end of life
-- P20  MY-REPL-016    GTID set has gaps
-- P20  MY-SCHEMA-001  InnoDB tables without a primary key on a replicated source
-- P50  MY-BAK-004     Binary logs never expire
-- P50  MY-CAP-007     General query log enabled
-- P50  MY-CONN-002    Connections at or above 70 percent of max_connections
-- P50  MY-CONN-006    max_connections very high with no thread pool and no evidence of a pooler
-- P50  MY-CONN-009    Server saturated at snapshot time
-- P50  MY-DUR-006     InnoDB page checksums disabled
-- P50  MY-DUR-007     Non-transactional storage engines in use
-- P50  MY-IDX-001     Unused index of 1 GB or more
-- P50  MY-IDX-003     Redundant or duplicate indexes
-- P50  MY-IDX-004     Large table with heavy full table scans
-- P50  MY-LOCK-002    Transaction waiting on a row lock for over 30 seconds
-- P50  MY-LOCK-005    Idle transaction holding locks for over 5 minutes
-- P50  MY-LOCK-006    Sessions waiting for a metadata lock
-- P50  MY-MEM-002     Buffer pool far smaller than the InnoDB working set
-- P50  MY-MEM-007     Worst-case memory commitment exceeds host RAM
-- P50  MY-MEM-009     Query cache enabled
-- P50  MY-REPL-004    Replica lag over 30 seconds
-- P50  MY-REPL-006    GTID not in use in a replicated topology
-- P50  MY-REPL-007    Statement-based binary logging
-- P50  MY-REPL-008    Replication errors are being skipped
-- P50  MY-REPL-009    Semi-synchronous replication has fallen back to asynchronous
-- P50  MY-REPL-015    Replication filters configured
-- P50  MY-SCHEMA-004  sql_mode is not strict
-- P50  MY-SCHEMA-006  AUTO_INCREMENT at or above 70 percent exhausted
-- P50  MY-SCHEMA-007  Integrity checks disabled globally
-- P50  MY-SCHEMA-013  Shared InnoDB tablespace in use
-- P50  MY-SEC-008     Application connections running as a privileged account
-- P50  MY-UNDO-002    InnoDB history list length elevated
-- P50  MY-UNDO-003    Undo tablespaces large
-- P50  MY-WAL-001     Redo log capacity below one hour of writes
-- P100 MY-BAK-006     Binary log checksums off
-- P100 MY-CAP-008     InnoDB temporary tablespace large
-- P100 MY-CONN-004    Aborted connections high
-- P100 MY-CONN-005    Host approaching the connect-error block threshold
-- P100 MY-CONN-007    Most connections are sleeping
-- P100 MY-DUR-008     Replica not crash-safe
-- P100 MY-IDX-005     Write-heavy table carrying many indexes
-- P100 MY-IDX-006     Table fragmentation (DATA_FREE) high
-- P100 MY-LOCK-009    Query running for over 10 minutes
-- P100 MY-MEM-003     Buffer pool over 80 percent of host RAM
-- P100 MY-MEM-004     Buffer pool read miss rate high
-- P100 MY-MEM-005     Implicit temporary tables spilling to disk
-- P100 MY-MEM-006     Oversized per-session buffers
-- P100 MY-MEM-008     Table open cache too small, or open-file limit at risk
-- P100 MY-QRY-001     performance_schema disabled
-- P100 MY-QRY-003     Slow query log off, or its threshold at the default
-- P100 MY-QRY-010     One statement digest dominates total latency
-- P100 MY-QRY-012     Join and scan counters high
-- P100 MY-REL-003     Server version within six months of end of life
-- P100 MY-REL-006     No evidence of a monitoring agent
-- P100 MY-REL-010     Persisted variables override the configuration files
-- P100 MY-REPL-011    Single-threaded replica applier while lagging
-- P100 MY-REPL-013    Replication heartbeat or connection retry misconfigured
-- P100 MY-REPL-014    binlog_row_image MINIMAL with logical consumers configured
-- P100 MY-SCHEMA-002  InnoDB tables without a primary key
-- P100 MY-SCHEMA-008  Leftover online-schema-change artefacts
-- P100 MY-SEC-004     Application accounts allowed from any host
-- P100 MY-SEC-005     TLS not enforced, or largely unused
-- P100 MY-SEC-009     LOAD DATA LOCAL enabled
-- P100 MY-SEC-010     FILE privilege unrestricted by secure_file_priv
-- P100 MY-UNDO-004    Purge threads at default on a server that is not purging fast enough
-- P100 MY-WAL-002     Redo log buffer waits
-- P100 MY-WAL-004     Checkpoint age near redo capacity
-- P150 MY-CONN-008    Thread cache misses
-- P150 MY-CONN-010    DNS lookups performed on every connection
-- P150 MY-IDX-002     Unused index (smaller, or statistics window too short)
-- P150 MY-IDX-007     Single-column index on a very low-cardinality column
-- P150 MY-IDX-008     InnoDB persistent statistics stale
-- P150 MY-IDX-009     Wide composite indexes
-- P150 MY-LOCK-007    Deadlocks occurring regularly
-- P150 MY-LOCK-008    Table-level lock waits
-- P150 MY-MEM-010     Single buffer pool instance with a large pool
-- P150 MY-MEM-012     innodb_flush_method not O_DIRECT on Linux
-- P150 MY-QRY-002     Statement digest instrumentation incomplete
-- P150 MY-QRY-011     Statements failing or warning frequently
-- P150 MY-QRY-013     Sort merge passes high
-- P150 MY-QRY-014     Plan-hostile patterns in top statement digests
-- P150 MY-REL-007     sys schema missing
-- P150 MY-REL-008     Error log verbosity reduced
-- P150 MY-SCHEMA-003  sql_require_primary_key off while primary-key-less tables exist
-- P150 MY-SCHEMA-009  Very large table not partitioned
-- P150 MY-SCHEMA-010  Table with more than 1,000 partitions
-- P150 MY-SCHEMA-011  Triggers on high-write tables
-- P150 MY-SCHEMA-014  Character set or collation inconsistent within a schema
-- P150 MY-SEC-006     Deprecated or weak authentication plugins
-- P150 MY-SEC-011     No password validation policy
-- P150 MY-SEC-012     Legacy test database or test grants present
-- P150 MY-WAL-003     Binary log cache spilling to disk
-- P150 MY-WAL-005     innodb_io_capacity at its rotational-disk default on solid-state storage
-- P150 MY-WAL-006     Buffer pool dirty page ratio high
-- P240 MY-QRY-004     Top 10 statements by total latency
-- P240 MY-QRY-005     Top 10 statements by average latency
-- P240 MY-QRY-006     Top 10 statements by rows examined per row sent
-- P240 MY-QRY-007     Top 10 statements creating disk temporary tables
-- P240 MY-QRY-008     Top 10 statements with full table scans
-- P240 MY-QRY-009     Top 10 statements by execution count

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-BAK-001' AS marker;
-- check: MY-BAK-001
-- title: Binary logging disabled — point-in-time recovery impossible
-- priority: 1 | category: BAK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- platform_skip: rds;aurora;cloudsql;azure  (the platform archives outside the
--   server; MY-BAK-007 fires there instead)
-- thresholds: (none)
-- reads: @@GLOBAL.log_bin, @dbt_platform, @dbt_is_replica
-- Default divergence: MySQL 8.0+ ships log_bin=ON; MySQL 5.7 and every MariaDB
-- release ship it OFF. A MariaDB server with no explicit log_bin therefore has
-- no PITR and no ability to add a replica, and nobody chose that.
-- Without binary logs the recoverable window is exactly "the last full backup",
-- whatever the backup schedule claims. Skipped on a replica: a replica's own
-- binlog is optional unless it is also a source (log_slave_updates).
SELECT
  'MY-BAK-001' AS check_id,
  'cluster'    AS scope,
  NULL         AS object,
  CONCAT('log_bin = OFF on a ', @dbt_platform,
         ' server. There is no binary log, so point-in-time recovery is impossible: ',
         'the best achievable RPO is the age of the newest full backup, and no replica can be attached. ',
         'InnoDB data size ', ROUND(s.bytes / 1073741824, 1), ' GB across ',
         s.tables, ' tables. ',
         IF(@dbt_is_mariadb,
            'MariaDB ships log_bin OFF by default, so this may be an unreviewed default rather than a decision.',
            'MySQL 8.0 ships log_bin ON by default, so this was switched off deliberately.')) AS details,
  JSON_OBJECT(
    'log_bin', 'OFF',
    'platform', @dbt_platform,
    'fork', @dbt_fork,
    'data_bytes', s.bytes,
    'table_count', s.tables,
    'is_replica', IFNULL(@dbt_is_replica, 0)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes, COUNT(*) AS tables
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE @@GLOBAL.log_bin = 0
  AND IFNULL(@dbt_is_replica, 0) = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-004' AS marker;
-- check: MY-DUR-004
-- title: InnoDB doublewrite buffer disabled
-- priority: 1 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_doublewrite, @@GLOBAL.innodb_page_size
-- Type divergence: MariaDB and MySQL < 8.0.30 expose this as a boolean (1/0);
-- MySQL 8.0.30+ made it an enum (ON | OFF | DETECT_ONLY | DETECT_AND_RECOVER).
-- Casting to CHAR and comparing against a set covers both. DETECT_ONLY writes
-- only page metadata, so torn pages are detected but not repairable — that is
-- still a loss of the crash-recovery guarantee, so it fires too.
SELECT
  'MY-DUR-004' AS check_id,
  'setting'    AS scope,
  'innodb_doublewrite' AS object,
  CONCAT('innodb_doublewrite = ', d.val,
         IF(d.val = 'DETECT_ONLY',
            ': only page metadata is doublewritten, so a torn page is detected but cannot be recovered.',
            ': torn pages are neither detected nor recoverable.'),
         ' A power loss or kernel panic mid-write leaves a partially written ',
         @@GLOBAL.innodb_page_size,
         '-byte page that InnoDB cannot repair, unless the storage layer guarantees atomic writes of that size (ZFS, some NVMe with atomic-write support, Fusion-io). Confirm the filesystem and device before treating this as intentional.') AS details,
  JSON_OBJECT(
    'innodb_doublewrite', d.val,
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'innodb_flush_method', IFNULL(@dbt_v_innodb_flush_method, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM (SELECT UPPER(CAST(@@GLOBAL.innodb_doublewrite AS CHAR)) AS val) AS d
WHERE d.val IN ('0', 'OFF', 'DETECT_ONLY');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-005' AS marker;
-- check: MY-DUR-005
-- title: Server running in innodb_force_recovery mode
-- priority: 1 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_force_recovery
-- Universal, read-only variable. 1-3 disable parts of recovery; from 4 upward
-- InnoDB is explicitly allowed to corrupt data structures to stay up, and from
-- 4 (MySQL 8.0 / MariaDB 10.x) the server refuses writes. Anything above 0 is a
-- rescue mode nobody should still be in.
SELECT
  'MY-DUR-005' AS check_id,
  'setting'    AS scope,
  'innodb_force_recovery' AS object,
  CONCAT('innodb_force_recovery = ', @@GLOBAL.innodb_force_recovery,
         CASE
           WHEN @@GLOBAL.innodb_force_recovery >= 4
             THEN ': InnoDB is permitted to damage data structures to keep the server up, and writes are refused. This is a data-rescue mode, not a running configuration.'
           ELSE ': parts of InnoDB crash recovery, the purge thread and/or the insert buffer merge are disabled. Undo is not being purged and background repair is not happening.'
         END,
         ' Uptime is ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h, so this is not a transient boot state.') AS details,
  JSON_OBJECT(
    'innodb_force_recovery', @@GLOBAL.innodb_force_recovery,
    'uptime_seconds', @dbt_uptime_s,
    'read_only', CAST(@@GLOBAL.read_only AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.innodb_force_recovery > 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-002' AS marker;
-- check: MY-REL-002
-- title: End-of-life server reachable from any network interface
-- priority: 1 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: eol_as_of=2026-09-02
-- reads: as MY-REL-001, plus @@GLOBAL.bind_address, @@GLOBAL.skip_networking,
--        and the wildcard-host account count
-- Derived: MY-REL-001 (no more security patches) AND MY-SEC-014 (listening on
-- every interface) AND at least one account reachable from any host. Each alone
-- is a P20 or a P200 review row; together they are the sp_Blitz "you get fired"
-- shape — a server with known-unpatchable vulnerabilities and an open front door.
-- The combination is what raises it to P1, so suppressing MY-REL-001 for a
-- deliberate upgrade freeze does not also suppress this.
SET @dbt_eol_as_of := IFNULL(@dbt_eol_as_of, '2026-09-02');
SET @dbt_q := "
SELECT
  'MY-REL-002' AS check_id,
  'cluster'    AS scope,
  CONCAT(v.fork, ' ', v.branch) AS object,
  CONCAT(v.fork, ' ', @@GLOBAL.version, ' passed end of life on ', v.eol, ' (',
         DATEDIFF(CURDATE(), v.eol), ' days ago, no further security patches) AND it listens on ',
         @@GLOBAL.bind_address, ':', @@GLOBAL.port, ' — every network interface — with ',
         w.n, ' account(s) whose host pattern accepts any host. ',
         'require_secure_transport = ', IFNULL(@dbt_v_require_secure_transport, 'n/a'), '. ',
         'Individually these are MY-REL-001 (P20) and MY-SEC-014 (P200 review). Together they are an unpatchable server with an open front door, which is why this is P1. ',
         'If a firewall or security group already restricts reachability, record it in .db-triage.yml so this stops firing; if not, restricting the network is faster than the major upgrade and buys time for it.') AS details,
  JSON_OBJECT(
    'fork', v.fork, 'version', @@GLOBAL.version, 'branch', v.branch,
    'eol_date', v.eol, 'days_past_eol', DATEDIFF(CURDATE(), v.eol),
    'bind_address', @@GLOBAL.bind_address, 'port', @@GLOBAL.port,
    'skip_networking', CAST(@@GLOBAL.skip_networking AS CHAR),
    'wildcard_host_accounts', w.n,
    'require_secure_transport', IFNULL(@dbt_v_require_secure_transport, 'n/a'),
    'release_data_as_of', @dbt_eol_as_of) AS evidence_json,
  IF(DATEDIFF(CURDATE(), @dbt_eol_as_of) > 365, 'low', 'high') AS confidence
FROM (BRANCHES) AS v,
(
  SELECT COUNT(*) AS n FROM information_schema.USER_PRIVILEGES WHERE GRANTEE LIKE '%@''%''%'
) AS w
WHERE v.eol < CURDATE()
  AND @@GLOBAL.skip_networking = 0
  AND (@@GLOBAL.bind_address IN ('*', '0.0.0.0', '::', '') OR @@GLOBAL.bind_address LIKE '%0.0.0.0%')
  AND w.n > 0";
-- The release table is redefined here rather than inherited from MY-REL-001,
-- so this check still works when the runner is invoked with --only MY-REL-002.
-- The release table. Matched on fork + major.minor.
SET @dbt_branches := "
  SELECT b.* FROM (
              SELECT 'mysql'   AS fork, '5.7'   AS branch, '2023-10-31' AS eol, '8.4 LTS' AS successor
    UNION ALL SELECT 'mysql',   '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'mysql',   '8.4',   '2032-04-30', '9.x innovation / the next LTS'
    UNION ALL SELECT 'percona', '5.7',   '2023-10-31', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.4',   '2032-04-30', 'the next LTS'
    UNION ALL SELECT 'mariadb', '10.4',  '2024-06-18', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.5',  '2025-06-24', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.6',  '2026-07-06', '10.11 LTS or 11.4 LTS'
    UNION ALL SELECT 'mariadb', '10.11', '2028-02-16', '11.4 LTS'
    UNION ALL SELECT 'mariadb', '11.4',  '2029-05-29', '11.8 LTS'
    UNION ALL SELECT 'mariadb', '11.8',  '2030-06-04', 'the next LTS'
  ) AS b
  WHERE b.fork = @dbt_fork
    AND b.branch = CONCAT(@dbt_vmajor, '.', @dbt_vminor)";

SET @dbt_q := REPLACE(@dbt_q, 'BRANCHES', @dbt_branches);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-001' AS marker;
-- check: MY-REPL-001
-- title: Replication stopped with an error
-- priority: 1 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: @dbt_repl_io_state / @dbt_repl_sql_state / @dbt_repl_err_* (01_session.sql §6c)
-- Fork divergence is resolved in 01_session.sql. On MariaDB the receiver (I/O)
-- thread state is not readable from SQL at all, so @dbt_repl_io_state is NULL
-- and the details say which threads were actually observed rather than implying
-- a clean receiver. The applier state and its last error ARE readable on both.
-- A replica stopped with an error is a failover target that is silently stale:
-- the monitoring dashboards still show the host up, and the data is frozen at
-- the moment the error hit.
SELECT
  'MY-REPL-001' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replication from ', IFNULL(@dbt_repl_source, 'the configured source'),
         ' is stopped with error ', @dbt_repl_err_no, ': ',
         SUBSTRING(IFNULL(@dbt_repl_err_msg, '(no message recorded)'), 1, 300),
         ' (last error at ', IFNULL(CAST(@dbt_repl_err_ts AS CHAR), 'unknown'), '). ',
         'Applier thread: ', IFNULL(@dbt_repl_sql_state, 'not reported'), '; ',
         'receiver thread: ', IFNULL(@dbt_repl_io_state,
            'not readable from SQL on this fork — check SHOW SLAVE STATUS / SHOW REPLICA STATUS'),
         '. This replica has not applied anything since; it is not a usable failover target.') AS details,
  JSON_OBJECT(
    'source', IFNULL(@dbt_repl_source, 'unknown'),
    'io_thread_state', IFNULL(@dbt_repl_io_state, 'unreadable'),
    'sql_thread_state', IFNULL(@dbt_repl_sql_state, 'unreadable'),
    'last_error_number', @dbt_repl_err_no,
    'last_error_message', SUBSTRING(IFNULL(@dbt_repl_err_msg, ''), 1, 500),
    'last_error_timestamp', CAST(@dbt_repl_err_ts AS CHAR),
    'channels', @dbt_repl_channels) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND IFNULL(@dbt_repl_err_no, 0) <> 0
  AND (IFNULL(@dbt_repl_sql_state, 'ON') <> 'ON' OR IFNULL(@dbt_repl_io_state, 'ON') <> 'ON');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-001' AS marker;
-- check: MY-SEC-001
-- title: Accounts with no password
-- priority: 1 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src (01_session.sql §6d)
-- PRIVACY: this check tests only whether the credential is empty. No hash value
-- is read, compared, echoed or stored, on either fork.
-- Excluded, because an empty credential is correct for them:
--   * external/socket authentication plugins (unix_socket, auth_socket, PAM,
--     LDAP, Kerberos, GSSAPI, AWS IAM) — the credential lives elsewhere;
--   * locked accounts;
--   * MariaDB roles (is_role), which never authenticate;
--   * MariaDB's literal 'invalid' credential marker, which means "this method is
--     deliberately unusable" and implies another auth_or method exists — the
--     default MariaDB root@localhost is exactly this and is not a finding.
-- What remains is an account anyone who can reach the port can log in as.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-001' AS check_id,
  'role'       AS scope,
  CONCAT(IF(a.acct_user = '', '(anonymous)', a.acct_user), '@', a.acct_host) AS object,
  CONCAT('Account ', IF(a.acct_user = '', '(anonymous)', CONCAT('''', a.acct_user, '''')),
         '@''', a.acct_host, ''' has an empty credential and authenticates with plugin ',
         a.acct_plugin, ', which is not an external or socket method. ',
         'Anyone who can reach ', @@GLOBAL.bind_address, ':', @@GLOBAL.port,
         ' from a host matching ''', a.acct_host, ''' can connect as it',
         IF(a.has_all_privs, ' WITH FULL PRIVILEGES', IF(a.priv_list <> '',
            CONCAT(' with ', a.priv_list), ' with no global privileges')),
         '. Account is not locked.') AS details,
  JSON_OBJECT(
    'user', a.acct_user,
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'has_credential', a.has_credential,
    'account_locked', a.account_locked,
    'has_all_privileges', a.has_all_privs,
    'global_privileges', a.priv_list,
    'bind_address', @@GLOBAL.bind_address) AS evidence_json,
  'high' AS confidence
FROM (ACCTSRC) AS a
WHERE a.has_credential = 0
  AND a.auth_marker <> 'invalid'
  AND a.account_locked = 0
  AND a.is_role = 0
  AND LOWER(a.acct_plugin) NOT IN ('unix_socket', 'auth_socket', 'auth_pam', 'auth_pam_v1',
        'pam', 'gssapi', 'auth_gssapi', 'authentication_kerberos', 'authentication_ldap_simple',
        'authentication_ldap_sasl', 'authentication_fido', 'authentication_webauthn',
        'auth_ed25519', 'ed25519', 'aws_authentication_plugin', 'mysql_no_login', 'auth_0x0100')
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-002' AS marker;
-- check: MY-SEC-002
-- title: Superuser-equivalent account reachable from any host
-- priority: 1 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- The classic root@'%'. Two conditions must both hold: the account holds SUPER
-- or the full global privilege set, AND its host pattern is a wildcard rather
-- than a specific address. Either alone is defensible; together they mean a
-- single leaked or guessed credential is complete control of the server, from
-- anywhere the network allows.
-- Host patterns treated as unrestricted: '%', '', '%.%', and wildcards that
-- cover whole public ranges. A bare IP or a fully qualified name is not flagged
-- here — MY-SEC-007 lists all privileged accounts for review regardless.
-- Platform-managed accounts (rdsadmin, cloudsqladmin, mysql.sys, mariadb.sys...)
-- are excluded; they are created by the vendor and cannot be removed.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-002' AS check_id,
  'role'       AS scope,
  CONCAT(a.acct_user, '@', a.acct_host) AS object,
  CONCAT('Account ''', a.acct_user, '''@''', a.acct_host,
         ''' holds ', IF(a.has_all_privs, 'the full global privilege set', 'SUPER'),
         ' (', a.priv_list, ') and its host pattern matches any host. ',
         'Authentication plugin: ', a.acct_plugin,
         ', credential set: ', IF(a.has_credential, 'yes', 'NO — see MY-SEC-001'),
         ', account locked: ', IF(a.account_locked, 'yes', 'no'), '. ',
         'The server listens on ', @@GLOBAL.bind_address, ':', @@GLOBAL.port,
         ', so one leaked credential is complete control of this instance from anywhere the network permits.') AS details,
  JSON_OBJECT(
    'user', a.acct_user,
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'has_all_privileges', a.has_all_privs,
    'global_privileges', a.priv_list,
    'has_credential', a.has_credential,
    'account_locked', a.account_locked,
    'bind_address', @@GLOBAL.bind_address,
    'port', @@GLOBAL.port) AS evidence_json,
  'high' AS confidence
FROM (ACCTSRC) AS a
WHERE a.is_role = 0
  AND a.account_locked = 0
  AND (a.Super_priv = 'Y' OR a.has_all_privs)
  AND (a.acct_host IN ('%', '') OR a.acct_host LIKE '%\\%%')
  AND a.acct_user NOT IN ACCTSYS
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-001' AS marker;
-- check: MY-CONN-001
-- title: Connections at or above 90 percent of max_connections
-- priority: 5 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: conn_critical_ratio=0.90
-- reads: @dbt_s_threads_connected (now), @dbt_s_max_used_connections (since restart),
--        @@GLOBAL.max_connections
-- Two readings with different meanings, both reported: Threads_connected is a
-- snapshot and can miss a spike entirely; Max_used_connections is the high-water
-- mark since restart and cannot tell you when it happened. Either crossing 90%
-- fires, because the consequence is the same — the next connection attempt is
-- refused with ER_CON_COUNT_ERROR and the application sees an outage, not a
-- slowdown. MySQL reserves exactly one extra slot for a SUPER account, which is
-- what lets a DBA still get in.
SELECT
  'MY-CONN-001' AS check_id,
  'cluster'     AS scope,
  'max_connections' AS object,
  CONCAT('Connections are at ', c.now_n, ' now and peaked at ', c.peak,
         ' since restart ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h ago, against max_connections = ', @@GLOBAL.max_connections,
         ' (', ROUND(100.0 * GREATEST(c.now_n, c.peak) / @@GLOBAL.max_connections, 0),
         '%, threshold ', ROUND(100 * COALESCE(@conn_critical_ratio, 0.90), 0), '%). ',
         'Connection_errors_max_connections = ',
         CAST(IFNULL(@dbt_s_connection_errors_max_connections, 0) AS UNSIGNED),
         IF(CAST(IFNULL(@dbt_s_connection_errors_max_connections, 0) AS UNSIGNED) > 0,
            ' — clients have already been refused (MY-CONN-003).', ' — no client refused yet.')) AS details,
  JSON_OBJECT(
    'threads_connected', c.now_n,
    'max_used_connections', c.peak,
    'max_connections', @@GLOBAL.max_connections,
    'ratio', ROUND(GREATEST(c.now_n, c.peak) / @@GLOBAL.max_connections, 4),
    'threshold_ratio', COALESCE(@conn_critical_ratio, 0.90),
    'connection_errors_max_connections', CAST(IFNULL(@dbt_s_connection_errors_max_connections, 0) AS UNSIGNED)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_threads_connected, 0) AS DECIMAL(20, 0))    AS now_n,
         CAST(IFNULL(@dbt_s_max_used_connections, 0) AS DECIMAL(20, 0)) AS peak
) AS c
WHERE GREATEST(c.now_n, c.peak) >= @@GLOBAL.max_connections * COALESCE(@conn_critical_ratio, 0.90);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-003' AS marker;
-- check: MY-DUR-003
-- title: Crash-unsafe replication source
-- priority: 5 | category: DUR | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.sync_binlog, @@GLOBAL.log_bin,
--        information_schema.PROCESSLIST (Binlog Dump threads, via @dbt_binlog_dump_threads)
-- Derived from MY-DUR-001 and MY-DUR-002. Neither alone justifies P5; together,
-- on a server that other servers replicate from, they do: after a crash the
-- source rolls back transactions it already shipped, so every replica is ahead
-- of its source and the topology can only be repaired by rebuilding replicas.
-- "Has replicas" is proved by a live Binlog Dump thread, which needs PROCESS.
-- Without PROCESS the count reads 0 here and the check stays silent rather than
-- guessing; MY-DUR-001/002 still fire on their own.
SELECT
  'MY-DUR-003' AS check_id,
  'cluster'    AS scope,
  NULL         AS object,
  CONCAT('This server has ', @dbt_binlog_dump_threads,
         ' replica(s) connected and both durability settings are relaxed: ',
         'innodb_flush_log_at_trx_commit = ', @@GLOBAL.innodb_flush_log_at_trx_commit,
         ', sync_binlog = ', @@GLOBAL.sync_binlog,
         '. After a crash this source can lose transactions its replicas have already applied, leaving every replica ahead of it.') AS details,
  JSON_OBJECT(
    'innodb_flush_log_at_trx_commit', @@GLOBAL.innodb_flush_log_at_trx_commit,
    'sync_binlog', @@GLOBAL.sync_binlog,
    'connected_replicas', @dbt_binlog_dump_threads,
    'semi_sync_status', IFNULL(@dbt_s_rpl_semi_sync_source_status,
                        IFNULL(@dbt_s_rpl_semi_sync_master_status, 'not-enabled'))) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND IFNULL(@dbt_binlog_dump_threads, 0) > 0
  AND @@GLOBAL.innodb_flush_log_at_trx_commit <> 1
  AND @@GLOBAL.sync_binlog <> 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-003' AS marker;
-- check: MY-REPL-003
-- title: Replica lag over 5 minutes
-- priority: 5 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: lag_critical_seconds=300;lag_warn_seconds=30
-- reads: @dbt_repl_lag_s / @dbt_repl_lag_src (01_session.sql §6c)
-- Lag source, in the design's preference order: the applier's
-- APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP when a transaction is in
-- flight, otherwise LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP. Those
-- columns exist only in MySQL 8.0+; MariaDB has no SQL-readable lag at all, so
-- on MariaDB @dbt_repl_lag_s is NULL and this check emits nothing rather than a
-- false all-clear. Seconds_Behind_Source is deliberately not used even where it
-- exists: it reads 0 while the receiver thread is far behind, and NULL when
-- replication is stopped.
-- Confidence is medium, never high: on an idle source the last-applied
-- timestamp measures how long the source has been quiet, not how far behind
-- this replica is. The details say which of the two readings was used.
SELECT
  'MY-REPL-003' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replica is ', FORMAT(@dbt_repl_lag_s, 0), ' s (',
         ROUND(@dbt_repl_lag_s / 60, 1), ' min) behind ',
         IFNULL(@dbt_repl_source, 'its source'),
         ', past the ', COALESCE(@lag_critical_seconds, 300), ' s threshold. ',
         'Measured from: ', @dbt_repl_lag_src, '. ',
         'Parallel appliers: ', IFNULL(COALESCE(@dbt_v_replica_parallel_workers,
                                                @dbt_v_slave_parallel_workers), 'unknown'),
         '. A failover now would lose or replay this much work.') AS details,
  JSON_OBJECT(
    'lag_seconds', @dbt_repl_lag_s,
    'threshold_seconds', COALESCE(@lag_critical_seconds, 300),
    'lag_source', @dbt_repl_lag_src,
    'source', IFNULL(@dbt_repl_source, 'unknown'),
    'parallel_workers', COALESCE(@dbt_v_replica_parallel_workers, @dbt_v_slave_parallel_workers)) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND @dbt_repl_lag_s IS NOT NULL
  AND @dbt_repl_lag_s >= COALESCE(@lag_critical_seconds, 300);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-010' AS marker;
-- check: MY-REPL-010
-- title: Group Replication member not ONLINE
-- priority: 5 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql | min_version: 5.7.17 | requires: SELECT ON performance_schema.*
-- thresholds: min_members=3
-- reads: performance_schema.replication_group_members
-- MySQL only. MariaDB has no Group Replication and no such table (verified
-- absent on 10.11) — Galera is its cluster technology and exposes
-- wsrep_* status variables instead, which is a different check not in this
-- catalog. The table-existence gate keeps MariaDB from erroring.
-- A member in RECOVERING, UNREACHABLE or ERROR state is not carrying traffic and
-- is not counted toward quorum; a group that drops below a majority stops
-- accepting writes entirely.
SET @dbt_q := "
SELECT
  'MY-REPL-010' AS check_id,
  'cluster'     AS scope,
  'group-replication' AS object,
  CONCAT('Group Replication group ', IFNULL(g.grp, 'unknown'), ' has ', g.total,
         ' member(s), ', g.online, ' ONLINE. ',
         IF(g.bad > 0, CONCAT('Not ONLINE: ', g.bad_list, '. '), ''),
         IF(g.total < COALESCE(@min_members, 3),
            CONCAT('A group of ', g.total, ' cannot tolerate a single failure and keep a majority; ',
                   COALESCE(@min_members, 3), ' is the minimum for fault tolerance. '), ''),
         'Members not ONLINE neither serve reads nor count toward quorum.') AS details,
  JSON_OBJECT(
    'group_name', g.grp,
    'member_count', g.total,
    'online_count', g.online,
    'not_online', g.bad_list,
    'min_members', COALESCE(@min_members, 3)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT MAX(CHANNEL_NAME) AS grp,
         COUNT(*) AS total,
         SUM(MEMBER_STATE = 'ONLINE') AS online,
         SUM(MEMBER_STATE <> 'ONLINE') AS bad,
         SUBSTRING(GROUP_CONCAT(IF(MEMBER_STATE <> 'ONLINE',
           CONCAT(MEMBER_HOST, ':', MEMBER_PORT, ' = ', MEMBER_STATE), NULL)
           SEPARATOR ', '), 1, 400) AS bad_list
    FROM performance_schema.replication_group_members
) AS g
WHERE g.total > 0
  AND (g.bad > 0 OR g.total < COALESCE(@min_members, 3))";
SET @dbt_q := IF(IFNULL(@dbt_has_group_members, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-005' AS marker;
-- check: MY-SCHEMA-005
-- title: AUTO_INCREMENT at or above 90 percent exhausted
-- priority: 5 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: autoinc_critical_ratio=0.90;autoinc_warn_ratio=0.70
-- reads: sys.schema_auto_increment_columns, with an information_schema fallback
-- Verified present with identical columns on MySQL 5.7+/8.x and MariaDB 10.6+
-- (sys.schema_auto_increment_columns: max_value, auto_increment,
-- auto_increment_ratio). The fallback computes the same figures from
-- information_schema.COLUMNS + TABLES for servers with no sys schema.
-- The failure mode is the reason this is P5 and not P50: when the counter
-- reaches the column type's maximum, MySQL does NOT wrap and does NOT raise an
-- overflow error. It hands out the maximum value again, so the insert fails with
-- ER_DUP_ENTRY — a duplicate-key error on a surrogate key, which reads like an
-- application bug and is routinely misdiagnosed for hours.
-- The fix (ALTER to a wider type) rewrites the whole table, so a 90%-full
-- 500 GB table needs a maintenance window planned now, not when it fills.
SET @dbt_q_sys := "
SELECT
  'MY-SCHEMA-005' AS check_id,
  'relation'      AS scope,
  CONCAT(a.table_schema, '.', a.table_name, '.', a.column_name) AS object,
  CONCAT('`', a.table_schema, '`.`', a.table_name, '`.', a.column_name, ' (',
         a.column_type, ') is at ', FORMAT(a.auto_increment, 0), ' of a maximum ',
         FORMAT(a.max_value, 0), ' — ', ROUND(100 * a.auto_increment_ratio, 1),
         '% used (threshold ', ROUND(100 * COALESCE(@autoinc_critical_ratio, 0.90), 0), '%). ',
         'At the maximum, MySQL reissues that same value rather than wrapping or overflowing, so inserts fail with a DUPLICATE KEY error on a surrogate key. ',
         'Table size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB, so widening the column rewrites that much data — plan the window now.') AS details,
  JSON_OBJECT(
    'schema', a.table_schema,
    'table', a.table_name,
    'column', a.column_name,
    'column_type', a.column_type,
    'auto_increment', a.auto_increment,
    'max_value', a.max_value,
    'ratio', ROUND(a.auto_increment_ratio, 4),
    'threshold_ratio', COALESCE(@autoinc_critical_ratio, 0.90),
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH) AS evidence_json,
  'high' AS confidence
FROM sys.schema_auto_increment_columns AS a
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = a.table_schema AND t.TABLE_NAME = a.table_name
WHERE a.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND a.auto_increment_ratio >= COALESCE(@autoinc_critical_ratio, 0.90)
ORDER BY a.auto_increment_ratio DESC
LIMIT 20";

SET @dbt_q_fb := "
SELECT
  'MY-SCHEMA-005' AS check_id,
  'relation'      AS scope,
  CONCAT(x.TABLE_SCHEMA, '.', x.TABLE_NAME, '.', x.COLUMN_NAME) AS object,
  CONCAT('`', x.TABLE_SCHEMA, '`.`', x.TABLE_NAME, '`.', x.COLUMN_NAME, ' (',
         x.COLUMN_TYPE, ') is at ', FORMAT(x.auto_increment, 0), ' of a maximum ',
         FORMAT(x.max_value, 0), ' — ', ROUND(100 * x.auto_increment / x.max_value, 1),
         '% used (threshold ', ROUND(100 * COALESCE(@autoinc_critical_ratio, 0.90), 0),
         '%). Computed from information_schema because this server has no sys schema. ',
         'At the maximum, inserts fail with a DUPLICATE KEY error rather than an overflow.') AS details,
  JSON_OBJECT(
    'schema', x.TABLE_SCHEMA, 'table', x.TABLE_NAME, 'column', x.COLUMN_NAME,
    'column_type', x.COLUMN_TYPE, 'auto_increment', x.auto_increment,
    'max_value', x.max_value, 'ratio', ROUND(x.auto_increment / x.max_value, 4),
    'threshold_ratio', COALESCE(@autoinc_critical_ratio, 0.90),
    'source', 'information_schema fallback') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE,
         IFNULL(t.AUTO_INCREMENT, 0) AS auto_increment,
         CASE
           WHEN c.DATA_TYPE = 'tinyint'   THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 255, 127)
           WHEN c.DATA_TYPE = 'smallint'  THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 65535, 32767)
           WHEN c.DATA_TYPE = 'mediumint' THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 16777215, 8388607)
           WHEN c.DATA_TYPE = 'int'       THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 4294967295, 2147483647)
           WHEN c.DATA_TYPE = 'bigint'    THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 18446744073709551615, 9223372036854775807)
           ELSE NULL
         END AS max_value
  FROM information_schema.COLUMNS AS c
  JOIN information_schema.TABLES AS t
    ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
  WHERE c.EXTRA LIKE '%auto_increment%'
    AND c.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS x
WHERE x.max_value IS NOT NULL
  AND x.auto_increment >= x.max_value * COALESCE(@autoinc_critical_ratio, 0.90)
ORDER BY x.auto_increment / x.max_value DESC
LIMIT 20";

SET @dbt_q := IF(IFNULL(@dbt_sys_autoinc, 0) = 1, @dbt_q_sys, @dbt_q_fb);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-003' AS marker;
-- check: MY-SEC-003
-- title: Anonymous accounts present
-- priority: 5 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- An account with an empty User matches ANY username at authentication time.
-- Two consequences people are routinely surprised by: anyone can connect without
-- supplying a valid username, and — because MySQL sorts the user table
-- most-specific-host-first — an anonymous ''@'localhost' entry is matched BEFORE
-- a real 'app'@'%' entry for a connection from localhost, so a legitimate user
-- silently authenticates as the anonymous one and loses their privileges.
-- MariaDB's mariadb-install-db still creates these on some packagings; MySQL
-- 5.7+ does not, and mysql_secure_installation removes them.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-003' AS check_id,
  'role'       AS scope,
  CONCAT('(anonymous)@', a.acct_host) AS object,
  CONCAT('An anonymous account exists for host ''', a.acct_host,
         ''' (empty User), credential set: ', IF(a.has_credential, 'yes', 'no'),
         ', plugin ', a.acct_plugin, '. ',
         'An empty username matches any supplied username. Because account matching sorts the most specific host first, a connection from ''',
         a.acct_host, ''' will match this row BEFORE a real account with a wildcard host — so a legitimate user can silently authenticate as the anonymous account and lose their privileges. ',
         'Global privileges here: ', IF(a.priv_list = '', 'none', a.priv_list), '.') AS details,
  JSON_OBJECT(
    'user', '',
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'has_credential', a.has_credential,
    'global_privileges', a.priv_list) AS evidence_json,
  'high' AS confidence
FROM (ACCTSRC) AS a
WHERE a.acct_user = ''
  AND a.is_role = 0
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-UNDO-001' AS marker;
-- check: MY-UNDO-001
-- title: InnoDB history list length very high
-- priority: 5 | category: UNDO | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: hll_critical=1000000
-- reads: information_schema.INNODB_METRICS trx_rseg_history_len (via @dbt_hll)
-- The history list is the queue of undo records the purge threads have not yet
-- reclaimed. It grows when purge cannot keep up — almost always because one old
-- read view (a long or forgotten transaction, MY-LOCK-003) pins it. Every
-- consistent read then walks a longer version chain, undo tablespaces grow and
-- never shrink without truncation, and the server slows toward a stall.
-- Column-name divergence between forks (STATUS vs ENABLED) is resolved once in
-- 01_session.sql. @dbt_metrics_enabled = 0 means the metric is off and COUNT is
-- a meaningless zero, so this check stays silent rather than reporting all-clear.
SELECT
  'MY-UNDO-001' AS check_id,
  'cluster'     AS scope,
  NULL          AS object,
  CONCAT('InnoDB history list length is ', FORMAT(@dbt_hll, 0),
         ' undo records (threshold ', FORMAT(COALESCE(@hll_critical, 1000000), 0),
         '). Purge is not keeping up. innodb_purge_threads = ', @@GLOBAL.innodb_purge_threads,
         ', innodb_undo_log_truncate = ', @@GLOBAL.innodb_undo_log_truncate,
         '. Oldest open transaction: ', IFNULL(t.oldest, 'none visible'),
         '. Check MY-LOCK-003/004 for the transaction pinning the read view.') AS details,
  JSON_OBJECT(
    'history_list_length', @dbt_hll,
    'threshold', COALESCE(@hll_critical, 1000000),
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads,
    'innodb_undo_log_truncate', CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR),
    'oldest_transaction_seconds', t.oldest_s) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    MAX(TIMESTAMPDIFF(SECOND, trx_started, NOW()))                       AS oldest_s,
    CONCAT(MAX(TIMESTAMPDIFF(SECOND, trx_started, NOW())), ' s old')     AS oldest
  FROM information_schema.INNODB_TRX
) AS t
WHERE IFNULL(@dbt_metrics_enabled, 0) = 1
  AND @dbt_hll >= COALESCE(@hll_critical, 1000000);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-001' AS marker;
-- check: MY-DUR-001
-- title: innodb_flush_log_at_trx_commit not 1
-- priority: 10 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none — the safe value is fixed by the engine, not by opinion)
-- reads: @@GLOBAL.innodb_flush_log_at_trx_commit, @@GLOBAL.innodb_flush_log_at_timeout
-- Universal: the variable exists in every MySQL 5.x-9.x and MariaDB 10.x-11.x.
-- Value 1 = flush+fsync the redo log at every commit (the only durable setting).
-- Value 2 = write to the OS page cache, fsync once per second: an OS crash or
-- power loss loses up to innodb_flush_log_at_timeout seconds of commits.
-- Value 0 = write AND fsync once per second: a mysqld crash alone loses them.
SELECT
  'MY-DUR-001' AS check_id,
  'setting'    AS scope,
  'innodb_flush_log_at_trx_commit' AS object,
  CONCAT('innodb_flush_log_at_trx_commit = ', v.val,
         CASE v.val
           WHEN 0 THEN ': redo is written and fsynced once per second, so a mysqld crash (not just an OS crash) loses every commit since the last flush'
           WHEN 2 THEN ': redo is written to the OS page cache at commit but fsynced once per second, so an OS crash or power loss loses committed transactions'
           ELSE ''
         END,
         '. Worst-case loss window is innodb_flush_log_at_timeout = ',
         @@GLOBAL.innodb_flush_log_at_timeout, ' s.',
         IF(@@GLOBAL.log_bin = 1 AND @@GLOBAL.sync_binlog <> 1,
            ' sync_binlog is also ', ''),
         IF(@@GLOBAL.log_bin = 1 AND @@GLOBAL.sync_binlog <> 1,
            CONCAT(@@GLOBAL.sync_binlog, ' (MY-DUR-002); see MY-DUR-003.'), '')) AS details,
  JSON_OBJECT(
    'innodb_flush_log_at_trx_commit', v.val,
    'innodb_flush_log_at_timeout_seconds', @@GLOBAL.innodb_flush_log_at_timeout,
    'sync_binlog', @@GLOBAL.sync_binlog,
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (SELECT @@GLOBAL.innodb_flush_log_at_trx_commit AS val) AS v
WHERE v.val <> 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-002' AS marker;
-- check: MY-DUR-002
-- title: sync_binlog not 1
-- priority: 10 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.sync_binlog, @@GLOBAL.log_bin
-- Only meaningful when binary logging is on. sync_binlog=1 fsyncs the binlog at
-- every commit group; anything else lets the binlog fall behind the redo log, so
-- after a crash the server has transactions its own binlog never recorded —
-- replicas and any PITR restore silently diverge from the source of truth.
-- sync_binlog=0 means "never fsync, leave it to the OS".
SELECT
  'MY-DUR-002' AS check_id,
  'setting'    AS scope,
  'sync_binlog' AS object,
  CONCAT('sync_binlog = ', @@GLOBAL.sync_binlog,
         ' with binary logging ON. ',
         IF(@@GLOBAL.sync_binlog = 0,
            'The binary log is fsynced only when the OS chooses to.',
            CONCAT('The binary log is fsynced once every ', @@GLOBAL.sync_binlog,
                   ' commit groups.')),
         ' After a crash the redo log can contain transactions the binary log does not, so replicas and point-in-time restores diverge from this server.') AS details,
  JSON_OBJECT(
    'sync_binlog', @@GLOBAL.sync_binlog,
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR),
    'binlog_format', @@GLOBAL.binlog_format,
    'innodb_flush_log_at_trx_commit', @@GLOBAL.innodb_flush_log_at_trx_commit,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1 AND @@GLOBAL.sync_binlog <> 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-001' AS marker;
-- check: MY-LOCK-001
-- title: Transaction waiting on a row lock for over 5 minutes
-- priority: 10 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: lock_wait_critical_seconds=300;lock_wait_warn_seconds=30
-- reads: information_schema.INNODB_TRX (trx_wait_started, trx_state), PROCESSLIST
-- Deliberately built on INNODB_TRX rather than on the lock-waits view, because
-- that view is where the forks diverge hardest: MySQL 8.0 replaced
-- information_schema.INNODB_LOCK_WAITS with performance_schema.data_lock_waits,
-- MariaDB kept INNODB_LOCK_WAITS (verified present on 10.11), and sys.innodb_lock_waits
-- exists on both but with different underlying columns.
-- INNODB_TRX.trx_wait_started exists identically on MySQL 5.6-9.x and every
-- MariaDB, so the waiting side is always visible. The blocking side is
-- identified where the fork allows; MY-LOCK-002 is the lower tier.
-- Five minutes of waiting means innodb_lock_wait_timeout (default 50 s) was
-- raised, so somebody has already decided to wait rather than fail.
SELECT
  'MY-LOCK-001' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ', operation state ', IFNULL(NULLIF(t.trx_operation_state, ''), 'none'),
         ') has been waiting for a row lock for ',
         TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()), ' s (threshold ',
         COALESCE(@lock_wait_critical_seconds, 300), ' s). ',
         'It started ', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
         ' s ago, holds ', t.trx_rows_locked, ' row lock(s) and has modified ',
         t.trx_rows_modified, ' row(s). innodb_lock_wait_timeout = ',
         @@GLOBAL.innodb_lock_wait_timeout, ' s. Statement: ',
         SUBSTRING(IFNULL(t.trx_query, '(not visible)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'wait_seconds', TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()),
    'transaction_age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'rows_locked', t.trx_rows_locked,
    'rows_modified', t.trx_rows_modified,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'innodb_lock_wait_timeout', @@GLOBAL.innodb_lock_wait_timeout,
    'threshold_seconds', COALESCE(@lock_wait_critical_seconds, 300),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
LEFT JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE t.trx_state = 'LOCK WAIT'
  AND t.trx_wait_started IS NOT NULL
  AND TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()) >= COALESCE(@lock_wait_critical_seconds, 300);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-004' AS marker;
-- check: MY-LOCK-004
-- title: Idle transaction holding locks for over an hour
-- priority: 10 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: idle_txn_critical_seconds=3600;idle_txn_warn_seconds=300
-- reads: information_schema.INNODB_TRX joined to PROCESSLIST (COMMAND='Sleep')
-- The MySQL analogue of PostgreSQL's idle-in-transaction backend, and worse in
-- one respect: MySQL has no idle_in_transaction_session_timeout equivalent
-- before MySQL 8.0's innodb_lock_wait_timeout-unrelated
-- `wait_timeout` (which does not apply mid-transaction), so nothing reclaims it.
-- MariaDB has idle_transaction_timeout / idle_write_transaction_timeout, which
-- is why the details name them when the fork supports them.
-- An idle transaction holding row locks is strictly worse than a busy one: it is
-- doing no work, blocking others, and pinning purge. The usual cause is an
-- application that opened a transaction, made a network call, and never came back.
SELECT
  'MY-LOCK-004' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ') is IDLE (COMMAND = Sleep for ', p.TIME, ' s) but still open after ',
         ROUND(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) / 3600, 2),
         ' h, holding ', t.trx_rows_locked, ' row lock(s) and ',
         t.trx_rows_modified, ' modified row(s) (threshold ',
         ROUND(COALESCE(@idle_txn_critical_seconds, 3600) / 3600, 1), ' h). ',
         'Nothing will clean this up: wait_timeout does not apply mid-transaction. ',
         IF(@dbt_is_mariadb,
            'MariaDB offers idle_transaction_timeout / idle_write_transaction_timeout as a guard.',
            'MySQL has no idle-in-transaction timeout; the application must close it.'),
         ' Last statement: ', SUBSTRING(IFNULL(p.INFO, '(none recorded)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'transaction_age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'idle_seconds', p.TIME,
    'rows_locked', t.trx_rows_locked,
    'rows_modified', t.trx_rows_modified,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'threshold_seconds', COALESCE(@idle_txn_critical_seconds, 3600)) AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE p.COMMAND = 'Sleep'
  AND t.trx_rows_locked > 0
  AND TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) >= COALESCE(@idle_txn_critical_seconds, 3600);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-005' AS marker;
-- check: MY-REL-005
-- title: Server restarted within the last 24 hours
-- priority: 10 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: recent_restart_seconds=86400
-- reads: @dbt_s_uptime
-- This is a META-shaped finding at P10 rather than P0 because it is a fact about
-- the SERVER, not about the run: something restarted this database recently and
-- that is worth knowing on its own. Its effect on the report is the larger point.
-- MySQL and MariaDB have no equivalent of PostgreSQL's per-view stats_reset
-- timestamp: every status counter, every performance_schema aggregate and every
-- InnoDB metric starts from zero at startup and there is no record of when a
-- previous window ended. So a short uptime does not merely reduce confidence in
-- the rate-based findings — it means the buffer pool is still cold, the digest
-- table is nearly empty, and index usage counters (MY-IDX-001/002) show almost
-- everything as unused. Acting on any of those now would be wrong.
-- Whether the restart was clean is a separate question: MY-CORR-002 reads the
-- error log for crash-recovery messages where the fork allows it.
SELECT
  'MY-REL-005' AS check_id,
  'cluster'    AS scope,
  'uptime'     AS object,
  CONCAT('The server has been up for ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h (started approximately ', DATE_FORMAT(NOW() - INTERVAL @dbt_uptime_s SECOND, '%Y-%m-%d %H:%i UTC'),
         '), under the ', ROUND(COALESCE(@recent_restart_seconds, 86400) / 3600, 0), ' h threshold. ',
         'Neither MySQL nor MariaDB records when the previous counter window ended, so every rate in this report covers only these ',
         ROUND(@dbt_uptime_s / 3600, 1), ' hours. Specifically: the buffer pool is still warming (MY-MEM-004 will overstate the miss rate), ',
         'the statement digest table is nearly empty (MY-QRY-004 to MY-QRY-011), ',
         'and per-index usage counters show almost every index as unused (MY-IDX-001/002) — do not drop anything on that basis. ',
         'Whether the restart was clean is a separate question; MY-CORR-002 reads the error log where the fork exposes it.') AS details,
  JSON_OBJECT(
    'uptime_seconds', @dbt_uptime_s,
    'started_approximately', DATE_FORMAT(NOW() - INTERVAL @dbt_uptime_s SECOND, '%Y-%m-%dT%H:%i:%sZ'),
    'threshold_seconds', COALESCE(@recent_restart_seconds, 86400),
    'counter_confidence', @dbt_counter_conf,
    'affected_checks', 'MY-MEM-004,MY-QRY-004..011,MY-IDX-001..005,MY-LOCK-007,MY-CONN-004,MY-CONN-008') AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @dbt_uptime_s > 0
  AND @dbt_uptime_s < COALESCE(@recent_restart_seconds, 86400);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-002' AS marker;
-- check: MY-REPL-002
-- title: Replication threads stopped without an error
-- priority: 10 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: @dbt_repl_io_state / @dbt_repl_sql_state / @dbt_repl_err_no
-- No error recorded means somebody ran STOP REPLICA (STOP SLAVE) and did not
-- start it again — a maintenance window that was never closed, or a script that
-- exited early. Separated from MY-REPL-001 because the fix is different: there
-- is nothing to diagnose, only something to restart, after confirming why.
-- MariaDB caveat as in MY-REPL-001: the receiver thread is invisible to SQL, so
-- a MariaDB replica whose applier is running but whose receiver is stopped will
-- NOT fire here. That gap is listed in reference/checks-mysql.md.
SELECT
  'MY-REPL-002' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replication from ', IFNULL(@dbt_repl_source, 'the configured source'),
         ' is not running and no error is recorded, so it was stopped deliberately. ',
         'Applier thread: ', IFNULL(@dbt_repl_sql_state, 'not reported'), '; ',
         'receiver thread: ', IFNULL(@dbt_repl_io_state,
            'not readable from SQL on this fork'),
         '. Relay logs and the source binary logs keep accumulating while it is stopped; if the source purges a log this replica still needs, it will need a rebuild.') AS details,
  JSON_OBJECT(
    'source', IFNULL(@dbt_repl_source, 'unknown'),
    'io_thread_state', IFNULL(@dbt_repl_io_state, 'unreadable'),
    'sql_thread_state', IFNULL(@dbt_repl_sql_state, 'unreadable'),
    'last_error_number', IFNULL(@dbt_repl_err_no, 0),
    'channels', @dbt_repl_channels) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND IFNULL(@dbt_repl_err_no, 0) = 0
  AND (IFNULL(@dbt_repl_sql_state, 'ON') <> 'ON' OR IFNULL(@dbt_repl_io_state, 'ON') <> 'ON');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-005' AS marker;
-- check: MY-REPL-005
-- title: Replica is writable
-- priority: 10 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.read_only, @dbt_v_super_read_only, @dbt_is_replica
-- Fork divergence: super_read_only exists in MySQL 5.7+ but NOT in MariaDB
-- (verified absent on 10.11). It is read from the bundle, so on MariaDB it is
-- NULL and only read_only is judged — with the details saying so, because on
-- MariaDB an account holding SUPER can still write to a read_only replica and
-- there is no second lock to close that hole.
-- A writable replica is one typo or one misrouted connection away from a split
-- brain that replication will not detect and cannot merge.
SELECT
  'MY-REPL-005' AS check_id,
  'replica'     AS scope,
  IF(@@GLOBAL.read_only = 0, 'read_only', 'super_read_only') AS object,
  CONCAT('This instance replicates from ', IFNULL(@dbt_repl_source, 'a source'),
         ' but accepts writes: read_only = ', IF(@@GLOBAL.read_only = 1, 'ON', 'OFF'),
         ', super_read_only = ',
         IFNULL(@dbt_v_super_read_only, 'not available on this fork'), '. ',
         IF(@@GLOBAL.read_only = 1,
            'read_only is ON but privileged accounts bypass it; only super_read_only stops them.',
            'Any account with write privileges can write here, and those writes will not exist on the source.'),
         IF(@dbt_is_mariadb,
            ' MariaDB has no super_read_only, so read_only plus tightly held SUPER/READ_ONLY ADMIN is the strongest available guard.',
            '')) AS details,
  JSON_OBJECT(
    'read_only', CAST(@@GLOBAL.read_only AS CHAR),
    'super_read_only', IFNULL(@dbt_v_super_read_only, 'n/a'),
    'fork', @dbt_fork,
    'source', IFNULL(@dbt_repl_source, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND (@@GLOBAL.read_only = 0
       OR LOWER(IFNULL(@dbt_v_super_read_only, 'on')) IN ('off', '0'));
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-BAK-003' AS marker;
-- check: MY-BAK-003
-- title: Binary log retention shorter than one day
-- priority: 20 | category: BAK | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: min_retention_seconds=86400
-- reads: @dbt_v_binlog_expire_logs_seconds, @dbt_v_expire_logs_days, @@GLOBAL.log_bin
-- Variable divergence, all four combinations occur in the field:
--   MySQL 5.7            expire_logs_days only (days, integer)
--   MySQL 8.0            binlog_expire_logs_seconds (default 2592000) AND the
--                        deprecated expire_logs_days; the seconds one wins
--   MySQL 8.4            expire_logs_days removed
--   MariaDB 10.6+        both exist; expire_logs_days accepts fractions
-- Both are read from the bundle so a fork that lacks one yields NULL instead of
-- an "Unknown system variable" error. Effective retention = the seconds setting
-- when it is non-zero, else days x 86400.
-- Retention shorter than the backup interval means PITR has holes: a restore of
-- last night's full backup has no binlogs to roll forward from.
SELECT
  'MY-BAK-003' AS check_id,
  'setting'    AS scope,
  IF(r.secs_set > 0, 'binlog_expire_logs_seconds', 'expire_logs_days') AS object,
  CONCAT('Binary logs are purged after ', ROUND(r.eff / 3600, 1), ' h (',
         IF(r.secs_set > 0,
            CONCAT('binlog_expire_logs_seconds = ', r.secs_set),
            CONCAT('expire_logs_days = ', r.days_set)),
         '), which is less than the ', ROUND(COALESCE(@min_retention_seconds, 86400) / 3600, 0),
         ' h minimum. A restore from a nightly full backup has no binary logs to roll forward, so point-in-time recovery has a gap for part of every day.') AS details,
  JSON_OBJECT(
    'effective_retention_seconds', r.eff,
    'binlog_expire_logs_seconds', r.secs_set,
    'expire_logs_days', r.days_set,
    'threshold_seconds', COALESCE(@min_retention_seconds, 86400)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)) AS secs_set,
    CAST(IFNULL(@dbt_v_expire_logs_days, 0) AS DECIMAL(20, 6))           AS days_set,
    IF(CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)) > 0,
       CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)),
       CAST(IFNULL(@dbt_v_expire_logs_days, 0) AS DECIMAL(20, 6)) * 86400) AS eff
) AS r
WHERE @@GLOBAL.log_bin = 1
  AND r.eff > 0
  AND r.eff < COALESCE(@min_retention_seconds, 86400);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-003' AS marker;
-- check: MY-CONN-003
-- title: Clients refused because max_connections was reached
-- priority: 20 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_s_connection_errors_max_connections
-- This counter is not a risk indicator, it is a record of an outage that already
-- happened: every increment is a client that got ER_CON_COUNT_ERROR instead of a
-- connection. It is not reset except by restart or FLUSH STATUS, so the details
-- state the window explicitly.
-- Available from MySQL 5.6.5 and MariaDB 10.0; where absent the bundle returns
-- NULL and the check is silent.
SELECT
  'MY-CONN-003' AS check_id,
  'cluster'     AS scope,
  'max_connections' AS object,
  CONCAT('Connection_errors_max_connections = ', FORMAT(e.n, 0),
         ': that many client connection attempts were refused because max_connections (',
         @@GLOBAL.max_connections, ') was already reached, at ', ROUND(e.per_day, 1),
         '/day over the ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days since restart. Each one was an error returned to an application, not a delay. ',
         'Peak connections since restart: ',
         CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED), '.') AS details,
  JSON_OBJECT(
    'connection_errors_max_connections', e.n,
    'per_day', ROUND(e.per_day, 2),
    'max_connections', @@GLOBAL.max_connections,
    'max_used_connections', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_connection_errors_max_connections, 0) AS DECIMAL(30, 0)) AS n,
         CAST(IFNULL(@dbt_s_connection_errors_max_connections, 0) AS DECIMAL(30, 0)) / @dbt_uptime_d AS per_day
) AS e
WHERE e.n > 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-003' AS marker;
-- check: MY-LOCK-003
-- title: Transaction open for over an hour
-- priority: 20 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: long_txn_seconds=3600
-- reads: information_schema.INNODB_TRX (trx_started), PROCESSLIST
-- INNODB_TRX exists with these column names on every supported MySQL and
-- MariaDB, so no version gate is needed.
-- A long transaction is the usual root cause of MY-UNDO-001/002: its read view
-- pins the history list, so purge cannot reclaim ANY undo newer than it, no
-- matter how much has since been committed and deleted. It also holds every lock
-- it has taken, and on MySQL it blocks the metadata-lock queue behind any DDL
-- (MY-LOCK-006). Transactions that merely sit idle are MY-LOCK-004/005.
SELECT
  'MY-LOCK-003' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ', state ', t.trx_state, ') has been open for ',
         ROUND(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) / 3600, 2), ' h (started ',
         t.trx_started, ', threshold ', ROUND(COALESCE(@long_txn_seconds, 3600) / 3600, 1),
         ' h). It holds ', t.trx_rows_locked, ' row lock(s), has modified ',
         t.trx_rows_modified, ' row(s), and its read view prevents purge from reclaiming any undo generated since it started — history list length is now ',
         FORMAT(IFNULL(@dbt_hll, 0), 0), '. Current statement: ',
         SUBSTRING(IFNULL(NULLIF(t.trx_query, ''), IFNULL(p.INFO, '(idle — see MY-LOCK-004)')), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'trx_started', CAST(t.trx_started AS CHAR),
    'trx_state', t.trx_state,
    'rows_locked', t.trx_rows_locked,
    'rows_modified', t.trx_rows_modified,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'command', IFNULL(p.COMMAND, 'unknown'),
    'history_list_length', IFNULL(@dbt_hll, 0),
    'threshold_seconds', COALESCE(@long_txn_seconds, 3600)) AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
LEFT JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) >= COALESCE(@long_txn_seconds, 3600);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-001' AS marker;
-- check: MY-MEM-001
-- title: InnoDB buffer pool at the shipped default
-- priority: 20 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: default_pool_bytes=134217728
-- reads: @@GLOBAL.innodb_buffer_pool_size, @dbt_v_innodb_dedicated_server
-- 128 MB is the shipped default on both forks and it is sized for a laptop.
-- Version divergence: MySQL 8.0 added innodb_dedicated_server, which sizes the
-- pool from detected RAM at startup; when that is ON the 128 MB reading means
-- the host really has under ~1 GB of RAM, so the check is suppressed and the
-- host-sizing question belongs to MY-MEM-002 instead. MariaDB has no such
-- variable (verified absent on 10.11), so the bundle returns NULL there and the
-- suppression never applies.
-- Managed platforms always size the pool from the instance class, so seeing this
-- almost always means an unreviewed self-managed install.
SELECT
  'MY-MEM-001' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_size' AS object,
  CONCAT('innodb_buffer_pool_size = ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1048576, 0),
         ' MB, the shipped default. InnoDB data and indexes total ',
         ROUND(s.bytes / 1073741824, 2), ' GB across ', s.tables,
         ' tables, so ', IF(s.bytes > 0, ROUND(100.0 * @@GLOBAL.innodb_buffer_pool_size / s.bytes, 1), 0),
         '% of the working set can be cached. ',
         'innodb_dedicated_server = ', IFNULL(@dbt_v_innodb_dedicated_server, 'not available on this fork'),
         '. Changing the pool size is dynamic on MySQL 5.7+ and MariaDB 10.2+, but it resizes in innodb_buffer_pool_chunk_size steps and briefly holds a global mutex.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_data_bytes', s.bytes,
    'table_count', s.tables,
    'innodb_dedicated_server', IFNULL(@dbt_v_innodb_dedicated_server, 'n/a'),
    'ram_bytes', IFNULL(@dbt_ram_bytes, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes, COUNT(*) AS tables
  FROM information_schema.TABLES
  WHERE ENGINE = 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE @@GLOBAL.innodb_buffer_pool_size <= COALESCE(@default_pool_bytes, 134217728)
  AND UPPER(IFNULL(@dbt_v_innodb_dedicated_server, 'OFF')) NOT IN ('ON', '1');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-001' AS marker;
-- check: MY-REL-001
-- title: Server version is past end of life
-- priority: 20 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: eol_as_of=2026-09-02
-- reads: @@GLOBAL.version, @dbt_fork, and the embedded release table below
-- SOURCE OF THE DATES. The design puts EOL dates in reference/versions.yml with
-- an `as_of` stamp. That file is generated elsewhere in the repo, so this check
-- embeds the same table as a UNION ALL of literals and stamps it with
-- @dbt_eol_as_of. The runner SHOULD overwrite @dbt_eol_as_of and the branch rows
-- from versions.yml when it has them; when it does not, XX-META-004 fires if the
-- embedded stamp is more than a year old and every REL finding drops to low
-- confidence, exactly as the design specifies.
-- Working values as of 2026-09-02, from dev.mysql.com and mariadb.org:
--   MySQL   5.7  EOL 2023-10-31   8.0 EOL 2026-04-30   8.4 LTS EOL 2032-04-30
--           9.x  innovation releases: supported only until the next one ships
--   MariaDB 10.4 EOL 2024-06-18   10.5 EOL 2025-06-24  10.6 EOL 2026-07-06
--           10.11 EOL 2028-02-16  11.4 EOL 2029-05-29  11.8 EOL 2030-06-04
-- Note that MySQL 8.0 reached EOL in April 2026, so most fleets trip this.
-- Past EOL means no security patches at all: a CVE published tomorrow has no fix
-- for this server, and the only remedy is the major upgrade that was already due.
SET @dbt_eol_as_of := IFNULL(@dbt_eol_as_of, '2026-09-02');
SET @dbt_q := "
SELECT
  'MY-REL-001' AS check_id,
  'cluster'    AS scope,
  CONCAT(v.fork, ' ', v.branch) AS object,
  CONCAT(v.fork, ' ', @@GLOBAL.version, ' is on the ', v.branch,
         ' branch, which reached end of life on ', v.eol, ' — ',
         DATEDIFF(CURDATE(), v.eol), ' days ago. ',
         'There are no further security patches for this branch: a vulnerability published tomorrow will have no fix for this server. ',
         'Next supported branch: ', v.successor, '. ',
         'Release data as of ', @dbt_eol_as_of,
         '; if that is more than a year old, treat this finding as low confidence and check the vendor page.') AS details,
  JSON_OBJECT(
    'fork', v.fork,
    'version', @@GLOBAL.version,
    'branch', v.branch,
    'eol_date', v.eol,
    'days_past_eol', DATEDIFF(CURDATE(), v.eol),
    'successor', v.successor,
    'release_data_as_of', @dbt_eol_as_of) AS evidence_json,
  IF(DATEDIFF(CURDATE(), @dbt_eol_as_of) > 365, 'low', 'high') AS confidence
FROM (BRANCHES) AS v
WHERE v.eol < CURDATE()";

-- The release table. Matched on fork + major.minor.
SET @dbt_branches := "
  SELECT b.* FROM (
              SELECT 'mysql'   AS fork, '5.7'   AS branch, '2023-10-31' AS eol, '8.4 LTS' AS successor
    UNION ALL SELECT 'mysql',   '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'mysql',   '8.4',   '2032-04-30', '9.x innovation / the next LTS'
    UNION ALL SELECT 'percona', '5.7',   '2023-10-31', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.4',   '2032-04-30', 'the next LTS'
    UNION ALL SELECT 'mariadb', '10.4',  '2024-06-18', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.5',  '2025-06-24', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.6',  '2026-07-06', '10.11 LTS or 11.4 LTS'
    UNION ALL SELECT 'mariadb', '10.11', '2028-02-16', '11.4 LTS'
    UNION ALL SELECT 'mariadb', '11.4',  '2029-05-29', '11.8 LTS'
    UNION ALL SELECT 'mariadb', '11.8',  '2030-06-04', 'the next LTS'
  ) AS b
  WHERE b.fork = @dbt_fork
    AND b.branch = CONCAT(@dbt_vmajor, '.', @dbt_vminor)";

SET @dbt_q := REPLACE(@dbt_q, 'BRANCHES', @dbt_branches);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-016' AS marker;
-- check: MY-REPL-016
-- title: GTID set has gaps
-- priority: 20 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql | min_version: 5.6 | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_gtid_executed, @dbt_v_gtid_purged
-- NOT in the design's §5.2 table; added because requirement lists GTID gaps
-- explicitly and nothing else in the catalog detects them.
-- MySQL's gtid_executed is a set of UUID:interval entries, e.g.
--   3E11FA47-...:1-5:8-12,8C4C4D0F-...:1-900
-- A UUID with MORE THAN ONE interval means transactions in between were never
-- executed here: skipped with sql_slave_skip_counter, injected empty with
-- gtid_next, or lost. Those numbers can never be filled in, so a replica built
-- from this server inherits the hole, and AUTO_POSITION will not re-fetch them.
-- Detection is textual and deliberately conservative: total colons across the
-- whole set versus the number of UUID entries (commas + 1). More colons than
-- UUIDs means at least one UUID carries a second interval. Confidence is medium
-- because it identifies that a gap exists, not which transactions are missing.
-- MariaDB is excluded: its GTID format is domain-server-sequence
-- (0-1-4711) with no interval notation, so a gap is not expressible in the
-- variable and this test would be meaningless there.
SELECT
  'MY-REPL-016' AS check_id,
  'cluster'     AS scope,
  'gtid_executed' AS object,
  CONCAT('gtid_executed contains ', g.colons, ' interval(s) across ', g.uuids,
         ' source UUID(s), so at least ', g.colons - g.uuids,
         ' gap(s) exist in the executed set: some transactions from those sources were never applied here. ',
         'Common causes are sql_slave_skip_counter, an empty transaction injected with gtid_next, or a restore from a backup taken mid-stream. ',
         'gtid_purged = ', SUBSTRING(IFNULL(@dbt_v_gtid_purged, '(empty)'), 1, 200),
         '. Set (truncated): ', SUBSTRING(REPLACE(@dbt_v_gtid_executed, '\n', ''), 1, 300)) AS details,
  JSON_OBJECT(
    'interval_count', g.colons,
    'uuid_count', g.uuids,
    'gap_count', g.colons - g.uuids,
    'gtid_executed', SUBSTRING(REPLACE(@dbt_v_gtid_executed, '\n', ''), 1, 1000),
    'gtid_purged', SUBSTRING(IFNULL(@dbt_v_gtid_purged, ''), 1, 500)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT
    LENGTH(x.g) - LENGTH(REPLACE(x.g, ':', ''))     AS colons,
    LENGTH(x.g) - LENGTH(REPLACE(x.g, ',', '')) + 1 AS uuids
  FROM (SELECT REPLACE(IFNULL(@dbt_v_gtid_executed, ''), '\n', '') AS g) AS x
) AS g
WHERE IFNULL(@dbt_v_gtid_executed, '') <> ''
  AND g.colons > g.uuids;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-001' AS marker;
-- check: MY-SCHEMA-001
-- title: InnoDB tables without a primary key on a replicated source
-- priority: 20 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_listed=20
-- reads: information_schema.TABLES, information_schema.STATISTICS (PRIMARY),
--        @@GLOBAL.binlog_format, @@GLOBAL.log_bin, @dbt_binlog_dump_threads
-- THE genuinely MySQL-specific hazard, and the reason it outranks its
-- no-replication sibling MY-SCHEMA-002 by 80 priority points:
-- under row-based replication a replica applying an UPDATE or DELETE looks the
-- row up by primary key. With no primary key and no unique NOT NULL index there
-- is nothing to look it up by, so the applier falls back to a FULL TABLE SCAN
-- PER ROW EVENT. A single 100,000-row DELETE on a million-row table becomes
-- 100,000 full scans, and the replica goes from seconds behind to hours behind
-- while the source shows nothing wrong at all.
-- Secondary costs, mentioned because they justify the fix on their own: InnoDB
-- adds a hidden 6-byte row id that all secondary indexes carry, rows have no
-- useful clustering order, and several online-DDL paths are unavailable.
-- Detection is via information_schema.STATISTICS rather than TABLE_CONSTRAINTS
-- because it also reveals whether a usable unique NOT NULL index exists, which
-- is what the replication applier actually looks for.
SELECT
  'MY-SCHEMA-001' AS check_id,
  'relation'      AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('InnoDB table `', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` has no PRIMARY KEY',
         IF(IFNULL(k.unique_notnull, 0) > 0,
            CONCAT(' but does have ', k.unique_notnull,
                   ' unique NOT NULL index(es), which the row-based applier can use as a substitute'),
            ' and no unique NOT NULL index the row-based applier could use instead'),
         '. Size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1048576, 1), ' MB, ~',
         FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows, ', IFNULL(k.idx_count, 0), ' index(es). ',
         'binlog_format = ', @@GLOBAL.binlog_format, ', connected replicas: ',
         IFNULL(@dbt_binlog_dump_threads, 0),
         IF(IFNULL(k.unique_notnull, 0) > 0,
            '. Row lookups on the replica will use that unique index.',
            '. Every UPDATE and DELETE row event replayed on a replica scans this whole table once per row.')) AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA,
    'table', t.TABLE_NAME,
    'bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'index_count', IFNULL(k.idx_count, 0),
    'unique_notnull_indexes', IFNULL(k.unique_notnull, 0),
    'binlog_format', @@GLOBAL.binlog_format,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'high' AS confidence
FROM information_schema.TABLES AS t
-- LEFT JOIN, not JOIN: a table with no indexes at all has NO rows in
-- information_schema.STATISTICS, and an inner join would silently drop exactly
-- the worst case — a table with neither a primary key nor any index.
LEFT JOIN (
  SELECT s.TABLE_SCHEMA, s.TABLE_NAME,
         COUNT(DISTINCT s.INDEX_NAME) AS idx_count,
         COUNT(DISTINCT IF(s.NON_UNIQUE = 0 AND s.NULLABLE = '', s.INDEX_NAME, NULL)) AS unique_notnull,
         MAX(s.INDEX_NAME = 'PRIMARY') AS has_pk
  FROM information_schema.STATISTICS AS s
  WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY s.TABLE_SCHEMA, s.TABLE_NAME
) AS k ON k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.ENGINE = 'InnoDB'
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND IFNULL(k.has_pk, 0) = 0
  AND @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_format) IN ('ROW', 'MIXED')
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-BAK-004' AS marker;
-- check: MY-BAK-004
-- title: Binary logs never expire
-- priority: 50 | category: BAK | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- platform_skip: rds;aurora;cloudsql;azure
-- thresholds: (none)
-- reads: @dbt_v_binlog_expire_logs_seconds, @dbt_v_expire_logs_days, @@GLOBAL.log_bin
-- Both retention variables zero means PURGE BINARY LOGS is the only thing that
-- ever removes a binlog file. That is a disk-full outage with a long fuse, and
-- the fuse burns faster the busier the server gets. Pairs with MY-CAP-006
-- (binlog volume) and MY-CAP-001/002 (filesystem headroom).
-- MariaDB 10.6+ and MySQL 5.7 both default expire_logs_days to 0; MySQL 8.0
-- defaults binlog_expire_logs_seconds to 2592000 (30 days), so a zero there was
-- set on purpose.
SELECT
  'MY-BAK-004' AS check_id,
  'setting'    AS scope,
  'binlog-retention' AS object,
  CONCAT('Binary logging is ON and no retention is configured: ',
         'binlog_expire_logs_seconds = ', IFNULL(@dbt_v_binlog_expire_logs_seconds, 'n/a'),
         ', expire_logs_days = ', IFNULL(@dbt_v_expire_logs_days, 'n/a'),
         '. Binary logs accumulate until the filesystem fills or someone runs PURGE BINARY LOGS by hand. ',
         'log_bin_basename = ', IFNULL(@dbt_v_log_bin_basename, 'unknown'), '.') AS details,
  JSON_OBJECT(
    'binlog_expire_logs_seconds', IFNULL(@dbt_v_binlog_expire_logs_seconds, 'n/a'),
    'expire_logs_days', IFNULL(@dbt_v_expire_logs_days, 'n/a'),
    'log_bin_basename', IFNULL(@dbt_v_log_bin_basename, 'unknown'),
    'platform', @dbt_platform) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)) = 0
  AND CAST(IFNULL(@dbt_v_expire_logs_days, 0) AS DECIMAL(20, 6)) = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CAP-007' AS marker;
-- check: MY-CAP-007
-- title: General query log enabled
-- priority: 50 | category: CAP | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.general_log, @@GLOBAL.log_output, @dbt_s_questions
-- The general log records EVERY statement, including every SELECT, with no
-- threshold and no sampling. Three consequences worth stating with numbers:
-- it costs roughly ten to twenty percent of throughput; at the current statement
-- rate it produces an estimable volume per day; and when log_output=TABLE it
-- writes into mysql.general_log, which is a CSV-engine table that grows inside
-- the data directory and cannot be rotated by logrotate.
-- It is almost never intentional in production — it is normally switched on to
-- debug something and never switched off. It is dynamic on both forks, so
-- turning it off needs no restart.
-- Note it is also NOT an audit log: it records statements but not their results
-- or their success, and any account can be granted enough to read it. MY-SEC-015
-- covers actual audit facilities.
SELECT
  'MY-CAP-007' AS check_id,
  'setting'    AS scope,
  'general_log' AS object,
  CONCAT('general_log = ON with log_output = ', @@GLOBAL.log_output,
         '. Every statement is being recorded, with no threshold and no sampling. ',
         'At the observed rate of ',
         ROUND(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1), 0),
         ' statements/s that is roughly ',
         FORMAT(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) * 86400, 0),
         ' log entries per day, and it costs on the order of 10-20% of throughput. ',
         IF(@@GLOBAL.log_output LIKE '%TABLE%',
            'Because log_output includes TABLE, it is written into mysql.general_log — a CSV-engine table inside the data directory that logrotate cannot touch. ',
            CONCAT('It is written to ', @@GLOBAL.general_log_file, '. ')),
         'This is normally switched on to debug something and never switched off; it is dynamic, so switching it off needs no restart. ',
         'It is not an audit log either: it records statements but not their outcome (see MY-SEC-015).') AS details,
  JSON_OBJECT(
    'general_log', 'ON',
    'log_output', @@GLOBAL.log_output,
    'general_log_file', @@GLOBAL.general_log_file,
    'questions_per_second', ROUND(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1), 2),
    'estimated_entries_per_day', ROUND(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) * 86400)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.general_log = 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-002' AS marker;
-- check: MY-CONN-002
-- title: Connections at or above 70 percent of max_connections
-- priority: 50 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: conn_warn_ratio=0.70;conn_critical_ratio=0.90
-- reads: as MY-CONN-001
-- Magnitude tier below MY-CONN-001, separate ID so the tiers suppress
-- independently. 70% is the point at which a normal daily peak plus one
-- application restart storm reaches the ceiling.
SELECT
  'MY-CONN-002' AS check_id,
  'cluster'     AS scope,
  'max_connections' AS object,
  CONCAT('Connections are at ', c.now_n, ' now, peak ', c.peak,
         ' since restart, against max_connections = ', @@GLOBAL.max_connections,
         ' (', ROUND(100.0 * GREATEST(c.now_n, c.peak) / @@GLOBAL.max_connections, 0),
         '%, threshold ', ROUND(100 * COALESCE(@conn_warn_ratio, 0.70), 0),
         '%; the P5 tier MY-CONN-001 starts at ',
         ROUND(100 * COALESCE(@conn_critical_ratio, 0.90), 0), '%). ',
         'Headroom is ', @@GLOBAL.max_connections - GREATEST(c.now_n, c.peak),
         ' connections — roughly one application restart.') AS details,
  JSON_OBJECT(
    'threads_connected', c.now_n,
    'max_used_connections', c.peak,
    'max_connections', @@GLOBAL.max_connections,
    'ratio', ROUND(GREATEST(c.now_n, c.peak) / @@GLOBAL.max_connections, 4),
    'threshold_ratio', COALESCE(@conn_warn_ratio, 0.70)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_threads_connected, 0) AS DECIMAL(20, 0))    AS now_n,
         CAST(IFNULL(@dbt_s_max_used_connections, 0) AS DECIMAL(20, 0)) AS peak
) AS c
WHERE GREATEST(c.now_n, c.peak) >= @@GLOBAL.max_connections * COALESCE(@conn_warn_ratio, 0.70)
  AND GREATEST(c.now_n, c.peak) <  @@GLOBAL.max_connections * COALESCE(@conn_critical_ratio, 0.90);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-006' AS marker;
-- check: MY-CONN-006
-- title: max_connections very high with no thread pool and no evidence of a pooler
-- priority: 50 | category: CONN | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: high_max_connections=1000;pooler_host_concentration=0.80;pooler_max_hosts=3
-- reads: @@GLOBAL.max_connections, @dbt_v_thread_handling,
--        information_schema.PLUGINS (thread_pool), information_schema.PROCESSLIST
-- Fork divergence: MariaDB and Percona Server implement the thread pool in the
-- server and expose thread_handling = 'pool-of-threads'; MySQL Community has no
-- thread pool at all (it is an Enterprise plugin, visible in
-- information_schema.PLUGINS as thread_pool). Both are checked, and
-- thread_handling comes from the bundle because stock MySQL lacks the variable.
-- The heuristic: a genuine pooler (ProxySQL, RDS Proxy, HAProxy, pgbouncer's
-- MySQL equivalents) concentrates connections into a handful of source hosts.
-- Many source hosts plus a four-figure max_connections means every application
-- process connects directly, and MySQL's one-thread-per-connection model turns
-- a connection storm into a scheduling collapse. Confidence is medium: an
-- application fleet on a small number of hosts looks identical to a pooler.
SELECT
  'MY-CONN-006' AS check_id,
  'setting'     AS scope,
  'max_connections' AS object,
  CONCAT('max_connections = ', @@GLOBAL.max_connections,
         ' with no thread pool (thread_handling = ',
         IFNULL(@dbt_v_thread_handling, 'not available; MySQL Community has no in-server thread pool'),
         ', thread_pool plugin ', IF(p.thread_pool_active > 0, 'ACTIVE', 'not installed'),
         ') and no evidence of a connection pooler: ', h.hosts,
         ' distinct client host(s) hold ', h.conns, ' connections, the busiest ',
         COALESCE(@pooler_max_hosts, 3), ' accounting for ',
         ROUND(100.0 * h.top_conns / GREATEST(h.conns, 1), 0),
         '% (a pooler would concentrate above ',
         ROUND(100 * COALESCE(@pooler_host_concentration, 0.80), 0), '%). ',
         'MySQL runs one thread per connection, so a connection storm becomes a scheduling problem long before it becomes a memory problem — see MY-MEM-007 for the memory ceiling this implies.') AS details,
  JSON_OBJECT(
    'max_connections', @@GLOBAL.max_connections,
    'thread_handling', IFNULL(@dbt_v_thread_handling, 'n/a'),
    'thread_pool_plugin_active', p.thread_pool_active,
    'distinct_client_hosts', h.hosts,
    'connections', h.conns,
    'top_host_share', ROUND(h.top_conns / GREATEST(h.conns, 1), 3),
    'threshold_max_connections', COALESCE(@high_max_connections, 1000),
    'threshold_concentration', COALESCE(@pooler_host_concentration, 0.80)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT
    COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS hosts,
    COUNT(*)                                      AS conns,
    (SELECT IFNULL(SUM(c), 0) FROM (
        SELECT COUNT(*) AS c
        FROM information_schema.PROCESSLIST
        WHERE HOST IS NOT NULL AND HOST <> ''
        GROUP BY SUBSTRING_INDEX(HOST, ':', 1)
        ORDER BY c DESC
        LIMIT 3) AS t)                            AS top_conns
  FROM information_schema.PROCESSLIST
  WHERE HOST IS NOT NULL AND HOST <> ''
) AS h,
(
  SELECT SUM(PLUGIN_NAME = 'thread_pool' AND PLUGIN_STATUS = 'ACTIVE') AS thread_pool_active
  FROM information_schema.PLUGINS
) AS p
WHERE @@GLOBAL.max_connections >= COALESCE(@high_max_connections, 1000)
  AND LOWER(IFNULL(@dbt_v_thread_handling, '')) NOT LIKE '%pool%'
  AND IFNULL(p.thread_pool_active, 0) = 0
  AND h.conns > 0
  AND h.top_conns / GREATEST(h.conns, 1) < COALESCE(@pooler_host_concentration, 0.80);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-009' AS marker;
-- check: MY-CONN-009
-- title: Server saturated at snapshot time
-- priority: 50 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: running_per_core=2;running_absolute=64
-- reads: @dbt_s_threads_running, @dbt_cpu_count
-- Threads_running is the number of threads not idle right now — the closest
-- MySQL gets to a run queue. Above roughly two per core, threads are waiting on
-- each other rather than on work, and latency rises much faster than throughput
-- falls. Core count is not readable from any MySQL variable; the runner supplies
-- it from .db-triage.yml baseline.cpus or nproc. Without it the check falls back
-- to an absolute figure of 64, which is deliberately conservative, and says so.
-- One sample can catch a one-off spike or miss a storm entirely; deep mode
-- re-samples, and the details label this as a snapshot either way.
SELECT
  'MY-CONN-009' AS check_id,
  'cluster'     AS scope,
  'threads_running' AS object,
  CONCAT('Threads_running = ', r.running, ' at snapshot time',
         IF(@dbt_cpu_count IS NULL,
            CONCAT(', against an absolute threshold of ', COALESCE(@running_absolute, 64),
                   ' because the host core count was not supplied (set baseline.cpus)'),
            CONCAT(' on ', @dbt_cpu_count, ' cores — ', ROUND(r.running / @dbt_cpu_count, 1),
                   ' per core, threshold ', COALESCE(@running_per_core, 2), ')')),
         '. Threads_connected = ', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
         ', Innodb_row_lock_current_waits = ',
         CAST(IFNULL(@dbt_s_innodb_row_lock_current_waits, 0) AS UNSIGNED),
         '. A single sample can catch a spike or miss one; MY-LOCK-001/002/006 say whether the threads are waiting on locks.') AS details,
  JSON_OBJECT(
    'threads_running', r.running,
    'threads_connected', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
    'cpu_count', IFNULL(@dbt_cpu_count, 'unknown'),
    'row_lock_current_waits', CAST(IFNULL(@dbt_s_innodb_row_lock_current_waits, 0) AS UNSIGNED),
    'threshold_per_core', COALESCE(@running_per_core, 2),
    'threshold_absolute', COALESCE(@running_absolute, 64),
    'measured', 'snapshot') AS evidence_json,
  IF(@dbt_cpu_count IS NULL, 'low', 'medium') AS confidence
FROM (SELECT CAST(IFNULL(@dbt_s_threads_running, 0) AS DECIMAL(20, 0)) AS running) AS r
WHERE (@dbt_cpu_count IS NOT NULL AND r.running >= @dbt_cpu_count * COALESCE(@running_per_core, 2))
   OR (@dbt_cpu_count IS NULL     AND r.running >= COALESCE(@running_absolute, 64));
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-006' AS marker;
-- check: MY-DUR-006
-- title: InnoDB page checksums disabled
-- priority: 50 | category: DUR | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_innodb_checksum_algorithm (bundle: present in MySQL 5.6+ and
--        MariaDB 10.x, but read through the bundle so a fork that drops it
--        yields NULL and this check stays silent instead of erroring)
-- 'none' means InnoDB writes a constant instead of a checksum and never verifies
-- it. Silent bit rot in the storage stack then reaches the buffer pool as if it
-- were good data. The PostgreSQL analogue is PG-CORR-004 (data checksums off).
SELECT
  'MY-DUR-006' AS check_id,
  'setting'    AS scope,
  'innodb_checksum_algorithm' AS object,
  CONCAT('innodb_checksum_algorithm = ', @dbt_v_innodb_checksum_algorithm,
         ': InnoDB neither writes nor verifies page checksums, so corruption arriving from the storage layer is read into the buffer pool undetected. ',
         'Data size at risk: ', s.gb, ' GB of InnoDB data and indexes.') AS details,
  JSON_OBJECT(
    'innodb_checksum_algorithm', @dbt_v_innodb_checksum_algorithm,
    'innodb_data_gb', s.gb,
    'innodb_doublewrite', CAST(@@GLOBAL.innodb_doublewrite AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT ROUND(IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) / 1073741824, 1) AS gb
  FROM information_schema.TABLES
  WHERE ENGINE = 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE LOWER(IFNULL(@dbt_v_innodb_checksum_algorithm, '')) = 'none';
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-007' AS marker;
-- check: MY-DUR-007
-- title: Non-transactional storage engines in use
-- priority: 50 | category: DUR | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_rows=20
-- reads: information_schema.TABLES
-- MyISAM and Aria(transactional=0) have no crash recovery for data, take
-- table-level locks for every write, and cannot participate in a transaction —
-- so a statement that fails halfway leaves the table half-updated and the binary
-- log records it as if it succeeded. MEMORY/CSV/ARCHIVE/BLACKHOLE are called out
-- separately because their non-durability is usually the point.
-- Emission shape (b) per DESIGN §2.1: one summary row per engine with a top-N
-- list, so a 4,000-table legacy schema does not produce 4,000 findings.
-- MariaDB note: mysql.* system tables are Aria and are excluded, as is the
-- MariaDB-specific `sys` schema copy.
SELECT
  'MY-DUR-007' AS check_id,
  'relation'   AS scope,
  t.ENGINE     AS object,
  CONCAT(t.n, ' user table(s) use the ', t.ENGINE, ' engine, totalling ',
         ROUND(t.bytes / 1048576, 1), ' MB across ', t.schema_ct, ' schema(s). ',
         CASE t.ENGINE
           WHEN 'MyISAM' THEN 'MyISAM has no crash recovery, no transactions and a table-level write lock; a crash leaves tables needing REPAIR TABLE and a failed multi-row statement is left half-applied yet fully binlogged.'
           WHEN 'Aria'   THEN 'Aria is crash-safe for its own metadata but non-transactional for row data unless TRANSACTIONAL=1; it still takes table-level write locks.'
           WHEN 'MEMORY' THEN 'MEMORY tables are emptied on restart and their contents are not replicated consistently.'
           WHEN 'ARCHIVE' THEN 'ARCHIVE supports no UPDATE/DELETE and no transactions.'
           WHEN 'CSV'    THEN 'CSV supports no indexes, no NULLs and no transactions.'
           WHEN 'BLACKHOLE' THEN 'BLACKHOLE discards every row written to it; verify this is a deliberate binlog relay.'
           ELSE 'This engine is not transactional and not crash-safe.'
         END,
         ' Largest: ', t.top_tables, '.') AS details,
  JSON_OBJECT(
    'engine', t.ENGINE,
    'table_count', t.n,
    'schema_count', t.schema_ct,
    'total_bytes', t.bytes,
    'largest_tables', t.top_tables) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    ENGINE,
    COUNT(*)                                   AS n,
    COUNT(DISTINCT TABLE_SCHEMA)               AS schema_ct,
    IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes,
    SUBSTRING(GROUP_CONCAT(
      CONCAT(TABLE_SCHEMA, '.', TABLE_NAME, ' (',
             ROUND((DATA_LENGTH + INDEX_LENGTH) / 1048576, 1), ' MB)')
      ORDER BY DATA_LENGTH + INDEX_LENGTH DESC SEPARATOR ', '), 1, 400) AS top_tables
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND ENGINE IS NOT NULL
    AND ENGINE NOT IN ('InnoDB', 'RocksDB', 'TokuDB', 'MyRocks', 'SEQUENCE')
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY ENGINE
) AS t;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-001' AS marker;
-- check: MY-IDX-001
-- title: Unused index of 1 GB or more
-- priority: 50 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*, SELECT ON mysql.*
-- thresholds: unused_index_bytes=1073741824;min_uptime_days=30
-- reads: sys.schema_unused_indexes, or performance_schema.table_io_waits_summary_by_index_usage
--        directly; mysql.innodb_index_stats (stat_name='size') x @@innodb_page_size for size
-- Availability, verified: sys.schema_unused_indexes exists on MySQL 5.7+ and
-- MariaDB 10.6+ with the same three columns (object_schema, object_name,
-- index_name). Where sys is absent the check reads
-- performance_schema.table_io_waits_summary_by_index_usage itself, which is what
-- the view is built on, so the result is identical.
-- Index SIZE is the harder half: information_schema has no per-index size at
-- all. mysql.innodb_index_stats carries a 'size' row per index measured in
-- PAGES, so bytes = size x innodb_page_size. That table is written by InnoDB's
-- persistent statistics and exists on both forks.
-- THE CAVEAT THAT MUST TRAVEL WITH THIS FINDING: index usage is counted PER
-- INSTANCE and only since the last restart. An index unused on this server may
-- be the one the reporting replica depends on. Never drop on this evidence
-- alone — check every replica, and check that uptime covers a full business
-- cycle including month-end. That is why min_uptime_days defaults to 30.
SET @dbt_q_sys := "
SELECT
  'MY-IDX-001' AS check_id,
  'index'      AS scope,
  CONCAT(u.object_schema, '.', u.object_name, '.', u.index_name) AS object,
  CONCAT('Index `', u.index_name, '` on `', u.object_schema, '`.`', u.object_name,
         '` has been read ZERO times since this server started ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago, and occupies ',
         ROUND(sz.bytes / 1073741824, 2), ' GB (', FORMAT(sz.pages, 0), ' pages x ',
         @@GLOBAL.innodb_page_size, ' bytes; threshold ',
         ROUND(COALESCE(@unused_index_bytes, 1073741824) / 1073741824, 1), ' GB). ',
         'It is still maintained on every INSERT, UPDATE and DELETE to the table. ',
         'VERIFY BEFORE DROPPING: this counter is per instance and resets on restart, so an index unused here may be the one a reporting replica relies on, and ',
         ROUND(@dbt_uptime_s / 86400, 1),
         ' days may not include month-end or quarter-end reporting.') AS details,
  JSON_OBJECT(
    'schema', u.object_schema, 'table', u.object_name, 'index', u.index_name,
    'index_bytes', sz.bytes, 'index_pages', sz.pages,
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'threshold_bytes', COALESCE(@unused_index_bytes, 1073741824),
    'uptime_days', ROUND(@dbt_uptime_s / 86400, 2),
    'scope_note', 'usage counted on this instance only, since last restart') AS evidence_json,
  IF(@dbt_uptime_s >= COALESCE(@min_uptime_days, 30) * 86400, 'medium', 'low') AS confidence
FROM sys.schema_unused_indexes AS u
JOIN (
  SELECT database_name, table_name, index_name,
         stat_value AS pages, stat_value * @@GLOBAL.innodb_page_size AS bytes
    FROM mysql.innodb_index_stats
   WHERE stat_name = 'size'
) AS sz
  ON sz.database_name = u.object_schema
 AND sz.table_name    = u.object_name
 AND sz.index_name    = u.index_name
WHERE u.object_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND u.index_name <> 'PRIMARY'
  AND sz.bytes >= COALESCE(@unused_index_bytes, 1073741824)
ORDER BY sz.bytes DESC
LIMIT 20";

SET @dbt_q_ps := REPLACE(@dbt_q_sys, 'sys.schema_unused_indexes AS u', "(
  SELECT OBJECT_SCHEMA AS object_schema, OBJECT_NAME AS object_name, INDEX_NAME AS index_name
    FROM performance_schema.table_io_waits_summary_by_index_usage
   WHERE INDEX_NAME IS NOT NULL
     AND INDEX_NAME <> 'PRIMARY'
     AND COUNT_STAR = 0
     AND OBJECT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS u");

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_innodb_index_stats, 0) = 0 OR IFNULL(@dbt_priv_mysql_schema, 0) = 0 THEN 'DO 1'
  WHEN IFNULL(@dbt_sys_unused_idx, 0) = 1  THEN @dbt_q_sys
  WHEN IFNULL(@dbt_has_index_usage, 0) = 1 THEN @dbt_q_ps
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-003' AS marker;
-- check: MY-IDX-003
-- title: Redundant or duplicate indexes
-- priority: 50 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: sys.schema_redundant_indexes, or an information_schema.STATISTICS
--        self-join where sys is absent
-- Availability, verified on MariaDB 10.11: sys.schema_redundant_indexes exists
-- on MySQL 5.7+ and MariaDB 10.6+ with identical columns, including the
-- ready-made sql_drop_index text. The fallback reproduces the leftmost-prefix
-- comparison directly from information_schema.STATISTICS by building each
-- index's ordered column list and testing prefix containment.
-- Unlike MY-IDX-001 this needs no usage statistics and carries no per-instance
-- caveat: an index that is a strict leftmost prefix of another is redundant as a
-- matter of B-tree structure, on every replica, forever. Any query the prefix
-- index can serve, the longer index can serve at the same cost.
-- The exception the check respects: a UNIQUE index is never redundant to a
-- non-unique one, because it also enforces a constraint.
SET @dbt_q_sys := "
SELECT
  'MY-IDX-003' AS check_id,
  'index'      AS scope,
  CONCAT(r.table_schema, '.', r.table_name, '.', r.redundant_index_name) AS object,
  CONCAT('Index `', r.redundant_index_name, '` (', r.redundant_index_columns,
         ') on `', r.table_schema, '`.`', r.table_name,
         '` is redundant: `', r.dominant_index_name, '` (', r.dominant_index_columns,
         ') already covers it. ',
         IF(r.subpart_exists = 1,
            'NOTE: one of these uses a column prefix (a partial index), so confirm the covering claim before dropping. ', ''),
         'This is structural, not statistical — it holds on every replica and does not depend on workload, so unlike MY-IDX-001 it needs no per-replica verification. ',
         'The redundant index still costs a write on every INSERT, UPDATE and DELETE to the table and consumes buffer pool space. ',
         'Drop statement generated by the sys schema: ', r.sql_drop_index) AS details,
  JSON_OBJECT(
    'schema', r.table_schema, 'table', r.table_name,
    'redundant_index', r.redundant_index_name, 'redundant_columns', r.redundant_index_columns,
    'dominant_index', r.dominant_index_name, 'dominant_columns', r.dominant_index_columns,
    'redundant_is_non_unique', r.redundant_index_non_unique,
    'dominant_is_non_unique', r.dominant_index_non_unique,
    'has_column_prefix', r.subpart_exists,
    'drop_statement', r.sql_drop_index) AS evidence_json,
  'high' AS confidence
FROM sys.schema_redundant_indexes AS r
WHERE r.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY r.table_schema, r.table_name
LIMIT 50";

SET @dbt_q_fb := "
SELECT
  'MY-IDX-003' AS check_id,
  'index'      AS scope,
  CONCAT(a.sch, '.', a.tbl, '.', a.idx) AS object,
  CONCAT('Index `', a.idx, '` (', a.cols, ') on `', a.sch, '`.`', a.tbl,
         '` is a leftmost prefix of `', b.idx, '` (', b.cols,
         '), so it is redundant. Computed from information_schema.STATISTICS because this server has no sys schema. ',
         'This is structural and holds on every replica. The redundant index still costs a write on every modification of the table. ',
         'Drop with: ALTER TABLE `', a.sch, '`.`', a.tbl, '` DROP INDEX `', a.idx, '`;') AS details,
  JSON_OBJECT(
    'schema', a.sch, 'table', a.tbl,
    'redundant_index', a.idx, 'redundant_columns', a.cols,
    'dominant_index', b.idx, 'dominant_columns', b.cols,
    'source', 'information_schema.STATISTICS fallback') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT TABLE_SCHEMA AS sch, TABLE_NAME AS tbl, INDEX_NAME AS idx,
         MIN(NON_UNIQUE) AS non_unique,
         GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS cols
    FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
   GROUP BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME
) AS a
JOIN (
  SELECT TABLE_SCHEMA AS sch, TABLE_NAME AS tbl, INDEX_NAME AS idx,
         MIN(NON_UNIQUE) AS non_unique,
         GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS cols
    FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
   GROUP BY TABLE_SCHEMA, TABLE_NAME, INDEX_NAME
) AS b
  ON b.sch = a.sch AND b.tbl = a.tbl AND b.idx <> a.idx
WHERE a.idx <> 'PRIMARY'
  AND a.non_unique = 1
  AND (b.cols = a.cols OR b.cols LIKE CONCAT(a.cols, ',%'))
  AND (b.cols <> a.cols OR a.idx > b.idx)
LIMIT 50";

SET @dbt_q := IF(IFNULL(@dbt_sys_redundant_idx, 0) = 1, @dbt_q_sys, @dbt_q_fb);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-004' AS marker;
-- check: MY-IDX-004
-- title: Large table with heavy full table scans
-- priority: 50 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: scan_table_bytes=1073741824;rows_full_scanned=10000000
-- reads: sys.schema_tables_with_full_table_scans (object_schema, object_name,
--        rows_full_scanned), information_schema.TABLES for size
-- Availability, verified: the view exists on MySQL 5.7+ and MariaDB 10.6+ with
-- the same columns. It is derived from
-- performance_schema.table_io_waits_summary_by_index_usage where INDEX_NAME IS
-- NULL — that is, reads that used no index at all.
-- Confidence is medium and the wording is careful, because a full scan is not
-- automatically wrong: on a small table it is the cheapest plan, and an
-- analytical query over a large table may legitimately scan it. What the numbers
-- here establish is volume — ten million rows read without an index on a table
-- over a gigabyte is a workload characteristic, not a one-off report.
-- The finding deliberately does NOT propose an index: db-triage points at the
-- table and at the statements (MY-QRY-006/008) and stops there, because
-- inventing an index definition from a scan count is how bad indexes get made.
SET @dbt_q := "
SELECT
  'MY-IDX-004' AS check_id,
  'relation'   AS scope,
  CONCAT(f.object_schema, '.', f.object_name) AS object,
  CONCAT('`', f.object_schema, '`.`', f.object_name, '` is ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2), ' GB and has had ',
         FORMAT(f.rows_full_scanned, 0),
         ' rows read WITHOUT USING AN INDEX since this server started ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago (thresholds: ',
         ROUND(COALESCE(@scan_table_bytes, 1073741824) / 1073741824, 1), ' GB and ',
         FORMAT(COALESCE(@rows_full_scanned, 10000000), 0), ' rows). ',
         'The table has ', ix.n, ' index(es) defined. ',
         'A full scan is not automatically wrong — it is the cheapest plan on a small table and legitimate for analytics — but this volume on a table this size is a workload characteristic, not a one-off report. ',
         'MY-QRY-006 and MY-QRY-008 name the statements responsible. db-triage does not propose an index definition; the statements have to be read first.') AS details,
  JSON_OBJECT(
    'schema', f.object_schema, 'table', f.object_name,
    'rows_full_scanned', f.rows_full_scanned,
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'index_count', ix.n,
    'threshold_bytes', COALESCE(@scan_table_bytes, 1073741824),
    'threshold_rows', COALESCE(@rows_full_scanned, 10000000),
    'window_seconds', @dbt_uptime_s,
    'scope_note', 'counted on this instance only, since last restart') AS evidence_json,
  'medium' AS confidence
FROM sys.schema_tables_with_full_table_scans AS f
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = f.object_schema AND t.TABLE_NAME = f.object_name
LEFT JOIN (
  SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(DISTINCT INDEX_NAME) AS n
    FROM information_schema.STATISTICS GROUP BY TABLE_SCHEMA, TABLE_NAME
) AS ix ON ix.TABLE_SCHEMA = f.object_schema AND ix.TABLE_NAME = f.object_name
WHERE f.object_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@scan_table_bytes, 1073741824)
  AND f.rows_full_scanned >= COALESCE(@rows_full_scanned, 10000000)
ORDER BY f.rows_full_scanned DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_sys_full_scans, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-002' AS marker;
-- check: MY-LOCK-002
-- title: Transaction waiting on a row lock for over 30 seconds
-- priority: 50 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: lock_wait_warn_seconds=30;lock_wait_critical_seconds=300
-- reads: information_schema.INNODB_TRX, PROCESSLIST
-- Magnitude tier below MY-LOCK-001, separate ID so the tiers suppress
-- independently. 30 s is below the 50 s innodb_lock_wait_timeout default, so a
-- transaction seen here on a default-configured server is within seconds of
-- being rolled back with ER_LOCK_WAIT_TIMEOUT.
SELECT
  'MY-LOCK-002' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ') has waited ', TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()),
         ' s for a row lock (threshold ', COALESCE(@lock_wait_warn_seconds, 30),
         ' s; the P10 tier MY-LOCK-001 starts at ',
         COALESCE(@lock_wait_critical_seconds, 300), ' s). innodb_lock_wait_timeout = ',
         @@GLOBAL.innodb_lock_wait_timeout, ' s, so it will be rolled back with ER_LOCK_WAIT_TIMEOUT in ',
         GREATEST(@@GLOBAL.innodb_lock_wait_timeout - TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()), 0),
         ' s. Statement: ', SUBSTRING(IFNULL(t.trx_query, '(not visible)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'wait_seconds', TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()),
    'rows_locked', t.trx_rows_locked,
    'user', IFNULL(p.USER, 'unknown'),
    'innodb_lock_wait_timeout', @@GLOBAL.innodb_lock_wait_timeout,
    'threshold_seconds', COALESCE(@lock_wait_warn_seconds, 30),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
LEFT JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE t.trx_state = 'LOCK WAIT'
  AND t.trx_wait_started IS NOT NULL
  AND TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()) >= COALESCE(@lock_wait_warn_seconds, 30)
  AND TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()) <  COALESCE(@lock_wait_critical_seconds, 300);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-005' AS marker;
-- check: MY-LOCK-005
-- title: Idle transaction holding locks for over 5 minutes
-- priority: 50 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: idle_txn_warn_seconds=300;idle_txn_critical_seconds=3600
-- reads: information_schema.INNODB_TRX joined to PROCESSLIST
-- Magnitude tier below MY-LOCK-004, separate ID for independent suppression.
SELECT
  'MY-LOCK-005' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ') is idle for ', p.TIME, ' s with the transaction open ',
         TIMESTAMPDIFF(SECOND, t.trx_started, NOW()), ' s and ',
         t.trx_rows_locked, ' row lock(s) held (threshold ',
         COALESCE(@idle_txn_warn_seconds, 300), ' s; the P10 tier MY-LOCK-004 starts at ',
         COALESCE(@idle_txn_critical_seconds, 3600), ' s). Last statement: ',
         SUBSTRING(IFNULL(p.INFO, '(none recorded)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'transaction_age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'idle_seconds', p.TIME,
    'rows_locked', t.trx_rows_locked,
    'user', IFNULL(p.USER, 'unknown'),
    'threshold_seconds', COALESCE(@idle_txn_warn_seconds, 300)) AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE p.COMMAND = 'Sleep'
  AND t.trx_rows_locked > 0
  AND TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) >= COALESCE(@idle_txn_warn_seconds, 300)
  AND TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) <  COALESCE(@idle_txn_critical_seconds, 3600);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-006' AS marker;
-- check: MY-LOCK-006
-- title: Sessions waiting for a metadata lock
-- priority: 50 | category: LOCK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: mdl_wait_seconds=30
-- reads: information_schema.PROCESSLIST (STATE = 'Waiting for table metadata lock')
-- MySQL-specific pile-up with no PostgreSQL analogue in this shape. The
-- mechanism: an ALTER TABLE needs an exclusive metadata lock; a long-running
-- transaction that merely SELECTed from the table holds a shared one and will
-- not release it until it commits. The ALTER queues — and because MDL requests
-- are served in order, EVERY subsequent query on that table queues behind the
-- ALTER, including plain SELECTs that would otherwise have run fine.
-- The result is a table that goes from healthy to completely unavailable in one
-- step, with no lock wait timeout firing (lock_wait_timeout defaults to 1 year
-- (31536000 s) on both forks).
-- The PROCESSLIST STATE string is identical on MySQL 5.6-9.x and MariaDB, which
-- is why this is portable without a version gate;
-- performance_schema.metadata_locks (MySQL 5.7+, present on MariaDB 10.11) gives
-- the blocking side and is used by the reference doc's confirmation query.
SELECT
  'MY-LOCK-006' AS check_id,
  'cluster'     AS scope,
  'metadata-locks' AS object,
  CONCAT(w.waiters, ' session(s) are waiting for a table metadata lock, the longest for ',
         w.max_wait, ' s (threshold ', COALESCE(@mdl_wait_seconds, 30), ' s). ',
         'Waiting on: ', w.tables, '. ',
         'MDL requests are granted in order, so every query on those tables now queues behind the DDL at the head of the line — including SELECTs. ',
         'lock_wait_timeout = ', @@GLOBAL.lock_wait_timeout,
         ' s, so this will not clear itself in any useful time. ',
         'The blocker is normally a long or idle transaction: see MY-LOCK-003/004.') AS details,
  JSON_OBJECT(
    'waiting_sessions', w.waiters,
    'max_wait_seconds', w.max_wait,
    'tables', w.tables,
    'lock_wait_timeout', @@GLOBAL.lock_wait_timeout,
    'threshold_seconds', COALESCE(@mdl_wait_seconds, 30),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS waiters,
         MAX(TIME) AS max_wait,
         SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(IFNULL(DB, '?'), ' / ',
           SUBSTRING(REGEXP_REPLACE(IFNULL(INFO, '(no statement)'), '[[:space:]]+', ' '), 1, 80))
           SEPARATOR '; '), 1, 500) AS tables
  FROM information_schema.PROCESSLIST
  WHERE STATE = 'Waiting for table metadata lock'
) AS w
WHERE w.waiters > 0
  AND w.max_wait >= COALESCE(@mdl_wait_seconds, 30);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-002' AS marker;
-- check: MY-MEM-002
-- title: Buffer pool far smaller than the InnoDB working set
-- priority: 50 | category: MEM | scope: setting | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: pool_to_data_ratio=0.25;pool_to_ram_ratio=0.50
-- reads: @@GLOBAL.innodb_buffer_pool_size, information_schema.TABLES, @dbt_ram_bytes
-- CAVEAT that belongs in the finding, not a footnote: on MySQL 8.0
-- information_schema.TABLES sizes are served from a cache refreshed at most
-- every information_schema_stats_expiry seconds (default 86400), so the data
-- size can be up to a day stale. db-triage never runs ANALYZE TABLE to refresh
-- it. MariaDB reads the sizes live from the storage engine, so there the figure
-- is current. The details name which behaviour applies.
-- Only fires when the pool is ALSO not simply capped by host memory: if RAM is
-- known and the pool already holds half of it, the constraint is the host, and
-- MY-MEM-003/007 are the relevant findings instead.
SELECT
  'MY-MEM-002' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_size' AS object,
  CONCAT('Buffer pool is ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB against ', ROUND(s.bytes / 1073741824, 2), ' GB of InnoDB data and indexes (',
         ROUND(100.0 * @@GLOBAL.innodb_buffer_pool_size / s.bytes, 1), '%, threshold ',
         ROUND(100 * COALESCE(@pool_to_data_ratio, 0.25), 0), '%). ',
         'Buffer pool read miss rate since restart: ',
         IF(CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS DECIMAL(30, 0)) > 0,
            CONCAT(ROUND(100.0 * CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS DECIMAL(30, 0))
                       / CAST(@dbt_s_innodb_buffer_pool_read_requests AS DECIMAL(30, 0)), 2), '%'),
            'not measurable'),
         '. Host RAM: ', IF(@dbt_ram_bytes IS NULL, 'not supplied (set baseline.ram_gb)',
                            CONCAT(ROUND(@dbt_ram_bytes / 1073741824, 1), ' GB')),
         '. Sizes are ', IF(@dbt_is_mariadb,
            'read live from the storage engine',
            CONCAT('served from the information_schema cache and may be up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20,0)) / 3600, 1),
                   ' h stale (information_schema_stats_expiry)')),
         '.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_data_bytes', s.bytes,
    'pool_to_data_ratio', ROUND(@@GLOBAL.innodb_buffer_pool_size / s.bytes, 4),
    'threshold_ratio', COALESCE(@pool_to_data_ratio, 0.25),
    'ram_bytes', IFNULL(@dbt_ram_bytes, 'unknown'),
    'buffer_pool_reads', CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS UNSIGNED),
    'buffer_pool_read_requests', CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS UNSIGNED),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  IF(@dbt_ram_bytes IS NULL, 'medium', 'high') AS confidence
FROM (
  SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes
  FROM information_schema.TABLES
  WHERE ENGINE = 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE s.bytes > 0
  AND @@GLOBAL.innodb_buffer_pool_size < s.bytes * COALESCE(@pool_to_data_ratio, 0.25)
  AND (@dbt_ram_bytes IS NULL
       OR @@GLOBAL.innodb_buffer_pool_size < @dbt_ram_bytes * COALESCE(@pool_to_ram_ratio, 0.50));
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-007' AS marker;
-- check: MY-MEM-007
-- title: Worst-case memory commitment exceeds host RAM
-- priority: 50 | category: MEM | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: commitment_ratio=1.0
-- reads: @@GLOBAL.innodb_buffer_pool_size, innodb_log_buffer_size, key_buffer_size,
--        max_connections, sort/join/read/read_rnd buffers, binlog_cache_size,
--        thread_stack, tmp_table_size, @dbt_ram_bytes
-- The arithmetic MySQL never does for you: a fixed global part plus a per-session
-- part multiplied by max_connections. It is a genuine WORST case — most sessions
-- never allocate their sort or join buffer, and MySQL 8.0's TempTable pool is
-- shared rather than per session — so it overstates typical usage on purpose.
-- Priority follows what is known: P50 when RAM was supplied and the number really
-- does exceed it, P100 when RAM is unknown and the figure is reported for the
-- operator to compare. The registry carries both rows via platform_priority; the
-- confidence field carries the same distinction.
SELECT
  'MY-MEM-007' AS check_id,
  'cluster'    AS scope,
  'memory-commitment' AS object,
  CONCAT('Worst-case memory commitment is ', ROUND(m.total / 1073741824, 1), ' GB: ',
         ROUND(m.fixed / 1073741824, 2), ' GB fixed (buffer pool ',
         ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB + log buffer + key buffer) plus ', @@GLOBAL.max_connections,
         ' connections x ', ROUND(m.per_conn / 1048576, 1), ' MB per session. ',
         IF(@dbt_ram_bytes IS NULL,
            'Host RAM was not supplied, so this cannot be compared to anything — set baseline.ram_gb in .db-triage.yml.',
            CONCAT('Host RAM is ', ROUND(@dbt_ram_bytes / 1073741824, 1), ' GB, so the worst case is ',
                   ROUND(100.0 * m.total / @dbt_ram_bytes, 0), '% of it.')),
         ' This is a ceiling, not a forecast: most sessions never allocate their sort or join buffer. Peak connections so far: ',
         FORMAT(CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED), 0), '.') AS details,
  JSON_OBJECT(
    'worst_case_bytes', m.total,
    'fixed_bytes', m.fixed,
    'per_connection_bytes', m.per_conn,
    'max_connections', @@GLOBAL.max_connections,
    'max_used_connections', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED),
    'ram_bytes', IFNULL(@dbt_ram_bytes, 'unknown'),
    'threshold_ratio', COALESCE(@commitment_ratio, 1.0)) AS evidence_json,
  IF(@dbt_ram_bytes IS NULL, 'low', 'medium') AS confidence
FROM (
  SELECT f.fixed, p.per_conn, f.fixed + p.per_conn * @@GLOBAL.max_connections AS total
  FROM (SELECT CAST(@@GLOBAL.innodb_buffer_pool_size AS DECIMAL(30, 0))
             + @@GLOBAL.innodb_log_buffer_size
             + @@GLOBAL.key_buffer_size AS fixed) AS f,
       (SELECT CAST(@@GLOBAL.sort_buffer_size AS DECIMAL(30, 0))
             + @@GLOBAL.join_buffer_size
             + @@GLOBAL.read_buffer_size
             + @@GLOBAL.read_rnd_buffer_size
             + @@GLOBAL.binlog_cache_size
             + @@GLOBAL.thread_stack
             + @@GLOBAL.tmp_table_size AS per_conn) AS p
) AS m
WHERE @dbt_ram_bytes IS NULL
   OR m.total >= @dbt_ram_bytes * COALESCE(@commitment_ratio, 1.0);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-009' AS marker;
-- check: MY-MEM-009
-- title: Query cache enabled
-- priority: 50 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mariadb | requires: (none)
-- thresholds: threads_running=8
-- reads: @dbt_v_query_cache_type, @dbt_v_query_cache_size, @dbt_s_threads_running
-- Version divergence: the query cache was deprecated in MySQL 5.7.20 and REMOVED
-- in MySQL 8.0, so both variables are absent there and the bundle returns NULL —
-- this check then emits nothing. It remains present and OFF-by-default in
-- MariaDB, which is the only fork where it can still be found switched on.
-- The mechanism is a single global mutex: every read consults it and every write
-- to any table invalidates every cached result for that table. On a server with
-- real concurrency it converts parallel work into a queue, and the effect grows
-- with core count. There is no PostgreSQL analogue.
SELECT
  'MY-MEM-009' AS check_id,
  'setting'    AS scope,
  'query_cache_type' AS object,
  CONCAT('query_cache_type = ', @dbt_v_query_cache_type, ' with query_cache_size = ',
         ROUND(CAST(@dbt_v_query_cache_size AS DECIMAL(30, 0)) / 1048576, 1), ' MB. ',
         'Every read takes the single global query cache mutex and every write invalidates all cached results for the tables it touches, so throughput falls as concurrency rises. ',
         'Threads_running at snapshot: ', IFNULL(@dbt_s_threads_running, 'unknown'),
         '. Removed entirely in MySQL 8.0; MariaDB keeps it OFF by default.') AS details,
  JSON_OBJECT(
    'query_cache_type', @dbt_v_query_cache_type,
    'query_cache_size', CAST(@dbt_v_query_cache_size AS UNSIGNED),
    'threads_running', CAST(IFNULL(@dbt_s_threads_running, 0) AS UNSIGNED),
    'fork', @dbt_fork) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @dbt_v_query_cache_type IS NOT NULL
  AND UPPER(@dbt_v_query_cache_type) NOT IN ('OFF', '0')
  AND CAST(IFNULL(@dbt_v_query_cache_size, 0) AS DECIMAL(30, 0)) > 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-004' AS marker;
-- check: MY-REPL-004
-- title: Replica lag over 30 seconds
-- priority: 50 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: lag_warn_seconds=30;lag_critical_seconds=300
-- reads: @dbt_repl_lag_s / @dbt_repl_lag_src
-- Magnitude tier below MY-REPL-003, own ID so the tiers suppress independently.
-- Same MariaDB limitation: no SQL-readable lag, so this never fires there.
SELECT
  'MY-REPL-004' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replica is ', FORMAT(@dbt_repl_lag_s, 0), ' s behind ',
         IFNULL(@dbt_repl_source, 'its source'),
         ' (threshold ', COALESCE(@lag_warn_seconds, 30), ' s; the P5 tier MY-REPL-003 starts at ',
         COALESCE(@lag_critical_seconds, 300), ' s). Measured from: ', @dbt_repl_lag_src,
         '. Read-your-writes traffic routed here will see stale rows.') AS details,
  JSON_OBJECT(
    'lag_seconds', @dbt_repl_lag_s,
    'threshold_seconds', COALESCE(@lag_warn_seconds, 30),
    'lag_source', @dbt_repl_lag_src,
    'source', IFNULL(@dbt_repl_source, 'unknown')) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND @dbt_repl_lag_s IS NOT NULL
  AND @dbt_repl_lag_s >= COALESCE(@lag_warn_seconds, 30)
  AND @dbt_repl_lag_s <  COALESCE(@lag_critical_seconds, 300);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-006' AS marker;
-- check: MY-REPL-006
-- title: GTID not in use in a replicated topology
-- priority: 50 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_gtid_mode (MySQL), @dbt_repl_using_gtid (both),
--        @dbt_v_gtid_strict_mode / @dbt_v_gtid_binlog_pos (MariaDB)
-- Fork divergence: MySQL has a server-wide @@gtid_mode. MariaDB has no such
-- variable at all — GTID is chosen per replication connection
-- (MASTER_USE_GTID = slave_pos | current_pos | no), which is why the
-- authoritative reading on MariaDB is USING_GTID from
-- performance_schema.replication_connection_configuration, captured in
-- 01_session.sql §6c.
-- Without GTID, re-pointing a replica at a new source means computing a binlog
-- file and offset by hand under time pressure, which is where failovers go
-- wrong. gtid_strict_mode/ASSIGN_GTIDS_TO_ANONYMOUS_TRANSACTIONS are the
-- follow-on hardening, not the headline.
SELECT
  'MY-REPL-006' AS check_id,
  'cluster'     AS scope,
  IF(@dbt_is_mariadb, 'replication_connection_configuration.USING_GTID', 'gtid_mode') AS object,
  CONCAT('Replication is configured but GTID is not in use: ',
         IF(@dbt_is_mariadb,
            CONCAT('USING_GTID = ', IFNULL(@dbt_repl_using_gtid, 'No'),
                   ', gtid_strict_mode = ', IFNULL(@dbt_v_gtid_strict_mode, 'unknown'),
                   ' (MariaDB has no server-wide gtid_mode; GTID is per connection)'),
            CONCAT('gtid_mode = ', IFNULL(@dbt_v_gtid_mode, 'OFF'),
                   ', enforce_gtid_consistency would also be required')),
         '. Failing over or re-pointing a replica means deriving a binary log file and offset by hand. ',
         'Role here: ', IF(IFNULL(@dbt_is_replica, 0) = 1, 'replica', 'source'),
         ', connected replicas: ', IFNULL(@dbt_binlog_dump_threads, 0), '.') AS details,
  JSON_OBJECT(
    'gtid_mode', IFNULL(@dbt_v_gtid_mode, 'n/a'),
    'using_gtid', IFNULL(@dbt_repl_using_gtid, 'n/a'),
    'gtid_strict_mode', IFNULL(@dbt_v_gtid_strict_mode, 'n/a'),
    'is_replica', IFNULL(@dbt_is_replica, 0),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'fork', @dbt_fork) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE (IFNULL(@dbt_is_replica, 0) = 1 OR IFNULL(@dbt_binlog_dump_threads, 0) > 0)
  AND IF(@dbt_is_mariadb,
         LOWER(IFNULL(@dbt_repl_using_gtid, 'no')) IN ('no', '0', ''),
         UPPER(IFNULL(@dbt_v_gtid_mode, 'OFF')) <> 'ON');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-007' AS marker;
-- check: MY-REPL-007
-- title: Statement-based binary logging
-- priority: 50 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.binlog_format, @@GLOBAL.log_bin
-- Universal variable. STATEMENT replicates the SQL text, so anything
-- non-deterministic (UUID(), NOW() in some contexts, LIMIT without ORDER BY,
-- UDFs, triggers with side effects, INSERT ... SELECT on a table with an
-- AUTO_INCREMENT and a unique key) produces different rows on the replica, and
-- nothing detects the divergence. Both forks default to ROW on current
-- releases; MariaDB historically defaulted to MIXED.
-- MIXED is not flagged here: it is only unsafe for statements the server itself
-- cannot classify, which is not observable from the catalog. That caveat is in
-- the reference doc rather than being asserted as a finding.
SELECT
  'MY-REPL-007' AS check_id,
  'setting'     AS scope,
  'binlog_format' AS object,
  CONCAT('binlog_format = STATEMENT with binary logging ON. ',
         'Non-deterministic statements replicate as text and produce different rows downstream, and nothing in the topology detects the divergence. ',
         'Connected replicas: ', IFNULL(@dbt_binlog_dump_threads, 0),
         '; binlog_row_image = ', @@GLOBAL.binlog_row_image,
         ' (relevant once you switch to ROW).') AS details,
  JSON_OBJECT(
    'binlog_format', @@GLOBAL.binlog_format,
    'binlog_row_image', @@GLOBAL.binlog_row_image,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_format) = 'STATEMENT';
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-008' AS marker;
-- check: MY-REPL-008
-- title: Replication errors are being skipped
-- priority: 50 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_replica_skip_errors / @dbt_v_slave_skip_errors,
--        @dbt_v_replica_exec_mode / @dbt_v_slave_exec_mode
-- Name divergence: MySQL 8.0.26+ renamed slave_skip_errors to
-- replica_skip_errors and slave_exec_mode to replica_exec_mode, keeping the old
-- names as deprecated aliases until 8.4 removed them. MariaDB keeps only the
-- slave_* spelling. Both spellings are read from the bundle and COALESCEd, so
-- the check works on 5.7, 8.0, 8.4, 9.x and every MariaDB.
-- Either setting makes replication continue past an error instead of stopping,
-- which converts a loud failure into silent, permanent divergence. IDEMPOTENT
-- exec mode turns duplicate-key and not-found row events into no-ops.
SELECT
  'MY-REPL-008' AS check_id,
  'setting'     AS scope,
  IF(LOWER(IFNULL(v.skip, '')) NOT IN ('', 'off'), 'replica_skip_errors', 'replica_exec_mode') AS object,
  CONCAT('Replication is configured to continue past errors: ',
         CONCAT_WS('; ',
           IF(LOWER(IFNULL(v.skip, '')) NOT IN ('', 'off'),
              CONCAT('skip_errors = ', v.skip), NULL),
           IF(UPPER(IFNULL(v.mode, 'STRICT')) = 'IDEMPOTENT',
              'exec_mode = IDEMPOTENT (duplicate-key and row-not-found events are silently ignored)', NULL)),
         '. Rows that fail to apply are dropped without stopping the applier, so this replica diverges from its source and nothing reports it. ',
         'A checksum tool (pt-table-checksum, mariadb-check) is the only way to find out what is already different.') AS details,
  JSON_OBJECT(
    'skip_errors', IFNULL(v.skip, 'n/a'),
    'exec_mode', IFNULL(v.mode, 'n/a'),
    'is_replica', IFNULL(@dbt_is_replica, 0)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COALESCE(@dbt_v_replica_skip_errors, @dbt_v_slave_skip_errors) AS skip,
         COALESCE(@dbt_v_replica_exec_mode, @dbt_v_slave_exec_mode)     AS mode
) AS v
WHERE LOWER(IFNULL(v.skip, '')) NOT IN ('', 'off')
   OR UPPER(IFNULL(v.mode, 'STRICT')) = 'IDEMPOTENT';
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-009' AS marker;
-- check: MY-REPL-009
-- title: Semi-synchronous replication has fallen back to asynchronous
-- priority: 50 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_rpl_semi_sync_source_enabled / @dbt_v_rpl_semi_sync_master_enabled,
--        @dbt_s_rpl_semi_sync_source_status / @dbt_s_rpl_semi_sync_master_status,
--        @dbt_s_rpl_semi_sync_*_no_tx
-- Name divergence: MySQL 8.0.26 renamed every rpl_semi_sync_master_* to
-- rpl_semi_sync_source_* (and 8.4 moved the plugin to a component with
-- rpl_semi_sync_source_* only); MariaDB keeps the master spelling. Both are read
-- and COALESCEd, and both are absent unless the plugin is installed, in which
-- case this check is silent.
-- The hazard is specific to semi-sync: when no replica acknowledges within
-- rpl_semi_sync_source_timeout the source does not block — it silently reverts
-- to asynchronous and keeps committing. The durability guarantee people believe
-- they bought is gone and nothing raises an alarm. This is the MySQL analogue of
-- PG-REPL-001, except Postgres hangs and MySQL lies.
SELECT
  'MY-REPL-009' AS check_id,
  'cluster'     AS scope,
  'semi-sync'   AS object,
  CONCAT('Semi-synchronous replication is enabled (',
         IF(@dbt_v_rpl_semi_sync_source_enabled IS NOT NULL,
            'rpl_semi_sync_source_enabled', 'rpl_semi_sync_master_enabled'),
         ' = ON) but its status variable reads OFF: the source has timed out waiting for a replica acknowledgement and reverted to asynchronous commits. ',
         FORMAT(CAST(COALESCE(@dbt_s_rpl_semi_sync_source_no_tx,
                              @dbt_s_rpl_semi_sync_master_no_tx, 0) AS UNSIGNED), 0),
         ' transaction(s) have committed without acknowledgement since restart (',
         ROUND(@dbt_uptime_s / 3600, 1), ' h ago). ',
         'Connected replicas: ', IFNULL(@dbt_binlog_dump_threads, 0), '.') AS details,
  JSON_OBJECT(
    'semi_sync_enabled', COALESCE(@dbt_v_rpl_semi_sync_source_enabled, @dbt_v_rpl_semi_sync_master_enabled),
    'semi_sync_status', COALESCE(@dbt_s_rpl_semi_sync_source_status, @dbt_s_rpl_semi_sync_master_status),
    'unacknowledged_transactions', CAST(COALESCE(@dbt_s_rpl_semi_sync_source_no_tx, @dbt_s_rpl_semi_sync_master_no_tx, 0) AS UNSIGNED),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'uptime_seconds', @dbt_uptime_s) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE UPPER(COALESCE(@dbt_v_rpl_semi_sync_source_enabled,
                     @dbt_v_rpl_semi_sync_master_enabled, 'OFF')) IN ('ON', '1')
  AND UPPER(COALESCE(@dbt_s_rpl_semi_sync_source_status,
                     @dbt_s_rpl_semi_sync_master_status, 'ON')) IN ('OFF', '0');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-015' AS marker;
-- check: MY-REPL-015
-- title: Replication filters configured
-- priority: 50 | category: REPL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: performance_schema.replication_applier_filters /
--        replication_applier_global_filters (MySQL 8.0.1+);
--        @dbt_v_replicate_* bundle variables (MariaDB, and MySQL where the
--        performance_schema tables are unavailable)
-- NOT in the design's §5.2 table; added because filters are one of the few
-- MySQL replication settings that silently make a replica a non-backup and a
-- non-failover-target, and requirement lists them explicitly.
-- Why it matters: a filtered replica is missing data by design, so it can never
-- be promoted and a restore from it is incomplete. Worse, replicate_ignore_db
-- and replicate_do_db act on the *default database of the statement*, not on the
-- tables it touches, so a cross-schema statement issued with the wrong USE is
-- filtered or not filtered contrary to intent — that is a documented behaviour,
-- not a bug, and it is why the *_wild_*_table forms are the safer spelling.
-- Reported at P50 rather than higher because a filter is usually deliberate;
-- what is almost never deliberate is the failover plan that forgot about it.
SET @dbt_q_ps := "
SELECT
  'MY-REPL-015' AS check_id,
  'cluster'     AS scope,
  'replication-filters' AS object,
  CONCAT(f.n, ' replication filter(s) are active: ', f.list,
         '. A filtered replica is missing rows by design: it cannot be promoted to source and a backup taken from it is incomplete. ',
         'Note that the *_DB filters test the statement''s default database, not the tables it touches.') AS details,
  JSON_OBJECT('filter_count', f.n, 'filters', f.list, 'source', 'performance_schema.replication_applier_filters') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT(FILTER_NAME, ' = ', FILTER_RULE) SEPARATOR '; '), 1, 600) AS list
    FROM performance_schema.replication_applier_global_filters
) AS f
WHERE f.n > 0";

SET @dbt_q_var := "
SELECT
  'MY-REPL-015' AS check_id,
  'cluster'     AS scope,
  'replication-filters' AS object,
  CONCAT(f.n, ' replication filter variable(s) are set: ', f.list,
         '. A filtered replica is missing rows by design: it cannot be promoted to source and a backup taken from it is incomplete. ',
         'Note that replicate_do_db / replicate_ignore_db test the statement''s default database, not the tables it touches, so the *_wild_*_table forms are the predictable spelling.') AS details,
  JSON_OBJECT('filter_count', f.n, 'filters', f.list, 'source', 'global variables') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    (IFNULL(@dbt_v_replicate_do_db, '') <> '')
  + (IFNULL(@dbt_v_replicate_ignore_db, '') <> '')
  + (IFNULL(@dbt_v_replicate_do_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_ignore_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_wild_do_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_wild_ignore_table, '') <> '')
  + (IFNULL(@dbt_v_replicate_rewrite_db, '') <> '') AS n,
    SUBSTRING(CONCAT_WS('; ',
      IF(IFNULL(@dbt_v_replicate_do_db, '') <> '',            CONCAT('replicate_do_db = ', @dbt_v_replicate_do_db), NULL),
      IF(IFNULL(@dbt_v_replicate_ignore_db, '') <> '',        CONCAT('replicate_ignore_db = ', @dbt_v_replicate_ignore_db), NULL),
      IF(IFNULL(@dbt_v_replicate_do_table, '') <> '',         CONCAT('replicate_do_table = ', @dbt_v_replicate_do_table), NULL),
      IF(IFNULL(@dbt_v_replicate_ignore_table, '') <> '',     CONCAT('replicate_ignore_table = ', @dbt_v_replicate_ignore_table), NULL),
      IF(IFNULL(@dbt_v_replicate_wild_do_table, '') <> '',    CONCAT('replicate_wild_do_table = ', @dbt_v_replicate_wild_do_table), NULL),
      IF(IFNULL(@dbt_v_replicate_wild_ignore_table, '') <> '',CONCAT('replicate_wild_ignore_table = ', @dbt_v_replicate_wild_ignore_table), NULL),
      IF(IFNULL(@dbt_v_replicate_rewrite_db, '') <> '',       CONCAT('replicate_rewrite_db = ', @dbt_v_replicate_rewrite_db), NULL)
    ), 1, 600) AS list
) AS f
WHERE f.n > 0";

SET @dbt_q := IF(IFNULL(@dbt_has_applier_filters, 0) = 1 AND IFNULL(@dbt_is_mariadb, 0) = 0,
                 @dbt_q_ps, @dbt_q_var);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-004' AS marker;
-- check: MY-SCHEMA-004
-- title: sql_mode is not strict
-- priority: 50 | category: SCHEMA | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_global_sql_mode (the GLOBAL value captured in 01_session.sql
--        BEFORE this session changed its own sql_mode)
-- IMPORTANT: this check must never read @@sql_mode or @@SESSION.sql_mode.
-- 01_session.sql deliberately sets a fixed SESSION sql_mode so the dynamic SQL
-- elsewhere parses identically on every fork, which would make a session-scoped
-- reading of this check report db-triage's own setting. @dbt_global_sql_mode is
-- the server's real GLOBAL value, snapshotted before that change.
-- Default divergence: MySQL 5.7+ and 8.x ship STRICT_TRANS_TABLES,
-- ERROR_FOR_DIVISION_BY_ZERO, NO_ZERO_DATE and NO_ZERO_IN_DATE on by default.
-- MariaDB 10.2.4+ ships STRICT_TRANS_TABLES and ERROR_FOR_DIVISION_BY_ZERO but
-- NOT NO_ZERO_DATE/NO_ZERO_IN_DATE, so a MariaDB server missing only those two
-- is at its documented default — the finding says which modes are missing and
-- distinguishes truncation (data loss) from zero dates (data that no client
-- library can represent).
-- Without STRICT_*, an INSERT of 300 into a TINYINT stores 127 and returns a
-- warning nobody reads; a 300-character string into VARCHAR(255) is silently cut.
SELECT
  'MY-SCHEMA-004' AS check_id,
  'setting'       AS scope,
  'sql_mode'      AS object,
  CONCAT('Global sql_mode = ''', IF(@dbt_global_sql_mode = '', '(empty)', @dbt_global_sql_mode),
         '''. Missing: ', m.missing, '. ',
         IF(m.no_strict,
            'Without STRICT_TRANS_TABLES an out-of-range or over-length value is silently coerced and stored: 300 into a TINYINT becomes 127, a 300-character string into VARCHAR(255) is truncated, and the statement succeeds with a warning. That is data loss the application never sees. ',
            ''),
         IF(m.no_zero_date,
            'Without NO_ZERO_DATE / NO_ZERO_IN_DATE the value ''0000-00-00'' can be stored, which most client libraries cannot represent and which breaks on any later migration. ',
            ''),
         'Changing sql_mode affects existing applications that rely on the lenient behaviour, so test before applying it globally.') AS details,
  JSON_OBJECT(
    'global_sql_mode', @dbt_global_sql_mode,
    'missing_modes', m.missing,
    'strict_missing', m.no_strict,
    'zero_date_missing', m.no_zero_date,
    'fork', @dbt_fork,
    'server_version', @@GLOBAL.version) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    (@dbt_global_sql_mode NOT LIKE '%STRICT_TRANS_TABLES%'
     AND @dbt_global_sql_mode NOT LIKE '%STRICT_ALL_TABLES%') AS no_strict,
    (@dbt_global_sql_mode NOT LIKE '%NO_ZERO_DATE%'
     OR @dbt_global_sql_mode NOT LIKE '%NO_ZERO_IN_DATE%')    AS no_zero_date,
    CONCAT_WS(', ',
      IF(@dbt_global_sql_mode NOT LIKE '%STRICT_TRANS_TABLES%'
         AND @dbt_global_sql_mode NOT LIKE '%STRICT_ALL_TABLES%', 'STRICT_TRANS_TABLES', NULL),
      IF(@dbt_global_sql_mode NOT LIKE '%ERROR_FOR_DIVISION_BY_ZERO%', 'ERROR_FOR_DIVISION_BY_ZERO', NULL),
      IF(@dbt_global_sql_mode NOT LIKE '%NO_ZERO_DATE%', 'NO_ZERO_DATE', NULL),
      IF(@dbt_global_sql_mode NOT LIKE '%NO_ZERO_IN_DATE%', 'NO_ZERO_IN_DATE', NULL)) AS missing
) AS m
WHERE m.missing <> '';
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-006' AS marker;
-- check: MY-SCHEMA-006
-- title: AUTO_INCREMENT at or above 70 percent exhausted
-- priority: 50 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: autoinc_critical_ratio=0.90;autoinc_warn_ratio=0.70
-- reads: sys.schema_auto_increment_columns, with an information_schema fallback
-- Verified present with identical columns on MySQL 5.7+/8.x and MariaDB 10.6+
-- (sys.schema_auto_increment_columns: max_value, auto_increment,
-- auto_increment_ratio). The fallback computes the same figures from
-- information_schema.COLUMNS + TABLES for servers with no sys schema.
-- Magnitude tier below MY-SCHEMA-005, with its own ID so suppressing the noisy
-- tier can never hide the urgent one.
-- The failure mode: when the counter
-- reaches the column type's maximum, MySQL does NOT wrap and does NOT raise an
-- overflow error. It hands out the maximum value again, so the insert fails with
-- ER_DUP_ENTRY — a duplicate-key error on a surrogate key, which reads like an
-- application bug and is routinely misdiagnosed for hours.
-- The fix (ALTER to a wider type) rewrites the whole table, so a 90%-full
-- 500 GB table needs a maintenance window planned now, not when it fills.
SET @dbt_q_sys := "
SELECT
  'MY-SCHEMA-006' AS check_id,
  'relation'      AS scope,
  CONCAT(a.table_schema, '.', a.table_name, '.', a.column_name) AS object,
  CONCAT('`', a.table_schema, '`.`', a.table_name, '`.', a.column_name, ' (',
         a.column_type, ') is at ', FORMAT(a.auto_increment, 0), ' of a maximum ',
         FORMAT(a.max_value, 0), ' — ', ROUND(100 * a.auto_increment_ratio, 1),
         '% used (threshold ', ROUND(100 * COALESCE(@autoinc_warn_ratio, 0.70), 0), '%). ',
         'At the maximum, MySQL reissues that same value rather than wrapping or overflowing, so inserts fail with a DUPLICATE KEY error on a surrogate key. ',
         'Table size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB, so widening the column rewrites that much data — plan the window now.') AS details,
  JSON_OBJECT(
    'schema', a.table_schema,
    'table', a.table_name,
    'column', a.column_name,
    'column_type', a.column_type,
    'auto_increment', a.auto_increment,
    'max_value', a.max_value,
    'ratio', ROUND(a.auto_increment_ratio, 4),
    'threshold_ratio', COALESCE(@autoinc_warn_ratio, 0.70),
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH) AS evidence_json,
  'high' AS confidence
FROM sys.schema_auto_increment_columns AS a
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = a.table_schema AND t.TABLE_NAME = a.table_name
WHERE a.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND a.auto_increment_ratio >= COALESCE(@autoinc_warn_ratio, 0.70)
  AND a.auto_increment_ratio <  COALESCE(@autoinc_critical_ratio, 0.90)
ORDER BY a.auto_increment_ratio DESC
LIMIT 20";

SET @dbt_q_fb := "
SELECT
  'MY-SCHEMA-006' AS check_id,
  'relation'      AS scope,
  CONCAT(x.TABLE_SCHEMA, '.', x.TABLE_NAME, '.', x.COLUMN_NAME) AS object,
  CONCAT('`', x.TABLE_SCHEMA, '`.`', x.TABLE_NAME, '`.', x.COLUMN_NAME, ' (',
         x.COLUMN_TYPE, ') is at ', FORMAT(x.auto_increment, 0), ' of a maximum ',
         FORMAT(x.max_value, 0), ' — ', ROUND(100 * x.auto_increment / x.max_value, 1),
         '% used (threshold ', ROUND(100 * COALESCE(@autoinc_warn_ratio, 0.70), 0),
         '%). Computed from information_schema because this server has no sys schema. ',
         'At the maximum, inserts fail with a DUPLICATE KEY error rather than an overflow.') AS details,
  JSON_OBJECT(
    'schema', x.TABLE_SCHEMA, 'table', x.TABLE_NAME, 'column', x.COLUMN_NAME,
    'column_type', x.COLUMN_TYPE, 'auto_increment', x.auto_increment,
    'max_value', x.max_value, 'ratio', ROUND(x.auto_increment / x.max_value, 4),
    'threshold_ratio', COALESCE(@autoinc_warn_ratio, 0.70),
    'source', 'information_schema fallback') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE,
         IFNULL(t.AUTO_INCREMENT, 0) AS auto_increment,
         CASE
           WHEN c.DATA_TYPE = 'tinyint'   THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 255, 127)
           WHEN c.DATA_TYPE = 'smallint'  THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 65535, 32767)
           WHEN c.DATA_TYPE = 'mediumint' THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 16777215, 8388607)
           WHEN c.DATA_TYPE = 'int'       THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 4294967295, 2147483647)
           WHEN c.DATA_TYPE = 'bigint'    THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 18446744073709551615, 9223372036854775807)
           ELSE NULL
         END AS max_value
  FROM information_schema.COLUMNS AS c
  JOIN information_schema.TABLES AS t
    ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
  WHERE c.EXTRA LIKE '%auto_increment%'
    AND c.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS x
WHERE x.max_value IS NOT NULL
  AND x.auto_increment >= x.max_value * COALESCE(@autoinc_warn_ratio, 0.70)
  AND x.auto_increment <  x.max_value * COALESCE(@autoinc_critical_ratio, 0.90)
ORDER BY x.auto_increment / x.max_value DESC
LIMIT 20";

SET @dbt_q := IF(IFNULL(@dbt_sys_autoinc, 0) = 1, @dbt_q_sys, @dbt_q_fb);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-007' AS marker;
-- check: MY-SCHEMA-007
-- title: Integrity checks disabled globally
-- priority: 50 | category: SCHEMA | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.foreign_key_checks, @@GLOBAL.unique_checks
-- Both are SESSION variables with a GLOBAL default, and both are legitimately
-- set to OFF for the duration of a bulk import — that is what mysqldump output
-- does, in the session, and it is fine.
-- Setting them OFF GLOBALLY is different: every future session inherits it, so
-- foreign keys stop being enforced and unique indexes stop being checked on
-- insert for the whole server. InnoDB does not re-validate afterwards, so rows
-- that violate a constraint are simply in the table, and the first time anyone
-- notices is when a JOIN returns orphans or a unique index reports duplicates
-- during a rebuild.
-- @@GLOBAL is read explicitly, never @@SESSION, so an import running right now
-- in another session cannot produce a false positive.
SELECT
  'MY-SCHEMA-007' AS check_id,
  'setting'       AS scope,
  IF(@@GLOBAL.foreign_key_checks = 0, 'foreign_key_checks', 'unique_checks') AS object,
  CONCAT('Globally: foreign_key_checks = ', IF(@@GLOBAL.foreign_key_checks = 1, 'ON', 'OFF'),
         ', unique_checks = ', IF(@@GLOBAL.unique_checks = 1, 'ON', 'OFF'),
         '. Every new session inherits this, so ',
         CONCAT_WS(' and ',
           IF(@@GLOBAL.foreign_key_checks = 0, 'foreign key constraints are not enforced on insert, update or delete', NULL),
           IF(@@GLOBAL.unique_checks = 0, 'unique secondary indexes are not checked on insert', NULL)),
         '. InnoDB never revalidates afterwards, so violating rows stay in the table and only surface as orphaned JOIN results or as duplicate-key errors during a later index rebuild. ',
         'There are ', fk.n, ' foreign key constraint(s) defined on this server, which is what is currently not being enforced. ',
         'Setting these OFF per-session for a bulk import is normal; setting them OFF globally is not.') AS details,
  JSON_OBJECT(
    'foreign_key_checks', CAST(@@GLOBAL.foreign_key_checks AS CHAR),
    'unique_checks', CAST(@@GLOBAL.unique_checks AS CHAR),
    'foreign_key_constraints', fk.n) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_TYPE = 'FOREIGN KEY'
    AND CONSTRAINT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS fk
WHERE @@GLOBAL.foreign_key_checks = 0 OR @@GLOBAL.unique_checks = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-013' AS marker;
-- check: MY-SCHEMA-013
-- title: Shared InnoDB tablespace in use
-- priority: 50 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_file_per_table, information_schema.INNODB_TABLES (MySQL 8.0)
--        or information_schema.INNODB_SYS_TABLES (MySQL 5.7 / MariaDB)
-- Catalog rename, verified: MySQL 8.0 renamed every INNODB_SYS_* table to
-- INNODB_* (INNODB_SYS_TABLES became INNODB_TABLES). MariaDB 10.11 kept the
-- INNODB_SYS_* names (verified present). The check probes for whichever exists
-- and emits nothing if neither does.
-- Why it matters: ibdata1 only ever grows. Dropping a table stored inside it
-- returns the space to InnoDB's free list, never to the filesystem, and the only
-- way to shrink it is a full logical dump and reload of the entire instance.
-- Per-table tablespaces also unlock transportable tablespaces, per-table
-- compression, and TRUNCATE actually freeing space.
SET @dbt_q := "
SELECT
  'MY-SCHEMA-013' AS check_id,
  'relation'      AS scope,
  'innodb_system' AS object,
  CONCAT(IF(@@GLOBAL.innodb_file_per_table = 0,
            'innodb_file_per_table = OFF, so every new InnoDB table is created inside the shared system tablespace. ',
            'innodb_file_per_table = ON, but '),
         x.n, ' existing table(s) still live in the shared system tablespace: ', x.list,
         '. ibdata1 never shrinks: dropping or truncating a table inside it returns the space to InnoDB''s internal free list, not to the filesystem, and the only way to reclaim it is a full logical dump and reload of the whole instance. ',
         'Per-table tablespaces also enable transportable tablespaces and per-table compression.') AS details,
  JSON_OBJECT(
    'innodb_file_per_table', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
    'tables_in_system_tablespace', x.n,
    'tables', x.list,
    'catalog', x.src) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(NAME ORDER BY NAME SEPARATOR ', '), 1, 500) AS list,
         'CATALOGNAME' AS src
    FROM information_schema.CATALOGNAME
   WHERE SPACE = 0
     AND NAME NOT LIKE 'mysql/%'
     AND NAME NOT LIKE 'sys/%'
     AND NAME LIKE '%/%'
) AS x
WHERE x.n > 0 OR @@GLOBAL.innodb_file_per_table = 0";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_innodb_tables, 0) = 1     THEN REPLACE(@dbt_q, 'CATALOGNAME', 'INNODB_TABLES')
  WHEN IFNULL(@dbt_has_innodb_sys_tables, 0) = 1 THEN REPLACE(@dbt_q, 'CATALOGNAME', 'INNODB_SYS_TABLES')
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-008' AS marker;
-- check: MY-SEC-008
-- title: Application connections running as a privileged account
-- priority: 50 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS, SELECT ON mysql.*
-- thresholds: privileged_conn_count=5
-- reads: information_schema.PROCESSLIST joined to the normalised account source
-- The difference between "a privileged account exists" (MY-SEC-007, a review
-- item) and "the application is using one right now" (this, a finding). Five or
-- more concurrent non-local connections from an account holding SUPER or the
-- full privilege set is an application connecting as an administrator: every SQL
-- injection is then a server compromise rather than a data leak, and no
-- least-privilege boundary exists to contain a bad deployment.
-- Localhost connections are excluded — that is where a DBA and the backup tool
-- legitimately live.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-008' AS check_id,
  'role'       AS scope,
  CONCAT(x.acct_user, '@', x.acct_host) AS object,
  CONCAT(x.conns, ' concurrent non-local connection(s) are running as ''',
         x.acct_user, '''@''', x.acct_host, ''', which holds ', x.priv_list,
         '. Client hosts: ', x.client_hosts,
         '. An application connected as an administrator turns any SQL injection into full server control and removes every least-privilege boundary. ',
         'Schemas in use: ', IFNULL(x.dbs, 'none reported'), '.') AS details,
  JSON_OBJECT(
    'user', x.acct_user,
    'host_pattern', x.acct_host,
    'concurrent_connections', x.conns,
    'client_hosts', x.client_hosts,
    'global_privileges', x.priv_list,
    'schemas', IFNULL(x.dbs, ''),
    'threshold', COALESCE(@privileged_conn_count, 5),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT a.acct_user, a.acct_host, a.priv_list,
         COUNT(*) AS conns,
         SUBSTRING(GROUP_CONCAT(DISTINCT SUBSTRING_INDEX(p.HOST, ':', 1) SEPARATOR ', '), 1, 200) AS client_hosts,
         SUBSTRING(GROUP_CONCAT(DISTINCT p.DB SEPARATOR ', '), 1, 200) AS dbs
  FROM information_schema.PROCESSLIST AS p
  JOIN (ACCTSRC) AS a ON a.acct_user = p.USER
  WHERE p.HOST IS NOT NULL
    AND p.HOST <> ''
    AND SUBSTRING_INDEX(p.HOST, ':', 1) NOT IN ('localhost', '127.0.0.1', '::1')
    AND (a.Super_priv = 'Y' OR a.has_all_privs)
    AND a.acct_user NOT IN ACCTSYS
  GROUP BY a.acct_user, a.acct_host, a.priv_list
) AS x
WHERE x.conns >= COALESCE(@privileged_conn_count, 5)
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-UNDO-002' AS marker;
-- check: MY-UNDO-002
-- title: InnoDB history list length elevated
-- priority: 50 | category: UNDO | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: hll_elevated=100000;hll_critical=1000000
-- reads: information_schema.INNODB_METRICS trx_rseg_history_len (via @dbt_hll)
-- Magnitude tier below MY-UNDO-001, with its own ID so suppressing the noisy
-- tier can never hide the severe one (DESIGN §2.2). 100,000 is roughly where
-- purge lag becomes visible as extra read latency on a busy OLTP server; below
-- that a healthy server routinely sits in the thousands.
SELECT
  'MY-UNDO-002' AS check_id,
  'cluster'     AS scope,
  NULL          AS object,
  CONCAT('InnoDB history list length is ', FORMAT(@dbt_hll, 0),
         ' undo records (threshold ', FORMAT(COALESCE(@hll_elevated, 100000), 0),
         '; the P5 tier MY-UNDO-001 starts at ', FORMAT(COALESCE(@hll_critical, 1000000), 0),
         '). Purge is falling behind. innodb_purge_threads = ',
         @@GLOBAL.innodb_purge_threads, '.') AS details,
  JSON_OBJECT(
    'history_list_length', @dbt_hll,
    'threshold', COALESCE(@hll_elevated, 100000),
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_metrics_enabled, 0) = 1
  AND @dbt_hll >= COALESCE(@hll_elevated, 100000)
  AND @dbt_hll <  COALESCE(@hll_critical, 1000000);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-UNDO-003' AS marker;
-- check: MY-UNDO-003
-- title: Undo tablespaces large
-- priority: 50 | category: UNDO | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: undo_bytes=10737418240;undo_bytes_no_truncate=2147483648
-- reads: information_schema.FILES (MySQL 8.0, FILE_TYPE='UNDO LOG');
--        information_schema.INNODB_SYS_TABLESPACES (MariaDB, NAME LIKE 'innodb_undo%');
--        @@GLOBAL.innodb_undo_tablespaces, @@GLOBAL.innodb_undo_log_truncate
-- Fork divergence, verified on MariaDB 10.11: information_schema.FILES returns
-- ZERO rows there (it is an NDB-era table MariaDB does not populate for InnoDB),
-- so the MySQL query would silently never fire. MariaDB therefore reads
-- INNODB_SYS_TABLESPACES.FILE_SIZE for the separate undo tablespaces, and when
-- innodb_undo_tablespaces = 0 (the MariaDB default) undo lives inside ibdata1
-- and cannot be sized separately at all — that case is reported at low
-- confidence against the system tablespace rather than guessed at.
-- Undo space is never returned to the filesystem unless innodb_undo_log_truncate
-- is ON and the tablespaces are separate, which is why OFF halves the threshold.
SET @dbt_q := "
SELECT
  'MY-UNDO-003' AS check_id,
  'cluster'     AS scope,
  u.name        AS object,
  CONCAT('Undo storage is ', ROUND(u.bytes / 1073741824, 2), ' GB (', u.what, '). ',
         'innodb_undo_tablespaces = ', @@GLOBAL.innodb_undo_tablespaces,
         ', innodb_undo_log_truncate = ', @@GLOBAL.innodb_undo_log_truncate,
         '. Threshold ', ROUND(u.threshold / 1073741824, 1), ' GB. ',
         IF(@@GLOBAL.innodb_undo_log_truncate IN (0, 'OFF'),
            'With truncation OFF this space is never returned, even after purge catches up.',
            'Truncation is ON, so this space is reclaimable once the history list drains (MY-UNDO-001/002).')) AS details,
  JSON_OBJECT(
    'undo_bytes', u.bytes,
    'source', u.what,
    'threshold_bytes', u.threshold,
    'innodb_undo_tablespaces', @@GLOBAL.innodb_undo_tablespaces,
    'innodb_undo_log_truncate', CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR),
    'history_list_length', @dbt_hll) AS evidence_json,
  u.conf AS confidence
FROM (SRC) AS u
WHERE u.bytes >= u.threshold";

SET @dbt_src_mysql := "
  SELECT 'undo tablespaces' AS name,
         IFNULL(SUM(TOTAL_EXTENTS * EXTENT_SIZE), 0) AS bytes,
         'information_schema.FILES FILE_TYPE=UNDO LOG' AS what,
         IF(@@GLOBAL.innodb_undo_log_truncate IN (0, 'OFF'),
            COALESCE(@undo_bytes_no_truncate, 2147483648),
            COALESCE(@undo_bytes, 10737418240)) AS threshold,
         'high' AS conf
    FROM information_schema.FILES
   WHERE FILE_TYPE = 'UNDO LOG'";

SET @dbt_src_maria := "
  SELECT IF(@@GLOBAL.innodb_undo_tablespaces > 0, 'undo tablespaces', 'innodb_system (ibdata1)') AS name,
         IFNULL(SUM(FILE_SIZE), 0) AS bytes,
         IF(@@GLOBAL.innodb_undo_tablespaces > 0,
            'information_schema.INNODB_SYS_TABLESPACES innodb_undo*',
            'information_schema.INNODB_SYS_TABLESPACES innodb_system: undo is inside the system tablespace and cannot be sized separately, so this figure includes non-undo data') AS what,
         IF(@@GLOBAL.innodb_undo_log_truncate IN (0, 'OFF'),
            COALESCE(@undo_bytes_no_truncate, 2147483648),
            COALESCE(@undo_bytes, 10737418240)) AS threshold,
         IF(@@GLOBAL.innodb_undo_tablespaces > 0, 'high', 'low') AS conf
    FROM information_schema.INNODB_SYS_TABLESPACES
   WHERE NAME LIKE IF(@@GLOBAL.innodb_undo_tablespaces > 0, 'innodb_undo%', 'innodb_system')";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_is_files, 0) = 1 AND IFNULL(@dbt_is_mariadb, 0) = 0
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_mysql)
  WHEN IFNULL(@dbt_has_innodb_sys_tablespaces, 0) = 1
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_maria)
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-WAL-001' AS marker;
-- check: MY-WAL-001
-- title: Redo log capacity below one hour of writes
-- priority: 50 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: redo_hours=1;min_write_rate_bytes_per_hour=10485760;small_capacity_bytes=104857600
-- reads: @dbt_v_innodb_redo_log_capacity (MySQL 8.0.30+),
--        @dbt_v_innodb_log_file_size x @dbt_v_innodb_log_files_in_group (older MySQL, MariaDB),
--        @dbt_s_innodb_os_log_written, @dbt_uptime_s
-- Version divergence: MySQL 8.0.30 introduced innodb_redo_log_capacity (default
-- 100 MB) and deprecated the file-size x file-count arithmetic. MariaDB 10.5
-- REMOVED innodb_log_files_in_group entirely (there is one file), so on MariaDB
-- capacity is innodb_log_file_size alone. Both readings come from the bundle and
-- the fallback chain covers 5.7, 8.0 pre-.30, 8.0.30+, 8.4, 9.x and MariaDB.
-- Sizing rule (Percona's): the redo log should hold roughly an hour of writes.
-- When it cannot, checkpoints become continuous, InnoDB switches to aggressive
-- adaptive flushing, and throughput collapses in bursts rather than degrading
-- smoothly. Rate is bytes written since restart divided by uptime, so its
-- confidence follows the counter window (@dbt_counter_conf).
SELECT
  'MY-WAL-001' AS check_id,
  'setting'    AS scope,
  IF(@dbt_v_innodb_redo_log_capacity IS NOT NULL, 'innodb_redo_log_capacity', 'innodb_log_file_size') AS object,
  CONCAT('Redo capacity is ', ROUND(c.capacity / 1048576, 0), ' MB (',
         c.how, ') while redo is written at ', ROUND(c.rate_h / 1048576, 1),
         ' MB/h averaged over ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h of uptime. That is ', ROUND(c.capacity / GREATEST(c.rate_h, 1), 2),
         ' h of headroom, below the ', COALESCE(@redo_hours, 1),
         ' h target. Checkpointing becomes continuous and InnoDB flushes aggressively, which shows up as write stalls rather than steady slowdown.') AS details,
  JSON_OBJECT(
    'redo_capacity_bytes', c.capacity,
    'capacity_source', c.how,
    'redo_bytes_per_hour', ROUND(c.rate_h),
    'hours_of_headroom', ROUND(c.capacity / GREATEST(c.rate_h, 1), 3),
    'threshold_hours', COALESCE(@redo_hours, 1),
    'uptime_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CASE
      WHEN @dbt_v_innodb_redo_log_capacity IS NOT NULL
        THEN CAST(@dbt_v_innodb_redo_log_capacity AS DECIMAL(30, 0))
      ELSE CAST(IFNULL(@dbt_v_innodb_log_file_size, 0) AS DECIMAL(30, 0))
         * GREATEST(CAST(IFNULL(@dbt_v_innodb_log_files_in_group, 1) AS SIGNED), 1)
    END AS capacity,
    CASE
      WHEN @dbt_v_innodb_redo_log_capacity IS NOT NULL THEN 'innodb_redo_log_capacity'
      WHEN @dbt_v_innodb_log_files_in_group IS NOT NULL THEN 'innodb_log_file_size x innodb_log_files_in_group'
      ELSE 'innodb_log_file_size (MariaDB 10.5+ has a single redo file)'
    END AS how,
    CAST(IFNULL(@dbt_s_innodb_os_log_written, 0) AS DECIMAL(30, 0)) / @dbt_uptime_h AS rate_h
) AS c
WHERE c.capacity > 0
  AND c.rate_h >= COALESCE(@min_write_rate_bytes_per_hour, 10485760)
  AND c.capacity < c.rate_h * COALESCE(@redo_hours, 1);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-BAK-006' AS marker;
-- check: MY-BAK-006
-- title: Binary log checksums off
-- priority: 100 | category: BAK | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.binlog_checksum, @@GLOBAL.master_verify_checksum equivalents
-- binlog_checksum=NONE means a truncated or bit-rotted binlog event is replayed
-- rather than rejected. Both forks default to CRC32; NONE is only needed for
-- replicas older than MySQL 5.6, which no supported topology has.
SELECT
  'MY-BAK-006' AS check_id,
  'setting'    AS scope,
  'binlog_checksum' AS object,
  CONCAT('binlog_checksum = NONE with binary logging ON. ',
         'Binary log events carry no integrity check, so a truncated or corrupted event is applied by a replica or a PITR restore instead of being rejected. ',
         'Both MySQL 5.6+ and MariaDB 10.x default to CRC32; NONE is only required for pre-5.6 replicas.') AS details,
  JSON_OBJECT(
    'binlog_checksum', @@GLOBAL.binlog_checksum,
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_checksum) = 'NONE';
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CAP-008' AS marker;
-- check: MY-CAP-008
-- title: InnoDB temporary tablespace large
-- priority: 100 | category: CAP | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: temp_tablespace_bytes=10737418240
-- reads: information_schema.FILES (MySQL 8.0, FILE_TYPE='TEMPORARY') or
--        information_schema.INNODB_SYS_TABLESPACES (MariaDB, NAME='innodb_temporary');
--        @dbt_v_innodb_temp_data_file_path
-- Same fork split as MY-UNDO-003 and for the same verified reason:
-- information_schema.FILES returns ZERO rows on MariaDB 10.11, so the MySQL
-- query would silently never fire there. MariaDB's size comes from
-- INNODB_SYS_TABLESPACES.FILE_SIZE for the innodb_temporary space.
-- The trap: ibtmp1 autoextends by default (innodb_temp_data_file_path is
-- `ibtmp1:12M:autoextend` on both forks) and IS NEVER SHRUNK WHILE THE SERVER
-- RUNS. One badly written report that spills a huge sort or GROUP BY can grow it
-- to tens of gigabytes, and that space stays allocated until the next restart —
-- there is no online way to reclaim it.
-- Setting a max in innodb_temp_data_file_path (e.g. `ibtmp1:12M:autoextend:max:8G`)
-- converts an unbounded disk-full risk into a failed query, which is the right
-- trade on most servers. MySQL 8.0.16+ additionally has session temporary
-- tablespaces, which are reclaimed when the session ends.
SET @dbt_q := "
SELECT
  'MY-CAP-008' AS check_id,
  'cluster'    AS scope,
  'innodb-temporary-tablespace' AS object,
  CONCAT('The InnoDB temporary tablespace is ', ROUND(x.bytes / 1073741824, 2),
         ' GB (threshold ', ROUND(COALESCE(@temp_tablespace_bytes, 10737418240) / 1073741824, 0),
         ' GB), read from ', x.src, '. ',
         'innodb_temp_data_file_path = ', IFNULL(@dbt_v_innodb_temp_data_file_path, 'unknown'), '. ',
         'This file autoextends and is never shrunk while the server runs: a single report that spills a large sort or GROUP BY grows it, and the space stays allocated until the next restart with no online way to reclaim it. ',
         'Disk temp tables since restart: ',
         FORMAT(CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS DECIMAL(30, 0)), 0),
         ' (see MY-MEM-005 and MY-QRY-007 for what is spilling). ',
         'Adding :max:<size> to innodb_temp_data_file_path turns an unbounded disk-full risk into a failed query.') AS details,
  JSON_OBJECT(
    'temp_tablespace_bytes', x.bytes,
    'source', x.src,
    'innodb_temp_data_file_path', IFNULL(@dbt_v_innodb_temp_data_file_path, 'unknown'),
    'created_tmp_disk_tables', CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS UNSIGNED),
    'threshold_bytes', COALESCE(@temp_tablespace_bytes, 10737418240)) AS evidence_json,
  'high' AS confidence
FROM (SRC) AS x
WHERE x.bytes >= COALESCE(@temp_tablespace_bytes, 10737418240)";

SET @dbt_src_mysql := "
  SELECT IFNULL(SUM(TOTAL_EXTENTS * EXTENT_SIZE), 0) AS bytes,
         'information_schema.FILES FILE_TYPE=TEMPORARY' AS src
    FROM information_schema.FILES WHERE FILE_TYPE = 'TEMPORARY'";
SET @dbt_src_maria := "
  SELECT IFNULL(SUM(FILE_SIZE), 0) AS bytes,
         'information_schema.INNODB_SYS_TABLESPACES innodb_temporary' AS src
    FROM information_schema.INNODB_SYS_TABLESPACES WHERE NAME = 'innodb_temporary'";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_is_files, 0) = 1 AND IFNULL(@dbt_is_mariadb, 0) = 0
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_mysql)
  WHEN IFNULL(@dbt_has_innodb_sys_tablespaces, 0) = 1
    THEN REPLACE(@dbt_q, 'SRC', @dbt_src_maria)
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-004' AS marker;
-- check: MY-CONN-004
-- title: Aborted connections high
-- priority: 100 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: aborted_ratio=0.01;min_connections=10000
-- reads: @dbt_s_aborted_connects, @dbt_s_aborted_clients, @dbt_s_connections
-- Two different failures with one threshold, distinguished in the text:
-- Aborted_connects counts handshakes that never completed (bad credentials, a
-- host blocked by max_connect_errors, connect_timeout, TLS negotiation failure);
-- Aborted_clients counts established connections the client dropped without a
-- clean COM_QUIT (application crash, pool eviction, wait_timeout, an oversized
-- packet). The first is a security or configuration signal, the second is an
-- application-lifecycle signal, and confusing them wastes an afternoon.
SELECT
  'MY-CONN-004' AS check_id,
  'cluster'     AS scope,
  IF(a.connects_ratio >= a.thr, 'Aborted_connects', 'Aborted_clients') AS object,
  CONCAT('Since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago, of ',
         FORMAT(a.total, 0), ' connections: Aborted_connects = ', FORMAT(a.connects, 0),
         ' (', ROUND(100 * a.connects_ratio, 2),
         '%, handshakes that never completed — bad credentials, a host blocked by max_connect_errors, connect_timeout or a TLS failure); ',
         'Aborted_clients = ', FORMAT(a.clients, 0), ' (', ROUND(100 * a.clients_ratio, 2),
         '%, established connections dropped without a clean close — application crashes, pool evictions, wait_timeout = ',
         @@GLOBAL.wait_timeout, ' s, or max_allowed_packet = ',
         ROUND(@@GLOBAL.max_allowed_packet / 1048576, 0), ' MB exceeded). Threshold ',
         ROUND(100 * a.thr, 1), '%.') AS details,
  JSON_OBJECT(
    'aborted_connects', a.connects,
    'aborted_clients', a.clients,
    'connections', a.total,
    'aborted_connects_ratio', ROUND(a.connects_ratio, 5),
    'aborted_clients_ratio', ROUND(a.clients_ratio, 5),
    'threshold_ratio', a.thr,
    'wait_timeout', @@GLOBAL.wait_timeout,
    'max_allowed_packet', @@GLOBAL.max_allowed_packet) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_s_aborted_connects, 0) AS DECIMAL(30, 0)) AS connects,
    CAST(IFNULL(@dbt_s_aborted_clients, 0) AS DECIMAL(30, 0))  AS clients,
    GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS total,
    CAST(IFNULL(@dbt_s_aborted_connects, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS connects_ratio,
    CAST(IFNULL(@dbt_s_aborted_clients, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS clients_ratio,
    COALESCE(@aborted_ratio, 0.01) AS thr
) AS a
WHERE a.total >= COALESCE(@min_connections, 10000)
  AND (a.connects_ratio >= a.thr OR a.clients_ratio >= a.thr);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-005' AS marker;
-- check: MY-CONN-005
-- title: Host approaching the connect-error block threshold
-- priority: 100 | category: CONN | scope: host | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: connect_error_ratio=0.50
-- reads: performance_schema.host_cache (SUM_CONNECT_ERRORS), @@GLOBAL.max_connect_errors
-- MySQL-specific failure mode with no PostgreSQL analogue: when a host
-- accumulates max_connect_errors failed handshakes, the server blocks it
-- ENTIRELY — every subsequent connection from that IP is refused with
-- ER_HOST_IS_BLOCKED until someone runs FLUSH HOSTS. The block survives the
-- original problem being fixed, and nothing logs a warning as the count climbs.
-- The design scopes this to MySQL; performance_schema.host_cache is in fact
-- present on MariaDB 10.11 as well (verified), so it is gated on the table
-- rather than on the fork, and the registry row records both engines.
-- Note that skip_name_resolve=OFF makes DNS failures count toward this, which is
-- how a DNS blip turns into a permanently blocked application host (MY-CONN-010).
SET @dbt_q := "
SELECT
  'MY-CONN-005' AS check_id,
  'host'        AS scope,
  h.IP          AS object,
  CONCAT('Host ', h.IP, ' has accumulated ', h.SUM_CONNECT_ERRORS,
         ' connect errors against max_connect_errors = ', @@GLOBAL.max_connect_errors,
         ' (', ROUND(100.0 * h.SUM_CONNECT_ERRORS / @@GLOBAL.max_connect_errors, 0),
         '%, threshold ', ROUND(100 * COALESCE(@connect_error_ratio, 0.50), 0),
         '%). At 100% the server blocks this host entirely with ER_HOST_IS_BLOCKED until FLUSH HOSTS is run; the block outlives whatever caused it. ',
         'Breakdown: ', h.detail, '. skip_name_resolve = ', @@GLOBAL.skip_name_resolve,
         ' (when OFF, DNS failures count here too).') AS details,
  JSON_OBJECT(
    'ip', h.IP,
    'host', h.HOST,
    'sum_connect_errors', h.SUM_CONNECT_ERRORS,
    'max_connect_errors', @@GLOBAL.max_connect_errors,
    'ratio', ROUND(h.SUM_CONNECT_ERRORS / @@GLOBAL.max_connect_errors, 4),
    'threshold_ratio', COALESCE(@connect_error_ratio, 0.50),
    'skip_name_resolve', CAST(@@GLOBAL.skip_name_resolve AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT IP, HOST, SUM_CONNECT_ERRORS,
         CONCAT_WS(', ',
           IF(COUNT_HOST_BLOCKED_ERRORS > 0, CONCAT(COUNT_HOST_BLOCKED_ERRORS, ' host-blocked'), NULL),
           IF(COUNT_AUTHENTICATION_ERRORS > 0, CONCAT(COUNT_AUTHENTICATION_ERRORS, ' auth'), NULL),
           IF(COUNT_HANDSHAKE_ERRORS > 0, CONCAT(COUNT_HANDSHAKE_ERRORS, ' handshake'), NULL),
           IF(COUNT_NAMEINFO_TRANSIENT_ERRORS + COUNT_NAMEINFO_PERMANENT_ERRORS > 0,
              CONCAT(COUNT_NAMEINFO_TRANSIENT_ERRORS + COUNT_NAMEINFO_PERMANENT_ERRORS, ' DNS'), NULL)) AS detail
    FROM performance_schema.host_cache
) AS h
WHERE h.SUM_CONNECT_ERRORS >= @@GLOBAL.max_connect_errors * COALESCE(@connect_error_ratio, 0.50)";
SET @dbt_q := IF(IFNULL(@dbt_has_host_cache, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-007' AS marker;
-- check: MY-CONN-007
-- title: Most connections are sleeping
-- priority: 100 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: sleep_ratio=0.80;min_conns=100;long_wait_timeout=28800
-- reads: information_schema.PROCESSLIST, @@GLOBAL.wait_timeout
-- Snapshot, and the details say so. A high sleeping ratio is normal for a
-- pooled application and is only reported when it combines with a long
-- wait_timeout, because that is the combination where an abandoned connection
-- occupies a slot (and its per-session buffers, MY-MEM-006/007) for up to eight
-- hours after the client forgot about it.
-- Requires PROCESS to see other accounts' threads; without it PROCESSLIST shows
-- only this session and the min_conns floor keeps the check silent.
SELECT
  'MY-CONN-007' AS check_id,
  'cluster'     AS scope,
  'connection-pool' AS object,
  CONCAT(p.sleeping, ' of ', p.total, ' connections (',
         ROUND(100.0 * p.sleeping / p.total, 0),
         '%) are idle at snapshot time, with wait_timeout = ', @@GLOBAL.wait_timeout,
         ' s (', ROUND(@@GLOBAL.wait_timeout / 3600, 1),
         ' h) and interactive_timeout = ', @@GLOBAL.interactive_timeout, ' s. ',
         'Longest idle: ', p.max_sleep, ' s. Each idle connection holds a slot out of ',
         @@GLOBAL.max_connections, ' and its per-session buffers. ',
         'Top idle accounts: ', p.top_users, '.') AS details,
  JSON_OBJECT(
    'sleeping', p.sleeping,
    'total', p.total,
    'sleep_ratio', ROUND(p.sleeping / p.total, 3),
    'max_sleep_seconds', p.max_sleep,
    'wait_timeout', @@GLOBAL.wait_timeout,
    'interactive_timeout', @@GLOBAL.interactive_timeout,
    'max_connections', @@GLOBAL.max_connections,
    'measured', 'snapshot') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT COUNT(*) AS total,
         SUM(COMMAND = 'Sleep') AS sleeping,
         MAX(IF(COMMAND = 'Sleep', TIME, 0)) AS max_sleep,
         SUBSTRING(GROUP_CONCAT(DISTINCT IF(COMMAND = 'Sleep', USER, NULL) SEPARATOR ', '), 1, 200) AS top_users
  FROM information_schema.PROCESSLIST
) AS p
WHERE p.total >= COALESCE(@min_conns, 100)
  AND p.sleeping / p.total >= COALESCE(@sleep_ratio, 0.80)
  AND @@GLOBAL.wait_timeout >= COALESCE(@long_wait_timeout, 28800);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-DUR-008' AS marker;
-- check: MY-DUR-008
-- title: Replica not crash-safe
-- priority: 100 | category: DUR | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_relay_log_recovery, @dbt_v_master_info_repository,
--        @dbt_v_relay_log_info_repository, @dbt_is_replica
-- Only meaningful on a replica (@dbt_is_replica comes from
-- performance_schema.replication_connection_configuration, which exists on both
-- forks and is empty on a non-replica).
-- Version divergence: master_info_repository / relay_log_info_repository were
-- removed in MySQL 8.4 (positions are always in InnoDB tables there) and never
-- existed under those names on MariaDB, which uses relay_log_recovery plus
-- crash-safe rpl.* tables. NULL from the bundle therefore means "this fork does
-- not have the FILE-vs-TABLE hazard", and only relay_log_recovery is judged.
SELECT
  'MY-DUR-008' AS check_id,
  'replica'    AS scope,
  'replication-position' AS object,
  CONCAT('This instance is a replica and ',
         CONCAT_WS('; ',
           IF(LOWER(IFNULL(@dbt_v_relay_log_recovery, 'on')) IN ('off', '0'),
              'relay_log_recovery = OFF, so after a crash the relay log is reused as-is and any partially written event is replayed or skipped', NULL),
           IF(UPPER(IFNULL(@dbt_v_master_info_repository, 'TABLE')) = 'FILE',
              'master_info_repository = FILE, so the source position is written to master.info outside any transaction', NULL),
           IF(UPPER(IFNULL(@dbt_v_relay_log_info_repository, 'TABLE')) = 'FILE',
              'relay_log_info_repository = FILE, so the applied position is not committed atomically with the data', NULL)),
         '. A replica crash can then leave the recorded position and the applied data disagreeing, which silently duplicates or skips transactions.') AS details,
  JSON_OBJECT(
    'relay_log_recovery', IFNULL(@dbt_v_relay_log_recovery, 'n/a'),
    'master_info_repository', IFNULL(@dbt_v_master_info_repository, 'n/a'),
    'relay_log_info_repository', IFNULL(@dbt_v_relay_log_info_repository, 'n/a'),
    'fork', @dbt_fork) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND (LOWER(IFNULL(@dbt_v_relay_log_recovery, 'on')) IN ('off', '0')
       OR UPPER(IFNULL(@dbt_v_master_info_repository, 'TABLE')) = 'FILE'
       OR UPPER(IFNULL(@dbt_v_relay_log_info_repository, 'TABLE')) = 'FILE');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-005' AS marker;
-- check: MY-IDX-005
-- title: Write-heavy table carrying many indexes
-- priority: 100 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: many_indexes=10;min_writes=1000000
-- reads: information_schema.STATISTICS (index count), sys.schema_table_statistics
--        (rows_inserted + rows_updated + rows_deleted)
-- Availability: sys.schema_table_statistics exists on MySQL 5.7+ and MariaDB
-- 10.6+ (verified) with these column names. Without sys the check emits nothing,
-- because an index count with no write volume behind it is not a finding.
-- Every secondary index is a second B-tree that every INSERT must add to, every
-- DELETE must remove from, and every UPDATE of an indexed column must maintain —
-- plus a change-buffer entry or a random read if the index page is not in the
-- buffer pool. Ten indexes on a table taking a million writes means ten times
-- the write amplification of the table itself.
-- This is the input to an index review, not a verdict: MY-IDX-001/002 say which
-- of them are unused and MY-IDX-003 says which are redundant. Read all three
-- together before dropping anything.
SET @dbt_q := "
SELECT
  'MY-IDX-005' AS check_id,
  'relation'   AS scope,
  CONCAT(x.sch, '.', x.tbl) AS object,
  CONCAT('`', x.sch, '`.`', x.tbl, '` has ', x.idx_count, ' indexes (threshold ',
         COALESCE(@many_indexes, 10), ') and has taken ', FORMAT(x.writes, 0),
         ' row write(s) since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago: ',
         FORMAT(x.ins, 0), ' inserted, ', FORMAT(x.upd, 0), ' updated, ',
         FORMAT(x.del, 0), ' deleted. Table size ',
         ROUND(x.bytes / 1073741824, 2), ' GB. ',
         'Every secondary index is a separate B-tree maintained on each of those writes, so the write cost of this table is a multiple of the row cost. ',
         'Indexes: ', x.idx_list, '. ',
         'Cross-reference MY-IDX-001/002 (unused) and MY-IDX-003 (redundant) before dropping any of them.') AS details,
  JSON_OBJECT(
    'schema', x.sch, 'table', x.tbl,
    'index_count', x.idx_count, 'indexes', x.idx_list,
    'writes', x.writes, 'rows_inserted', x.ins, 'rows_updated', x.upd, 'rows_deleted', x.del,
    'table_bytes', x.bytes,
    'threshold_indexes', COALESCE(@many_indexes, 10),
    'threshold_writes', COALESCE(@min_writes, 1000000),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT i.TABLE_SCHEMA AS sch, i.TABLE_NAME AS tbl,
         i.n AS idx_count, i.idx_list,
         IFNULL(t.DATA_LENGTH + t.INDEX_LENGTH, 0) AS bytes,
         IFNULL(s.rows_inserted, 0) AS ins,
         IFNULL(s.rows_updated, 0)  AS upd,
         IFNULL(s.rows_deleted, 0)  AS del,
         IFNULL(s.rows_inserted, 0) + IFNULL(s.rows_updated, 0) + IFNULL(s.rows_deleted, 0) AS writes
    FROM (
      SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(DISTINCT INDEX_NAME) AS n,
             SUBSTRING(GROUP_CONCAT(DISTINCT INDEX_NAME SEPARATOR ', '), 1, 300) AS idx_list
        FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
       GROUP BY TABLE_SCHEMA, TABLE_NAME
    ) AS i
    JOIN information_schema.TABLES AS t
      ON t.TABLE_SCHEMA = i.TABLE_SCHEMA AND t.TABLE_NAME = i.TABLE_NAME
    LEFT JOIN sys.schema_table_statistics AS s
      ON s.table_schema = i.TABLE_SCHEMA AND s.table_name = i.TABLE_NAME
) AS x
WHERE x.idx_count >= COALESCE(@many_indexes, 10)
  AND x.writes >= COALESCE(@min_writes, 1000000)
ORDER BY x.writes DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_sys_table_stats, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-006' AS marker;
-- check: MY-IDX-006
-- title: Table fragmentation (DATA_FREE) high
-- priority: 100 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: fragmented_table_bytes=1073741824;data_free_ratio=0.30
-- reads: information_schema.TABLES (DATA_FREE, DATA_LENGTH, INDEX_LENGTH),
--        @@GLOBAL.innodb_file_per_table
-- CONFIDENCE IS LOW AND THAT IS NOT A HEDGE. DATA_FREE is coarse: it counts
-- fully free EXTENTS (1 MB units), not free space inside partly used pages, so
-- it understates real fragmentation on a table with many half-empty pages and
-- overstates it right after a bulk delete that has not been purged.
-- It is also meaningless unless innodb_file_per_table is ON: for a table inside
-- the shared tablespace, DATA_FREE reports the free space of the ENTIRE ibdata1
-- file, repeated identically for every such table. The check therefore requires
-- per-table tablespaces and says so (MY-SCHEMA-013 covers the other case).
-- On MySQL 8.0 the value additionally comes from the information_schema cache
-- and can be a day old.
-- The remedy — OPTIMIZE TABLE, or ALTER TABLE ... ENGINE=InnoDB — rebuilds the
-- table. db-triage never runs it, and on a live server it should be done through
-- pt-online-schema-change or gh-ost rather than in place.
SELECT
  'MY-IDX-006' AS check_id,
  'relation'   AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('`', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` reports DATA_FREE = ',
         ROUND(t.DATA_FREE / 1073741824, 2), ' GB against ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB of data and indexes (', ROUND(100.0 * t.DATA_FREE / (t.DATA_LENGTH + t.INDEX_LENGTH), 0),
         '%, threshold ', ROUND(100 * COALESCE(@data_free_ratio, 0.30), 0), '%). ',
         'ESTIMATE ONLY: DATA_FREE counts whole free extents of 1 MB, not free space inside partly filled pages, so it understates fragmentation after many small deletes and overstates it right after a bulk delete that purge has not yet processed',
         IF(@dbt_is_mariadb, '. ',
            CONCAT('; on MySQL 8.0 it is also served from the information_schema cache and may be up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20, 0)) / 3600, 0),
                   ' h old. ')),
         'Reclaiming it means rebuilding the table (OPTIMIZE TABLE or ALTER TABLE ... ENGINE=InnoDB), which db-triage never runs and which should go through pt-online-schema-change or gh-ost on a live server.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA, 'table', t.TABLE_NAME,
    'data_free_bytes', t.DATA_FREE,
    'data_index_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'ratio', ROUND(t.DATA_FREE / (t.DATA_LENGTH + t.INDEX_LENGTH), 4),
    'threshold_ratio', COALESCE(@data_free_ratio, 0.30),
    'innodb_file_per_table', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
    'estimate_basis', 'DATA_FREE whole free extents only') AS evidence_json,
  'low' AS confidence
FROM information_schema.TABLES AS t
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.ENGINE = 'InnoDB'
  AND @@GLOBAL.innodb_file_per_table = 1
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@fragmented_table_bytes, 1073741824)
  AND t.DATA_FREE >= (t.DATA_LENGTH + t.INDEX_LENGTH) * COALESCE(@data_free_ratio, 0.30)
ORDER BY t.DATA_FREE DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-009' AS marker;
-- check: MY-LOCK-009
-- title: Query running for over 10 minutes
-- priority: 100 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: long_query_seconds=600
-- reads: information_schema.PROCESSLIST
-- Excludes the threads that are legitimately long-lived: replication receivers
-- and appliers (Binlog Dump, Connect, Slave/Replica threads), the event
-- scheduler, and this session itself. Backup tools are excluded by name where
-- they are recognisable, and the details name the account so an unrecognised
-- one is easy to classify.
-- A ten-minute query is not automatically wrong — a nightly report is fine — but
-- on an OLTP server it is usually a missing index (MY-IDX-004, MY-QRY-006/008) or
-- a query that should not be running there at all. It is P100 because the fix is
-- rarely urgent, and it is scoped per session so each one is separately
-- suppressible.
SELECT
  'MY-LOCK-009' AS check_id,
  'session'     AS scope,
  CONCAT('pid:', p.ID) AS object,
  CONCAT('Thread ', p.ID, ' (', IFNULL(p.USER, '?'), '@', IFNULL(p.HOST, '?'),
         ', schema ', IFNULL(p.DB, 'none'), ') has been running a ', p.COMMAND,
         ' for ', ROUND(p.TIME / 60, 1), ' min (threshold ',
         ROUND(COALESCE(@long_query_seconds, 600) / 60, 0), ' min), state "',
         IFNULL(p.STATE, 'none'), '". Statement: ',
         SUBSTRING(REGEXP_REPLACE(IFNULL(p.INFO, '(not visible without PROCESS)'), '[[:space:]]+', ' '), 1, 250)) AS details,
  JSON_OBJECT(
    'thread_id', p.ID,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'db', IFNULL(p.DB, ''),
    'command', p.COMMAND,
    'runtime_seconds', p.TIME,
    'state', IFNULL(p.STATE, ''),
    'threshold_seconds', COALESCE(@long_query_seconds, 600),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM information_schema.PROCESSLIST AS p
WHERE p.COMMAND NOT IN ('Sleep', 'Binlog Dump', 'Binlog Dump GTID', 'Connect', 'Daemon', 'Slave_IO', 'Slave_SQL')
  AND p.ID <> CONNECTION_ID()
  AND IFNULL(p.USER, '') NOT IN ('system user', 'event_scheduler')
  AND p.TIME >= COALESCE(@long_query_seconds, 600);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-003' AS marker;
-- check: MY-MEM-003
-- title: Buffer pool over 80 percent of host RAM
-- priority: 100 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: os
-- thresholds: pool_ram_ceiling=0.80
-- reads: @@GLOBAL.innodb_buffer_pool_size, @dbt_ram_bytes
-- Requires RAM, which no MySQL variable reports. The runner supplies it from
-- /proc/meminfo or .db-triage.yml baseline.ram_gb; without it this check emits
-- nothing rather than guessing, and the runner records it skipped with reason
-- `os`. MY-MEM-007 computes the full worst-case commitment, of which the pool
-- is only the fixed part.
-- The buffer pool is not the server's whole footprint: add the log buffer, the
-- per-connection buffers, the temptable pool and the OS page cache the redo and
-- binary logs need. Crossing 80% of RAM is where hosts start swapping, and a
-- swapping buffer pool is slower than no buffer pool.
SELECT
  'MY-MEM-003' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_size' AS object,
  CONCAT('Buffer pool is ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB of ', ROUND(@dbt_ram_bytes / 1073741824, 1), ' GB host RAM (',
         ROUND(100.0 * @@GLOBAL.innodb_buffer_pool_size / @dbt_ram_bytes, 1),
         '%, threshold ', ROUND(100 * COALESCE(@pool_ram_ceiling, 0.80), 0), '%). ',
         'That leaves ', ROUND((@dbt_ram_bytes - @@GLOBAL.innodb_buffer_pool_size) / 1073741824, 2),
         ' GB for up to ', @@GLOBAL.max_connections,
         ' connections'' per-session buffers, the redo log buffer and the OS page cache. See MY-MEM-007 for the worst-case total.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'ram_bytes', @dbt_ram_bytes,
    'ratio', ROUND(@@GLOBAL.innodb_buffer_pool_size / @dbt_ram_bytes, 4),
    'threshold_ratio', COALESCE(@pool_ram_ceiling, 0.80),
    'max_connections', @@GLOBAL.max_connections) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @dbt_ram_bytes IS NOT NULL
  AND @dbt_ram_bytes > 0
  AND @@GLOBAL.innodb_buffer_pool_size >= @dbt_ram_bytes * COALESCE(@pool_ram_ceiling, 0.80);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-004' AS marker;
-- check: MY-MEM-004
-- title: Buffer pool read miss rate high
-- priority: 100 | category: MEM | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: miss_ratio=0.05;min_read_requests=10000000
-- reads: @dbt_s_innodb_buffer_pool_reads, @dbt_s_innodb_buffer_pool_read_requests
-- Innodb_buffer_pool_reads counts logical reads that had to go to disk;
-- read_requests counts all logical reads. The ratio is a since-restart average,
-- so it hides both the warm-up after a restart and any recent change — hence
-- the confidence tracking the counter window and the explicit window in the text.
-- The 10 M request floor keeps a freshly started server from firing on a handful
-- of reads that were all misses.
SELECT
  'MY-MEM-004' AS check_id,
  'cluster'    AS scope,
  'buffer-pool-hit-rate' AS object,
  CONCAT(ROUND(100.0 * r.misses / r.reqs, 2), '% of ', FORMAT(r.reqs, 0),
         ' logical reads went to disk since restart ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days ago (threshold ', ROUND(100 * COALESCE(@miss_ratio, 0.05), 1), '%). ',
         'Buffer pool is ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB. This is an average over the whole window, so a recent regression is diluted and a warm-up after restart is included. ',
         'innodb_buffer_pool_dump_at_shutdown = ', @@GLOBAL.innodb_buffer_pool_dump_at_shutdown, '.') AS details,
  JSON_OBJECT(
    'buffer_pool_reads', r.misses,
    'buffer_pool_read_requests', r.reqs,
    'miss_ratio', ROUND(r.misses / r.reqs, 5),
    'threshold_ratio', COALESCE(@miss_ratio, 0.05),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS DECIMAL(30, 0))         AS misses,
         CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS DECIMAL(30, 0)) AS reqs
) AS r
WHERE r.reqs >= COALESCE(@min_read_requests, 10000000)
  AND r.misses / r.reqs >= COALESCE(@miss_ratio, 0.05);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-005' AS marker;
-- check: MY-MEM-005
-- title: Implicit temporary tables spilling to disk
-- priority: 100 | category: MEM | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: disk_tmp_ratio=0.25;disk_tmp_per_hour=1000
-- reads: @dbt_s_created_tmp_tables, @dbt_s_created_tmp_disk_tables,
--        @@GLOBAL.tmp_table_size, @@GLOBAL.max_heap_table_size, @dbt_v_temptable_max_ram
-- MySQL-specific hazard with no PostgreSQL analogue: Postgres spills per operator
-- against work_mem, MySQL materialises whole intermediate results as tables and
-- moves them to disk wholesale when they exceed the limit.
-- Version divergence: MySQL 8.0 replaced the MEMORY engine for internal temp
-- tables with TempTable, governed by temptable_max_ram (default 1 GB) rather
-- than tmp_table_size, and spills to mmapped files or InnoDB; MariaDB still uses
-- max_heap_table_size / tmp_table_size and aria/innodb on disk. Both limits are
-- reported so the right lever is obvious.
-- The usual real cause is a TEXT/BLOB column in a GROUP BY or ORDER BY, which
-- forces on-disk regardless of size on MySQL 5.7 and MariaDB.
SELECT
  'MY-MEM-005' AS check_id,
  'cluster'    AS scope,
  'internal-temp-tables' AS object,
  CONCAT(FORMAT(t.disk, 0), ' of ', FORMAT(t.total, 0),
         ' internal temporary tables (', ROUND(100.0 * t.disk / t.total, 1),
         '%, threshold ', ROUND(100 * COALESCE(@disk_tmp_ratio, 0.25), 0),
         '%) were written to disk since restart, ', ROUND(t.disk_per_hour, 0),
         '/h over ', ROUND(@dbt_uptime_s / 3600, 1), ' h. ',
         'tmp_table_size = ', ROUND(@@GLOBAL.tmp_table_size / 1048576, 1),
         ' MB, max_heap_table_size = ', ROUND(@@GLOBAL.max_heap_table_size / 1048576, 1), ' MB',
         IF(@dbt_v_temptable_max_ram IS NOT NULL,
            CONCAT(', temptable_max_ram = ', ROUND(@dbt_v_temptable_max_ram / 1048576, 0),
                   ' MB (MySQL 8.0 uses TempTable, so this is the limit that matters)'),
            ' (this fork uses the MEMORY engine for internal temp tables)'),
         '. Raising the limits is per-session memory; a TEXT/BLOB column in GROUP BY or ORDER BY forces disk regardless of size, so check MY-QRY-007 for the statements responsible.') AS details,
  JSON_OBJECT(
    'created_tmp_tables', t.total,
    'created_tmp_disk_tables', t.disk,
    'disk_ratio', ROUND(t.disk / t.total, 4),
    'disk_per_hour', ROUND(t.disk_per_hour, 1),
    'threshold_ratio', COALESCE(@disk_tmp_ratio, 0.25),
    'tmp_table_size', @@GLOBAL.tmp_table_size,
    'max_heap_table_size', @@GLOBAL.max_heap_table_size,
    'temptable_max_ram', IFNULL(@dbt_v_temptable_max_ram, 'n/a')) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_created_tmp_tables, 0) AS DECIMAL(30, 0))      AS total,
         CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS DECIMAL(30, 0)) AS disk,
         CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS DECIMAL(30, 0)) / @dbt_uptime_h AS disk_per_hour
) AS t
WHERE t.total > 0
  AND t.disk / t.total >= COALESCE(@disk_tmp_ratio, 0.25)
  AND t.disk_per_hour >= COALESCE(@disk_tmp_per_hour, 1000);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-006' AS marker;
-- check: MY-MEM-006
-- title: Oversized per-session buffers
-- priority: 100 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: session_buffer_bytes=8388608
-- reads: @@GLOBAL.sort_buffer_size, join_buffer_size, read_buffer_size, read_rnd_buffer_size
-- All four are universal and all four are allocated PER SESSION, and for
-- sort_buffer_size and join_buffer_size potentially more than once per query.
-- At 8 MB and 500 connections that is 4 GB of commitment that does not appear
-- in the buffer pool figure. Worse, a large sort_buffer_size is actively slower:
-- MySQL allocates and touches the whole buffer for sorts that need a fraction of
-- it, so raising it globally to fix one query penalises every other query.
-- The right fix is nearly always to set it per session for the one statement
-- that needs it, which is why this is P100 and not a tuning suggestion.
SELECT
  'MY-MEM-006' AS check_id,
  'setting'    AS scope,
  b.name       AS object,
  CONCAT(b.name, ' = ', ROUND(b.val / 1048576, 1), ' MB globally (threshold ',
         ROUND(COALESCE(@session_buffer_bytes, 8388608) / 1048576, 0),
         ' MB). This is allocated per session', 
         IF(b.name IN ('sort_buffer_size', 'join_buffer_size'),
            ' and can be allocated more than once per query', ''),
         ', so at max_connections = ', @@GLOBAL.max_connections,
         ' the worst case is ', ROUND(b.val * @@GLOBAL.max_connections / 1073741824, 1),
         ' GB for this buffer alone',
         IF(b.name = 'sort_buffer_size',
            '. A large sort_buffer_size also slows small sorts, because the whole buffer is allocated and touched regardless of how much of it the sort needs.',
            '.'),
         ' Set it per session for the statement that needs it instead.') AS details,
  JSON_OBJECT(
    'variable', b.name,
    'value_bytes', b.val,
    'threshold_bytes', COALESCE(@session_buffer_bytes, 8388608),
    'max_connections', @@GLOBAL.max_connections,
    'worst_case_bytes', b.val * @@GLOBAL.max_connections) AS evidence_json,
  'high' AS confidence
FROM (
            SELECT 'sort_buffer_size'     AS name, @@GLOBAL.sort_buffer_size     AS val
  UNION ALL SELECT 'join_buffer_size',          @@GLOBAL.join_buffer_size
  UNION ALL SELECT 'read_buffer_size',          @@GLOBAL.read_buffer_size
  UNION ALL SELECT 'read_rnd_buffer_size',      @@GLOBAL.read_rnd_buffer_size
) AS b
WHERE b.val >= COALESCE(@session_buffer_bytes, 8388608);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-008' AS marker;
-- check: MY-MEM-008
-- title: Table open cache too small, or open-file limit at risk
-- priority: 100 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: overflows_per_minute=1;opened_tables_per_second=10;open_files_ratio=0.80
-- reads: @dbt_s_table_open_cache_overflows, @dbt_s_opened_tables, @dbt_s_open_files,
--        @@GLOBAL.table_open_cache, @@GLOBAL.open_files_limit, @dbt_v_table_definition_cache
-- Covers both halves of the design's row: cache pressure and the file-descriptor
-- ceiling behind it. Table_open_cache_overflows exists in MySQL 5.6.6+ and
-- MariaDB 10.1+; where it is missing the Opened_tables rate carries the check.
-- Every cache miss reopens a table: a file descriptor, a metadata lock and a
-- .frm/data-dictionary read. At tens per second that is pure overhead, and it
-- also multiplies the open-file count, which is capped by open_files_limit and
-- ultimately by the OS.
SELECT
  'MY-MEM-008' AS check_id,
  'setting'    AS scope,
  IF(f.fd_ratio >= COALESCE(@open_files_ratio, 0.80), 'open_files_limit', 'table_open_cache') AS object,
  CONCAT(CONCAT_WS('; ',
    IF(f.overflow_per_min >= COALESCE(@overflows_per_minute, 1),
       CONCAT('Table_open_cache_overflows = ', FORMAT(f.overflows, 0), ' (',
              ROUND(f.overflow_per_min, 1), '/min) against table_open_cache = ',
              @@GLOBAL.table_open_cache), NULL),
    IF(f.opened_per_sec >= COALESCE(@opened_tables_per_second, 10),
       CONCAT('Opened_tables = ', FORMAT(f.opened, 0), ' (', ROUND(f.opened_per_sec, 1),
              '/s) — tables are being reopened continuously'), NULL),
    IF(f.fd_ratio >= COALESCE(@open_files_ratio, 0.80),
       CONCAT('Open_files = ', FORMAT(f.open_files, 0), ' of open_files_limit ',
              @@GLOBAL.open_files_limit, ' (', ROUND(100 * f.fd_ratio, 0),
              '%) — new connections and table opens fail once this is reached'), NULL)),
    '. Measured over ', ROUND(@dbt_uptime_s / 3600, 1), ' h of uptime. table_definition_cache = ',
    IFNULL(@dbt_v_table_definition_cache, 'unknown'),
    '. Raising table_open_cache also raises the file-descriptor requirement.') AS details,
  JSON_OBJECT(
    'table_open_cache_overflows', f.overflows,
    'overflows_per_minute', ROUND(f.overflow_per_min, 2),
    'opened_tables', f.opened,
    'opened_tables_per_second', ROUND(f.opened_per_sec, 2),
    'open_files', f.open_files,
    'open_files_limit', @@GLOBAL.open_files_limit,
    'table_open_cache', @@GLOBAL.table_open_cache,
    'table_definition_cache', IFNULL(@dbt_v_table_definition_cache, 'n/a')) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_s_table_open_cache_overflows, 0) AS DECIMAL(30, 0)) AS overflows,
    CAST(IFNULL(@dbt_s_table_open_cache_overflows, 0) AS DECIMAL(30, 0)) / (@dbt_uptime_h * 60) AS overflow_per_min,
    CAST(IFNULL(@dbt_s_opened_tables, 0) AS DECIMAL(30, 0)) AS opened,
    CAST(IFNULL(@dbt_s_opened_tables, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) AS opened_per_sec,
    CAST(IFNULL(@dbt_s_open_files, 0) AS DECIMAL(30, 0)) AS open_files,
    CAST(IFNULL(@dbt_s_open_files, 0) AS DECIMAL(30, 0)) / GREATEST(@@GLOBAL.open_files_limit, 1) AS fd_ratio
) AS f
WHERE f.overflow_per_min >= COALESCE(@overflows_per_minute, 1)
   OR f.opened_per_sec >= COALESCE(@opened_tables_per_second, 10)
   OR f.fd_ratio >= COALESCE(@open_files_ratio, 0.80);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-001' AS marker;
-- check: MY-QRY-001
-- title: performance_schema disabled
-- priority: 100 | category: QRY | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.performance_schema
-- A META-shaped finding that lives in QRY because it is about workload
-- visibility: with performance_schema OFF there are no statement digests, no
-- index usage counters and no replication applier tables, so MY-QRY-002 and
-- 004..011, MY-IDX-001..005, MY-REPL-001..004/010/013 and MY-CONN-005 cannot run
-- at all. The runner records every one of them in XX-META-001 with reason
-- `privilege`, and this row explains why.
-- Default divergence: MySQL 5.6+ ships performance_schema ON. MariaDB ships it
-- OFF by default to this day (10.11 included) — so on MariaDB this is usually an
-- unreviewed default rather than a decision, and the details say so.
-- It cannot be turned on without a restart on either fork.
-- The cost of turning it on is real but modest with the default instrumentation:
-- a few hundred MB of memory and single-digit percent overhead. The cost of
-- leaving it off is that roughly a quarter of this catalog is blind.
SELECT
  'MY-QRY-001' AS check_id,
  'setting'    AS scope,
  'performance_schema' AS object,
  CONCAT('performance_schema = OFF. ',
         IF(@dbt_is_mariadb,
            'MariaDB ships it OFF by default, so this is probably an unreviewed default rather than a decision.',
            'MySQL ships it ON by default, so it was disabled deliberately.'),
         ' Without it there are no statement digests, no per-index usage counters and no replication applier tables, so these checks cannot run: ',
         'MY-QRY-002, MY-QRY-004 to MY-QRY-011, MY-IDX-001 to MY-IDX-005, MY-REPL-001 to MY-REPL-004, MY-REPL-010, MY-REPL-013, MY-CONN-005. ',
         'That is a large fraction of the workload and index sections of this report. ',
         'Enabling it needs a server restart on both forks; with the default instrumentation it costs a few hundred MB of memory and low single-digit percent overhead. ',
         'sys schema present: ', IF(IFNULL(@dbt_sys_view_count, 0) > 0, 'yes (but its views return nothing without performance_schema)', 'no'), '.') AS details,
  JSON_OBJECT(
    'performance_schema', 'OFF',
    'fork', @dbt_fork,
    'sys_views', IFNULL(@dbt_sys_view_count, 0),
    'checks_disabled', 'MY-QRY-002,MY-QRY-004..011,MY-IDX-001..005,MY-REPL-001..004,MY-REPL-010,MY-REPL-013,MY-CONN-005') AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.performance_schema = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-003' AS marker;
-- check: MY-QRY-003
-- title: Slow query log off, or its threshold at the default
-- priority: 100 | category: QRY | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: long_query_seconds=10;recommended_long_query_seconds=1
-- reads: @@GLOBAL.slow_query_log, @@GLOBAL.long_query_time,
--        @dbt_v_log_slow_extra (MySQL 8.0.14+) / @dbt_v_log_slow_verbosity (MariaDB)
-- Complements rather than duplicates performance_schema: the digest table gives
-- aggregates but no individual execution, no parameter values and no timestamp.
-- The slow log gives the actual statement text of the actual slow execution,
-- which is what pt-query-digest consumes and what you need to reproduce a
-- problem that happened at 03:00.
-- The default long_query_time of 10 s is the real finding on most servers: a
-- statement has to take ten seconds to be recorded, so the 200 ms statement
-- executed forty thousand times an hour — which is where the load actually is —
-- never appears. 0.5 to 1 s is the usual working setting.
-- Fork divergence in the extra-detail variable: MySQL 8.0.14+ has log_slow_extra
-- (adds rows examined, tmp tables, etc. to each entry); MariaDB has
-- log_slow_verbosity with a different value syntax. Both read from the bundle.
SELECT
  'MY-QRY-003' AS check_id,
  'setting'    AS scope,
  IF(@@GLOBAL.slow_query_log = 0, 'slow_query_log', 'long_query_time') AS object,
  CONCAT(IF(@@GLOBAL.slow_query_log = 0,
            'slow_query_log = OFF, so no slow statement is recorded anywhere with its actual text, parameters or timestamp. ',
            CONCAT('slow_query_log = ON but long_query_time = ', @@GLOBAL.long_query_time,
                   ' s, the shipped default. A statement must take ten seconds to be recorded, so the 200 ms statement running forty thousand times an hour — where the load usually is — never appears. ')),
         'performance_schema digests give aggregates but never an individual execution, its parameter values or when it ran; the slow log is what pt-query-digest reads and what lets you reproduce a 03:00 incident. ',
         'Recommended threshold: ', COALESCE(@recommended_long_query_seconds, 1), ' s or lower. ',
         'Extra detail per entry: ',
         IFNULL(COALESCE(@dbt_v_log_slow_extra, @dbt_v_log_slow_verbosity),
                'not available on this version'),
         '. log_output = ', @@GLOBAL.log_output,
         '; log_queries_not_using_indexes = ', CAST(@@GLOBAL.log_queries_not_using_indexes AS CHAR),
         ' (leave that OFF on a busy server — it logs every small unindexed lookup and can fill a disk).') AS details,
  JSON_OBJECT(
    'slow_query_log', CAST(@@GLOBAL.slow_query_log AS CHAR),
    'long_query_time', @@GLOBAL.long_query_time,
    'log_output', @@GLOBAL.log_output,
    'log_queries_not_using_indexes', CAST(@@GLOBAL.log_queries_not_using_indexes AS CHAR),
    'log_slow_extra', IFNULL(@dbt_v_log_slow_extra, 'n/a'),
    'log_slow_verbosity', IFNULL(@dbt_v_log_slow_verbosity, 'n/a'),
    'threshold_seconds', COALESCE(@long_query_seconds, 10)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.slow_query_log = 0
   OR @@GLOBAL.long_query_time >= COALESCE(@long_query_seconds, 10);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-010' AS marker;
-- check: MY-QRY-010
-- title: One statement digest dominates total latency
-- priority: 100 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: dominance_ratio=0.25;min_executions=1000
-- reads: performance_schema.events_statements_summary_by_digest
-- Derived from the same data as MY-QRY-004 but stated as a finding rather than a
-- list, because a single digest taking a quarter of all statement time is a
-- structural fact about the workload: it means one query is the server's
-- capacity limit, and tuning anything else first is wasted effort.
-- The percentage is understated whenever MY-QRY-002 reports lost digests, and
-- the window is since restart, so both are named in the details.
SET @dbt_q := "
SELECT
  'MY-QRY-010' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT('A single statement digest accounts for ',
         ROUND(100.0 * d.SUM_TIMER_WAIT / d.grand_total, 1),
         '% of all statement execution time on this server (threshold ',
         ROUND(100 * COALESCE(@dominance_ratio, 0.25), 0), '%), over ',
         FORMAT(d.COUNT_STAR, 0), ' executions totalling ',
         ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s, averaging ',
         ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms each. ',
         'Rows examined per row sent: ',
         ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1),
         '. This one statement is the server''s capacity limit; tuning anything else first has a smaller ceiling than fixing this. ',
         'Window: since restart ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days ago. The percentage is understated if MY-QRY-002 reported lost digests. ',
         'Schema ', IFNULL(d.SCHEMA_NAME, '(none)'), '. Statement: ',
         SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', IFNULL(d.SCHEMA_NAME, ''),
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / d.grand_total, 2),
    'threshold_ratio', COALESCE(@dominance_ratio, 0.25),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
) AS d
WHERE d.grand_total > 0
  AND d.COUNT_STAR >= COALESCE(@min_executions, 1000)
  AND d.SUM_TIMER_WAIT >= d.grand_total * COALESCE(@dominance_ratio, 0.25)";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-012' AS marker;
-- check: MY-QRY-012
-- title: Join and scan counters high
-- priority: 100 | category: QRY | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: full_join_ratio=0.01;scan_ratio=0.20;min_questions=100000
-- reads: @dbt_s_select_full_join, @dbt_s_select_scan, @dbt_s_select_range_check,
--        @dbt_s_questions
-- Server-wide counters, available identically on both forks and — unlike the
-- digest table — not dependent on performance_schema. That makes this the
-- fallback signal when MY-QRY-001 has fired.
-- Select_full_join counts joins performed with NO index on the joined table.
-- These are the expensive ones: MySQL's block nested loop reads the whole inner
-- table for each batch of outer rows, so cost grows with the product of the
-- table sizes. Even 1% of statements doing this is usually one query in a hot
-- path. MySQL 8.0.20+ replaced BNL with hash join for many of these, which makes
-- them faster but no less a sign of a missing index.
-- Select_scan counts full scans of the FIRST table in a join, which is far more
-- often legitimate — a small lookup table, a deliberate report — hence the much
-- higher 20% threshold and the softer wording.
SELECT
  'MY-QRY-012' AS check_id,
  'cluster'    AS scope,
  IF(q.full_join_ratio >= COALESCE(@full_join_ratio, 0.01), 'Select_full_join', 'Select_scan') AS object,
  CONCAT('Over ', FORMAT(q.questions, 0), ' statements since restart ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago: ',
         CONCAT_WS('; ',
           IF(q.full_join_ratio >= COALESCE(@full_join_ratio, 0.01),
              CONCAT('Select_full_join = ', FORMAT(q.full_join, 0), ' (',
                     ROUND(100 * q.full_join_ratio, 2),
                     '%) — joins performed with no index on the joined table, where cost grows with the product of the table sizes'), NULL),
           IF(q.scan_ratio >= COALESCE(@scan_ratio, 0.20),
              CONCAT('Select_scan = ', FORMAT(q.scan_n, 0), ' (',
                     ROUND(100 * q.scan_ratio, 1),
                     '%) — full scans of the first table in a join, which is often legitimate for small lookup tables and reports'), NULL),
           IF(q.range_check > 0,
              CONCAT('Select_range_check = ', FORMAT(q.range_check, 0),
                     ' — the optimizer had to re-decide the index for each outer row, which means no usable key on the join column'), NULL)),
         '. These counters do not need performance_schema, so they are the fallback when MY-QRY-001 has fired; MY-QRY-006 and MY-QRY-008 name the statements when it has not.') AS details,
  JSON_OBJECT(
    'questions', q.questions,
    'select_full_join', q.full_join,
    'select_scan', q.scan_n,
    'select_range_check', q.range_check,
    'full_join_ratio', ROUND(q.full_join_ratio, 5),
    'scan_ratio', ROUND(q.scan_ratio, 5),
    'threshold_full_join_ratio', COALESCE(@full_join_ratio, 0.01),
    'threshold_scan_ratio', COALESCE(@scan_ratio, 0.20),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    GREATEST(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)), 1) AS questions,
    CAST(IFNULL(@dbt_s_select_full_join, 0) AS DECIMAL(30, 0))       AS full_join,
    CAST(IFNULL(@dbt_s_select_scan, 0) AS DECIMAL(30, 0))            AS scan_n,
    CAST(IFNULL(@dbt_s_select_range_check, 0) AS DECIMAL(30, 0))     AS range_check,
    CAST(IFNULL(@dbt_s_select_full_join, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)), 1) AS full_join_ratio,
    CAST(IFNULL(@dbt_s_select_scan, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)), 1) AS scan_ratio
) AS q
WHERE q.questions >= COALESCE(@min_questions, 100000)
  AND (q.full_join_ratio >= COALESCE(@full_join_ratio, 0.01)
       OR q.scan_ratio >= COALESCE(@scan_ratio, 0.20));
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-003' AS marker;
-- check: MY-REL-003
-- title: Server version within six months of end of life
-- priority: 100 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: eol_warning_days=180;eol_as_of=2026-09-02
-- reads: as MY-REL-001
-- The lead time this finding exists to protect: a major-version upgrade on a
-- production database is a rehearsal, an application compatibility pass, a
-- replica-first rollout and a rollback plan. Six months is roughly the minimum
-- for that to happen calmly rather than as an incident, which is why the warning
-- comes here rather than at MY-REL-001 when the date has already passed.
SET @dbt_eol_as_of := IFNULL(@dbt_eol_as_of, '2026-09-02');
SET @dbt_q := "
SELECT
  'MY-REL-003' AS check_id,
  'cluster'    AS scope,
  CONCAT(v.fork, ' ', v.branch) AS object,
  CONCAT(v.fork, ' ', @@GLOBAL.version, ' (branch ', v.branch,
         ') reaches end of life on ', v.eol, ' — in ',
         DATEDIFF(v.eol, CURDATE()), ' days (threshold ',
         COALESCE(@eol_warning_days, 180), ' days). Next supported branch: ',
         v.successor, '. ',
         'A major upgrade on a production database needs a rehearsal, an application compatibility pass, a replica-first rollout and a rollback plan; ',
         DATEDIFF(v.eol, CURDATE()),
         ' days is enough to do that calmly and not much more. ',
         'Release data as of ', @dbt_eol_as_of, '.') AS details,
  JSON_OBJECT(
    'fork', v.fork, 'version', @@GLOBAL.version, 'branch', v.branch,
    'eol_date', v.eol, 'days_until_eol', DATEDIFF(v.eol, CURDATE()),
    'successor', v.successor,
    'threshold_days', COALESCE(@eol_warning_days, 180),
    'release_data_as_of', @dbt_eol_as_of) AS evidence_json,
  IF(DATEDIFF(CURDATE(), @dbt_eol_as_of) > 365, 'low', 'high') AS confidence
FROM (BRANCHES) AS v
WHERE v.eol >= CURDATE()
  AND DATEDIFF(v.eol, CURDATE()) <= COALESCE(@eol_warning_days, 180)";
-- The release table is redefined here rather than inherited from MY-REL-001,
-- so this check still works when the runner is invoked with --only MY-REL-002.
-- The release table. Matched on fork + major.minor.
SET @dbt_branches := "
  SELECT b.* FROM (
              SELECT 'mysql'   AS fork, '5.7'   AS branch, '2023-10-31' AS eol, '8.4 LTS' AS successor
    UNION ALL SELECT 'mysql',   '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'mysql',   '8.4',   '2032-04-30', '9.x innovation / the next LTS'
    UNION ALL SELECT 'percona', '5.7',   '2023-10-31', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.0',   '2026-04-30', '8.4 LTS'
    UNION ALL SELECT 'percona', '8.4',   '2032-04-30', 'the next LTS'
    UNION ALL SELECT 'mariadb', '10.4',  '2024-06-18', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.5',  '2025-06-24', '10.11 LTS'
    UNION ALL SELECT 'mariadb', '10.6',  '2026-07-06', '10.11 LTS or 11.4 LTS'
    UNION ALL SELECT 'mariadb', '10.11', '2028-02-16', '11.4 LTS'
    UNION ALL SELECT 'mariadb', '11.4',  '2029-05-29', '11.8 LTS'
    UNION ALL SELECT 'mariadb', '11.8',  '2030-06-04', 'the next LTS'
  ) AS b
  WHERE b.fork = @dbt_fork
    AND b.branch = CONCAT(@dbt_vmajor, '.', @dbt_vminor)";

SET @dbt_q := REPLACE(@dbt_q, 'BRANCHES', @dbt_branches);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-006' AS marker;
-- check: MY-REL-006
-- title: No evidence of a monitoring agent
-- priority: 100 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS, SELECT ON mysql.*
-- thresholds: (none)
-- reads: information_schema.PROCESSLIST (USER, HOST), information_schema.USER_PRIVILEGES
-- CONFIDENCE IS LOW AND THE WORDING IS "NO EVIDENCE OF", NOT "NO MONITORING".
-- This is the design's absence-of-evidence rule applied literally: an agent that
-- polls once a minute is almost never connected at the instant of the snapshot,
-- an agent may connect as a generically named account, and a metrics exporter
-- may scrape through a proxy. All three produce a false positive here.
-- What the check actually establishes is that no account and no connected
-- session carries a recognisable monitoring name, which is worth one question.
-- Recognised names cover the common agents: Percona PMM, Datadog, New Relic,
-- Zabbix, Nagios, Prometheus/mysqld_exporter, Grafana, Dynatrace, SolarWinds,
-- AppDynamics, Netdata, VividCortex/SolarWinds DPM, and Telegraf.
SET @dbt_mon_pat := 'pmm|percona|datadog|dd_|newrelic|new_relic|nrmysql|zabbix|nagios|icinga|prometheus|exporter|grafana|dynatrace|solarwinds|vividcortex|appdynamics|netdata|telegraf|monitor|metrics|observ';
SET @dbt_q := "
SELECT
  'MY-REL-006' AS check_id,
  'cluster'    AS scope,
  'monitoring' AS object,
  CONCAT('No account or connected session has a name matching a known monitoring agent. ',
         'Accounts on this server: ', a.n_accounts, ' (', a.sample, '). ',
         'Sessions at snapshot: ', p.n_sessions, ' from ', p.n_users, ' distinct account(s). ',
         'THIS IS ABSENCE OF EVIDENCE, NOT EVIDENCE OF ABSENCE: an agent polling once a minute is usually not connected at the instant of a snapshot, an agent may use a generic account name, and a metrics exporter may scrape through a proxy. Any of those produces this finding on a well-monitored server. ',
         'What it is worth is one question: what watches this database, and would it have paged someone for the P1 and P5 findings above? ',
         'Record the answer in .db-triage.yml so this stops firing.') AS details,
  JSON_OBJECT(
    'monitoring_accounts_found', 0,
    'account_count', a.n_accounts,
    'session_count', p.n_sessions,
    'distinct_session_users', p.n_users,
    'basis', 'name pattern match on accounts and current sessions',
    'patterns', @dbt_mon_pat) AS evidence_json,
  'low' AS confidence
FROM (
  SELECT COUNT(DISTINCT GRANTEE) AS n_accounts,
         SUBSTRING(GROUP_CONCAT(DISTINCT GRANTEE SEPARATOR ', '), 1, 300) AS sample,
         SUM(GRANTEE REGEXP @dbt_mon_pat) AS monitoring_accounts
    FROM information_schema.USER_PRIVILEGES
) AS a,
(
  SELECT COUNT(*) AS n_sessions,
         COUNT(DISTINCT USER) AS n_users,
         SUM(IFNULL(USER, '') REGEXP @dbt_mon_pat) AS monitoring_sessions
    FROM information_schema.PROCESSLIST
) AS p
WHERE IFNULL(a.monitoring_accounts, 0) = 0
  AND IFNULL(p.monitoring_sessions, 0) = 0";
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-010' AS marker;
-- check: MY-REL-010
-- title: Persisted variables override the configuration files
-- priority: 100 | category: REL | scope: setting | cost: 0 | pass: fast
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: performance_schema.persisted_variables, performance_schema.variables_info
-- MySQL 8.0 only. SET PERSIST writes to mysqld-auto.cnf in the data directory,
-- which is read AFTER every other configuration file — so a persisted value
-- silently wins over my.cnf, over the packaging defaults and over whatever the
-- configuration-management system believes it applied.
-- MariaDB has no SET PERSIST and no persisted_variables table (verified absent
-- on 10.11), so the check emits nothing there.
-- The failure this catches: someone fixes an incident at 03:00 with SET PERSIST,
-- the change is invisible in every file under version control, and six months
-- later a rebuilt server behaves differently from its predecessor for reasons
-- nobody can find. VARIABLE_SOURCE in variables_info distinguishes PERSISTED
-- from EXPLICIT (a file) and shows which file and line a file-sourced value
-- came from.
SET @dbt_q := "
SELECT
  'MY-REL-010' AS check_id,
  'setting'    AS scope,
  p.VARIABLE_NAME AS object,
  CONCAT('`', p.VARIABLE_NAME, '` is persisted in mysqld-auto.cnf with value ''',
         SUBSTRING(p.VARIABLE_VALUE, 1, 120), '''',
         IFNULL(CONCAT(', set by ', p.SET_USER, '@', p.SET_HOST, ' on ', p.SET_TIME), ''),
         '. The running value is ''', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 120),
         ''' with source ', IFNULL(i.VARIABLE_SOURCE, 'unknown'),
         IF(IFNULL(i.VARIABLE_PATH, '') <> '', CONCAT(' (', i.VARIABLE_PATH, ')'), ''), '. ',
         'mysqld-auto.cnf is read after every other configuration file, so this value wins over my.cnf and over anything configuration management applies. ',
         'A change made this way is invisible in version control, which is how a rebuilt server ends up behaving differently from its predecessor for no findable reason. ',
         'RESET PERSIST <name> removes it.') AS details,
  JSON_OBJECT(
    'variable', p.VARIABLE_NAME,
    'persisted_value', SUBSTRING(p.VARIABLE_VALUE, 1, 500),
    'running_value', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 500),
    'variable_source', IFNULL(i.VARIABLE_SOURCE, 'unknown'),
    'variable_path', IFNULL(i.VARIABLE_PATH, ''),
    'set_by', CONCAT(IFNULL(p.SET_USER, ''), '@', IFNULL(p.SET_HOST, '')),
    'set_time', CAST(p.SET_TIME AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM performance_schema.persisted_variables AS p
LEFT JOIN performance_schema.global_variables AS g ON g.VARIABLE_NAME = p.VARIABLE_NAME
LEFT JOIN performance_schema.variables_info  AS i ON i.VARIABLE_NAME = p.VARIABLE_NAME
ORDER BY p.VARIABLE_NAME";
SET @dbt_q := IF(IFNULL(@dbt_has_persisted_variables, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1,
                 @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-011' AS marker;
-- check: MY-REPL-011
-- title: Single-threaded replica applier while lagging
-- priority: 100 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: lag_warn_seconds=30
-- reads: @dbt_v_replica_parallel_workers / @dbt_v_slave_parallel_workers, @dbt_repl_lag_s
-- Name divergence: MySQL 8.0.26+ replica_parallel_workers (default 4 from
-- 8.0.27), older MySQL and all MariaDB slave_parallel_workers (default 0).
-- Both spellings are COALESCEd from the bundle.
-- Derived: only fires when lag is already measurable, so a healthy replica that
-- happens to run one applier thread is not nagged. Where lag is unreadable
-- (MariaDB, see MY-REPL-003) this check cannot fire either — that gap is
-- documented rather than worked around with a guess.
SELECT
  'MY-REPL-011' AS check_id,
  'setting'     AS scope,
  IF(@dbt_v_replica_parallel_workers IS NOT NULL, 'replica_parallel_workers', 'slave_parallel_workers') AS object,
  CONCAT('Replica is ', FORMAT(@dbt_repl_lag_s, 0), ' s behind and applies transactions with ',
         w.workers, ' worker thread(s). ',
         'A single applier serialises everything the source committed in parallel, so lag grows under any write burst. ',
         'binlog_transaction_dependency_tracking on the source = ',
         IFNULL(@dbt_v_binlog_transaction_dependency_tracking, 'not readable here'),
         ' (WRITESET lets replicas parallelise much more aggressively).') AS details,
  JSON_OBJECT(
    'parallel_workers', w.workers,
    'lag_seconds', @dbt_repl_lag_s,
    'threshold_seconds', COALESCE(@lag_warn_seconds, 30),
    'dependency_tracking', IFNULL(@dbt_v_binlog_transaction_dependency_tracking, 'n/a')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(COALESCE(@dbt_v_replica_parallel_workers, @dbt_v_slave_parallel_workers, 0) AS SIGNED) AS workers
) AS w
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND @dbt_repl_lag_s IS NOT NULL
  AND @dbt_repl_lag_s >= COALESCE(@lag_warn_seconds, 30)
  AND w.workers <= 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-013' AS marker;
-- check: MY-REPL-013
-- title: Replication heartbeat or connection retry misconfigured
-- priority: 100 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: max_retry_interval=600;min_heartbeat_seconds=0
-- reads: performance_schema.replication_connection_configuration
--        (CONNECTION_RETRY_INTERVAL, CONNECTION_RETRY_COUNT, HEARTBEAT_INTERVAL)
--        via @dbt_repl_retry_* / @dbt_repl_heartbeat, set in 01_session.sql §6c
-- These three columns exist under the same names on MySQL 5.7+ and MariaDB
-- 10.5+ (verified on 10.11), so no branch is needed — unlike SHOW REPLICA
-- STATUS's Connect_Retry / Source_Retry_Count, which cannot be selected from.
-- A long retry interval means a dead source goes unnoticed for that long; a zero
-- heartbeat interval means the receiver only discovers a silently dropped
-- connection when slave_net_timeout expires, which defaults to 60 s and is often
-- raised to an hour.
SELECT
  'MY-REPL-013' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replication connection settings for ', IFNULL(@dbt_repl_source, 'the source'), ': ',
         CONCAT_WS('; ',
           IF(@dbt_repl_retry_interval >= COALESCE(@max_retry_interval, 600),
              CONCAT('retry interval ', @dbt_repl_retry_interval,
                     ' s — a dropped source goes unnoticed for that long between attempts'), NULL),
           IF(IFNULL(@dbt_repl_retry_count, 1) = 0,
              'retry count 0 — the receiver gives up after the first failed reconnect and stays down', NULL),
           IF(IFNULL(@dbt_repl_heartbeat, 0) = 0,
              'heartbeat interval 0 — a silently dropped TCP connection is only noticed when slave_net_timeout expires', NULL)),
         '.') AS details,
  JSON_OBJECT(
    'connection_retry_interval_seconds', @dbt_repl_retry_interval,
    'connection_retry_count', @dbt_repl_retry_count,
    'heartbeat_interval_seconds', @dbt_repl_heartbeat,
    'threshold_retry_interval', COALESCE(@max_retry_interval, 600)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND (@dbt_repl_retry_interval >= COALESCE(@max_retry_interval, 600)
       OR IFNULL(@dbt_repl_retry_count, 1) = 0
       OR IFNULL(@dbt_repl_heartbeat, 0) = 0);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-014' AS marker;
-- check: MY-REPL-014
-- title: binlog_row_image MINIMAL with logical consumers configured
-- priority: 100 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: interview
-- thresholds: (none)
-- reads: @@GLOBAL.binlog_row_image, @dbt_v_binlog_row_metadata
-- Requires the .db-triage.yml baseline to declare CDC consumers (Debezium,
-- Maxwell, Canal, a data-lake sink). Without that declaration the runner does
-- not surface this row, because MINIMAL is a perfectly good setting for a
-- topology whose only consumers are MySQL replicas — it is only wrong when
-- something downstream needs the unchanged columns of an UPDATE.
-- binlog_row_metadata (MySQL 8.0+; NULL on MariaDB) decides whether column names
-- and types travel with the events, which most CDC tools need to avoid
-- reconstructing the schema from a side channel.
SELECT
  'MY-REPL-014' AS check_id,
  'setting'     AS scope,
  'binlog_row_image' AS object,
  CONCAT('binlog_row_image = ', @@GLOBAL.binlog_row_image,
         ': row events carry only the primary key and the changed columns. ',
         'A logical consumer (CDC, a data lake sink, an audit stream) receives UPDATE events without the unchanged columns and without before-images, so it cannot reconstruct a full row. ',
         'binlog_row_metadata = ', IFNULL(@dbt_v_binlog_row_metadata,
            'not available on this fork; MariaDB always ships minimal metadata'),
         '.') AS details,
  JSON_OBJECT(
    'binlog_row_image', @@GLOBAL.binlog_row_image,
    'binlog_row_metadata', IFNULL(@dbt_v_binlog_row_metadata, 'n/a'),
    'binlog_format', @@GLOBAL.binlog_format) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_row_image) = 'MINIMAL';
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-002' AS marker;
-- check: MY-SCHEMA-002
-- title: InnoDB tables without a primary key
-- priority: 100 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_listed=20
-- reads: information_schema.TABLES, information_schema.STATISTICS (PRIMARY),
--        @@GLOBAL.binlog_format, @@GLOBAL.log_bin, @dbt_binlog_dump_threads
-- The lower-priority sibling of MY-SCHEMA-001: same defect, but binary logging
-- is off or set to STATEMENT, so the row-based-replication disaster (a full
-- table scan per row event on the replica) does not apply today. It applies the
-- moment anyone enables binary logging or attaches a replica, which is why this
-- is still reported rather than ignored.
-- The costs that apply regardless of replication: InnoDB assigns a hidden 6-byte
-- row id that every secondary index carries, rows have no useful clustering
-- order so range scans are random I/O, and several ALGORITHM=INPLACE online-DDL
-- paths are unavailable.
-- Detection is via information_schema.STATISTICS rather than TABLE_CONSTRAINTS
-- because it also reveals whether a usable unique NOT NULL index exists, which
-- is what the replication applier actually looks for.
SELECT
  'MY-SCHEMA-002' AS check_id,
  'relation'      AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('InnoDB table `', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` has no PRIMARY KEY',
         IF(IFNULL(k.unique_notnull, 0) > 0,
            CONCAT(' but does have ', k.unique_notnull,
                   ' unique NOT NULL index(es), which the row-based applier can use as a substitute'),
            ' and no unique NOT NULL index the row-based applier could use instead'),
         '. Size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1048576, 1), ' MB, ~',
         FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows, ', IFNULL(k.idx_count, 0), ' index(es). ',
         'log_bin = ', CAST(@@GLOBAL.log_bin AS CHAR), ', binlog_format = ',
         @@GLOBAL.binlog_format,
         '. Row-based replication is not in use here, so the replica full-scan hazard (MY-SCHEMA-001) does not apply yet — it starts applying the day binary logging is enabled or a replica is attached.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA,
    'table', t.TABLE_NAME,
    'bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'index_count', IFNULL(k.idx_count, 0),
    'unique_notnull_indexes', IFNULL(k.unique_notnull, 0),
    'binlog_format', @@GLOBAL.binlog_format,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'high' AS confidence
FROM information_schema.TABLES AS t
-- LEFT JOIN, not JOIN: a table with no indexes at all has NO rows in
-- information_schema.STATISTICS, and an inner join would silently drop exactly
-- the worst case — a table with neither a primary key nor any index.
LEFT JOIN (
  SELECT s.TABLE_SCHEMA, s.TABLE_NAME,
         COUNT(DISTINCT s.INDEX_NAME) AS idx_count,
         COUNT(DISTINCT IF(s.NON_UNIQUE = 0 AND s.NULLABLE = '', s.INDEX_NAME, NULL)) AS unique_notnull,
         MAX(s.INDEX_NAME = 'PRIMARY') AS has_pk
  FROM information_schema.STATISTICS AS s
  WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY s.TABLE_SCHEMA, s.TABLE_NAME
) AS k ON k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.ENGINE = 'InnoDB'
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND IFNULL(k.has_pk, 0) = 0
  AND NOT (@@GLOBAL.log_bin = 1 AND UPPER(@@GLOBAL.binlog_format) IN ('ROW', 'MIXED'))
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-008' AS marker;
-- check: MY-SCHEMA-008
-- title: Leftover online-schema-change artefacts
-- priority: 100 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.TABLES, information_schema.TRIGGERS
-- pt-online-schema-change and gh-ost both work by building a shadow copy of the
-- table and swapping it in. If the tool is killed — a lost SSH session is the
-- usual cause — the shadow table and, for pt-osc, THREE TRIGGERS on the original
-- table are left behind.
-- The triggers are the expensive part and the reason this is not just clutter:
-- every INSERT, UPDATE and DELETE on the production table continues to be
-- mirrored into an abandoned copy forever, roughly doubling write cost and
-- silently growing the shadow table until the disk notices.
-- Naming conventions matched: pt-osc uses _<table>_new and _<table>_old plus
-- pt_osc_%_{ins,upd,del} triggers; gh-ost uses _<table>_gho, _<table>_ghc and
-- _<table>_del. MySQL's own failed ALTER leaves #sql-* tables, also matched.
SELECT
  'MY-SCHEMA-008' AS check_id,
  'relation'      AS scope,
  CONCAT(x.sch, '.', x.nm) AS object,
  CONCAT('`', x.sch, '`.`', x.nm, '` is a ', x.kind,
         ' left behind by an interrupted online schema change (', x.tool, '), size ',
         ROUND(x.bytes / 1048576, 1), ' MB, created ', IFNULL(CAST(x.created AS CHAR), 'unknown'), '. ',
         IF(x.trigger_count > 0,
            CONCAT('There are also ', x.trigger_count,
                   ' pt-osc trigger(s) still attached to the original table: ', x.trigger_names,
                   '. Every write to the production table is still being mirrored into this abandoned copy, roughly doubling write cost and growing it without bound.'),
            'No matching triggers remain, so this is dead weight rather than an active cost — but confirm before dropping it that no schema change is in flight.')) AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'table', x.nm,
    'kind', x.kind,
    'tool', x.tool,
    'bytes', x.bytes,
    'created', CAST(x.created AS CHAR),
    'orphan_triggers', x.trigger_count,
    'trigger_names', x.trigger_names) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    t.TABLE_SCHEMA AS sch, t.TABLE_NAME AS nm,
    t.DATA_LENGTH + t.INDEX_LENGTH AS bytes,
    t.CREATE_TIME AS created,
    CASE
      WHEN t.TABLE_NAME LIKE '#sql-%' OR t.TABLE_NAME LIKE '#sql_%' THEN 'temporary ALTER table'
      WHEN t.TABLE_NAME LIKE '\_%\_old' THEN 'pre-swap original'
      ELSE 'shadow copy'
    END AS kind,
    CASE
      WHEN t.TABLE_NAME LIKE '\_%\_gho' OR t.TABLE_NAME LIKE '\_%\_ghc'
        OR t.TABLE_NAME LIKE '\_%\_del' THEN 'gh-ost'
      WHEN t.TABLE_NAME LIKE '#sql%'    THEN 'MySQL ALTER TABLE'
      ELSE 'pt-online-schema-change'
    END AS tool,
    (SELECT COUNT(*) FROM information_schema.TRIGGERS AS g
      WHERE g.TRIGGER_SCHEMA = t.TABLE_SCHEMA AND g.TRIGGER_NAME LIKE 'pt\_osc\_%') AS trigger_count,
    (SELECT SUBSTRING(GROUP_CONCAT(g.TRIGGER_NAME SEPARATOR ', '), 1, 250)
       FROM information_schema.TRIGGERS AS g
      WHERE g.TRIGGER_SCHEMA = t.TABLE_SCHEMA AND g.TRIGGER_NAME LIKE 'pt\_osc\_%') AS trigger_names
  FROM information_schema.TABLES AS t
  WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
    AND (t.TABLE_NAME LIKE '\_%\_new' OR t.TABLE_NAME LIKE '\_%\_old'
      OR t.TABLE_NAME LIKE '\_%\_gho' OR t.TABLE_NAME LIKE '\_%\_ghc'
      OR t.TABLE_NAME LIKE '\_%\_del' OR t.TABLE_NAME LIKE '#sql%')
) AS x;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-004' AS marker;
-- check: MY-SEC-004
-- title: Application accounts allowed from any host
-- priority: 100 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- Summary shape (DESIGN §2.1 form b): one finding with a count and the list,
-- because a fleet legitimately has many such accounts and one row each would
-- bury the report.
-- Confidence is LOW on purpose: a wildcard host is normal when a security group,
-- VPC or firewall already constrains who can reach the port, and db-triage
-- cannot see any of that. This is a review item, not a defect — which is exactly
-- how the design says absence-of-evidence checks must be phrased.
-- Accounts already reported by MY-SEC-002 (privileged AND wildcard) are excluded
-- so the P1 finding is not diluted by being restated at P100.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-004' AS check_id,
  'role'       AS scope,
  'wildcard-host-accounts' AS object,
  CONCAT(x.n, ' non-privileged account(s) may connect from any host: ', x.list,
         '. The server listens on ', @@GLOBAL.bind_address, ':', @@GLOBAL.port,
         ' and skip_name_resolve = ', CAST(@@GLOBAL.skip_name_resolve AS CHAR),
         '. This is only safe if a firewall, security group or private network already restricts who can reach the port — db-triage cannot see those, so confirm rather than assume.') AS details,
  JSON_OBJECT(
    'account_count', x.n,
    'accounts', x.list,
    'bind_address', @@GLOBAL.bind_address,
    'port', @@GLOBAL.port,
    'skip_name_resolve', CAST(@@GLOBAL.skip_name_resolve AS CHAR)) AS evidence_json,
  'low' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 600) AS list
  FROM (ACCTSRC) AS a
  WHERE a.is_role = 0
    AND a.account_locked = 0
    AND a.acct_user <> ''
    AND (a.acct_host IN ('%', '') OR a.acct_host LIKE '%\\%%')
    AND a.Super_priv <> 'Y'
    AND NOT a.has_all_privs
    AND a.acct_user NOT IN ACCTSYS
) AS x
WHERE x.n > 0
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-005' AS marker;
-- check: MY-SEC-005
-- title: TLS not enforced, or largely unused
-- priority: 100 | category: SEC | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: tls_usage_ratio=0.50
-- reads: @dbt_v_require_secure_transport, @dbt_v_have_ssl, @dbt_v_tls_version,
--        @dbt_s_ssl_accepts, @dbt_s_connections
-- Version divergence handled through the bundle: have_ssl was deprecated in
-- MySQL 8.0.26 and REMOVED in 8.4 (replaced by the performance_schema
-- tls_channel_status table); require_secure_transport arrived in MySQL 5.7.8 and
-- MariaDB 10.5. A NULL from the bundle means "this fork/version does not have
-- the variable", not "off".
-- Two separate statements, reported together because the fix differs:
--   * require_secure_transport OFF means an unencrypted connection is ACCEPTED,
--     even if most clients happen to use TLS;
--   * a low Ssl_accepts / Connections ratio means clients are in fact connecting
--     in the clear right now.
-- Per-account REQUIRE SSL clauses are not visible here, so a server that
-- enforces TLS through grants rather than globally will still fire — hence
-- medium confidence and the wording.
SELECT
  'MY-SEC-005' AS check_id,
  'setting'    AS scope,
  'require_secure_transport' AS object,
  CONCAT('require_secure_transport = ', IFNULL(@dbt_v_require_secure_transport,
            'not available on this version'),
         ', have_ssl/TLS availability = ', IFNULL(@dbt_v_have_ssl,
            'not reported (removed in MySQL 8.4; see performance_schema.tls_channel_status)'),
         ', tls_version = ', IFNULL(@dbt_v_tls_version, 'unknown'), '. ',
         IF(t.conns > 0,
            CONCAT(FORMAT(t.ssl_conns, 0), ' of ', FORMAT(t.conns, 0), ' connections since restart used TLS (',
                   ROUND(100.0 * t.ssl_conns / t.conns, 1), '%, threshold ',
                   ROUND(100 * COALESCE(@tls_usage_ratio, 0.50), 0), '%). '),
            ''),
         'Unencrypted connections are accepted, so credentials and result sets cross the network in the clear unless every client opts in. ',
         'Per-account REQUIRE SSL clauses are not visible from here, so confirm before treating this as unprotected.') AS details,
  JSON_OBJECT(
    'require_secure_transport', IFNULL(@dbt_v_require_secure_transport, 'n/a'),
    'have_ssl', IFNULL(@dbt_v_have_ssl, 'n/a'),
    'tls_version', IFNULL(@dbt_v_tls_version, 'n/a'),
    'ssl_accepts', t.ssl_conns,
    'connections', t.conns,
    'tls_ratio', IF(t.conns > 0, ROUND(t.ssl_conns / t.conns, 4), NULL),
    'threshold_ratio', COALESCE(@tls_usage_ratio, 0.50)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_ssl_accepts, 0) AS DECIMAL(30, 0)) AS ssl_conns,
         CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0))  AS conns
) AS t
WHERE UPPER(IFNULL(@dbt_v_require_secure_transport, 'OFF')) IN ('OFF', '0')
  AND (t.conns = 0 OR t.ssl_conns / t.conns < COALESCE(@tls_usage_ratio, 0.50));
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-009' AS marker;
-- check: MY-SEC-009
-- title: LOAD DATA LOCAL enabled
-- priority: 100 | category: SEC | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.local_infile
-- The threat runs the wrong way round from what the name suggests. With
-- local_infile ON, a malicious or compromised SERVER can answer any client query
-- with a request for a local file, and a client library that honours it will
-- upload that file — /etc/passwd, an SSH key, an application config — without
-- the user doing anything. The database is the attacker and the client is the
-- victim, which is why it is a server-side setting worth turning off even though
-- the exposure is client-side.
-- MySQL 8.0 and MariaDB 10.x both default it to OFF; finding it ON means an
-- import job needed it once. Universal variable, no version gate needed.
SELECT
  'MY-SEC-009' AS check_id,
  'setting'    AS scope,
  'local_infile' AS object,
  CONCAT('local_infile = ON. A compromised or hostile server can respond to any client query with a file-transfer request, and client libraries that honour LOAD DATA LOCAL will upload the named local file without user interaction. ',
         'secure_file_priv = ',
         IF(IFNULL(@dbt_v_secure_file_priv, '') = '', '(empty — see MY-SEC-010)',
            IFNULL(@dbt_v_secure_file_priv, 'unknown')),
         '. Both forks ship local_infile OFF, so this was enabled for an import and probably not turned back off.') AS details,
  JSON_OBJECT(
    'local_infile', 'ON',
    'secure_file_priv', IFNULL(@dbt_v_secure_file_priv, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.local_infile = 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-010' AS marker;
-- check: MY-SEC-010
-- title: FILE privilege unrestricted by secure_file_priv
-- priority: 100 | category: SEC | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: @dbt_v_secure_file_priv, normalised account source (FILE holders)
-- Derived: neither half is a finding alone. secure_file_priv empty means SELECT
-- ... INTO OUTFILE and LOAD_FILE() may read and write ANY path the mysqld OS
-- user can reach; that only matters if some account actually holds FILE.
-- Together they mean any of those accounts can read the server's private key,
-- /etc/shadow if mysqld runs as root, or any other database's data files, and
-- can write files into directories the OS user owns.
-- Empty string and NULL mean different things: NULL/absent (MySQL 5.7 default
-- on some builds) also disables the restriction; a path restricts to that
-- directory; the literal string 'NULL' disables the feature entirely, which is
-- the secure setting and is deliberately NOT flagged.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-010' AS check_id,
  'setting'    AS scope,
  'secure_file_priv' AS object,
  CONCAT('secure_file_priv is ',
         IF(IFNULL(@dbt_v_secure_file_priv, '') = '', 'empty', 'unset'),
         ', so file import and export are not restricted to any directory, and ',
         f.n, ' account(s) hold the FILE privilege: ', f.list, '. ',
         'Those accounts can read any file the mysqld OS user can read (including other databases'' data files and the server''s TLS private key) via LOAD_FILE(), and write files anywhere it can write via SELECT ... INTO OUTFILE. ',
         'Setting secure_file_priv to a dedicated directory, or to the literal NULL to disable file access entirely, closes this.') AS details,
  JSON_OBJECT(
    'secure_file_priv', IFNULL(@dbt_v_secure_file_priv, ''),
    'file_privilege_holders', f.n,
    'accounts', f.list,
    'local_infile', CAST(@@GLOBAL.local_infile AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 400) AS list
  FROM (ACCTSRC) AS a
  WHERE a.File_priv = 'Y' AND a.is_role = 0 AND a.acct_user NOT IN ACCTSYS
) AS f
WHERE f.n > 0
  AND IFNULL(@dbt_v_secure_file_priv, '') = ''
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-UNDO-004' AS marker;
-- check: MY-UNDO-004
-- title: Purge threads at default on a server that is not purging fast enough
-- priority: 100 | category: UNDO | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: hll_elevated=100000;purge_threads=4
-- reads: @@GLOBAL.innodb_purge_threads, @dbt_hll
-- Derived: only meaningful once the history list is already elevated, so it
-- never fires on a healthy server that happens to run the default. MySQL 8.0
-- defaults innodb_purge_threads to 4, MariaDB to 4 as well; on a write-heavy
-- server with a growing history list more threads is the first lever, and it
-- needs a restart, which is why this is P100 and not P50.
SELECT
  'MY-UNDO-004' AS check_id,
  'setting'     AS scope,
  'innodb_purge_threads' AS object,
  CONCAT('innodb_purge_threads = ', @@GLOBAL.innodb_purge_threads,
         ' while the history list length is ', FORMAT(@dbt_hll, 0),
         ' (above the ', FORMAT(COALESCE(@hll_elevated, 100000), 0),
         ' elevated threshold). Purge is the only consumer of undo and it is behind.',
         ' innodb_max_purge_lag = ', @@GLOBAL.innodb_max_purge_lag,
         ' (0 = no throttling of writers to let purge catch up).') AS details,
  JSON_OBJECT(
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads,
    'history_list_length', @dbt_hll,
    'innodb_max_purge_lag', @@GLOBAL.innodb_max_purge_lag,
    'innodb_max_purge_lag_delay', @@GLOBAL.innodb_max_purge_lag_delay) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_metrics_enabled, 0) = 1
  AND @dbt_hll >= COALESCE(@hll_elevated, 100000)
  AND @@GLOBAL.innodb_purge_threads <= COALESCE(@purge_threads, 4);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-WAL-002' AS marker;
-- check: MY-WAL-002
-- title: Redo log buffer waits
-- priority: 100 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: log_waits_per_hour=1
-- reads: @dbt_s_innodb_log_waits, @@GLOBAL.innodb_log_buffer_size
-- Innodb_log_waits counts the times a transaction had to wait for the redo log
-- buffer to be flushed because it was full. Every one of those is a writer
-- stalled on a resource that costs nothing but memory to enlarge. Both forks
-- expose the counter identically.
SELECT
  'MY-WAL-002' AS check_id,
  'setting'    AS scope,
  'innodb_log_buffer_size' AS object,
  CONCAT('Innodb_log_waits = ', FORMAT(w.waits, 0), ' since restart (',
         ROUND(w.per_hour, 2), '/h over ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h). Transactions are stalling because the ',
         ROUND(@@GLOBAL.innodb_log_buffer_size / 1048576, 1),
         ' MB redo log buffer filled before it could be flushed. This is a memory-only fix and needs no restart on MySQL 8.0+ (innodb_log_buffer_size is dynamic there; MariaDB still requires a restart).') AS details,
  JSON_OBJECT(
    'innodb_log_waits', w.waits,
    'waits_per_hour', ROUND(w.per_hour, 3),
    'innodb_log_buffer_size', @@GLOBAL.innodb_log_buffer_size,
    'uptime_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_log_waits, 0) AS DECIMAL(30, 0)) AS waits,
         CAST(IFNULL(@dbt_s_innodb_log_waits, 0) AS DECIMAL(30, 0)) / @dbt_uptime_h AS per_hour
) AS w
WHERE w.waits > 0
  AND w.per_hour >= COALESCE(@log_waits_per_hour, 1);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-WAL-004' AS marker;
-- check: MY-WAL-004
-- title: Checkpoint age near redo capacity
-- priority: 100 | category: WAL | scope: cluster | cost: 0 | pass: fast
-- engine: mariadb | requires: (none)
-- thresholds: checkpoint_age_ratio=0.75
-- reads: @dbt_s_innodb_checkpoint_age, @dbt_s_innodb_checkpoint_max_age
-- Fork divergence, and a deliberate narrowing of the design's row: the design
-- specifies parsing "Log sequence number" minus "Last checkpoint at" out of
-- SHOW ENGINE INNODB STATUS, which cannot be done from SQL (a SHOW cannot be
-- selected from) and needs PROCESS. MariaDB and Percona Server expose the same
-- figure directly as the status variables Innodb_checkpoint_age and
-- Innodb_checkpoint_max_age, so this check reads those and emits nothing on
-- stock MySQL, where the runner records it as skipped with reason `version`.
-- Checkpoint age approaching its maximum is the state immediately before InnoDB
-- starts blocking writers to force flushing — the stall that MY-WAL-001 predicts
-- from sizing, observed directly.
SELECT
  'MY-WAL-004' AS check_id,
  'cluster'    AS scope,
  'checkpoint-age' AS object,
  CONCAT('Checkpoint age is ', ROUND(c.age / 1048576, 0), ' MB of a ',
         ROUND(c.maxage / 1048576, 0), ' MB maximum (',
         ROUND(100.0 * c.age / c.maxage, 1), '%, threshold ',
         ROUND(100 * COALESCE(@checkpoint_age_ratio, 0.75), 0),
         '%) at snapshot time. InnoDB throttles and then blocks writers as this approaches 100%. ',
         'Redo capacity and the write rate are assessed by MY-WAL-001; innodb_io_capacity_max = ',
         @@GLOBAL.innodb_io_capacity_max, ' governs how fast it can drain.') AS details,
  JSON_OBJECT(
    'checkpoint_age_bytes', c.age,
    'checkpoint_max_age_bytes', c.maxage,
    'ratio', ROUND(c.age / c.maxage, 4),
    'threshold_ratio', COALESCE(@checkpoint_age_ratio, 0.75),
    'innodb_io_capacity_max', @@GLOBAL.innodb_io_capacity_max) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_checkpoint_age, 0) AS DECIMAL(30, 0))     AS age,
         CAST(IFNULL(@dbt_s_innodb_checkpoint_max_age, 0) AS DECIMAL(30, 0)) AS maxage
) AS c
WHERE c.maxage > 0
  AND c.age / c.maxage >= COALESCE(@checkpoint_age_ratio, 0.75);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-008' AS marker;
-- check: MY-CONN-008
-- title: Thread cache misses
-- priority: 150 | category: CONN | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: thread_miss_ratio=0.01;min_connections=100000
-- reads: @dbt_s_threads_created, @dbt_s_connections, @@GLOBAL.thread_cache_size
-- Threads_created / Connections is the fraction of connections that needed a new
-- OS thread rather than a cached one. MySQL 8.0 auto-sizes thread_cache_size
-- from max_connections, so this rarely fires there; MariaDB's default formula is
-- more conservative and a connection-per-request application can outrun it.
-- The 100,000-connection floor exists because on a low-traffic server every
-- connection legitimately creates a thread and the ratio means nothing.
SELECT
  'MY-CONN-008' AS check_id,
  'setting'     AS scope,
  'thread_cache_size' AS object,
  CONCAT(FORMAT(t.created, 0), ' threads created for ', FORMAT(t.conns, 0),
         ' connections since restart (', ROUND(100.0 * t.created / t.conns, 2),
         '%, threshold ', ROUND(100 * COALESCE(@thread_miss_ratio, 0.01), 1),
         '%) with thread_cache_size = ', @@GLOBAL.thread_cache_size,
         '. Each miss is an OS thread creation and stack allocation (thread_stack = ',
         ROUND(@@GLOBAL.thread_stack / 1024, 0), ' KB) on the connection path. ',
         'Threads_cached now: ', CAST(IFNULL(@dbt_s_threads_cached, 0) AS UNSIGNED),
         '. The deeper fix is connection pooling in the application.') AS details,
  JSON_OBJECT(
    'threads_created', t.created,
    'connections', t.conns,
    'miss_ratio', ROUND(t.created / t.conns, 5),
    'threshold_ratio', COALESCE(@thread_miss_ratio, 0.01),
    'thread_cache_size', @@GLOBAL.thread_cache_size,
    'threads_cached', CAST(IFNULL(@dbt_s_threads_cached, 0) AS UNSIGNED)) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_threads_created, 0) AS DECIMAL(30, 0)) AS created,
         GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS conns
) AS t
WHERE t.conns >= COALESCE(@min_connections, 100000)
  AND t.created / t.conns >= COALESCE(@thread_miss_ratio, 0.01);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CONN-010' AS marker;
-- check: MY-CONN-010
-- title: DNS lookups performed on every connection
-- priority: 150 | category: CONN | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.skip_name_resolve, mysql.user host patterns
-- With skip_name_resolve OFF, every incoming connection triggers a reverse DNS
-- lookup and then a forward lookup to confirm it. Three consequences, all real:
-- connection latency depends on a DNS server, a DNS outage looks like a database
-- outage, and failed lookups count toward max_connect_errors and can get a host
-- permanently blocked (MY-CONN-005).
-- It is also a security surface: host-based grants written against names rather
-- than addresses are only as trustworthy as reverse DNS. Turning it on requires
-- that every grant use an IP or a wildcard, which is why this is P150 with the
-- count of name-based grants included rather than a bare recommendation.
SELECT
  'MY-CONN-010' AS check_id,
  'setting'     AS scope,
  'skip_name_resolve' AS object,
  CONCAT('skip_name_resolve = OFF, so every connection performs a reverse and forward DNS lookup before authentication. ',
         'Connection latency then depends on the resolver, a DNS outage presents as a database outage, and failed lookups count toward max_connect_errors = ',
         @@GLOBAL.max_connect_errors, ' (MY-CONN-005). ',
         'Host-based grants that name a hostname are only as trustworthy as reverse DNS. ',
         'Aborted_connects since restart: ',
         CAST(IFNULL(@dbt_s_aborted_connects, 0) AS UNSIGNED),
         '. Before enabling it, confirm no account grant relies on a hostname (MY-SEC-004 lists host patterns).') AS details,
  JSON_OBJECT(
    'skip_name_resolve', 'OFF',
    'max_connect_errors', @@GLOBAL.max_connect_errors,
    'aborted_connects', CAST(IFNULL(@dbt_s_aborted_connects, 0) AS UNSIGNED)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.skip_name_resolve = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-002' AS marker;
-- check: MY-IDX-002
-- title: Unused index (smaller, or statistics window too short)
-- priority: 150 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*, SELECT ON mysql.*
-- thresholds: small_unused_index_bytes=52428800;unused_index_bytes=1073741824;min_uptime_days=30
-- reads: sys.schema_unused_indexes, or performance_schema.table_io_waits_summary_by_index_usage
--        directly; mysql.innodb_index_stats (stat_name='size') x @@innodb_page_size for size
-- Availability, verified: sys.schema_unused_indexes exists on MySQL 5.7+ and
-- MariaDB 10.6+ with the same three columns (object_schema, object_name,
-- index_name). Where sys is absent the check reads
-- performance_schema.table_io_waits_summary_by_index_usage itself, which is what
-- the view is built on, so the result is identical.
-- Index SIZE is the harder half: information_schema has no per-index size at
-- all. mysql.innodb_index_stats carries a 'size' row per index measured in
-- PAGES, so bytes = size x innodb_page_size. That table is written by InnoDB's
-- persistent statistics and exists on both forks.
-- THE CAVEAT THAT MUST TRAVEL WITH THIS FINDING: index usage is counted PER
-- INSTANCE and only since the last restart. An index unused on this server may
-- be the one the reporting replica depends on. Never drop on this evidence
-- alone — check every replica, and check that uptime covers a full business
-- cycle including month-end. That is why min_uptime_days defaults to 30.
SET @dbt_q_sys := "
SELECT
  'MY-IDX-002' AS check_id,
  'index'      AS scope,
  CONCAT(u.object_schema, '.', u.object_name, '.', u.index_name) AS object,
  CONCAT('Index `', u.index_name, '` on `', u.object_schema, '`.`', u.object_name,
         '` has been read ZERO times since this server started ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago, and occupies ',
         ROUND(sz.bytes / 1073741824, 2), ' GB (', FORMAT(sz.pages, 0), ' pages x ',
         @@GLOBAL.innodb_page_size, ' bytes; threshold ',
         ROUND(COALESCE(@small_unused_index_bytes, 52428800) / 1048576, 0),
         ' MB, below the ', ROUND(COALESCE(@unused_index_bytes, 1073741824) / 1073741824, 1),
         ' GB tier MY-IDX-001). ',
         'It is still maintained on every INSERT, UPDATE and DELETE to the table. ',
         'VERIFY BEFORE DROPPING: this counter is per instance and resets on restart, so an index unused here may be the one a reporting replica relies on, and ',
         ROUND(@dbt_uptime_s / 86400, 1),
         ' days may not include month-end or quarter-end reporting.') AS details,
  JSON_OBJECT(
    'schema', u.object_schema, 'table', u.object_name, 'index', u.index_name,
    'index_bytes', sz.bytes, 'index_pages', sz.pages,
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'threshold_bytes', COALESCE(@small_unused_index_bytes, 52428800),
    'uptime_days', ROUND(@dbt_uptime_s / 86400, 2),
    'scope_note', 'usage counted on this instance only, since last restart') AS evidence_json,
  'low' AS confidence
FROM sys.schema_unused_indexes AS u
JOIN (
  SELECT database_name, table_name, index_name,
         stat_value AS pages, stat_value * @@GLOBAL.innodb_page_size AS bytes
    FROM mysql.innodb_index_stats
   WHERE stat_name = 'size'
) AS sz
  ON sz.database_name = u.object_schema
 AND sz.table_name    = u.object_name
 AND sz.index_name    = u.index_name
WHERE u.object_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND u.index_name <> 'PRIMARY'
  AND sz.bytes >= COALESCE(@small_unused_index_bytes, 52428800)
  AND sz.bytes <  COALESCE(@unused_index_bytes, 1073741824)
ORDER BY sz.bytes DESC
LIMIT 20";

SET @dbt_q_ps := REPLACE(@dbt_q_sys, 'sys.schema_unused_indexes AS u', "(
  SELECT OBJECT_SCHEMA AS object_schema, OBJECT_NAME AS object_name, INDEX_NAME AS index_name
    FROM performance_schema.table_io_waits_summary_by_index_usage
   WHERE INDEX_NAME IS NOT NULL
     AND INDEX_NAME <> 'PRIMARY'
     AND COUNT_STAR = 0
     AND OBJECT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS u");

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_innodb_index_stats, 0) = 0 OR IFNULL(@dbt_priv_mysql_schema, 0) = 0 THEN 'DO 1'
  WHEN IFNULL(@dbt_sys_unused_idx, 0) = 1  THEN @dbt_q_sys
  WHEN IFNULL(@dbt_has_index_usage, 0) = 1 THEN @dbt_q_ps
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-007' AS marker;
-- check: MY-IDX-007
-- title: Single-column index on a very low-cardinality column
-- priority: 150 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: low_cardinality=3;idx_table_bytes=104857600
-- reads: information_schema.STATISTICS (CARDINALITY), information_schema.TABLES
-- CARDINALITY is an ESTIMATE produced by InnoDB's index dives
-- (innodb_stats_persistent_sample_pages, default 20), not a count, and it is
-- stale until statistics are recalculated — which is why this is P150 with
-- medium confidence rather than a firm recommendation, and why MY-IDX-008 checks
-- whether those statistics are stale at all.
-- The mechanism: an index on a column with three distinct values over a million
-- rows selects a third of the table per lookup. The optimizer costs that as
-- worse than a table scan — because with InnoDB's clustered layout every
-- secondary-index hit is a second lookup into the primary key — so the index is
-- never chosen, yet it is still maintained on every write.
-- Two legitimate exceptions the finding names rather than assumes away: a
-- skewed distribution where the rare value is the one queried, and use as the
-- leading column of a composite index (excluded here by construction).
SELECT
  'MY-IDX-007' AS check_id,
  'index'      AS scope,
  CONCAT(s.TABLE_SCHEMA, '.', s.TABLE_NAME, '.', s.INDEX_NAME) AS object,
  CONCAT('Index `', s.INDEX_NAME, '` on `', s.TABLE_SCHEMA, '`.`', s.TABLE_NAME,
         '`.', s.COLUMN_NAME, ' is a single-column index with an estimated cardinality of ',
         s.CARDINALITY, ' distinct value(s) over ~', FORMAT(IFNULL(t.TABLE_ROWS, 0), 0),
         ' rows (threshold ', COALESCE(@low_cardinality, 3), '; table ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1048576, 0), ' MB). ',
         'A lookup selects roughly ', ROUND(100.0 / GREATEST(s.CARDINALITY, 1), 0),
         '% of the table, and because InnoDB stores secondary indexes as pointers into the clustered primary key, each hit costs a second lookup — so the optimizer will usually prefer a table scan and never use this index, while every write still maintains it. ',
         'CARDINALITY is an InnoDB estimate from index dives, not a count (see MY-IDX-008 for whether it is stale). ',
         'It may still be correct to keep this if the distribution is skewed and the rare value is the one queried.') AS details,
  JSON_OBJECT(
    'schema', s.TABLE_SCHEMA, 'table', s.TABLE_NAME,
    'index', s.INDEX_NAME, 'column', s.COLUMN_NAME,
    'cardinality_estimate', s.CARDINALITY,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'threshold_cardinality', COALESCE(@low_cardinality, 3),
    'estimate_basis', 'InnoDB index dive sample') AS evidence_json,
  'medium' AS confidence
FROM information_schema.STATISTICS AS s
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = s.TABLE_SCHEMA AND t.TABLE_NAME = s.TABLE_NAME
WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND s.INDEX_NAME <> 'PRIMARY'
  AND s.NON_UNIQUE = 1
  AND s.SEQ_IN_INDEX = 1
  AND s.CARDINALITY IS NOT NULL
  AND s.CARDINALITY <= COALESCE(@low_cardinality, 3)
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@idx_table_bytes, 104857600)
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS AS s2
     WHERE s2.TABLE_SCHEMA = s.TABLE_SCHEMA AND s2.TABLE_NAME = s.TABLE_NAME
       AND s2.INDEX_NAME = s.INDEX_NAME AND s2.SEQ_IN_INDEX > 1)
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-008' AS marker;
-- check: MY-IDX-008
-- title: InnoDB persistent statistics stale
-- priority: 150 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: stats_age_days=30;stats_table_bytes=1073741824
-- reads: mysql.innodb_table_stats (last_update), @@GLOBAL.innodb_stats_persistent,
--        @@GLOBAL.innodb_stats_auto_recalc
-- mysql.innodb_table_stats exists on both forks (MySQL 5.6+, MariaDB 10.0+) with
-- the same last_update column.
-- Two distinct causes, distinguished in the text because the fixes differ:
--   innodb_stats_persistent = OFF — statistics are recomputed by sampling on
--     every server restart and on some metadata operations, so they are both
--     unstable and never durable. Plans change after a restart for no reason.
--   innodb_stats_auto_recalc = ON but last_update is old — automatic
--     recalculation only triggers when more than 10% of the rows have changed.
--     A large append-only table never reaches 10% in any reasonable time, so its
--     statistics silently describe the table as it was months ago.
-- Stale statistics are what makes the optimizer choose the wrong index on a
-- table that has grown, and they are the input to MY-IDX-007's cardinality
-- figures — which is why that check is medium confidence.
-- The fix (ANALYZE TABLE) is a write operation and is on db-triage's forbidden
-- list; the human runs it.
SET @dbt_q := "
SELECT
  'MY-IDX-008' AS check_id,
  'relation'   AS scope,
  CONCAT(st.database_name, '.', st.table_name) AS object,
  CONCAT('`', st.database_name, '`.`', st.table_name, '` is ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB and its InnoDB statistics were last updated ', st.last_update, ' — ',
         DATEDIFF(NOW(), st.last_update), ' days ago (threshold ',
         COALESCE(@stats_age_days, 30), ' days). Recorded rows: ',
         FORMAT(st.n_rows, 0), '. ',
         IF(@@GLOBAL.innodb_stats_persistent = 0,
            'innodb_stats_persistent = OFF, so statistics are re-sampled at every restart and are never durable — query plans can change after a restart with no other cause. ',
            CONCAT('innodb_stats_auto_recalc = ', CAST(@@GLOBAL.innodb_stats_auto_recalc AS CHAR),
                   '; automatic recalculation only fires once more than 10% of rows have changed, which an append-only or slowly-changing table of this size never reaches. ')),
         'The optimizer is planning against a description of this table as it was ',
         DATEDIFF(NOW(), st.last_update),
         ' days ago, which is also the basis for the cardinality figures in MY-IDX-007. ',
         'ANALYZE TABLE refreshes it; db-triage does not run it because it is a write.') AS details,
  JSON_OBJECT(
    'schema', st.database_name, 'table', st.table_name,
    'stats_last_update', CAST(st.last_update AS CHAR),
    'stats_age_days', DATEDIFF(NOW(), st.last_update),
    'recorded_rows', st.n_rows,
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'innodb_stats_persistent', CAST(@@GLOBAL.innodb_stats_persistent AS CHAR),
    'innodb_stats_auto_recalc', CAST(@@GLOBAL.innodb_stats_auto_recalc AS CHAR),
    'threshold_days', COALESCE(@stats_age_days, 30)) AS evidence_json,
  'high' AS confidence
FROM mysql.innodb_table_stats AS st
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = st.database_name AND t.TABLE_NAME = st.table_name
WHERE st.database_name NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@stats_table_bytes, 1073741824)
  AND (DATEDIFF(NOW(), st.last_update) >= COALESCE(@stats_age_days, 30)
       OR @@GLOBAL.innodb_stats_persistent = 0)
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_has_innodb_table_stats, 0) = 1 AND IFNULL(@dbt_priv_mysql_schema, 0) = 1,
                 @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-IDX-009' AS marker;
-- check: MY-IDX-009
-- title: Wide composite indexes
-- priority: 150 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: wide_index_columns=6;idx_table_bytes=104857600
-- reads: information_schema.STATISTICS (SEQ_IN_INDEX, SUB_PART),
--        information_schema.COLUMNS for the declared widths
-- Hygiene, reported with the numbers that decide whether it matters.
-- In InnoDB every secondary index entry also carries the full primary key, so a
-- six-column index on a table with a composite primary key is wider still. Three
-- consequences: fewer entries per 16 KB page so more pages to read, more buffer
-- pool consumed by the index, and more work on every write.
-- The leftmost-prefix rule also means a six-column index can only be used by a
-- query that constrains the first column, so the trailing columns earn their
-- width only if queries actually reach them — which the catalog cannot tell you.
-- Hard limits worth knowing and reported alongside: 16 columns per index and
-- 3072 bytes of key length on both forks (767 bytes with COMPACT/REDUNDANT row
-- format, see MY-SCHEMA-012).
SELECT
  'MY-IDX-009' AS check_id,
  'index'      AS scope,
  CONCAT(x.sch, '.', x.tbl, '.', x.idx) AS object,
  CONCAT('Index `', x.idx, '` on `', x.sch, '`.`', x.tbl, '` spans ', x.ncols,
         ' columns (', x.cols, '; threshold ', COALESCE(@wide_index_columns, 6),
         ', hard limit 16). Declared key width ~', x.declared_bytes,
         ' bytes of the 3072-byte limit. Table ',
         ROUND(x.bytes / 1048576, 0), ' MB. ',
         'InnoDB appends the full primary key to every secondary index entry, so the stored entry is wider than the declared columns: fewer entries per 16 KB page, more pages read per lookup, more buffer pool consumed, more work on every write. ',
         'Because of the leftmost-prefix rule this index is only usable by queries that constrain `',
         x.first_col, '`, and the trailing columns earn their width only if queries reach them — which the catalog cannot show. Check MY-QRY-004 for what actually runs.') AS details,
  JSON_OBJECT(
    'schema', x.sch, 'table', x.tbl, 'index', x.idx,
    'column_count', x.ncols, 'columns', x.cols,
    'declared_key_bytes', x.declared_bytes,
    'first_column', x.first_col,
    'table_bytes', x.bytes,
    'threshold_columns', COALESCE(@wide_index_columns, 6)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT s.TABLE_SCHEMA AS sch, s.TABLE_NAME AS tbl, s.INDEX_NAME AS idx,
         MAX(s.SEQ_IN_INDEX) AS ncols,
         SUBSTRING(GROUP_CONCAT(s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX SEPARATOR ', '), 1, 300) AS cols,
         SUBSTRING_INDEX(GROUP_CONCAT(s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX SEPARATOR ','), ',', 1) AS first_col,
         IFNULL(SUM(IFNULL(s.SUB_PART, IFNULL(c.CHARACTER_OCTET_LENGTH, 8))), 0) AS declared_bytes,
         MAX(t.DATA_LENGTH + t.INDEX_LENGTH) AS bytes
    FROM information_schema.STATISTICS AS s
    JOIN information_schema.TABLES AS t
      ON t.TABLE_SCHEMA = s.TABLE_SCHEMA AND t.TABLE_NAME = s.TABLE_NAME
    LEFT JOIN information_schema.COLUMNS AS c
      ON c.TABLE_SCHEMA = s.TABLE_SCHEMA AND c.TABLE_NAME = s.TABLE_NAME
     AND c.COLUMN_NAME = s.COLUMN_NAME
   WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
   GROUP BY s.TABLE_SCHEMA, s.TABLE_NAME, s.INDEX_NAME
) AS x
WHERE x.ncols >= COALESCE(@wide_index_columns, 6)
  AND x.bytes >= COALESCE(@idx_table_bytes, 104857600)
ORDER BY x.ncols DESC, x.bytes DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-007' AS marker;
-- check: MY-LOCK-007
-- title: Deadlocks occurring regularly
-- priority: 150 | category: LOCK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: deadlocks_per_day=1;min_deadlocks=7
-- reads: information_schema.INNODB_METRICS lock_deadlocks (via @dbt_lock_deadlocks),
--        @dbt_s_innodb_deadlocks (MariaDB status variable), @@GLOBAL.innodb_print_all_deadlocks
-- Two sources because the forks differ: MySQL exposes deadlocks only through
-- INNODB_METRICS.lock_deadlocks; MariaDB exposes both that and the
-- Innodb_deadlocks status variable. The metric's enable-flag column also differs
-- (STATUS vs ENABLED), which 01_session.sql resolves.
-- Deadlocks are not corruption and not necessarily a bug: InnoDB detects the
-- cycle and rolls back the cheaper transaction, which the application should
-- retry. They are reported at P150 because a rising rate signals an access-order
-- problem, and because most applications do not actually retry.
-- innodb_print_all_deadlocks=OFF means only the most recent one is inspectable
-- via SHOW ENGINE INNODB STATUS, so diagnosis requires waiting for the next one.
SELECT
  'MY-LOCK-007' AS check_id,
  'cluster'     AS scope,
  'deadlocks'   AS object,
  CONCAT(FORMAT(d.n, 0), ' deadlock(s) since restart, ', ROUND(d.per_day, 1),
         '/day over ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days (threshold ', COALESCE(@deadlocks_per_day, 1), '/day, minimum ',
         COALESCE(@min_deadlocks, 7), ' total). Source: ', d.src, '. ',
         'innodb_print_all_deadlocks = ', @@GLOBAL.innodb_print_all_deadlocks,
         IF(@@GLOBAL.innodb_print_all_deadlocks IN (0, 'OFF'),
            ' — only the most recent deadlock is inspectable, so diagnosing the pattern means waiting for the next one.',
            ' — full deadlock details are in the error log.'),
         ' InnoDB rolls back the cheaper transaction; the application must retry it, and many do not.') AS details,
  JSON_OBJECT(
    'deadlocks', d.n,
    'per_day', ROUND(d.per_day, 3),
    'source', d.src,
    'threshold_per_day', COALESCE(@deadlocks_per_day, 1),
    'innodb_print_all_deadlocks', CAST(@@GLOBAL.innodb_print_all_deadlocks AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(COALESCE(NULLIF(@dbt_lock_deadlocks, 0), @dbt_s_innodb_deadlocks, 0) AS DECIMAL(30, 0)) AS n,
    CAST(COALESCE(NULLIF(@dbt_lock_deadlocks, 0), @dbt_s_innodb_deadlocks, 0) AS DECIMAL(30, 0)) / @dbt_uptime_d AS per_day,
    IF(IFNULL(@dbt_lock_deadlocks, 0) > 0,
       'information_schema.INNODB_METRICS.lock_deadlocks',
       'Innodb_deadlocks status variable') AS src
) AS d
WHERE d.n >= COALESCE(@min_deadlocks, 7)
  AND d.per_day >= COALESCE(@deadlocks_per_day, 1);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-LOCK-008' AS marker;
-- check: MY-LOCK-008
-- title: Table-level lock waits
-- priority: 150 | category: LOCK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: table_lock_wait_ratio=0.01;min_table_locks=10000
-- reads: @dbt_s_table_locks_waited, @dbt_s_table_locks_immediate
-- These counters only move for storage engines that take table-level locks —
-- in practice MyISAM, Aria and MEMORY — because InnoDB uses row locks and does
-- not increment them. A non-zero ratio is therefore a symptom whose cause is
-- MY-DUR-007 (non-transactional engines still in use), and the finding says so
-- rather than suggesting a lock-tuning fix that does not exist.
-- Both forks expose the counters identically.
SELECT
  'MY-LOCK-008' AS check_id,
  'cluster'     AS scope,
  'table-locks' AS object,
  CONCAT(FORMAT(l.waited, 0), ' of ', FORMAT(l.waited + l.immediate, 0),
         ' table lock requests had to wait since restart (',
         ROUND(100.0 * l.waited / (l.waited + l.immediate), 2), '%, threshold ',
         ROUND(100 * COALESCE(@table_lock_wait_ratio, 0.01), 1), '%). ',
         'InnoDB does not increment these counters, so the waits are on table-locking engines — see MY-DUR-007. ',
         'Non-InnoDB user tables found: ', t.n, '. ',
         'There is no lock-tuning fix for this; the fix is converting those tables to InnoDB.') AS details,
  JSON_OBJECT(
    'table_locks_waited', l.waited,
    'table_locks_immediate', l.immediate,
    'wait_ratio', ROUND(l.waited / (l.waited + l.immediate), 5),
    'threshold_ratio', COALESCE(@table_lock_wait_ratio, 0.01),
    'non_innodb_user_tables', t.n,
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_table_locks_waited, 0) AS DECIMAL(30, 0))    AS waited,
         CAST(IFNULL(@dbt_s_table_locks_immediate, 0) AS DECIMAL(30, 0)) AS immediate
) AS l,
(
  SELECT COUNT(*) AS n FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE' AND ENGINE IS NOT NULL AND ENGINE <> 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS t
WHERE l.waited + l.immediate >= COALESCE(@min_table_locks, 10000)
  AND l.waited / (l.waited + l.immediate) >= COALESCE(@table_lock_wait_ratio, 0.01);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-010' AS marker;
-- check: MY-MEM-010
-- title: Single buffer pool instance with a large pool
-- priority: 150 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: large_pool_bytes=8589934592
-- reads: @dbt_v_innodb_buffer_pool_instances, @@GLOBAL.innodb_buffer_pool_size
-- Version divergence, and the reason this must come from the bundle: MariaDB
-- 10.6 REMOVED innodb_buffer_pool_instances entirely (verified absent on 10.11)
-- because its buffer pool no longer partitions that way, and MySQL 8.0
-- auto-sizes it from the pool size. So this can only fire on MySQL 5.7, on
-- MariaDB 10.5 and earlier, or where someone pinned it to 1 by hand.
-- With one instance, every page lookup contends on one buffer pool mutex; the
-- classic guidance is one instance per GB up to the core count.
SELECT
  'MY-MEM-010' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_instances' AS object,
  CONCAT('innodb_buffer_pool_instances = ', @dbt_v_innodb_buffer_pool_instances,
         ' for a ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 1),
         ' GB buffer pool (threshold ',
         ROUND(COALESCE(@large_pool_bytes, 8589934592) / 1073741824, 0),
         ' GB). All page lookups contend on one buffer pool mutex. ',
         'Fork note: MySQL 8.0 auto-sizes this and MariaDB 10.6+ removed the setting, so this only applies to MySQL 5.7 / MariaDB 10.5 and earlier, or an explicit override.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_instances', CAST(@dbt_v_innodb_buffer_pool_instances AS UNSIGNED),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'threshold_bytes', COALESCE(@large_pool_bytes, 8589934592),
    'cpu_count', IFNULL(@dbt_cpu_count, 'unknown')) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE @dbt_v_innodb_buffer_pool_instances IS NOT NULL
  AND CAST(@dbt_v_innodb_buffer_pool_instances AS SIGNED) = 1
  AND @@GLOBAL.innodb_buffer_pool_size >= COALESCE(@large_pool_bytes, 8589934592);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-MEM-012' AS marker;
-- check: MY-MEM-012
-- title: innodb_flush_method not O_DIRECT on Linux
-- priority: 150 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: large_pool_bytes=4294967296
-- reads: @dbt_v_innodb_flush_method, @@GLOBAL.version_compile_os,
--        @@GLOBAL.innodb_buffer_pool_size
-- Read from the bundle because the variable does not exist on Windows builds and
-- its accepted values differ by fork: MySQL 8.0.14+ adds O_DIRECT_NO_FSYNC and
-- 8.0.26 makes it the default on Linux; MariaDB keeps O_DIRECT as the practical
-- choice and adds fsync/littlesync/nosync variants.
-- Without O_DIRECT every InnoDB page lives twice: once in the buffer pool and
-- once in the OS page cache. On a host where the pool is already several GB that
-- is a straight waste of RAM, and it makes MY-MEM-003/007 understate real usage.
-- Only judged on Linux, because O_DIRECT is a no-op or unavailable elsewhere.
SELECT
  'MY-MEM-012' AS check_id,
  'setting'    AS scope,
  'innodb_flush_method' AS object,
  CONCAT('innodb_flush_method = ', @dbt_v_innodb_flush_method, ' on ',
         @@GLOBAL.version_compile_os, ' with a ',
         ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 1),
         ' GB buffer pool. Pages are cached both by InnoDB and by the OS page cache, so up to that much RAM again is spent holding a second copy. ',
         'O_DIRECT (or O_DIRECT_NO_FSYNC where the filesystem allows it) removes the duplicate.') AS details,
  JSON_OBJECT(
    'innodb_flush_method', @dbt_v_innodb_flush_method,
    'version_compile_os', @@GLOBAL.version_compile_os,
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'threshold_bytes', COALESCE(@large_pool_bytes, 4294967296)) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE @dbt_v_innodb_flush_method IS NOT NULL
  AND LOWER(@@GLOBAL.version_compile_os) LIKE '%linux%'
  AND UPPER(@dbt_v_innodb_flush_method) NOT IN ('O_DIRECT', 'O_DIRECT_NO_FSYNC')
  AND @@GLOBAL.innodb_buffer_pool_size >= COALESCE(@large_pool_bytes, 4294967296);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-002' AS marker;
-- check: MY-QRY-002
-- title: Statement digest instrumentation incomplete
-- priority: 150 | category: QRY | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: performance_schema.setup_consumers (statements_digest),
--        @dbt_s_performance_schema_digest_lost, @dbt_v_performance_schema_digests_size
-- Two independent ways the digest table lies, both reported here because both
-- silently degrade MY-QRY-004..011 without any error:
--   1. the statements_digest consumer is disabled, so nothing is aggregated at
--      all and the top-N lists are simply empty;
--   2. the consumer is on but performance_schema_digests_size (default 5000 on
--      MySQL 8.0, 200 on MariaDB) is too small, so digests beyond the limit are
--      collapsed into a single NULL-digest row and
--      Performance_schema_digest_lost counts them. Any "% of total time" figure
--      computed from the table is then understated by an unknown amount.
-- Verified on MariaDB 10.11: setup_consumers has the statements_digest row and
-- the same NAME/ENABLED columns as MySQL.
SET @dbt_q := "
SELECT
  'MY-QRY-002' AS check_id,
  'setting'    AS scope,
  'statements_digest' AS object,
  CONCAT(CONCAT_WS('; ',
    IF(c.digest_enabled = 0,
       'the statements_digest consumer in performance_schema.setup_consumers is disabled, so no statement is aggregated and every top-N list in this report is empty', NULL),
    IF(d.lost > 0,
       CONCAT('Performance_schema_digest_lost = ', FORMAT(d.lost, 0),
              ' — that many distinct statements exceeded performance_schema_digests_size (',
              IFNULL(@dbt_v_performance_schema_digests_size, 'unknown'),
              ') and were collapsed into a single unnamed row, so any percentage-of-total computed from the digest table understates the true total by an unknown amount'), NULL),
    IF(c.history_long_enabled = 0,
       'events_statements_history_long is disabled, so individual slow statement executions cannot be inspected after the fact (the digest aggregate is still available)', NULL)),
    '. Affects MY-QRY-004 to MY-QRY-011 and MY-QRY-014.') AS details,
  JSON_OBJECT(
    'statements_digest_enabled', c.digest_enabled,
    'events_statements_history_long_enabled', c.history_long_enabled,
    'digest_lost', d.lost,
    'performance_schema_digests_size', IFNULL(@dbt_v_performance_schema_digests_size, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT MAX(NAME = 'statements_digest' AND ENABLED = 'YES') AS digest_enabled,
         MAX(NAME = 'events_statements_history_long' AND ENABLED = 'YES') AS history_long_enabled
    FROM performance_schema.setup_consumers
) AS c,
(
  SELECT CAST(IFNULL(@dbt_s_performance_schema_digest_lost, 0) AS DECIMAL(30, 0)) AS lost
) AS d
WHERE c.digest_enabled = 0 OR d.lost > 0 OR c.history_long_enabled = 0";
SET @dbt_q := IF(IFNULL(@dbt_ps_on, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-011' AS marker;
-- check: MY-QRY-011
-- title: Statements failing or warning frequently
-- priority: 150 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: error_ratio=0.05;min_executions=1000
-- reads: performance_schema.events_statements_summary_by_digest (SUM_ERRORS, SUM_WARNINGS)
-- Read directly from the digest table rather than from sys.statements_with_errors_or_warnings
-- so the threshold is explicit and the fork/version differences in that view do
-- not matter.
-- A statement erroring five percent of the time is doing real work and throwing
-- it away: the server pays the full parse, plan and partial execution cost and
-- the application gets an exception. Duplicate-key errors used as an upsert
-- idiom are the common benign case and are named in the finding so the reviewer
-- can dismiss them quickly.
-- WARNINGS matter more than they look on a server that failed MY-SCHEMA-004:
-- without strict SQL mode, silent truncation IS a warning, so a high warning
-- count there is data loss being reported and ignored.
SET @dbt_q := "
SELECT
  'MY-QRY-011' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT('Statement in ', IFNULL(d.SCHEMA_NAME, '(no schema)'), ' executed ',
         FORMAT(d.COUNT_STAR, 0), ' time(s) with ', FORMAT(d.SUM_ERRORS, 0),
         ' error(s) (', ROUND(100.0 * d.SUM_ERRORS / d.COUNT_STAR, 1),
         '%, threshold ', ROUND(100 * COALESCE(@error_ratio, 0.05), 0), '%) and ',
         FORMAT(d.SUM_WARNINGS, 0), ' warning(s). ',
         'Each failed execution still costs a parse, a plan and partial execution before it is thrown away. ',
         'A duplicate-key error rate is often a deliberate insert-or-update idiom and can be dismissed; ',
         IF(@dbt_global_sql_mode NOT LIKE '%STRICT%',
            'note that this server is NOT in strict SQL mode (MY-SCHEMA-004), so a high warning count here is silent truncation being reported and ignored. ',
            ''),
         'Window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago. Statement: ',
         SUBSTRING(d.DIGEST_TEXT, 1, 250)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', IFNULL(d.SCHEMA_NAME, ''),
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'errors', d.SUM_ERRORS,
    'warnings', d.SUM_WARNINGS,
    'error_ratio', ROUND(d.SUM_ERRORS / d.COUNT_STAR, 4),
    'threshold_ratio', COALESCE(@error_ratio, 0.05),
    'strict_sql_mode', IF(@dbt_global_sql_mode LIKE '%STRICT%', 1, 0),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM performance_schema.events_statements_summary_by_digest AS d
WHERE d.DIGEST IS NOT NULL
  AND IFNULL(d.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
  AND d.COUNT_STAR >= COALESCE(@min_executions, 1000)
  AND d.SUM_ERRORS >= d.COUNT_STAR * COALESCE(@error_ratio, 0.05)
ORDER BY d.SUM_ERRORS DESC
LIMIT 10";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-013' AS marker;
-- check: MY-QRY-013
-- title: Sort merge passes high
-- priority: 150 | category: QRY | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: merge_passes_per_second=10
-- reads: @dbt_s_sort_merge_passes, @@GLOBAL.sort_buffer_size
-- A merge pass happens when a sort does not fit in sort_buffer_size and has to
-- be written out and merged from disk. The counter is server-wide and available
-- on both forks without performance_schema.
-- The trap this finding exists to prevent: the obvious response is to raise
-- sort_buffer_size globally, and that is usually wrong twice over. It is
-- allocated per session per sort, so it multiplies by concurrency (MY-MEM-006
-- and MY-MEM-007 quantify that); and MySQL allocates and touches the whole
-- buffer regardless of how much of it the sort needs, so a large global value
-- makes every small sort slower.
-- The right responses, in order: an index that provides the sort order so no
-- sort happens; a smaller result set; and only then a per-session
-- SET sort_buffer_size for the one statement that needs it.
SELECT
  'MY-QRY-013' AS check_id,
  'cluster'    AS scope,
  'sort_buffer_size' AS object,
  CONCAT('Sort_merge_passes = ', FORMAT(s.passes, 0), ' since restart, ',
         ROUND(s.per_sec, 1), '/s over ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days (threshold ', COALESCE(@merge_passes_per_second, 10),
         '/s). Sorts are exceeding sort_buffer_size = ',
         ROUND(@@GLOBAL.sort_buffer_size / 1024, 0),
         ' KB and being written to disk and merged back. ',
         'Do NOT simply raise sort_buffer_size globally: it is allocated per session per sort, so at max_connections = ',
         @@GLOBAL.max_connections, ' the commitment is ',
         ROUND(@@GLOBAL.sort_buffer_size * @@GLOBAL.max_connections / 1073741824, 1),
         ' GB (MY-MEM-006/007), and MySQL touches the whole buffer even for a tiny sort, so a large value makes every small sort slower. ',
         'In order: add an index that supplies the ORDER BY so no sort happens; return fewer rows; only then set it per session for the one statement. MY-QRY-004 and MY-QRY-005 name the candidates.') AS details,
  JSON_OBJECT(
    'sort_merge_passes', s.passes,
    'per_second', ROUND(s.per_sec, 3),
    'threshold_per_second', COALESCE(@merge_passes_per_second, 10),
    'sort_buffer_size', @@GLOBAL.sort_buffer_size,
    'max_connections', @@GLOBAL.max_connections,
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_sort_merge_passes, 0) AS DECIMAL(30, 0)) AS passes,
         CAST(IFNULL(@dbt_s_sort_merge_passes, 0) AS DECIMAL(30, 0)) / GREATEST(@dbt_uptime_s, 1) AS per_sec
) AS s
WHERE s.per_sec >= COALESCE(@merge_passes_per_second, 10);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-014' AS marker;
-- check: MY-QRY-014
-- title: Plan-hostile patterns in top statement digests
-- priority: 150 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_digests=200;min_executions=100
-- reads: performance_schema.events_statements_summary_by_digest (DIGEST_TEXT)
-- CONFIDENCE IS LOW BY CONSTRUCTION AND THIS CHECK IS NEVER PROMOTED INTO
-- "Fix first". It is a regular-expression match on normalised statement text,
-- which means it can be wrong in both directions: a leading-wildcard LIKE
-- against a 50-row table is fine, and a plan-hostile query written in a way the
-- pattern does not match is missed entirely. Treat every row as a question.
-- Patterns and why each defeats an index:
--   LIKE '%...'         a B-tree can only seek on a known prefix, so a leading
--                       wildcard forces a scan of the whole index or table
--   ORDER BY RAND()     assigns a random value to every candidate row, then
--                       sorts all of them, to return one
--   function(column)    any expression around an indexed column makes the index
--                       unusable, unless it exactly matches a functional index
--                       (MySQL 8.0.13+; MariaDB has no functional indexes)
--   LIMIT n OFFSET big  MySQL reads and discards every skipped row; keyset
--                       pagination reads only what it returns
--   NOT IN (subquery)   historically materialised and re-evaluated per row
--   OR across columns   often prevents a single index from being used
-- DIGEST_TEXT is already normalised (literals replaced by ?), so no user data is
-- read or echoed by these patterns.
SET @dbt_q := "
SELECT
  'MY-QRY-014' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT('Statement in ', IFNULL(d.SCHEMA_NAME, '(no schema)'),
         ' matches plan-hostile pattern(s): ', d.patterns,
         '. Executed ', FORMAT(d.COUNT_STAR, 0), ' time(s), avg ',
         ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, rows examined/sent ',
         FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0), '. ',
         'THIS IS A TEXT PATTERN MATCH, NOT AN EXECUTION PLAN: a leading-wildcard LIKE on a 50-row lookup table is perfectly fine, and a differently-written plan-hostile query is missed entirely. Confirm with EXPLAIN before changing anything. ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 250)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', IFNULL(d.SCHEMA_NAME, ''),
    'patterns', d.patterns,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'basis', 'regular expression on normalised digest text') AS evidence_json,
  'low' AS confidence
FROM (
  SELECT s.DIGEST, s.SCHEMA_NAME, s.DIGEST_TEXT, s.COUNT_STAR, s.AVG_TIMER_WAIT,
         s.SUM_ROWS_EXAMINED, s.SUM_ROWS_SENT,
         CONCAT_WS(', ',
           IF(s.DIGEST_TEXT REGEXP 'LIKE[[:space:]]*\\\\?', 'leading-wildcard LIKE (only if the literal starts with %)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'ORDER[[:space:]]+BY[[:space:]]+RAND', 'ORDER BY RAND()', NULL),
           IF(s.DIGEST_TEXT REGEXP 'OFFSET[[:space:]]*\\\\?|LIMIT[[:space:]]*\\\\?[[:space:]]*,', 'LIMIT with OFFSET (deep pagination reads and discards every skipped row)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'NOT[[:space:]]+IN[[:space:]]*\\\\([[:space:]]*SELECT', 'NOT IN (subquery)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'WHERE[^;]*(UPPER|LOWER|DATE|CONCAT|SUBSTRING|COALESCE|IFNULL|CAST)[[:space:]]*\\\\(`', 'function applied to a column in WHERE', NULL),
           IF(s.DIGEST_TEXT REGEXP 'SELECT[[:space:]]+\\\\*[[:space:]]+FROM', 'SELECT * (defeats covering indexes and moves unused columns)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'COLLATE', 'explicit COLLATE in the statement (an index on the column cannot be used, see MY-SCHEMA-014)', NULL)) AS patterns
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND s.COUNT_STAR >= COALESCE(@min_executions, 100)
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
   ORDER BY s.SUM_TIMER_WAIT DESC
   LIMIT 200
) AS d
WHERE d.patterns <> ''
ORDER BY d.COUNT_STAR DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-007' AS marker;
-- check: MY-REL-007
-- title: sys schema missing
-- priority: 150 | category: REL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.VIEWS in schema sys (via @dbt_sys_view_count)
-- Availability, verified: MySQL ships sys from 5.7.7 and installs it by default.
-- MariaDB ships it from 10.6 (a MariaDB 10.11 install has 100 sys objects,
-- verified). Below those versions, or after someone dropped the schema, it is
-- absent.
-- Its absence is not a fault — every check that uses a sys view has an
-- information_schema or performance_schema fallback, and MY-IDX-003's fallback
-- was verified to produce byte-identical findings. What is lost is the
-- convenience for the human doing the follow-up work: the confirmation queries
-- in reference/checks-mysql.md are written against sys views because they are
-- an order of magnitude shorter and easier to read.
-- Reported at P150 with the list of which checks took a fallback path, so the
-- reader knows the findings are complete but derived differently.
SELECT
  'MY-REL-007' AS check_id,
  'cluster'    AS scope,
  'sys'        AS object,
  CONCAT('The sys schema is absent (', IFNULL(@dbt_sys_view_count, 0),
         ' views found). MySQL ships it from 5.7.7 and MariaDB from 10.6; this server is ',
         @dbt_fork, ' ', @@GLOBAL.version, '. ',
         'No finding is lost: MY-IDX-001, MY-IDX-003, MY-SCHEMA-005 and MY-SCHEMA-006 fall back to information_schema and performance_schema queries that produce the same results, ',
         'and MY-IDX-004, MY-IDX-005 and MY-SCHEMA-011 are skipped because they have no equivalent fallback worth the noise. ',
         'What is lost is the short confirmation queries in the reference documentation, which are written against sys views. ',
         'Installing it is a matter of loading the sys schema SQL and needs no restart.') AS details,
  JSON_OBJECT(
    'sys_view_count', IFNULL(@dbt_sys_view_count, 0),
    'fork', @dbt_fork,
    'version', @@GLOBAL.version,
    'checks_using_fallback', 'MY-IDX-001,MY-IDX-003,MY-SCHEMA-005,MY-SCHEMA-006',
    'checks_skipped', 'MY-IDX-004,MY-IDX-005,MY-SCHEMA-011') AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_sys_view_count, 0) = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-008' AS marker;
-- check: MY-REL-008
-- title: Error log verbosity reduced
-- priority: 150 | category: REL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: min_verbosity=2
-- reads: @dbt_v_log_error_verbosity (MySQL 5.7+), @dbt_v_log_warnings (MariaDB)
-- Fork divergence in both name and scale, which is why both come from the bundle:
--   MySQL 5.7+   log_error_verbosity: 1 = errors only, 2 = errors + warnings
--                (the default), 3 = + notes
--   MariaDB      log_warnings: 0 = errors only, 1 = + a few warnings (the
--                default), 2 = + aborted connections and access-denied, 3+ = more
-- The two scales are not comparable, so each is judged against its own default
-- and the finding says which variable it read.
-- At the lowest setting the error log records almost nothing: no aborted
-- connection detail (MY-CONN-004 then has counters with no explanation), no
-- InnoDB warnings short of a hard error, and on MySQL none of the messages
-- MY-CORR-001 and MY-CORR-002 look for. The log is the only record that survives
-- a restart, and turning it down is usually done to quieten disk noise from
-- something that deserved fixing instead.
SELECT
  'MY-REL-008' AS check_id,
  'setting'    AS scope,
  IF(@dbt_v_log_error_verbosity IS NOT NULL, 'log_error_verbosity', 'log_warnings') AS object,
  CONCAT(IF(@dbt_v_log_error_verbosity IS NOT NULL,
            CONCAT('log_error_verbosity = ', @dbt_v_log_error_verbosity,
                   ' (MySQL scale: 1 = errors only, 2 = errors and warnings — the default, 3 = also notes)'),
            CONCAT('log_warnings = ', @dbt_v_log_warnings,
                   ' (MariaDB scale: 0 = errors only, 1 = the default, 2 = also aborted connections and access-denied)')),
         '. At this level the error log records almost nothing beyond hard failures: no aborted-connection detail (so MY-CONN-004 gives counters with no explanation), no InnoDB warnings short of an error, and ',
         IF(@dbt_is_mariadb,
            'no access-denied records for a security review.',
            'none of the messages MY-CORR-001 and MY-CORR-002 search for.'),
         ' The error log is the only diagnostic record that survives a restart. log_error = ',
         @@GLOBAL.log_error, '.') AS details,
  JSON_OBJECT(
    'log_error_verbosity', IFNULL(@dbt_v_log_error_verbosity, 'n/a'),
    'log_warnings', IFNULL(@dbt_v_log_warnings, 'n/a'),
    'log_error', @@GLOBAL.log_error,
    'fork', @dbt_fork,
    'threshold', COALESCE(@min_verbosity, 2)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE (@dbt_v_log_error_verbosity IS NOT NULL
       AND CAST(@dbt_v_log_error_verbosity AS SIGNED) < COALESCE(@min_verbosity, 2))
   OR (@dbt_v_log_error_verbosity IS NULL AND @dbt_v_log_warnings IS NOT NULL
       AND CAST(@dbt_v_log_warnings AS SIGNED) < 1);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-003' AS marker;
-- check: MY-SCHEMA-003
-- title: sql_require_primary_key off while primary-key-less tables exist
-- priority: 150 | category: SCHEMA | scope: setting | cost: 1 | pass: fast
-- engine: mysql | min_version: 8.0.13 | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_sql_require_primary_key, information_schema.TABLES/STATISTICS
-- Availability: introduced in MySQL 8.0.13. MariaDB has no such variable at all
-- (verified absent on 10.11), so the bundle returns NULL there and this check
-- emits nothing rather than recommending something that cannot be done.
-- Derived: only fires when MY-SCHEMA-001 or MY-SCHEMA-002 already found
-- primary-key-less tables. Turning the variable on does not fix the existing
-- ones — it prevents the next one, which is why it is P150 hygiene rather than
-- part of the fix for the P20 finding.
-- Note it also blocks CREATE TABLE without a PK for every account including
-- migrations and ORMs, so it is a change that needs coordinating.
SELECT
  'MY-SCHEMA-003' AS check_id,
  'setting'       AS scope,
  'sql_require_primary_key' AS object,
  CONCAT('sql_require_primary_key = ', @dbt_v_sql_require_primary_key,
         ' while ', n.n, ' InnoDB table(s) already have no primary key (MY-SCHEMA-001/002). ',
         'Turning it ON does not fix those tables; it stops the next one being created. ',
         'It applies to every session including migrations and ORM-generated DDL, so coordinate it with whoever ships schema changes.') AS details,
  JSON_OBJECT(
    'sql_require_primary_key', @dbt_v_sql_require_primary_key,
    'tables_without_pk', n.n) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n
  FROM information_schema.TABLES AS t
  LEFT JOIN information_schema.STATISTICS AS s
    ON s.TABLE_SCHEMA = t.TABLE_SCHEMA AND s.TABLE_NAME = t.TABLE_NAME AND s.INDEX_NAME = 'PRIMARY'
  WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND t.ENGINE = 'InnoDB'
    AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
    AND s.INDEX_NAME IS NULL
) AS n
WHERE @dbt_v_sql_require_primary_key IS NOT NULL
  AND UPPER(@dbt_v_sql_require_primary_key) IN ('OFF', '0')
  AND n.n > 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-009' AS marker;
-- check: MY-SCHEMA-009
-- title: Very large table not partitioned
-- priority: 150 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: large_table_bytes=214748364800
-- reads: information_schema.TABLES, information_schema.PARTITIONS
-- Advisory, and deliberately at P150: partitioning is not a performance feature
-- and applying it to the wrong table makes things worse. What it does buy is
-- O(1) deletion of old data — DROP PARTITION instead of a DELETE that generates
-- undo, bloats the history list (MY-UNDO-001) and never returns the space.
-- On a 200 GB table with a retention policy that is a large difference; on a
-- 200 GB table that is all live data it is not, which is why the finding asks
-- rather than tells, and why it reports whether the table has an obvious
-- time-based partition key candidate.
-- Caveat carried in the text: on MySQL 8.0 these sizes come from the
-- information_schema cache and may be up to information_schema_stats_expiry old.
SELECT
  'MY-SCHEMA-009' AS check_id,
  'relation'      AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('`', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` is ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 1), ' GB (~',
         FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows) in a single partition (threshold ',
         ROUND(COALESCE(@large_table_bytes, 214748364800) / 1073741824, 0), ' GB). ',
         'Date/time columns that could serve as a partition key: ',
         IFNULL(c.date_cols, 'none — partitioning by range would need a synthetic column'),
         '. Partitioning is not a performance feature; what it buys is DROP PARTITION instead of a bulk DELETE, which on a table this size is the difference between an instant metadata operation and hours of undo generation that never returns the space. ',
         'Only worth doing if this table has a retention policy.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA,
    'table', t.TABLE_NAME,
    'bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'partition_count', 1,
    'candidate_partition_columns', IFNULL(c.date_cols, ''),
    'threshold_bytes', COALESCE(@large_table_bytes, 214748364800),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'medium' AS confidence
FROM information_schema.TABLES AS t
LEFT JOIN (
  SELECT TABLE_SCHEMA, TABLE_NAME,
         SUBSTRING(GROUP_CONCAT(COLUMN_NAME SEPARATOR ', '), 1, 150) AS date_cols
  FROM information_schema.COLUMNS
  WHERE DATA_TYPE IN ('date', 'datetime', 'timestamp')
  GROUP BY TABLE_SCHEMA, TABLE_NAME
) AS c ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@large_table_bytes, 214748364800)
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.PARTITIONS AS p
    WHERE p.TABLE_SCHEMA = t.TABLE_SCHEMA AND p.TABLE_NAME = t.TABLE_NAME
      AND p.PARTITION_NAME IS NOT NULL)
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-010' AS marker;
-- check: MY-SCHEMA-010
-- title: Table with more than 1,000 partitions
-- priority: 150 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_partitions=1000
-- reads: information_schema.PARTITIONS
-- The opposite failure to MY-SCHEMA-009. Every partition is a separate InnoDB
-- table internally: its own file descriptor, its own entry in the table cache
-- (MY-MEM-008), and its own row in the data dictionary. A query that cannot
-- prune partitions opens all of them, and even one that can prune pays the
-- planning cost of considering them.
-- The hard limit is 8,192 partitions per table on both forks, so a table at
-- 1,000 is not near the ceiling but is well past the point where the table cache
-- and open-file limit start to matter, especially with several such tables.
SELECT
  'MY-SCHEMA-010' AS check_id,
  'relation'      AS scope,
  CONCAT(p.TABLE_SCHEMA, '.', p.TABLE_NAME) AS object,
  CONCAT('`', p.TABLE_SCHEMA, '`.`', p.TABLE_NAME, '` has ', p.n,
         ' partitions (threshold ', COALESCE(@max_partitions, 1000),
         ', hard limit 8192), totalling ', ROUND(p.bytes / 1073741824, 1),
         ' GB with a ', p.method, ' partition scheme. ',
         'Each partition is a separate InnoDB table internally, consuming a file descriptor and a table-cache entry: table_open_cache = ',
         @@GLOBAL.table_open_cache, ', open_files_limit = ', @@GLOBAL.open_files_limit,
         '. A query that cannot prune opens all of them. See MY-MEM-008 for whether the cache is already overflowing.') AS details,
  JSON_OBJECT(
    'schema', p.TABLE_SCHEMA,
    'table', p.TABLE_NAME,
    'partition_count', p.n,
    'partition_method', p.method,
    'bytes', p.bytes,
    'threshold', COALESCE(@max_partitions, 1000),
    'table_open_cache', @@GLOBAL.table_open_cache,
    'open_files_limit', @@GLOBAL.open_files_limit) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(*) AS n,
         MAX(PARTITION_METHOD) AS method,
         IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes
  FROM information_schema.PARTITIONS
  WHERE PARTITION_NAME IS NOT NULL
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA, TABLE_NAME
) AS p
WHERE p.n >= COALESCE(@max_partitions, 1000);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-011' AS marker;
-- check: MY-SCHEMA-011
-- title: Triggers on high-write tables
-- priority: 150 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: min_writes=1000000
-- reads: information_schema.TRIGGERS, sys.schema_table_statistics
-- Requires the sys schema for the write counts (present on MySQL 5.7+ and
-- MariaDB 10.6+, verified); without it the check emits nothing rather than
-- listing every trigger regardless of traffic, which would be noise.
-- Triggers in MySQL run row-by-row inside the writing transaction: they extend
-- its duration (MY-LOCK-003), take their own locks in a different order than the
-- statement did (MY-LOCK-007), and are invisible in the statement digest, so the
-- statement that appears to take 5 ms in MY-QRY-004 may actually be doing far
-- more work. On a table taking a million writes that cost is structural.
SET @dbt_q := "
SELECT
  'MY-SCHEMA-011' AS check_id,
  'relation'      AS scope,
  CONCAT(x.sch, '.', x.tbl) AS object,
  CONCAT('`', x.sch, '`.`', x.tbl, '` has ', x.n_triggers, ' trigger(s) (', x.trig_list,
         ') and has taken ', FORMAT(x.writes, 0),
         ' write(s) since restart (threshold ', FORMAT(COALESCE(@min_writes, 1000000), 0), '). ',
         'MySQL triggers execute row by row inside the writing transaction: they lengthen it, take locks the statement itself did not, and do not appear in the statement digest — so the write latency measured in MY-QRY-004 excludes the trigger body. ',
         'Breakdown: ', FORMAT(x.ins, 0), ' inserted, ', FORMAT(x.upd, 0), ' updated, ',
         FORMAT(x.del, 0), ' deleted.') AS details,
  JSON_OBJECT(
    'schema', x.sch, 'table', x.tbl,
    'trigger_count', x.n_triggers, 'triggers', x.trig_list,
    'writes', x.writes, 'rows_inserted', x.ins, 'rows_updated', x.upd, 'rows_deleted', x.del,
    'threshold_writes', COALESCE(@min_writes, 1000000)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT g.EVENT_OBJECT_SCHEMA AS sch, g.EVENT_OBJECT_TABLE AS tbl,
         COUNT(*) AS n_triggers,
         SUBSTRING(GROUP_CONCAT(g.TRIGGER_NAME SEPARATOR ', '), 1, 200) AS trig_list,
         IFNULL(s.rows_inserted, 0) AS ins,
         IFNULL(s.rows_updated, 0)  AS upd,
         IFNULL(s.rows_deleted, 0)  AS del,
         IFNULL(s.rows_inserted, 0) + IFNULL(s.rows_updated, 0) + IFNULL(s.rows_deleted, 0) AS writes
    FROM information_schema.TRIGGERS AS g
    LEFT JOIN sys.schema_table_statistics AS s
      ON s.table_schema = g.EVENT_OBJECT_SCHEMA AND s.table_name = g.EVENT_OBJECT_TABLE
   WHERE g.EVENT_OBJECT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
   GROUP BY g.EVENT_OBJECT_SCHEMA, g.EVENT_OBJECT_TABLE,
            s.rows_inserted, s.rows_updated, s.rows_deleted
) AS x
WHERE x.writes >= COALESCE(@min_writes, 1000000)
ORDER BY x.writes DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_sys_table_stats, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-014' AS marker;
-- check: MY-SCHEMA-014
-- title: Character set or collation inconsistent within a schema
-- priority: 150 | category: SCHEMA | scope: schema | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.SCHEMATA, information_schema.TABLES, information_schema.COLUMNS
-- NOT in the design's §5.2 table. Added as the next free number in the category
-- because collation drift is a correctness and performance defect in its own
-- right, distinct from MY-SCHEMA-012's "these are legacy" inventory.
-- The mechanism, which is the part that surprises people: joining or comparing
-- two string columns with different collations forces MySQL to convert one side
-- at runtime. A converted column is a function of a column, so ANY INDEX ON IT
-- IS UNUSABLE. A join that has always used an index starts full-scanning the
-- moment one table is converted to utf8mb4 and the other is not — and EXPLAIN
-- shows the scan without ever saying why.
-- The second effect is correctness: two rows equal under utf8mb4_general_ci can
-- be unequal under utf8mb4_0900_ai_ci, so a UNIQUE constraint means different
-- things on different tables in the same schema.
-- Reported per schema, with the dominant collation and the exceptions named, so
-- the fix list is immediately actionable.
SELECT
  'MY-SCHEMA-014' AS check_id,
  'schema'        AS scope,
  x.sch           AS object,
  CONCAT('Schema `', x.sch, '` mixes ', x.n_collations,
         ' table collations across ', x.total, ' tables. Schema default: ',
         x.schema_collation, '. Dominant table collation: ', x.dominant,
         ' (', x.dominant_n, ' tables). Exceptions: ', x.exceptions, '. ',
         c.col_note,
         'Comparing or joining string columns whose collations differ forces a runtime conversion of one side, and a converted column cannot use its index — so a join that has always been indexed silently becomes a full scan, and EXPLAIN shows the scan without explaining it. ',
         'Collations also disagree about equality, so a UNIQUE constraint means different things on different tables here.') AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'schema_collation', x.schema_collation,
    'table_count', x.total,
    'distinct_table_collations', x.n_collations,
    'dominant_collation', x.dominant,
    'dominant_table_count', x.dominant_n,
    'exceptions', x.exceptions,
    'distinct_column_collations', c.n_col_collations) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT t.TABLE_SCHEMA AS sch,
         s.DEFAULT_COLLATION_NAME AS schema_collation,
         COUNT(*) AS total,
         COUNT(DISTINCT t.TABLE_COLLATION) AS n_collations,
         (SELECT t2.TABLE_COLLATION FROM information_schema.TABLES AS t2
           WHERE t2.TABLE_SCHEMA = t.TABLE_SCHEMA AND t2.TABLE_TYPE = 'BASE TABLE'
           GROUP BY t2.TABLE_COLLATION ORDER BY COUNT(*) DESC LIMIT 1) AS dominant,
         (SELECT COUNT(*) FROM information_schema.TABLES AS t3
           WHERE t3.TABLE_SCHEMA = t.TABLE_SCHEMA AND t3.TABLE_TYPE = 'BASE TABLE'
             AND t3.TABLE_COLLATION = (SELECT t4.TABLE_COLLATION FROM information_schema.TABLES AS t4
                WHERE t4.TABLE_SCHEMA = t.TABLE_SCHEMA AND t4.TABLE_TYPE = 'BASE TABLE'
                GROUP BY t4.TABLE_COLLATION ORDER BY COUNT(*) DESC LIMIT 1)) AS dominant_n,
         SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(t.TABLE_NAME, ' = ', t.TABLE_COLLATION)
           SEPARATOR '; '), 1, 400) AS exceptions
  FROM information_schema.TABLES AS t
  JOIN information_schema.SCHEMATA AS s ON s.SCHEMA_NAME = t.TABLE_SCHEMA
  WHERE t.TABLE_TYPE = 'BASE TABLE'
    AND t.TABLE_COLLATION IS NOT NULL
    AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY t.TABLE_SCHEMA, s.DEFAULT_COLLATION_NAME
) AS x
LEFT JOIN (
  SELECT TABLE_SCHEMA AS sch,
         COUNT(DISTINCT COLLATION_NAME) AS n_col_collations,
         IF(COUNT(DISTINCT COLLATION_NAME) > 1,
            CONCAT('Column level is worse: ', COUNT(DISTINCT COLLATION_NAME),
                   ' distinct collations across string columns. '), '') AS col_note
  FROM information_schema.COLUMNS
  WHERE COLLATION_NAME IS NOT NULL
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA
) AS c ON c.sch = x.sch
WHERE x.n_collations > 1;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-006' AS marker;
-- check: MY-SEC-006
-- title: Deprecated or weak authentication plugins
-- priority: 150 | category: SEC | scope: role | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- Version divergence that turns this from hygiene into a migration deadline:
--   MySQL 8.0     mysql_native_password deprecated, still enabled by default
--   MySQL 8.4     DISABLED by default (--mysql-native-password=OFF); accounts
--                 using it cannot authenticate until it is explicitly re-enabled
--   MySQL 9.0     REMOVED entirely; those accounts must be re-created
--   MariaDB       mysql_native_password remains supported and is still the
--                 default for many packagings, so there is no deadline there —
--                 only the cryptographic argument
-- Why it is weak regardless of deadline: mysql_native_password is unsalted
-- SHA1(SHA1(password)). The stored hash is password-equivalent for the
-- challenge-response handshake, so an attacker who reads mysql.user does not
-- need to crack anything. sha256_password (as distinct from
-- caching_sha2_password) additionally requires TLS or RSA key exchange to be
-- safe and is deprecated in 8.0.16+.
-- Summary shape: one row per plugin with a count, not one row per account.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-006' AS check_id,
  'role'       AS scope,
  x.acct_plugin AS object,
  CONCAT(x.n, ' account(s) authenticate with ', x.acct_plugin, ': ', x.list, '. ',
         CASE LOWER(x.acct_plugin)
           WHEN 'mysql_native_password' THEN
             CONCAT('This is unsalted SHA1(SHA1(password)); the stored hash is password-equivalent for the handshake, so reading mysql.user is enough to authenticate. ',
                    IF(@dbt_is_mariadb,
                       'MariaDB still supports it, so there is no removal deadline — but ed25519 or PAM is the stronger choice.',
                       'MySQL 8.4 disables it by default and 9.0 removed it, so these accounts will stop being able to connect on upgrade.'))
           WHEN 'sha256_password' THEN
             'Deprecated since MySQL 8.0.16 and only safe over TLS or with RSA key exchange; caching_sha2_password supersedes it.'
           WHEN 'mysql_old_password' THEN
             'The pre-4.1 16-byte hash. It is trivially breakable and was removed in MySQL 5.7.5.'
           ELSE 'This plugin is deprecated.'
         END) AS details,
  JSON_OBJECT(
    'plugin', x.acct_plugin,
    'account_count', x.n,
    'accounts', x.list,
    'fork', @dbt_fork,
    'server_version', @@GLOBAL.version) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT a.acct_plugin, COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 500) AS list
  FROM (ACCTSRC) AS a
  WHERE a.is_role = 0
    AND LOWER(a.acct_plugin) IN ('mysql_native_password', 'mysql_old_password', 'sha256_password')
    AND a.acct_user NOT IN ACCTSYS
  GROUP BY a.acct_plugin
) AS x
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-011' AS marker;
-- check: MY-SEC-011
-- title: No password validation policy
-- priority: 150 | category: SEC | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.PLUGINS, mysql.component (MySQL 8.0+)
-- Fork divergence in both the mechanism and the name:
--   MySQL 5.7        validate_password PLUGIN
--   MySQL 8.0+       validate_password COMPONENT, registered in mysql.component
--                    (the plugin form still loads but is deprecated)
--   MariaDB          simple_password_check and/or cracklib_password_check
--                    plugins; there is no validate_password at all
-- All three are probed; the component table is only consulted where it exists.
-- Without any of them the server accepts a one-character password, which matters
-- most for the accounts MY-SEC-002/004 says are reachable from anywhere.
-- Password EXPIRY is deliberately not part of this finding: forced rotation is
-- reported as a review row at P200 (MY-SEC-013) rather than as a defect, because
-- current guidance does not treat expiry as a control.
SET @dbt_q := "
SELECT
  'MY-SEC-011' AS check_id,
  'cluster'    AS scope,
  'password-policy' AS object,
  CONCAT('No password validation plugin or component is active: ',
         IF(@dbt_is_mariadb,
            'neither simple_password_check nor cracklib_password_check is loaded',
            'validate_password is loaded as neither a component nor a plugin'),
         '. The server will accept any password, including a single character, for every account — including the ',
         a.wildcard_accounts, ' account(s) reachable from any host (MY-SEC-004). ',
         'Active authentication-related plugins: ', IFNULL(p.auth_plugins, 'none'), '.') AS details,
  JSON_OBJECT(
    'validation_active', 0,
    'fork', @dbt_fork,
    'active_auth_plugins', IFNULL(p.auth_plugins, ''),
    'wildcard_host_accounts', a.wildcard_accounts) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT SUM(PLUGIN_STATUS = 'ACTIVE'
             AND (PLUGIN_NAME LIKE 'validate\\_password%'
               OR PLUGIN_NAME LIKE '%password\\_check%')) AS validators,
         SUBSTRING(GROUP_CONCAT(IF(PLUGIN_TYPE = 'AUTHENTICATION' AND PLUGIN_STATUS = 'ACTIVE',
                                   PLUGIN_NAME, NULL) SEPARATOR ', '), 1, 300) AS auth_plugins
    FROM information_schema.PLUGINS
) AS p,
(
  SELECT COUNT(*) AS wildcard_accounts FROM information_schema.USER_PRIVILEGES
   WHERE GRANTEE LIKE '%@''%'
) AS a
WHERE IFNULL(p.validators, 0) = 0
  AND IFNULL(@dbt_component_validate_password, 0) = 0";

-- mysql.component exists only on MySQL 8.0+; MariaDB has no component registry.
SET @dbt_component_validate_password := 0;
SET @dbt_q2 := IF(IFNULL(@dbt_has_mysql_component, 0) = 1 AND IFNULL(@dbt_priv_mysql_schema, 0) = 1,
  "SELECT COUNT(*) INTO @dbt_component_validate_password FROM mysql.component
     WHERE component_urn LIKE '%validate_password%'",
  'DO 1');
PREPARE dbt_stmt FROM @dbt_q2; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
PREPARE dbt_stmt FROM @dbt_q;  EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-012' AS marker;
-- check: MY-SEC-012
-- title: Legacy test database or test grants present
-- priority: 150 | category: SEC | scope: schema | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.SCHEMATA, information_schema.SCHEMA_PRIVILEGES
-- Historic MySQL packaging created a `test` schema plus rows in mysql.db that
-- grant every privilege on `test` and `test\_%` to ANY user, including the
-- anonymous ones (MY-SEC-003). The combination gives an unauthenticated
-- connection a writable schema on the server — useful for staging an
-- INTO OUTFILE attack or simply for filling the disk.
-- MariaDB's mariadb-install-db still creates it on several packagings (verified
-- present on a stock MariaDB 10.11 install); MySQL 5.7+ does not, and
-- mysql_secure_installation removes it.
-- Read through information_schema.SCHEMA_PRIVILEGES rather than mysql.db so the
-- check works without SELECT on the mysql schema.
SELECT
  'MY-SEC-012' AS check_id,
  'schema'     AS scope,
  'test'       AS object,
  CONCAT('The legacy `test` schema exists',
         IF(g.n > 0,
            CONCAT(' and ', g.n, ' grantee(s) hold schema-level privileges on test / test_%: ', g.list),
            ' (no wildcard grants on it were found in information_schema.SCHEMA_PRIVILEGES)'),
         '. Historic packaging granted all privileges on this schema to every user including anonymous accounts, which gives an unauthenticated connection somewhere writable on the server. ',
         'Tables in it: ', t.n, '. mysql_secure_installation removes both the schema and the grants.') AS details,
  JSON_OBJECT(
    'schema', 'test',
    'table_count', t.n,
    'wildcard_grants', g.n,
    'grantees', g.list) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'test'
) AS s,
(
  SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'test'
) AS t,
(
  SELECT COUNT(DISTINCT GRANTEE) AS n,
         SUBSTRING(GROUP_CONCAT(DISTINCT GRANTEE SEPARATOR ', '), 1, 300) AS list
    FROM information_schema.SCHEMA_PRIVILEGES
   WHERE TABLE_SCHEMA LIKE 'test%'
) AS g
WHERE s.n > 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-WAL-003' AS marker;
-- check: MY-WAL-003
-- title: Binary log cache spilling to disk
-- priority: 150 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: spill_ratio=0.01;min_cache_uses=10000
-- reads: @dbt_s_binlog_cache_use, @dbt_s_binlog_cache_disk_use, @@GLOBAL.binlog_cache_size
-- Every transaction buffers its row events in binlog_cache_size of memory before
-- commit; anything larger spills to a temporary file on disk and is read back at
-- commit time. A high spill ratio means large transactions, which are also the
-- transactions that block purge (MY-UNDO-001) and serialise replica appliers.
-- Raising binlog_cache_size is per-session memory, so it multiplies by
-- concurrency — the better fix is usually smaller transactions.
SELECT
  'MY-WAL-003' AS check_id,
  'setting'    AS scope,
  'binlog_cache_size' AS object,
  CONCAT(FORMAT(b.disk, 0), ' of ', FORMAT(b.uses, 0),
         ' transactions (', ROUND(100.0 * b.disk / b.uses, 2),
         '%) spilled their binary log events to disk since restart, past the ',
         ROUND(100 * COALESCE(@spill_ratio, 0.01), 2), '% threshold. ',
         'binlog_cache_size = ', ROUND(@@GLOBAL.binlog_cache_size / 1024, 0),
         ' KB per session. Raising it costs that much memory per concurrent writing session; splitting the large transactions costs nothing and also helps MY-UNDO-001 and replica apply latency.') AS details,
  JSON_OBJECT(
    'binlog_cache_use', b.uses,
    'binlog_cache_disk_use', b.disk,
    'spill_ratio', ROUND(b.disk / b.uses, 5),
    'binlog_cache_size', @@GLOBAL.binlog_cache_size,
    'threshold_ratio', COALESCE(@spill_ratio, 0.01)) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_binlog_cache_use, 0) AS DECIMAL(30, 0))      AS uses,
         CAST(IFNULL(@dbt_s_binlog_cache_disk_use, 0) AS DECIMAL(30, 0)) AS disk
) AS b
WHERE b.uses >= COALESCE(@min_cache_uses, 10000)
  AND b.disk / b.uses >= COALESCE(@spill_ratio, 0.01);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-WAL-005' AS marker;
-- check: MY-WAL-005
-- title: innodb_io_capacity at its rotational-disk default on solid-state storage
-- priority: 150 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: interview
-- thresholds: io_capacity_default=200;io_capacity_max_default=2000
-- reads: @@GLOBAL.innodb_io_capacity, @@GLOBAL.innodb_io_capacity_max, @dbt_storage
-- Requires .db-triage.yml baseline.storage to say ssd, nvme or cloud. Without
-- that the runner does not surface this row, because 200 IOPS is the right
-- answer on a spinning disk and there is no way to tell from inside the server
-- what the storage actually is. This is the MySQL sibling of PostgreSQL's
-- random_page_cost=4 finding, and it carries the same caveat.
-- The number bounds background flushing, so leaving it at 200 on an NVMe device
-- means InnoDB deliberately uses a fraction of the device and lets checkpoint
-- age climb (MY-WAL-004) under load it could easily absorb.
SELECT
  'MY-WAL-005' AS check_id,
  'setting'    AS scope,
  'innodb_io_capacity' AS object,
  CONCAT('innodb_io_capacity = ', @@GLOBAL.innodb_io_capacity,
         ' and innodb_io_capacity_max = ', @@GLOBAL.innodb_io_capacity_max,
         ' — the defaults, which assume a rotational disk — while the declared storage is ',
         IFNULL(@dbt_storage, 'unknown'),
         '. Background flushing is capped well below what the device can do, so checkpoint age climbs under write bursts instead of draining.') AS details,
  JSON_OBJECT(
    'innodb_io_capacity', @@GLOBAL.innodb_io_capacity,
    'innodb_io_capacity_max', @@GLOBAL.innodb_io_capacity_max,
    'declared_storage', IFNULL(@dbt_storage, 'unknown'),
    'innodb_flush_neighbors', @@GLOBAL.innodb_flush_neighbors) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE LOWER(IFNULL(@dbt_storage, '')) IN ('ssd', 'nvme', 'cloud')
  AND @@GLOBAL.innodb_io_capacity <= COALESCE(@io_capacity_default, 200)
  AND @@GLOBAL.innodb_io_capacity_max <= COALESCE(@io_capacity_max_default, 2000);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-WAL-006' AS marker;
-- check: MY-WAL-006
-- title: Buffer pool dirty page ratio high
-- priority: 150 | category: WAL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: dirty_ratio=0.75
-- reads: @dbt_s_innodb_buffer_pool_pages_dirty, @dbt_s_innodb_buffer_pool_pages_total,
--        @@GLOBAL.innodb_max_dirty_pages_pct
-- A snapshot, not a rate: this is the state at the moment the check ran, which
-- is why the details say so. Dirty pages above innodb_max_dirty_pages_pct mean
-- the page cleaners are behind the write rate; InnoDB responds by flushing
-- synchronously in the foreground, which users feel as latency spikes.
-- Both forks expose these counters identically.
SELECT
  'MY-WAL-006' AS check_id,
  'cluster'    AS scope,
  'buffer-pool-dirty-pages' AS object,
  CONCAT(FORMAT(p.dirty, 0), ' of ', FORMAT(p.total, 0),
         ' buffer pool pages are dirty at snapshot time (',
         ROUND(100.0 * p.dirty / p.total, 1), '%, threshold ',
         ROUND(100 * COALESCE(@dirty_ratio, 0.75), 0), '%; innodb_max_dirty_pages_pct = ',
         @@GLOBAL.innodb_max_dirty_pages_pct,
         '). The page cleaners are behind the write rate, so InnoDB starts flushing in the foreground and writers wait. See MY-WAL-001 for redo sizing and MY-WAL-005 for the flush rate cap.') AS details,
  JSON_OBJECT(
    'dirty_pages', p.dirty,
    'total_pages', p.total,
    'dirty_ratio', ROUND(p.dirty / p.total, 4),
    'threshold_ratio', COALESCE(@dirty_ratio, 0.75),
    'innodb_max_dirty_pages_pct', @@GLOBAL.innodb_max_dirty_pages_pct,
    'measured', 'snapshot') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_dirty, 0) AS DECIMAL(30, 0)) AS dirty,
         CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_total, 0) AS DECIMAL(30, 0)) AS total
) AS p
WHERE p.total > 0
  AND p.dirty / p.total >= COALESCE(@dirty_ratio, 0.75);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-004' AS marker;
-- check: MY-QRY-004
-- title: Top 10 statements by total latency
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- Ranked by total time, which is the only ranking that answers 'where does this server spend its day'. A 1 ms statement run ten million times outranks a 30 s report run once, and it should: fixing the first is worth ten thousand times more.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-004' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     
   ORDER BY s.SUM_TIMER_WAIT DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-005' AS marker;
-- check: MY-QRY-005
-- title: Top 10 statements by average latency
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- Ranked by average time with a 100-execution floor, so a single unlucky execution cannot top the list. This is the list a user complaint maps onto: the statements that are individually slow, as opposed to MY-QRY-004's statements that are collectively expensive.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-005' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     AND s.COUNT_STAR >= 100
   ORDER BY s.AVG_TIMER_WAIT DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-006' AS marker;
-- check: MY-QRY-006
-- title: Top 10 statements by rows examined per row sent
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- Rows examined divided by rows sent is the index-miss signature: a ratio of 1 means every row read was returned, a ratio of 10,000 means the server read ten thousand rows to return one. It finds missing indexes far more reliably than latency does, because a bad plan on a small table is fast today and catastrophic after the table grows.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-006' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     AND s.COUNT_STAR >= 100 AND s.SUM_ROWS_SENT > 0 AND (s.SUM_ROWS_EXAMINED / GREATEST(s.SUM_ROWS_SENT, 1)) >= 100
   ORDER BY (s.SUM_ROWS_EXAMINED / GREATEST(s.SUM_ROWS_SENT, 1)) DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-007' AS marker;
-- check: MY-QRY-007
-- title: Top 10 statements creating disk temporary tables
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- The statements behind MY-MEM-005. A disk temp table is usually a GROUP BY or ORDER BY that exceeded tmp_table_size, or — regardless of size — one that touches a TEXT or BLOB column, which forces disk on MySQL 5.7 and MariaDB no matter how small the result is.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-007' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     AND s.SUM_CREATED_TMP_DISK_TABLES > 0
   ORDER BY s.SUM_CREATED_TMP_DISK_TABLES DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-008' AS marker;
-- check: MY-QRY-008
-- title: Top 10 statements with full table scans
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- Statements that executed at least once with no index at all. SUM_NO_GOOD_INDEX_USED, reported alongside where present, counts the subtler case: an index existed and was rejected as worse than a scan. Read together with MY-IDX-004, which names the tables on the receiving end.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-008' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     AND s.SUM_NO_INDEX_USED > 0
   ORDER BY s.SUM_NO_INDEX_USED DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-009' AS marker;
-- check: MY-QRY-009
-- title: Top 10 statements by execution count
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- Ranked by raw frequency. This is the list that reveals an N+1 query pattern, a missing application cache, or a health check running every 200 ms — none of which show up as slow, and all of which set the floor on how much other work the server can do.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-009' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     
   ORDER BY s.COUNT_STAR DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

