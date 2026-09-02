-- db-triage — checks/mysql/inventory.sql
-- GENERATED FILE — do not hand-edit. Regenerated from
-- checks/registry-mysql.csv and checks/mysql/checks/*.sql.
--
-- HOW TO RUN (one session, in this order):
--   mysql --batch --raw --force "$DSN" \
--     -e "source checks/mysql/01_session.sql; \
--         source checks/mysql/00_preflight.sql; \
--         source checks/mysql/inventory.sql"
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
-- Contents: inventory pass, 21 checks, ordered by priority ascending so that
-- if the batch is interrupted the worst findings are already in hand.
-- P200 MY-CFG-001     Non-default global variables
-- P200 MY-CFG-002     Persisted variables (inventory)
-- P200 MY-REL-009     Buffer pool warm-up not configured (review)
-- P200 MY-REPL-012    server_id left at its default in a replicated topology
-- P200 MY-SCHEMA-012  Legacy character sets and row formats (inventory)
-- P200 MY-SEC-013     Accounts without password expiry (review)
-- P200 MY-SEC-014     Listening on all interfaces (review)
-- P200 MY-SEC-015     No audit logging (review)
-- P230 MY-SEC-007     Privileged accounts (review list)
-- P240 MY-QRY-015     Status snapshot
-- P240 MY-QRY-016     Per-account workload profile (MariaDB user statistics)
-- P250 MY-CAP-004     Schema sizes
-- P250 MY-CAP-005     Largest 20 tables
-- P250 MY-INFO-001    Server identity
-- P250 MY-INFO-003    Plugins and components
-- P250 MY-INFO-004    Replication topology
-- P250 MY-INFO-005    Connection summary
-- P250 MY-INFO-006    InnoDB summary
-- P250 MY-INFO-007    Object counts
-- P250 MY-INFO-008    Accounts summary
-- P250 MY-INFO-009    Statistics window

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CFG-001' AS marker;
-- check: MY-CFG-001
-- title: Non-default global variables
-- priority: 200 | category: CFG | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: MySQL: performance_schema.variables_info joined to global_variables;
--        MariaDB: information_schema.SYSTEM_VARIABLES (GLOBAL_VALUE vs DEFAULT_VALUE)
-- THE fork divergence for configuration inventory, and there is no common path:
--   MySQL 5.7.9+  performance_schema.variables_info gives VARIABLE_SOURCE
--                 (COMPILED / GLOBAL / SERVER / EXPLICIT / PERSISTED / DYNAMIC /
--                 COMMAND_LINE / LOGIN / USER) plus VARIABLE_PATH and the file
--                 line number, but NOT the compiled default value.
--   MariaDB       has no variables_info at all (verified absent on 10.11) but
--                 information_schema.SYSTEM_VARIABLES carries DEFAULT_VALUE and
--                 GLOBAL_VALUE_ORIGIN, which is the better shape for this check.
-- So MySQL answers "where did this come from" and MariaDB answers "what was it
-- before" — the finding says which question it could answer.
-- This is P200 inventory, not a problem list: it is what a reader consults AFTER
-- the findings, to understand why the server behaves as it does. The noise list
-- below removes the values that differ on every server by construction
-- (hostnames, paths, ports, UUIDs, locale and timezone).
SET @dbt_cfg_noise := "('hostname','server_uuid','datadir','socket','pid_file','port',
  'log_error','basedir','plugin_dir','tmpdir','time_zone','system_time_zone','server_id',
  'general_log_file','slow_query_log_file','log_bin_basename','log_bin_index','relay_log',
  'relay_log_basename','relay_log_index','secure_file_priv','innodb_data_home_dir',
  'innodb_log_group_home_dir','innodb_temp_data_file_path','innodb_undo_directory',
  'character_sets_dir','lc_messages_dir','version','version_comment','version_compile_os',
  'version_compile_machine','version_suffix','version_source_revision','version_ssl_library',
  'version_malloc_library','report_host','report_port','open_files_limit','gtid_executed',
  'gtid_purged','gtid_binlog_pos','gtid_binlog_state','gtid_slave_pos','gtid_current_pos')";

SET @dbt_q_mysql := "
SELECT
  'MY-CFG-001' AS check_id,
  'setting'    AS scope,
  i.VARIABLE_NAME AS object,
  CONCAT('`', i.VARIABLE_NAME, '` = ''', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 200),
         ''', source ', i.VARIABLE_SOURCE,
         IF(IFNULL(i.VARIABLE_PATH, '') <> '',
            CONCAT(' (', i.VARIABLE_PATH,
                   IF(i.VARIABLE_PATH IS NOT NULL, CONCAT(':', i.VARIABLE_SOURCE_LINE), ''), ')'), ''),
         IF(IFNULL(i.SET_USER, '') <> '',
            CONCAT(', last set by ', i.SET_USER, '@', IFNULL(i.SET_HOST, ''), ' at ', i.SET_TIME), ''),
         '. Not a finding: this is the configuration inventory, listing every variable this server did not take from its compiled default. ',
         'performance_schema.variables_info reports where a value came from but not what the compiled default was, so the previous value is not shown.') AS details,
  JSON_OBJECT(
    'variable', i.VARIABLE_NAME,
    'value', SUBSTRING(IFNULL(g.VARIABLE_VALUE, ''), 1, 500),
    'source', i.VARIABLE_SOURCE,
    'path', IFNULL(i.VARIABLE_PATH, ''),
    'source_line', i.VARIABLE_SOURCE_LINE,
    'set_user', IFNULL(i.SET_USER, ''),
    'set_time', CAST(i.SET_TIME AS CHAR),
    'catalog', 'performance_schema.variables_info') AS evidence_json,
  'high' AS confidence
FROM performance_schema.variables_info AS i
JOIN performance_schema.global_variables AS g ON g.VARIABLE_NAME = i.VARIABLE_NAME
WHERE i.VARIABLE_SOURCE <> 'COMPILED'
  AND i.VARIABLE_NAME NOT IN NOISE
ORDER BY i.VARIABLE_NAME";

SET @dbt_q_maria := "
SELECT
  'MY-CFG-001' AS check_id,
  'setting'    AS scope,
  LOWER(v.VARIABLE_NAME) AS object,
  CONCAT('`', LOWER(v.VARIABLE_NAME), '` = ''', SUBSTRING(IFNULL(v.GLOBAL_VALUE, ''), 1, 200),
         ''' (compiled default ''', SUBSTRING(IFNULL(v.DEFAULT_VALUE, '(none)'), 1, 200),
         '''), origin ', v.GLOBAL_VALUE_ORIGIN,
         IF(IFNULL(v.GLOBAL_VALUE_PATH, '') <> '', CONCAT(' from ', v.GLOBAL_VALUE_PATH), ''),
         ', scope ', v.VARIABLE_SCOPE, ', ',
         IF(v.READ_ONLY = 'YES', 'read-only (needs a restart to change)', 'dynamic'),
         '. Not a finding: this is the configuration inventory, listing every variable whose global value differs from the compiled default. ',
         'information_schema.SYSTEM_VARIABLES gives the default value but a coarser provenance than MySQL''s variables_info.') AS details,
  JSON_OBJECT(
    'variable', LOWER(v.VARIABLE_NAME),
    'value', SUBSTRING(IFNULL(v.GLOBAL_VALUE, ''), 1, 500),
    'default_value', SUBSTRING(IFNULL(v.DEFAULT_VALUE, ''), 1, 500),
    'origin', v.GLOBAL_VALUE_ORIGIN,
    'path', IFNULL(v.GLOBAL_VALUE_PATH, ''),
    'scope', v.VARIABLE_SCOPE,
    'read_only', v.READ_ONLY,
    'catalog', 'information_schema.SYSTEM_VARIABLES') AS evidence_json,
  'high' AS confidence
FROM information_schema.SYSTEM_VARIABLES AS v
WHERE v.VARIABLE_SCOPE IN ('GLOBAL', 'SESSION')
  AND v.GLOBAL_VALUE_ORIGIN <> 'COMPILED'
  AND NOT (IFNULL(v.GLOBAL_VALUE, '') <=> IFNULL(v.DEFAULT_VALUE, ''))
  AND LOWER(v.VARIABLE_NAME) NOT IN NOISE
ORDER BY v.VARIABLE_NAME";

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_variables_info, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1
    THEN REPLACE(@dbt_q_mysql, 'NOISE', @dbt_cfg_noise)
  WHEN IFNULL(@dbt_has_is_sysvars, 0) = 1
    THEN REPLACE(@dbt_q_maria, 'NOISE', @dbt_cfg_noise)
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CFG-002' AS marker;
-- check: MY-CFG-002
-- title: Persisted variables (inventory)
-- priority: 200 | category: CFG | scope: setting | cost: 0 | pass: inventory
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: performance_schema.persisted_variables
-- MySQL 8.0 only; MariaDB has no SET PERSIST and no such table (verified absent
-- on 10.11), so this emits nothing there.
-- The plain inventory of what is in mysqld-auto.cnf. MY-REL-010 is the FINDING
-- for the subset that conflicts with a file-sourced value; this row lists every
-- persisted variable regardless, because a reviewer comparing a server against
-- its configuration repository needs the whole list, not just the conflicts.
SET @dbt_q := "
SELECT
  'MY-CFG-002' AS check_id,
  'setting'    AS scope,
  p.VARIABLE_NAME AS object,
  CONCAT('`', p.VARIABLE_NAME, '` is persisted in mysqld-auto.cnf as ''',
         SUBSTRING(p.VARIABLE_VALUE, 1, 200), '''',
         IF(IFNULL(p.SET_USER, '') <> '',
            CONCAT(', set by ', p.SET_USER, '@', IFNULL(p.SET_HOST, ''), ' at ', p.SET_TIME), ''),
         '. Inventory only. mysqld-auto.cnf lives in the data directory and is read after every other configuration file, so anything here overrides my.cnf. ',
         'MY-REL-010 reports the subset that actually conflicts with a file-sourced value. ',
         'To remove one: RESET PERSIST `', p.VARIABLE_NAME, '`.') AS details,
  JSON_OBJECT(
    'variable', p.VARIABLE_NAME,
    'persisted_value', SUBSTRING(p.VARIABLE_VALUE, 1, 500),
    'set_user', IFNULL(p.SET_USER, ''),
    'set_host', IFNULL(p.SET_HOST, ''),
    'set_time', CAST(p.SET_TIME AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM performance_schema.persisted_variables AS p
ORDER BY p.VARIABLE_NAME";
SET @dbt_q := IF(IFNULL(@dbt_has_persisted_variables, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1,
                 @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REL-009' AS marker;
-- check: MY-REL-009
-- title: Buffer pool warm-up not configured (review)
-- priority: 200 | category: REL | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.innodb_buffer_pool_dump_at_shutdown,
--        @@GLOBAL.innodb_buffer_pool_load_at_startup,
--        @@GLOBAL.innodb_buffer_pool_dump_pct
-- Both variables exist on MySQL 5.6+ and MariaDB 10.0+ and both default to ON,
-- so finding either OFF means someone turned it off.
-- Reported at P200 as a review row, not a defect: it changes only how long a
-- restart takes to return to normal performance, and on a server with a small
-- pool or infrequent restarts that may not matter. On a server with a large
-- pool it matters a great deal — a cold pool means every query is reading from
-- disk, and a planned two-minute restart becomes an hour of degraded service
-- while the pool refills organically.
-- What is saved and restored is the LIST OF PAGE IDENTIFIERS, not the pages, so
-- the dump file is small and shutdown is not meaningfully delayed.
SELECT
  'MY-REL-009' AS check_id,
  'setting'    AS scope,
  IF(@@GLOBAL.innodb_buffer_pool_dump_at_shutdown = 0,
     'innodb_buffer_pool_dump_at_shutdown', 'innodb_buffer_pool_load_at_startup') AS object,
  CONCAT('innodb_buffer_pool_dump_at_shutdown = ',
         CAST(@@GLOBAL.innodb_buffer_pool_dump_at_shutdown AS CHAR),
         ', innodb_buffer_pool_load_at_startup = ',
         CAST(@@GLOBAL.innodb_buffer_pool_load_at_startup AS CHAR),
         ' (both default to ON, so this was changed). Buffer pool is ',
         ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2), ' GB. ',
         'Without warm-up, a restart leaves the pool empty and every query reads from disk until it refills organically — a planned two-minute restart becomes an extended period of degraded service on a pool this size. ',
         'What is dumped is the list of page identifiers, not the pages themselves, so the file is small and shutdown is not meaningfully delayed. ',
         'Recorded for review rather than as a defect: on a small pool or a server that never restarts, it does not matter.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_dump_at_shutdown', CAST(@@GLOBAL.innodb_buffer_pool_dump_at_shutdown AS CHAR),
    'innodb_buffer_pool_load_at_startup', CAST(@@GLOBAL.innodb_buffer_pool_load_at_startup AS CHAR),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_buffer_pool_dump_pct', @@GLOBAL.innodb_buffer_pool_dump_pct) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.innodb_buffer_pool_dump_at_shutdown = 0
   OR @@GLOBAL.innodb_buffer_pool_load_at_startup = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-REPL-012' AS marker;
-- check: MY-REPL-012
-- title: server_id left at its default in a replicated topology
-- priority: 200 | category: REPL | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.server_id, @dbt_v_server_uuid
-- Inventory, not a fault: nothing readable from one node can prove another node
-- shares this id. It is recorded because duplicate server_ids are a classic
-- cause of replicas that connect, disconnect and reconnect in a loop, and the
-- symptom (I/O thread flapping) rarely points at the cause.
-- Fork divergence: MySQL has @@server_uuid, which is generated per data
-- directory and is genuinely unique; MariaDB has no server_uuid at all, so the
-- numeric server_id is the only identity it has.
SELECT
  'MY-REPL-012' AS check_id,
  'setting'     AS scope,
  'server_id'   AS object,
  CONCAT('server_id = ', @@GLOBAL.server_id,
         IF(@@GLOBAL.server_id = 1, ' (the default)', ''),
         ' on a server that participates in replication. ',
         IF(@dbt_v_server_uuid IS NOT NULL,
            CONCAT('server_uuid = ', @dbt_v_server_uuid, ' is unique per data directory, so GTID-based replication is unaffected; only file-and-position replication and SHOW REPLICAS are.'),
            'MariaDB has no server_uuid, so server_id is this node''s only identity in the topology. Two nodes sharing it will fight over the same replication stream.'),
         ' Verify it is unique across the fleet; this cannot be checked from one node.') AS details,
  JSON_OBJECT(
    'server_id', @@GLOBAL.server_id,
    'server_uuid', IFNULL(@dbt_v_server_uuid, 'n/a'),
    'is_replica', IFNULL(@dbt_is_replica, 0),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0)) AS evidence_json,
  'low' AS confidence
FROM DUAL
WHERE (IFNULL(@dbt_is_replica, 0) = 1 OR IFNULL(@dbt_binlog_dump_threads, 0) > 0)
  AND @@GLOBAL.server_id IN (0, 1);
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SCHEMA-012' AS marker;
-- check: MY-SCHEMA-012
-- title: Legacy character sets and row formats (inventory)
-- priority: 200 | category: SCHEMA | scope: schema | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.TABLES (TABLE_COLLATION, ROW_FORMAT)
-- Inventory at P200: none of this is broken, but all of it constrains what can
-- be done later, and it is the context in which MY-SCHEMA-014 (collation
-- mismatch) is read.
--   latin1        cannot store most of the world's text; a later conversion
--                 rewrites every table and can change index sizes and sort order
--   utf8 / utf8mb3 MySQL's three-byte "utf8" cannot store emoji or many CJK
--                 characters; MySQL 8.0 renamed it utf8mb3 and deprecated it,
--                 MariaDB 10.6+ likewise
--   COMPACT/REDUNDANT  the pre-Barracuda row formats: no large-prefix indexes
--                 (767-byte limit rather than 3072), no per-table compression,
--                 and off-page BLOB storage behaves differently
-- Summary shape: one row per schema, since these are almost always uniform
-- within a schema and per-table rows would be pure noise.
SELECT
  'MY-SCHEMA-012' AS check_id,
  'schema'        AS scope,
  x.sch           AS object,
  CONCAT('Schema `', x.sch, '`: ', x.legacy_charset, ' of ', x.total,
         ' table(s) use a legacy character set (', IFNULL(x.charsets, 'none'), '), and ',
         x.legacy_rowfmt, ' use a pre-Barracuda row format (',
         IFNULL(x.rowfmts, 'none'), '). Total ',
         ROUND(x.bytes / 1073741824, 2), ' GB. ',
         'latin1 cannot represent most non-Western text; utf8/utf8mb3 is three-byte and cannot store emoji or many CJK characters (deprecated in MySQL 8.0 and MariaDB 10.6). ',
         'COMPACT and REDUNDANT limit index prefixes to 767 bytes rather than 3072 and cannot use per-table compression. ',
         'Server defaults: character_set_server = ', @@GLOBAL.character_set_server,
         ', collation_server = ', @@GLOBAL.collation_server, '.') AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'tables', x.total,
    'legacy_charset_tables', x.legacy_charset,
    'legacy_rowformat_tables', x.legacy_rowfmt,
    'charsets', IFNULL(x.charsets, ''),
    'row_formats', IFNULL(x.rowfmts, ''),
    'bytes', x.bytes,
    'character_set_server', @@GLOBAL.character_set_server,
    'collation_server', @@GLOBAL.collation_server) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT TABLE_SCHEMA AS sch,
         COUNT(*) AS total,
         IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes,
         SUM(TABLE_COLLATION LIKE 'latin1%' OR TABLE_COLLATION LIKE 'utf8mb3%'
             OR (TABLE_COLLATION LIKE 'utf8\_%')) AS legacy_charset,
         SUM(ROW_FORMAT IN ('Compact', 'Redundant')) AS legacy_rowfmt,
         SUBSTRING(GROUP_CONCAT(DISTINCT IF(TABLE_COLLATION LIKE 'latin1%'
             OR TABLE_COLLATION LIKE 'utf8mb3%' OR TABLE_COLLATION LIKE 'utf8\_%',
             TABLE_COLLATION, NULL) SEPARATOR ', '), 1, 200) AS charsets,
         SUBSTRING(GROUP_CONCAT(DISTINCT IF(ROW_FORMAT IN ('Compact', 'Redundant'),
             ROW_FORMAT, NULL) SEPARATOR ', '), 1, 100) AS rowfmts
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA
) AS x
WHERE x.legacy_charset > 0 OR x.legacy_rowfmt > 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-013' AS marker;
-- check: MY-SEC-013
-- title: Accounts without password expiry (review)
-- priority: 200 | category: SEC | scope: role | cost: 0 | pass: inventory
-- engine: mysql | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source (password_lifetime), @dbt_v_default_password_lifetime
-- Reported as a P200 review row, NOT as a problem. Forced rotation is no longer
-- recommended by NIST SP 800-63B or by most corporate standards, so db-triage
-- states the position rather than asserting a defect — which is what the design
-- asks for.
-- Fork divergence: mysql.user.password_lifetime is a MySQL column. MariaDB's
-- mysql.user view does not have it (verified absent on 10.11) — MariaDB does
-- support ALTER USER ... PASSWORD EXPIRE INTERVAL but stores it in the
-- global_priv JSON under a different key — so the normalised source returns NULL
-- there and this check emits nothing on MariaDB.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-013' AS check_id,
  'role'       AS scope,
  'password-expiry' AS object,
  CONCAT(x.n, ' account(s) inherit the global password lifetime, which is ',
         IF(CAST(IFNULL(@dbt_v_default_password_lifetime, 0) AS SIGNED) = 0,
            'unlimited (default_password_lifetime = 0)',
            CONCAT(@dbt_v_default_password_lifetime, ' days')),
         ': ', x.list,
         '. Recorded for review, not as a defect — current guidance (NIST SP 800-63B) treats scheduled rotation as harmful rather than protective, so the useful controls are MY-SEC-011 (validation), MY-SEC-005 (TLS) and MY-SEC-002/004 (reachability).') AS details,
  JSON_OBJECT(
    'accounts_without_explicit_expiry', x.n,
    'accounts', x.list,
    'default_password_lifetime', CAST(IFNULL(@dbt_v_default_password_lifetime, 0) AS SIGNED)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         SUBSTRING(GROUP_CONCAT(CONCAT('''', a.acct_user, '''@''', a.acct_host, '''')
           ORDER BY a.acct_user SEPARATOR ', '), 1, 500) AS list
  FROM (ACCTSRC) AS a
  WHERE a.is_role = 0
    AND a.password_lifetime IS NULL
    AND a.acct_user <> ''
    AND a.acct_user NOT IN ACCTSYS
) AS x
WHERE x.n > 0
  AND CAST(IFNULL(@dbt_v_default_password_lifetime, 0) AS SIGNED) = 0
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0 OR @dbt_is_mariadb, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-014' AS marker;
-- check: MY-SEC-014
-- title: Listening on all interfaces (review)
-- priority: 200 | category: SEC | scope: setting | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @@GLOBAL.bind_address, @@GLOBAL.port, @@GLOBAL.skip_networking
-- Inventory, at P200, because a database on a private network legitimately binds
-- to every interface and db-triage cannot see the firewall. It is recorded
-- because it is the context in which MY-SEC-002 and MY-SEC-004 are read: a
-- wildcard-host superuser account matters far more when the port answers on
-- every interface than when it answers only on loopback.
-- MySQL 8.0.13+ accepts a comma-separated list and the special values '*',
-- '0.0.0.0' and '::'; MariaDB accepts '*' and a single address. All the
-- unrestricted spellings are matched.
SELECT
  'MY-SEC-014' AS check_id,
  'setting'    AS scope,
  'bind_address' AS object,
  CONCAT('bind_address = ', IF(@@GLOBAL.bind_address = '', '(empty, meaning all interfaces)', @@GLOBAL.bind_address),
         ' on port ', @@GLOBAL.port, ', skip_networking = ',
         CAST(@@GLOBAL.skip_networking AS CHAR),
         ': the server answers on every network interface. ',
         'Read this together with MY-SEC-002 and MY-SEC-004 — ', w.n,
         ' account(s) have a wildcard host pattern. ',
         'require_secure_transport = ', IFNULL(@dbt_v_require_secure_transport, 'n/a'),
         '. Recorded for context, not as a defect: a private network or security group may already be the boundary.') AS details,
  JSON_OBJECT(
    'bind_address', @@GLOBAL.bind_address,
    'port', @@GLOBAL.port,
    'skip_networking', CAST(@@GLOBAL.skip_networking AS CHAR),
    'wildcard_host_accounts', w.n,
    'require_secure_transport', IFNULL(@dbt_v_require_secure_transport, 'n/a')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n FROM information_schema.USER_PRIVILEGES WHERE GRANTEE LIKE '%@''%''%'
) AS w
WHERE @@GLOBAL.skip_networking = 0
  AND (@@GLOBAL.bind_address IN ('*', '0.0.0.0', '::', '') OR @@GLOBAL.bind_address LIKE '%0.0.0.0%');
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-015' AS marker;
-- check: MY-SEC-015
-- title: No audit logging (review)
-- priority: 200 | category: SEC | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.PLUGINS, mysql.component
-- Fork and edition divergence, all four cases probed:
--   MySQL Enterprise   audit_log plugin (component form in 8.0.30+)
--   Percona Server     audit_log plugin (free)
--   MariaDB            server_audit plugin (free)
--   MySQL Community    no audit facility at all; the general log (MY-CAP-007) is
--                      the only alternative and is not an audit trail
-- Inventory at P200: whether an audit trail is required is a compliance
-- question, not a database one. What db-triage supplies is the fact, so the
-- reviewer does not have to ask.
SELECT
  'MY-SEC-015' AS check_id,
  'cluster'    AS scope,
  'audit-logging' AS object,
  CONCAT('No audit plugin is active (looked for audit_log, server_audit, ',
         'AUDIT-type plugins and the MySQL 8.0 audit_log component). ',
         'Active plugin count: ', p.total, '. ',
         IF(@dbt_is_mariadb,
            'MariaDB ships server_audit and it can be installed without a restart.',
            'The audit_log plugin is an Enterprise feature in Oracle MySQL; Percona Server ships an equivalent free one. MySQL Community has no audit facility.'),
         ' general_log = ', CAST(@@GLOBAL.general_log AS CHAR),
         ' — note the general log records everything and is not a substitute for an audit trail (see MY-CAP-007). ',
         'Recorded for review: whether an audit trail is required is a compliance decision.') AS details,
  JSON_OBJECT(
    'audit_plugin_active', 0,
    'active_plugins', p.total,
    'fork', @dbt_fork,
    'general_log', CAST(@@GLOBAL.general_log AS CHAR)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS total,
         SUM(PLUGIN_STATUS = 'ACTIVE'
             AND (PLUGIN_NAME LIKE '%audit%' OR PLUGIN_TYPE = 'AUDIT')) AS auditors
  FROM information_schema.PLUGINS
) AS p
WHERE IFNULL(p.auditors, 0) = 0;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-SEC-007' AS marker;
-- check: MY-SEC-007
-- title: Privileged accounts (review list)
-- priority: 230 | category: SEC | scope: role | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src
-- Not a problem: the list a security reviewer signs off on, in the P230 review
-- band. One row per account so each can be individually accepted or challenged.
-- Covers the global privileges that let an account escape its own scope: SUPER
-- (and its MySQL 8.0 replacements, which are dynamic privileges not visible in
-- mysql.user — noted in the details rather than silently missed), FILE (read and
-- write any file the server user can), PROCESS (see every other session's SQL),
-- GRANT OPTION (privilege escalation), SHUTDOWN, RELOAD, CREATE USER,
-- REPLICATION SLAVE (read the entire change stream).
-- Platform-managed accounts are excluded.
SET @dbt_q := REPLACE("
SELECT
  'MY-SEC-007' AS check_id,
  'role'       AS scope,
  CONCAT(a.acct_user, '@', a.acct_host) AS object,
  CONCAT('''', a.acct_user, '''@''', a.acct_host, ''' holds ', a.priv_list,
         IF(a.has_all_privs, ' (the complete global privilege set)', ''),
         '. Plugin ', a.acct_plugin, ', credential ', IF(a.has_credential, 'set', 'EMPTY'),
         ', ', IF(a.account_locked, 'locked', 'not locked'), '. ',
         IF(@dbt_is_mariadb,
            'MariaDB splits SUPER into named privileges (SET USER, CONNECTION ADMIN, BINLOG ADMIN, READ_ONLY ADMIN and others); those are held in mysql.global_priv and are not all visible in this list.',
            'MySQL 8.0 replaced much of SUPER with dynamic privileges (SYSTEM_VARIABLES_ADMIN, SYSTEM_USER, BACKUP_ADMIN, CLONE_ADMIN and others) which live in mysql.global_grants, not mysql.user, and are not shown here.'),
         ' Confirm this account is still required.') AS details,
  JSON_OBJECT(
    'user', a.acct_user,
    'host', a.acct_host,
    'plugin', a.acct_plugin,
    'global_privileges', a.priv_list,
    'has_all_privileges', a.has_all_privs,
    'has_credential', a.has_credential,
    'account_locked', a.account_locked) AS evidence_json,
  'medium' AS confidence
FROM (ACCTSRC) AS a
WHERE a.is_role = 0
  AND a.priv_list <> ''
  AND a.acct_user NOT IN ACCTSYS
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := REPLACE(@dbt_q, 'ACCTSYS', @dbt_acct_system);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-015' AS marker;
-- check: MY-QRY-015
-- title: Status snapshot
-- priority: 240 | category: QRY | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: the @dbt_s_* status bundle (01_session.sql §6)
-- Always emitted. Not a problem: the numbers a practitioner would ask for first,
-- in one row, so the rest of the report can be read in context.
-- Two kinds of number, deliberately labelled differently: the instantaneous ones
-- (Threads_running, current row-lock waits) are a SNAPSHOT and can miss a storm
-- entirely; the rates are averages SINCE RESTART and hide any recent change.
-- Neither is a substitute for monitoring, which is why MY-REL-006 checks whether
-- any exists.
SELECT
  'MY-QRY-015' AS check_id,
  'cluster'    AS scope,
  'status-snapshot' AS object,
  CONCAT('At snapshot: Threads_running = ', s.running, ', Threads_connected = ', s.connected,
         ', Innodb_row_lock_current_waits = ', s.lock_waits,
         ', average row-lock wait ', s.lock_time_avg, ' ms. ',
         'Rates since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago: ',
         ROUND(s.questions / GREATEST(@dbt_uptime_s, 1), 1), ' questions/s, ',
         ROUND(s.commits / GREATEST(@dbt_uptime_s, 1), 1), ' commits/s, ',
         ROUND(s.rollbacks / GREATEST(@dbt_uptime_s, 1), 2), ' rollbacks/s (',
         ROUND(100.0 * s.rollbacks / GREATEST(s.commits + s.rollbacks, 1), 1), '% of transactions), ',
         ROUND(s.data_reads / GREATEST(@dbt_uptime_s, 1), 1), ' InnoDB data reads/s, ',
         ROUND(s.data_writes / GREATEST(@dbt_uptime_s, 1), 1), ' InnoDB data writes/s, ',
         ROUND(s.slow / GREATEST(@dbt_uptime_s, 1) * 3600, 1), ' slow queries/h. ',
         'The instantaneous figures are one sample and can miss a storm; the rates are averages over the whole window and hide recent change. Neither replaces monitoring (MY-REL-006).') AS details,
  JSON_OBJECT(
    'threads_running', s.running,
    'threads_connected', s.connected,
    'innodb_row_lock_current_waits', s.lock_waits,
    'innodb_row_lock_time_avg_ms', s.lock_time_avg,
    'questions_per_second', ROUND(s.questions / GREATEST(@dbt_uptime_s, 1), 2),
    'commits_per_second', ROUND(s.commits / GREATEST(@dbt_uptime_s, 1), 3),
    'rollbacks_per_second', ROUND(s.rollbacks / GREATEST(@dbt_uptime_s, 1), 4),
    'rollback_pct', ROUND(100.0 * s.rollbacks / GREATEST(s.commits + s.rollbacks, 1), 2),
    'innodb_data_reads_per_second', ROUND(s.data_reads / GREATEST(@dbt_uptime_s, 1), 2),
    'innodb_data_writes_per_second', ROUND(s.data_writes / GREATEST(@dbt_uptime_s, 1), 2),
    'slow_queries_per_hour', ROUND(s.slow / GREATEST(@dbt_uptime_s, 1) * 3600, 2),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_s_threads_running, 0) AS DECIMAL(20, 0))                 AS running,
    CAST(IFNULL(@dbt_s_threads_connected, 0) AS DECIMAL(20, 0))               AS connected,
    CAST(IFNULL(@dbt_s_innodb_row_lock_current_waits, 0) AS DECIMAL(20, 0))   AS lock_waits,
    CAST(IFNULL(@dbt_s_innodb_row_lock_time_avg, 0) AS DECIMAL(20, 0))        AS lock_time_avg,
    CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0))                       AS questions,
    CAST(IFNULL(@dbt_s_com_commit, 0) AS DECIMAL(30, 0))                      AS commits,
    CAST(IFNULL(@dbt_s_com_rollback, 0) AS DECIMAL(30, 0))                    AS rollbacks,
    CAST(IFNULL(@dbt_s_innodb_data_reads, 0) AS DECIMAL(30, 0))               AS data_reads,
    CAST(IFNULL(@dbt_s_innodb_data_writes, 0) AS DECIMAL(30, 0))              AS data_writes,
    CAST(IFNULL(@dbt_s_slow_queries, 0) AS DECIMAL(30, 0))                    AS slow
) AS s;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-QRY-016' AS marker;
-- check: MY-QRY-016
-- title: Per-account workload profile (MariaDB user statistics)
-- priority: 240 | category: QRY | scope: role | cost: 1 | pass: inventory
-- engine: mariadb | requires: (none)
-- thresholds: top_n=15
-- reads: information_schema.USER_STATISTICS, @dbt_v_userstat
-- NOT in the design's §5.2 table. Added because MariaDB's userstat feature has
-- no MySQL or PostgreSQL equivalent and answers a question the digest tables
-- cannot: WHICH ACCOUNT is responsible for the load. The digest table aggregates
-- by statement text across all accounts, so a shared application user and a
-- runaway reporting job are indistinguishable there.
-- Availability: information_schema.USER_STATISTICS exists on MariaDB 10.x
-- (verified on 10.11) and on Percona Server. It is EMPTY unless the userstat
-- variable is ON, which it is not by default — hence the gate on @dbt_v_userstat
-- as well as on the table, and the note in the finding when it is off.
-- Oracle MySQL has no equivalent at all, so the check is engine=mariadb.
-- CPU_TIME and BUSY_TIME are in seconds and are cumulative since the counters
-- were last flushed, which on a server nobody has flushed means since restart.
SET @dbt_q := "
SELECT
  'MY-QRY-016' AS check_id,
  'role'       AS scope,
  u.USER       AS object,
  CONCAT('Account ''', u.USER, ''': ', FORMAT(u.TOTAL_CONNECTIONS, 0),
         ' connection(s) since counters were reset, ', u.CONCURRENT_CONNECTIONS,
         ' concurrent now, ', ROUND(u.BUSY_TIME, 1), ' s busy / ',
         ROUND(u.CPU_TIME, 1), ' s CPU. ',
         'Rows read ', FORMAT(u.ROWS_READ, 0), ', sent ', FORMAT(u.ROWS_SENT, 0),
         ' (ratio ', ROUND(u.ROWS_READ / GREATEST(u.ROWS_SENT, 1), 1), '), ',
         'inserted ', FORMAT(u.ROWS_INSERTED, 0), ', updated ', FORMAT(u.ROWS_UPDATED, 0),
         ', deleted ', FORMAT(u.ROWS_DELETED, 0), '. ',
         'Commands: ', FORMAT(u.SELECT_COMMANDS, 0), ' select, ',
         FORMAT(u.UPDATE_COMMANDS, 0), ' update, ', FORMAT(u.OTHER_COMMANDS, 0), ' other. ',
         'Transactions: ', FORMAT(u.COMMIT_TRANSACTIONS, 0), ' committed, ',
         FORMAT(u.ROLLBACK_TRANSACTIONS, 0), ' rolled back. ',
         'Denied connections ', u.DENIED_CONNECTIONS, ', access denied ', u.ACCESS_DENIED,
         ', lost connections ', u.LOST_CONNECTIONS, ', TLS connections ',
         FORMAT(u.TOTAL_SSL_CONNECTIONS, 0), ' of ', FORMAT(u.TOTAL_CONNECTIONS, 0), '. ',
         'This is the per-account view the statement digest cannot give: digests aggregate by statement text across every account, so a shared application user and a runaway report look identical there.') AS details,
  JSON_OBJECT(
    'user', u.USER,
    'total_connections', u.TOTAL_CONNECTIONS,
    'concurrent_connections', u.CONCURRENT_CONNECTIONS,
    'busy_seconds', ROUND(u.BUSY_TIME, 2),
    'cpu_seconds', ROUND(u.CPU_TIME, 2),
    'rows_read', u.ROWS_READ,
    'rows_sent', u.ROWS_SENT,
    'read_per_sent', ROUND(u.ROWS_READ / GREATEST(u.ROWS_SENT, 1), 2),
    'rows_inserted', u.ROWS_INSERTED,
    'rows_updated', u.ROWS_UPDATED,
    'rows_deleted', u.ROWS_DELETED,
    'select_commands', u.SELECT_COMMANDS,
    'update_commands', u.UPDATE_COMMANDS,
    'commit_transactions', u.COMMIT_TRANSACTIONS,
    'rollback_transactions', u.ROLLBACK_TRANSACTIONS,
    'denied_connections', u.DENIED_CONNECTIONS,
    'access_denied', u.ACCESS_DENIED,
    'ssl_connections', u.TOTAL_SSL_CONNECTIONS,
    'bytes_received', u.BYTES_RECEIVED,
    'bytes_sent', u.BYTES_SENT,
    'binlog_bytes_written', u.BINLOG_BYTES_WRITTEN) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM information_schema.USER_STATISTICS AS u
ORDER BY u.BUSY_TIME DESC
LIMIT 15";
SET @dbt_q := IF(IFNULL(@dbt_has_user_statistics, 0) = 1
                 AND UPPER(IFNULL(@dbt_v_userstat, 'OFF')) IN ('ON', '1'), @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CAP-004' AS marker;
-- check: MY-CAP-004
-- title: Schema sizes
-- priority: 250 | category: CAP | scope: schema | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.TABLES grouped by schema
-- Always emitted. Environment inventory, so the report doubles as documentation
-- of what this instance actually holds.
-- CACHE CAVEAT, carried in every finding that uses these numbers: on MySQL 8.0
-- the DATA_LENGTH, INDEX_LENGTH, DATA_FREE and TABLE_ROWS columns are served
-- from a cache refreshed at most every information_schema_stats_expiry seconds
-- (default 86400), so they can be a day stale. MariaDB reads them live from the
-- storage engine. db-triage never runs ANALYZE TABLE to refresh them, because
-- that is a write.
-- TABLE_ROWS is an InnoDB ESTIMATE from index dives in all cases, not a count,
-- and can be off by a large factor on a table with wide rows.
SELECT
  'MY-CAP-004' AS check_id,
  'schema'     AS scope,
  x.sch        AS object,
  CONCAT('Schema `', x.sch, '`: ', ROUND(x.total / 1073741824, 2), ' GB total (',
         ROUND(x.data / 1073741824, 2), ' GB data, ', ROUND(x.idx / 1073741824, 2),
         ' GB index, ', ROUND(x.free / 1073741824, 2), ' GB reported free), ',
         x.tables, ' table(s), ~', FORMAT(x.rows_est, 0), ' rows estimated. ',
         'Engines: ', x.engines, '. Collations: ', x.collations, '. ',
         'Sizes are ', IF(@dbt_is_mariadb, 'read live from the storage engine',
            CONCAT('from the information_schema cache, up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20, 0)) / 3600, 0),
                   ' h stale')),
         '; row counts are InnoDB estimates in all cases, not counts.') AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'total_bytes', x.total,
    'data_bytes', x.data,
    'index_bytes', x.idx,
    'data_free_bytes', x.free,
    'table_count', x.tables,
    'estimated_rows', x.rows_est,
    'engines', x.engines,
    'collations', x.collations,
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT TABLE_SCHEMA AS sch,
         IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS total,
         IFNULL(SUM(DATA_LENGTH), 0) AS data,
         IFNULL(SUM(INDEX_LENGTH), 0) AS idx,
         IFNULL(SUM(DATA_FREE), 0)   AS free,
         COUNT(*) AS tables,
         IFNULL(SUM(TABLE_ROWS), 0) AS rows_est,
         SUBSTRING(GROUP_CONCAT(DISTINCT ENGINE SEPARATOR ', '), 1, 120) AS engines,
         SUBSTRING(GROUP_CONCAT(DISTINCT TABLE_COLLATION SEPARATOR ', '), 1, 200) AS collations
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA
) AS x
ORDER BY x.total DESC;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CAP-005' AS marker;
-- check: MY-CAP-005
-- title: Largest 20 tables
-- priority: 250 | category: CAP | scope: relation | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: top_n=20
-- reads: information_schema.TABLES
-- Always emitted. Same cache and estimate caveats as MY-CAP-004, restated
-- because these rows are read on their own.
-- Index-to-data ratio is included because it is the cheapest signal of an
-- over-indexed table: above roughly 1.0 the indexes cost more space than the
-- rows do, which is worth reading next to MY-IDX-001/003/005.
SELECT
  'MY-CAP-005' AS check_id,
  'relation'   AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('`', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '`: ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2), ' GB (',
         ROUND(t.DATA_LENGTH / 1073741824, 2), ' GB data + ',
         ROUND(t.INDEX_LENGTH / 1073741824, 2), ' GB index, ratio ',
         ROUND(t.INDEX_LENGTH / GREATEST(t.DATA_LENGTH, 1), 2),
         '), ~', FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows estimated, ',
         'engine ', t.ENGINE, ', row format ', IFNULL(t.ROW_FORMAT, 'unknown'),
         ', collation ', IFNULL(t.TABLE_COLLATION, 'n/a'),
         ', DATA_FREE ', ROUND(t.DATA_FREE / 1073741824, 2), ' GB, created ',
         IFNULL(CAST(t.CREATE_TIME AS CHAR), 'unknown'), '. ',
         IF(t.INDEX_LENGTH > t.DATA_LENGTH,
            'Indexes occupy more space than the rows do — read with MY-IDX-001, MY-IDX-003 and MY-IDX-005. ', ''),
         'Sizes are ', IF(@dbt_is_mariadb, 'live', 'cached (up to information_schema_stats_expiry old)'),
         '; row counts are estimates.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA, 'table', t.TABLE_NAME,
    'total_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'data_bytes', t.DATA_LENGTH,
    'index_bytes', t.INDEX_LENGTH,
    'index_to_data_ratio', ROUND(t.INDEX_LENGTH / GREATEST(t.DATA_LENGTH, 1), 3),
    'data_free_bytes', t.DATA_FREE,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'engine', t.ENGINE,
    'row_format', IFNULL(t.ROW_FORMAT, ''),
    'collation', IFNULL(t.TABLE_COLLATION, ''),
    'created', CAST(t.CREATE_TIME AS CHAR),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'medium' AS confidence
FROM information_schema.TABLES AS t
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'sys')
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-001' AS marker;
-- check: MY-INFO-001
-- title: Server identity
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: version and fork facts from 01_session.sql plus the universal settings
-- Always emitted. The row a reader looks at first and the one that makes the
-- rest of the report interpretable: which fork, which version, which role in the
-- topology, and the handful of settings that change the meaning of every other
-- finding.
-- Fork-specific values that do not exist everywhere (server_uuid, gtid_mode,
-- super_read_only) are printed as their bundle value or 'n/a', never invented.
SELECT
  'MY-INFO-001' AS check_id,
  'cluster'     AS scope,
  @@GLOBAL.hostname AS object,
  CONCAT(@dbt_fork, ' ', @@GLOBAL.version, ' (', @@GLOBAL.version_comment, ') on ',
         @@GLOBAL.version_compile_os, '/', @@GLOBAL.version_compile_machine,
         ', platform ', IFNULL(@dbt_platform, 'unknown'),
         ', hostname ', @@GLOBAL.hostname, ':', @@GLOBAL.port,
         ', up ', ROUND(@dbt_uptime_s / 86400, 1), ' days. ',
         'Role: ', IF(IFNULL(@dbt_is_replica, 0) = 1, CONCAT('replica of ', IFNULL(@dbt_repl_source, 'unknown')), 'not a replica'),
         ', ', IFNULL(@dbt_binlog_dump_threads, 0), ' replica(s) connected',
         ', read_only = ', CAST(@@GLOBAL.read_only AS CHAR),
         ', super_read_only = ', IFNULL(@dbt_v_super_read_only, 'n/a'),
         ', server_id = ', @@GLOBAL.server_id,
         ', server_uuid = ', IFNULL(@dbt_v_server_uuid, 'n/a (MariaDB has none)'), '. ',
         'Durability and logging: log_bin = ', CAST(@@GLOBAL.log_bin AS CHAR),
         ', binlog_format = ', @@GLOBAL.binlog_format,
         ', gtid = ', IFNULL(@dbt_v_gtid_mode, IF(@dbt_is_mariadb, CONCAT('MariaDB per-connection; gtid_strict_mode = ', IFNULL(@dbt_v_gtid_strict_mode, 'n/a')), 'n/a')),
         ', innodb_flush_log_at_trx_commit = ', @@GLOBAL.innodb_flush_log_at_trx_commit,
         ', sync_binlog = ', @@GLOBAL.sync_binlog,
         ', innodb_doublewrite = ', CAST(@@GLOBAL.innodb_doublewrite AS CHAR), '. ',
         'Sizing: innodb_buffer_pool_size = ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB, max_connections = ', @@GLOBAL.max_connections,
         ', performance_schema = ', CAST(@@GLOBAL.performance_schema AS CHAR),
         ', sys views = ', IFNULL(@dbt_sys_view_count, 0), '. ',
         'Defaults: character_set_server = ', @@GLOBAL.character_set_server,
         ', collation_server = ', @@GLOBAL.collation_server,
         ', default_storage_engine = ', @@GLOBAL.default_storage_engine,
         ', global sql_mode = ''', @dbt_global_sql_mode, '''.') AS details,
  JSON_OBJECT(
    'fork', @dbt_fork, 'version', @@GLOBAL.version, 'version_num', CAST(@dbt_vnum AS UNSIGNED),
    'version_comment', @@GLOBAL.version_comment,
    'compile_os', @@GLOBAL.version_compile_os, 'compile_machine', @@GLOBAL.version_compile_machine,
    'platform', IFNULL(@dbt_platform, 'unknown'),
    'hostname', @@GLOBAL.hostname, 'port', @@GLOBAL.port,
    'uptime_seconds', @dbt_uptime_s,
    'is_replica', IFNULL(@dbt_is_replica, 0),
    'replication_source', IFNULL(@dbt_repl_source, ''),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'read_only', CAST(@@GLOBAL.read_only AS CHAR),
    'super_read_only', IFNULL(@dbt_v_super_read_only, 'n/a'),
    'server_id', @@GLOBAL.server_id,
    'server_uuid', IFNULL(@dbt_v_server_uuid, 'n/a'),
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR),
    'binlog_format', @@GLOBAL.binlog_format,
    'gtid_mode', IFNULL(@dbt_v_gtid_mode, 'n/a'),
    'innodb_flush_log_at_trx_commit', @@GLOBAL.innodb_flush_log_at_trx_commit,
    'sync_binlog', @@GLOBAL.sync_binlog,
    'innodb_doublewrite', CAST(@@GLOBAL.innodb_doublewrite AS CHAR),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'max_connections', @@GLOBAL.max_connections,
    'performance_schema', CAST(@@GLOBAL.performance_schema AS CHAR),
    'sys_view_count', IFNULL(@dbt_sys_view_count, 0),
    'character_set_server', @@GLOBAL.character_set_server,
    'collation_server', @@GLOBAL.collation_server,
    'default_storage_engine', @@GLOBAL.default_storage_engine,
    'global_sql_mode', @dbt_global_sql_mode) AS evidence_json,
  'high' AS confidence
FROM DUAL;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-003' AS marker;
-- check: MY-INFO-003
-- title: Plugins and components
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.PLUGINS, mysql.component (MySQL 8.0+)
-- Always emitted, grouped by plugin type so the row stays readable. What is
-- loaded determines what several findings mean: an audit plugin answers
-- MY-SEC-015, a password-validation plugin answers MY-SEC-011, the thread pool
-- answers MY-CONN-006, semi-sync answers MY-REPL-009, and a non-default
-- authentication plugin changes how MY-SEC-001 and MY-SEC-006 should be read.
-- mysql.component is MySQL 8.0's separate registry for components (the successor
-- to plugins); MariaDB has no such table, so the component list is omitted there.
SELECT
  'MY-INFO-003' AS check_id,
  'cluster'     AS scope,
  p.PLUGIN_TYPE AS object,
  CONCAT(p.n, ' active ', p.PLUGIN_TYPE, ' plugin(s): ', p.list,
         IF(p.inactive > 0, CONCAT('. Also ', p.inactive, ' present but not active: ', p.inactive_list), ''),
         '.') AS details,
  JSON_OBJECT(
    'plugin_type', p.PLUGIN_TYPE,
    'active_count', p.n,
    'active_plugins', p.list,
    'inactive_count', p.inactive,
    'inactive_plugins', IFNULL(p.inactive_list, '')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT PLUGIN_TYPE,
         SUM(PLUGIN_STATUS = 'ACTIVE') AS n,
         SUM(PLUGIN_STATUS <> 'ACTIVE') AS inactive,
         SUBSTRING(GROUP_CONCAT(IF(PLUGIN_STATUS = 'ACTIVE',
           CONCAT(PLUGIN_NAME, IF(IFNULL(PLUGIN_LIBRARY, '') <> '', '*', '')), NULL)
           ORDER BY PLUGIN_NAME SEPARATOR ', '), 1, 600) AS list,
         SUBSTRING(GROUP_CONCAT(IF(PLUGIN_STATUS <> 'ACTIVE', PLUGIN_NAME, NULL)
           ORDER BY PLUGIN_NAME SEPARATOR ', '), 1, 300) AS inactive_list
  FROM information_schema.PLUGINS
  GROUP BY PLUGIN_TYPE
) AS p
ORDER BY p.PLUGIN_TYPE;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-004' AS marker;
-- check: MY-INFO-004
-- title: Replication topology
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: the normalised replica status from 01_session.sql §6c,
--        @dbt_binlog_dump_threads, semi-sync status, GTID variables
-- Always emitted, including when there is no replication at all — "no
-- replication configured" is itself information a reader needs before
-- interpreting the BAK and DUR findings.
-- WHAT CANNOT BE SEEN FROM SQL, stated rather than omitted:
--   * on MariaDB the receiver (I/O) thread state and the replica lag are not
--     exposed to SQL at all — only SHOW SLAVE STATUS has them, and a SHOW cannot
--     be selected from;
--   * on both forks the identity of connected replicas comes from SHOW REPLICAS
--     (SHOW SLAVE HOSTS), which is likewise not selectable, so only the COUNT of
--     Binlog Dump threads is available here.
-- The reference doc gives the SHOW commands to run by hand for those.
SELECT
  'MY-INFO-004' AS check_id,
  'cluster'     AS scope,
  'replication' AS object,
  CONCAT(
    IF(IFNULL(@dbt_is_replica, 0) = 1,
       CONCAT('This server is a REPLICA of ', IFNULL(@dbt_repl_source, 'an unnamed source'),
              ' across ', IFNULL(@dbt_repl_channels, 1), ' channel(s). ',
              'Applier thread: ', IFNULL(@dbt_repl_sql_state, 'not reported'),
              '; receiver thread: ', IFNULL(@dbt_repl_io_state, 'NOT READABLE FROM SQL on this fork'),
              '. Last error: ', IF(IFNULL(@dbt_repl_err_no, 0) = 0, 'none',
                 CONCAT(@dbt_repl_err_no, ' — ', SUBSTRING(IFNULL(@dbt_repl_err_msg, ''), 1, 200))),
              '. Lag: ', IF(@dbt_repl_lag_s IS NULL,
                 CONCAT('NOT READABLE FROM SQL (', @dbt_repl_lag_src, ')'),
                 CONCAT(@dbt_repl_lag_s, ' s from ', @dbt_repl_lag_src)),
              '. GTID: ', IFNULL(@dbt_repl_using_gtid, 'unknown'),
              '. Parallel appliers: ', IFNULL(COALESCE(@dbt_v_replica_parallel_workers, @dbt_v_slave_parallel_workers), 'unknown'),
              '. Retry interval ', IFNULL(@dbt_repl_retry_interval, '?'),
              ' s, heartbeat ', IFNULL(@dbt_repl_heartbeat, '?'), ' s. '),
       'This server is not a replica. '),
    IFNULL(@dbt_binlog_dump_threads, 0), ' replica(s) are currently connected to it',
    IF(IFNULL(@dbt_binlog_dump_threads, 0) > 0,
       ' (identity requires SHOW REPLICAS / SHOW SLAVE HOSTS, which cannot be selected from SQL)', ''),
    '. log_bin = ', CAST(@@GLOBAL.log_bin AS CHAR),
    ', binlog_format = ', @@GLOBAL.binlog_format,
    ', binlog_row_image = ', @@GLOBAL.binlog_row_image,
    ', gtid_mode = ', IFNULL(@dbt_v_gtid_mode, 'n/a (MariaDB has no server-wide gtid_mode)'),
    ', gtid_executed = ', SUBSTRING(IFNULL(COALESCE(@dbt_v_gtid_executed, @dbt_v_gtid_binlog_pos), '(empty)'), 1, 150),
    '. Semi-sync: ', IFNULL(COALESCE(@dbt_s_rpl_semi_sync_source_status, @dbt_s_rpl_semi_sync_master_status), 'plugin not loaded'),
    '. Group Replication members table present: ', IF(IFNULL(@dbt_has_group_members, 0) = 1, 'yes', 'no'),
    '.') AS details,
  JSON_OBJECT(
    'is_replica', IFNULL(@dbt_is_replica, 0),
    'replication_source', IFNULL(@dbt_repl_source, ''),
    'channels', IFNULL(@dbt_repl_channels, 0),
    'io_thread_state', IFNULL(@dbt_repl_io_state, 'unreadable'),
    'sql_thread_state', IFNULL(@dbt_repl_sql_state, 'unreadable'),
    'last_error_number', IFNULL(@dbt_repl_err_no, 0),
    'lag_seconds', @dbt_repl_lag_s,
    'lag_source', @dbt_repl_lag_src,
    'using_gtid', IFNULL(@dbt_repl_using_gtid, ''),
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'log_bin', CAST(@@GLOBAL.log_bin AS CHAR),
    'binlog_format', @@GLOBAL.binlog_format,
    'binlog_row_image', @@GLOBAL.binlog_row_image,
    'gtid_mode', IFNULL(@dbt_v_gtid_mode, 'n/a'),
    'gtid_set', SUBSTRING(IFNULL(COALESCE(@dbt_v_gtid_executed, @dbt_v_gtid_binlog_pos), ''), 1, 500),
    'semi_sync_status', IFNULL(COALESCE(@dbt_s_rpl_semi_sync_source_status, @dbt_s_rpl_semi_sync_master_status), ''),
    'group_replication_available', IFNULL(@dbt_has_group_members, 0)) AS evidence_json,
  IF(@dbt_is_mariadb AND IFNULL(@dbt_is_replica, 0) = 1, 'medium', 'high') AS confidence
FROM DUAL;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-005' AS marker;
-- check: MY-INFO-005
-- title: Connection summary
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: (none)
-- reads: information_schema.PROCESSLIST
-- Always emitted. A SNAPSHOT, stated as such: one sample of who is connected,
-- from where, doing what. Its value is not the numbers but the shape — whether
-- connections arrive from three pooler hosts or three hundred application
-- processes (MY-CONN-006), whether one account holds everything (MY-SEC-008),
-- and whether the population is mostly idle (MY-CONN-007).
-- Requires PROCESS to see other accounts; without it this reports only this
-- session and says so.
SELECT
  'MY-INFO-005' AS check_id,
  'cluster'     AS scope,
  'connections' AS object,
  CONCAT(p.total, ' connection(s) at snapshot time from ', p.hosts,
         ' distinct client host(s) and ', p.users, ' account(s)',
         IF(IFNULL(@dbt_priv_process, 1) = 0,
            ' — NOTE: this account lacks PROCESS, so only its own session is visible and these numbers are not the server total', ''),
         '. By command: ', p.by_command,
         '. By account: ', p.by_user,
         '. Top client hosts: ', p.by_host,
         '. Schemas in use: ', IFNULL(p.by_db, 'none'),
         '. max_connections = ', @@GLOBAL.max_connections,
         ', Threads_connected = ', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
         ', Max_used_connections = ', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED), '.') AS details,
  JSON_OBJECT(
    'connections_at_snapshot', p.total,
    'distinct_hosts', p.hosts,
    'distinct_users', p.users,
    'by_command', p.by_command,
    'by_user', p.by_user,
    'by_host', p.by_host,
    'by_schema', IFNULL(p.by_db, ''),
    'max_connections', @@GLOBAL.max_connections,
    'threads_connected', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
    'max_used_connections', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED),
    'has_process_privilege', IFNULL(@dbt_priv_process, 1),
    'measured', 'snapshot') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT COUNT(*) AS total,
         COUNT(DISTINCT SUBSTRING_INDEX(IFNULL(HOST, ''), ':', 1)) AS hosts,
         COUNT(DISTINCT USER) AS users,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(COMMAND, '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT COMMAND, COUNT(*) AS c FROM information_schema.PROCESSLIST GROUP BY COMMAND) AS t1) AS by_command,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(IFNULL(USER, '?'), '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT USER, COUNT(*) AS c FROM information_schema.PROCESSLIST GROUP BY USER ORDER BY c DESC LIMIT 10) AS t2) AS by_user,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(h, '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT SUBSTRING_INDEX(IFNULL(HOST, ''), ':', 1) AS h, COUNT(*) AS c
                    FROM information_schema.PROCESSLIST GROUP BY h ORDER BY c DESC LIMIT 10) AS t3) AS by_host,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(d, '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT IFNULL(DB, '(none)') AS d, COUNT(*) AS c
                    FROM information_schema.PROCESSLIST GROUP BY d ORDER BY c DESC LIMIT 10) AS t4) AS by_db
  FROM information_schema.PROCESSLIST
) AS p;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-006' AS marker;
-- check: MY-INFO-006
-- title: InnoDB summary
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: InnoDB settings (universal ones inline, fork-specific ones from the
--        bundle), information_schema.TABLES for data size by engine
-- Always emitted. Every number the MEM, WAL and UNDO findings are computed from,
-- in one place, so a reader can check the arithmetic rather than trust it.
-- Fork-specific values print as their bundle value or 'n/a': innodb_redo_log_capacity
-- is MySQL 8.0.30+, innodb_buffer_pool_instances was removed in MariaDB 10.6,
-- innodb_log_files_in_group was removed in MariaDB 10.5.
SELECT
  'MY-INFO-006' AS check_id,
  'cluster'     AS scope,
  'innodb'      AS object,
  CONCAT('Buffer pool ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2), ' GB in ',
         IFNULL(@dbt_v_innodb_buffer_pool_instances, 'n/a (removed in MariaDB 10.6)'),
         ' instance(s), chunk size ', ROUND(@@GLOBAL.innodb_buffer_pool_chunk_size / 1048576, 0),
         ' MB; ', FORMAT(CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_total, 0) AS UNSIGNED), 0),
         ' pages of which ', FORMAT(CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_dirty, 0) AS UNSIGNED), 0),
         ' dirty. Read hit rate since restart: ',
         IF(CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS DECIMAL(30, 0)) > 0,
            CONCAT(ROUND(100.0 * (1 - CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS DECIMAL(30, 0))
                 / CAST(@dbt_s_innodb_buffer_pool_read_requests AS DECIMAL(30, 0))), 2), '%'),
            'not measurable'),
         '. Redo: ', IF(@dbt_v_innodb_redo_log_capacity IS NOT NULL,
            CONCAT('innodb_redo_log_capacity ', ROUND(CAST(@dbt_v_innodb_redo_log_capacity AS DECIMAL(30, 0)) / 1048576, 0), ' MB'),
            CONCAT('innodb_log_file_size ', ROUND(CAST(IFNULL(@dbt_v_innodb_log_file_size, 0) AS DECIMAL(30, 0)) / 1048576, 0),
                   ' MB x ', IFNULL(@dbt_v_innodb_log_files_in_group, '1'), ' file(s)')),
         ', log buffer ', ROUND(@@GLOBAL.innodb_log_buffer_size / 1048576, 1), ' MB, ',
         FORMAT(CAST(IFNULL(@dbt_s_innodb_os_log_written, 0) AS DECIMAL(30, 0)) / 1073741824, 2),
         ' GB written since restart. ',
         'Storage: innodb_file_per_table = ', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
         ', innodb_flush_method = ', IFNULL(@dbt_v_innodb_flush_method, 'n/a'),
         ', innodb_page_size = ', @@GLOBAL.innodb_page_size,
         ', innodb_io_capacity = ', @@GLOBAL.innodb_io_capacity, '/', @@GLOBAL.innodb_io_capacity_max,
         ', innodb_checksum_algorithm = ', IFNULL(@dbt_v_innodb_checksum_algorithm, 'n/a'), '. ',
         'Undo: ', @@GLOBAL.innodb_undo_tablespaces, ' tablespace(s), truncate = ',
         CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR), ', purge threads = ',
         @@GLOBAL.innodb_purge_threads, ', history list length = ',
         IFNULL(FORMAT(@dbt_hll, 0), 'not readable'), '. ',
         'Data by engine: ', e.by_engine, '.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_buffer_pool_instances', IFNULL(@dbt_v_innodb_buffer_pool_instances, 'n/a'),
    'innodb_buffer_pool_chunk_size', @@GLOBAL.innodb_buffer_pool_chunk_size,
    'buffer_pool_pages_total', CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_total, 0) AS UNSIGNED),
    'buffer_pool_pages_dirty', CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_dirty, 0) AS UNSIGNED),
    'innodb_redo_log_capacity', IFNULL(@dbt_v_innodb_redo_log_capacity, 'n/a'),
    'innodb_log_file_size', IFNULL(@dbt_v_innodb_log_file_size, 'n/a'),
    'innodb_log_files_in_group', IFNULL(@dbt_v_innodb_log_files_in_group, 'n/a'),
    'innodb_log_buffer_size', @@GLOBAL.innodb_log_buffer_size,
    'innodb_os_log_written', CAST(IFNULL(@dbt_s_innodb_os_log_written, 0) AS UNSIGNED),
    'innodb_file_per_table', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
    'innodb_flush_method', IFNULL(@dbt_v_innodb_flush_method, 'n/a'),
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'innodb_io_capacity', @@GLOBAL.innodb_io_capacity,
    'innodb_io_capacity_max', @@GLOBAL.innodb_io_capacity_max,
    'innodb_checksum_algorithm', IFNULL(@dbt_v_innodb_checksum_algorithm, 'n/a'),
    'innodb_undo_tablespaces', @@GLOBAL.innodb_undo_tablespaces,
    'innodb_undo_log_truncate', CAST(@@GLOBAL.innodb_undo_log_truncate AS CHAR),
    'innodb_purge_threads', @@GLOBAL.innodb_purge_threads,
    'history_list_length', @dbt_hll,
    'data_by_engine', e.by_engine) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT SUBSTRING(GROUP_CONCAT(CONCAT(ENGINE, ' ', ROUND(bytes / 1073741824, 2), ' GB in ', n, ' table(s)')
           ORDER BY bytes DESC SEPARATOR ', '), 1, 400) AS by_engine
  FROM (
    SELECT ENGINE, COUNT(*) AS n, IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes
    FROM information_schema.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE' AND ENGINE IS NOT NULL
      AND TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'sys')
    GROUP BY ENGINE
  ) AS t
) AS e;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-007' AS marker;
-- check: MY-INFO-007
-- title: Object counts
-- priority: 250 | category: INFO | scope: cluster | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema TABLES, VIEWS, ROUTINES, TRIGGERS, EVENTS, PARTITIONS,
--        STATISTICS, TABLE_CONSTRAINTS
-- Always emitted, and the storage-engine breakdown here is the inventory half of
-- MY-DUR-007 (which is the finding half): DUR-007 fires only on non-transactional
-- engines, whereas this row shows the whole picture including how many tables are
-- InnoDB, so "all 4,000 tables are InnoDB" is visible as a positive fact.
-- The relation count also drives the design's XX-META-007 sampling rule: above
-- 50,000 relations the per-relation checks are expected to fall back to top-N.
SELECT
  'MY-INFO-007' AS check_id,
  'cluster'     AS scope,
  'object-counts' AS object,
  CONCAT(o.n_tables, ' base table(s) across ', o.n_schemas, ' user schema(s), by engine: ',
         o.n_by_engine, '. ',
         o.n_views, ' view(s), ', o.n_routines, ' routine(s) (', o.n_procs, ' procedures, ',
         o.n_funcs, ' functions), ', o.n_triggers, ' trigger(s), ', o.n_events, ' event(s), ',
         o.n_partitions, ' partition(s) across ', o.n_partitioned, ' partitioned table(s). ',
         o.n_indexes, ' index(es), ', o.n_pks, ' primary key(s), ', o.n_fks, ' foreign key(s), ',
         o.n_uniques, ' unique constraint(s). ',
         IF(o.n_tables > o.n_pks, CONCAT(o.n_tables - o.n_pks, ' table(s) have no primary key — see MY-SCHEMA-001/002. '), ''),
         IF(o.n_tables >= 50000,
            'Over 50,000 relations: per-relation checks fall back to top-N sampling (XX-META-007). ', '')) AS details,
  JSON_OBJECT(
    'base_tables', o.n_tables, 'user_schemas', o.n_schemas, 'by_engine', o.n_by_engine,
    'views', o.n_views, 'routines', o.n_routines, 'procedures', o.n_procs, 'functions', o.n_funcs,
    'triggers', o.n_triggers, 'events', o.n_events,
    'partitions', o.n_partitions, 'partitioned_tables', o.n_partitioned,
    'indexes', o.n_indexes, 'primary_keys', o.n_pks, 'foreign_keys', o.n_fks,
    'unique_constraints', o.n_uniques,
    'tables_without_pk', GREATEST(o.n_tables - o.n_pks, 0)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    (SELECT COUNT(*) FROM information_schema.TABLES
      WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_tables,
    (SELECT COUNT(DISTINCT TABLE_SCHEMA) FROM information_schema.TABLES
      WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_schemas,
    (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(ENGINE, '=', n) ORDER BY n DESC SEPARATOR ', '), 1, 300)
       FROM (SELECT ENGINE, COUNT(*) AS n FROM information_schema.TABLES
              WHERE TABLE_TYPE = 'BASE TABLE' AND ENGINE IS NOT NULL
                AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')
              GROUP BY ENGINE) AS t) AS n_by_engine,
    (SELECT COUNT(*) FROM information_schema.VIEWS
      WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_views,
    (SELECT COUNT(*) FROM information_schema.ROUTINES
      WHERE ROUTINE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_routines,
    (SELECT COUNT(*) FROM information_schema.ROUTINES
      WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_procs,
    (SELECT COUNT(*) FROM information_schema.ROUTINES
      WHERE ROUTINE_TYPE = 'FUNCTION' AND ROUTINE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_funcs,
    (SELECT COUNT(*) FROM information_schema.TRIGGERS
      WHERE TRIGGER_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_triggers,
    (SELECT COUNT(*) FROM information_schema.EVENTS
      WHERE EVENT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_events,
    (SELECT COUNT(*) FROM information_schema.PARTITIONS
      WHERE PARTITION_NAME IS NOT NULL AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_partitions,
    (SELECT COUNT(DISTINCT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME)) FROM information_schema.PARTITIONS
      WHERE PARTITION_NAME IS NOT NULL AND TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_partitioned,
    (SELECT COUNT(DISTINCT CONCAT(TABLE_SCHEMA, '.', TABLE_NAME, '.', INDEX_NAME)) FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_indexes,
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_TYPE = 'PRIMARY KEY' AND CONSTRAINT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_pks,
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_TYPE = 'FOREIGN KEY' AND CONSTRAINT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_fks,
    (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
      WHERE CONSTRAINT_TYPE = 'UNIQUE' AND CONSTRAINT_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')) AS n_uniques
) AS o;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-008' AS marker;
-- check: MY-INFO-008
-- title: Accounts summary
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: SELECT ON mysql.*
-- thresholds: (none)
-- reads: normalised account source @dbt_acct_src (01_session.sql §6d)
-- Always emitted. Aggregate shape of the account catalog, so the individual SEC
-- findings can be read in proportion: "3 of 400 accounts have a wildcard host"
-- reads very differently from "3 of 4".
-- PRIVACY: counts only. No credential value is read; has_credential is derived
-- from emptiness alone, as documented in 01_session.sql §6d.
SET @dbt_q := REPLACE("
SELECT
  'MY-INFO-008' AS check_id,
  'cluster'     AS scope,
  'accounts'    AS object,
  CONCAT(a.n_total, ' account(s)', IF(a.n_roles > 0, CONCAT(' plus ', a.n_roles, ' role(s)'), ''),
         '. By authentication plugin: ', a.n_by_plugin,
         '. Host patterns: ', a.n_wildcard, ' wildcard, ', a.n_localhost, ' localhost-only, ',
         a.n_specific, ' specific host or address. ',
         a.n_locked, ' locked, ', a.n_no_credential, ' with an empty credential, ',
         a.n_anonymous, ' anonymous. ',
         a.n_superusers, ' hold SUPER or the full global privilege set, ',
         a.n_with_grant, ' hold GRANT OPTION, ', a.n_with_file, ' hold FILE. ',
         'Read the SEC findings against these totals: a proportion means more than a count.') AS details,
  JSON_OBJECT(
    'total_accounts', a.n_total, 'roles', a.n_roles,
    'by_plugin', a.n_by_plugin,
    'wildcard_host', a.n_wildcard, 'localhost_only', a.n_localhost, 'specific_host', a.n_specific,
    'locked', a.n_locked, 'empty_credential', a.n_no_credential, 'anonymous', a.n_anonymous,
    'superuser_equivalent', a.n_superusers, 'grant_option', a.n_with_grant, 'file_privilege', a.n_with_file) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    SUM(is_role = 0) AS n_total,
    SUM(is_role = 1) AS n_roles,
    SUM(is_role = 0 AND (acct_host IN ('%', '') OR acct_host LIKE '%\\%%')) AS n_wildcard,
    SUM(is_role = 0 AND acct_host IN ('localhost', '127.0.0.1', '::1')) AS n_localhost,
    SUM(is_role = 0 AND acct_host NOT IN ('%', '', 'localhost', '127.0.0.1', '::1')
        AND acct_host NOT LIKE '%\\%%') AS n_specific,
    SUM(is_role = 0 AND account_locked = 1) AS n_locked,
    SUM(is_role = 0 AND has_credential = 0 AND auth_marker <> 'invalid') AS n_no_credential,
    SUM(is_role = 0 AND acct_user = '') AS n_anonymous,
    SUM(is_role = 0 AND (Super_priv = 'Y' OR has_all_privs)) AS n_superusers,
    SUM(is_role = 0 AND Grant_priv = 'Y') AS n_with_grant,
    SUM(is_role = 0 AND File_priv = 'Y') AS n_with_file,
    (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(p, '=', n) ORDER BY n DESC SEPARATOR ', '), 1, 300)
       FROM (SELECT acct_plugin AS p, COUNT(*) AS n FROM (ACCTSRC) AS b
              WHERE b.is_role = 0 GROUP BY acct_plugin) AS t) AS n_by_plugin
  FROM (ACCTSRC) AS c
) AS a
", "ACCTSRC", @dbt_acct_src);
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 1) = 0, 'DO 1', @dbt_q);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-INFO-009' AS marker;
-- check: MY-INFO-009
-- title: Statistics window
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_uptime_s, @dbt_counter_conf, performance_schema lost-instrument counters
-- Always emitted, and it is the row that makes every rate in this report
-- interpretable. Neither MySQL nor MariaDB has PostgreSQL's per-view stats_reset
-- timestamp: status counters, performance_schema aggregates and InnoDB metrics
-- all begin at zero on startup, and FLUSH STATUS or a TRUNCATE of a
-- performance_schema summary table resets some of them with no record that it
-- happened. Uptime is therefore an UPPER BOUND on the window, not a measurement
-- of it, and this row says so explicitly.
-- The lost-instrument counters matter for the same reason: when
-- performance_schema runs out of its preallocated memory it silently drops
-- instrumentation, so a digest or index-usage figure can be incomplete without
-- any error being raised.
SELECT
  'MY-INFO-009' AS check_id,
  'cluster'     AS scope,
  'statistics-window' AS object,
  CONCAT('Counters cover at most ', ROUND(@dbt_uptime_s / 86400, 2), ' days (',
         ROUND(@dbt_uptime_s / 3600, 1), ' h) — the server has been up that long, ',
         'and neither fork records when a counter window actually started. ',
         'FLUSH STATUS and TRUNCATE on a performance_schema summary table both reset counters without leaving a trace, so this is an UPPER BOUND on the window, not a measurement of it. ',
         'Confidence assigned to every rate-based finding in this report: ', @dbt_counter_conf,
         ' (low under 1 day, medium under 7 days, high above). ',
         'performance_schema = ', CAST(@@GLOBAL.performance_schema AS CHAR),
         '; digests lost: ', CAST(IFNULL(@dbt_s_performance_schema_digest_lost, 0) AS UNSIGNED),
         ', index statistics lost: ', CAST(IFNULL(@dbt_s_performance_schema_index_stat_lost, 0) AS UNSIGNED),
         ' — a non-zero value means performance_schema ran out of its preallocated memory and silently dropped instrumentation, so the workload and index findings are incomplete by an unknown amount. ',
         'Sizes reported from information_schema are ',
         IF(@dbt_is_mariadb, 'read live from the storage engine on MariaDB',
            CONCAT('cached for up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20, 0)) / 3600, 1),
                   ' h on MySQL 8.0 (information_schema_stats_expiry)')),
         ', and row counts are InnoDB estimates in all cases.') AS details,
  JSON_OBJECT(
    'uptime_seconds', @dbt_uptime_s,
    'window_is_upper_bound', 1,
    'counter_confidence', @dbt_counter_conf,
    'performance_schema', CAST(@@GLOBAL.performance_schema AS CHAR),
    'digest_lost', CAST(IFNULL(@dbt_s_performance_schema_digest_lost, 0) AS UNSIGNED),
    'index_stat_lost', CAST(IFNULL(@dbt_s_performance_schema_index_stat_lost, 0) AS UNSIGNED),
    'information_schema_stats_expiry', IFNULL(@dbt_v_information_schema_stats_expiry, 'n/a'),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'high' AS confidence
FROM DUAL;
SELECT '@@END' AS marker;

