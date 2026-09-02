-- db-triage — checks/mysql/00_preflight.sql
-- One row describing the target, per DESIGN.md §7.3, plus a second row listing
-- the privileges that are missing and what each one would unlock.
--
-- ORDER OF EXECUTION. This file reads the @dbt_* session facts established by
-- 01_session.sql, so the runner must source 01_session.sql FIRST:
--     mysql < 01_session.sql ; mysql < 00_preflight.sql ; mysql < fast.sql
-- (all in one session). The numeric prefixes follow the design's file naming;
-- they are not the execution order. Running this file on a bare session yields
-- NULLs in the fork/capability columns rather than an error.
--
-- Read-only: SELECTs against information_schema and performance_schema only.

/* db-triage/0.1.0 preflight */

-- ---------------------------------------------------------------------------
-- Privilege probes
-- ---------------------------------------------------------------------------
-- information_schema.USER_PRIVILEGES lists global privileges granted DIRECTLY to
-- the current account. Privileges inherited through a role (MySQL 8.0 roles,
-- MariaDB roles) do not appear there, so a false "missing" is possible; the
-- functional probes below correct for that where they can.
SET @dbt_grantee := CONCAT(QUOTE(SUBSTRING_INDEX(CURRENT_USER(), '@', 1)),
                           '@',
                           QUOTE(SUBSTRING_INDEX(CURRENT_USER(), '@', -1)));

SELECT
  MAX(PRIVILEGE_TYPE = 'PROCESS'),
  -- MariaDB 10.5 renamed REPLICATION CLIENT to BINLOG MONITOR and split off
  -- SLAVE MONITOR / REPLICA MONITOR (SHOW REPLICA STATUS). Any of the four
  -- grants the replication visibility the REPL and CAP checks need.
  MAX(PRIVILEGE_TYPE IN ('REPLICATION CLIENT', 'BINLOG MONITOR', 'SLAVE MONITOR', 'REPLICA MONITOR')),
  MAX(PRIVILEGE_TYPE = 'SUPER'),
  MAX(PRIVILEGE_TYPE IN ('SELECT', 'ALL PRIVILEGES'))
INTO @dbt_priv_process, @dbt_priv_repl_client, @dbt_priv_super, @dbt_priv_global_select
FROM information_schema.USER_PRIVILEGES
WHERE GRANTEE = @dbt_grantee;

-- Functional probe for PROCESS: without it, PROCESSLIST shows only our own
-- threads. More than one distinct account visible proves PROCESS is effective
-- however it was granted. (A single-connection server gives a false negative,
-- which is why this only ever upgrades the answer, never downgrades it.)
SELECT COUNT(DISTINCT USER) > 1 INTO @dbt_proc_sees_others
FROM information_schema.PROCESSLIST;
SET @dbt_priv_process := GREATEST(IFNULL(@dbt_priv_process, 0), IFNULL(@dbt_proc_sees_others, 0));

-- Functional probe for readable account catalog. MariaDB stores accounts in
-- mysql.global_priv with mysql.user as a view over it; MySQL uses mysql.user
-- directly. Either way the SEC checks need SELECT on the mysql schema.
SELECT MAX(TABLE_NAME IN ('user', 'global_priv'))
INTO @dbt_priv_mysql_schema
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'mysql' AND TABLE_NAME IN ('user', 'global_priv');
SET @dbt_priv_mysql_schema := IFNULL(@dbt_priv_mysql_schema, 0);

-- performance_schema readability: the tables are visible in information_schema
-- even without SELECT, so probe by actually reading one small instrumented table.
SET @dbt_priv_perf_schema := 0;
SET @dbt_q := IF(IFNULL(@dbt_ps_on, 0),
  'SELECT COUNT(*) >= 0 INTO @dbt_priv_perf_schema FROM performance_schema.setup_consumers',
  'SET @dbt_priv_perf_schema := 0');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- ---------------------------------------------------------------------------
-- Platform fingerprint (DESIGN §7.3, MySQL column; first match wins)
-- ---------------------------------------------------------------------------
-- Aurora exposes @@aurora_version; RDS ships rdsadmin plus mysql.rds_* routines;
-- Cloud SQL ships cloudsqladmin and a Google version_comment; Azure Flexible
-- Server ships azure_superuser; Vitess/PlanetScale announces itself in
-- version_comment. None of these can be faked by a user table, so the order
-- below is safe. Everything else is treated as self-managed.
SET @dbt_has_aurora_version := 0;
SET @dbt_q := IF(@dbt_vartab IS NULL, 'SET @dbt_has_aurora_version := 0',
  CONCAT('SELECT COUNT(*) INTO @dbt_has_aurora_version FROM ', @dbt_vartab,
         ' WHERE LOWER(VARIABLE_NAME) = ''aurora_version'''));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

SELECT
  MAX(ROUTINE_SCHEMA = 'mysql' AND ROUTINE_NAME LIKE 'rds\_%')
INTO @dbt_has_rds_routines
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'mysql';
SET @dbt_has_rds_routines := IFNULL(@dbt_has_rds_routines, 0);

SET @dbt_platform_users := '';
SET @dbt_q := IF(IFNULL(@dbt_priv_mysql_schema, 0) = 0, 'SET @dbt_platform_users := ''''',
  'SELECT GROUP_CONCAT(DISTINCT User) INTO @dbt_platform_users FROM mysql.user
     WHERE User IN (''rdsadmin'', ''cloudsqladmin'', ''azure_superuser'', ''system_user'')');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SET @dbt_platform_users := IFNULL(@dbt_platform_users, '');

SET @dbt_platform :=
  CASE
    WHEN @dbt_has_aurora_version > 0                              THEN 'aurora'
    WHEN @dbt_has_rds_routines > 0
      OR FIND_IN_SET('rdsadmin', @dbt_platform_users) > 0         THEN 'rds'
    WHEN FIND_IN_SET('cloudsqladmin', @dbt_platform_users) > 0
      OR @@GLOBAL.version_comment LIKE '%Google%'                 THEN 'cloudsql'
    WHEN FIND_IN_SET('azure_superuser', @dbt_platform_users) > 0
      OR @@GLOBAL.version_comment LIKE '%Azure%'                  THEN 'azure'
    WHEN @@GLOBAL.version_comment LIKE '%Vitess%'
      OR @@GLOBAL.version_comment LIKE '%PlanetScale%'            THEN 'vitess'
    ELSE 'self-managed'
  END;

-- ---------------------------------------------------------------------------
-- The preflight row
-- ---------------------------------------------------------------------------
-- gtid: MySQL exposes @@gtid_mode (OFF/OFF_PERMISSIVE/ON_PERMISSIVE/ON).
-- MariaDB has no gtid_mode at all — GTID is per-connection (CHANGE MASTER ...
-- MASTER_USE_GTID) and the closest server-wide evidence is a non-empty
-- gtid_slave_pos / gtid_binlog_pos. Reported as such rather than invented.
SELECT
  'db-triage-preflight'                                       AS notice,
  IFNULL(@dbt_fork, 'unknown')                                AS fork,
  @@GLOBAL.version                                            AS version,
  @@GLOBAL.version_comment                                    AS version_comment,
  CAST(IFNULL(@dbt_vnum, 0) AS UNSIGNED)                      AS version_num,
  @@GLOBAL.version_compile_os                                 AS compile_os,
  @@GLOBAL.version_compile_machine                            AS compile_machine,
  @dbt_platform                                               AS platform,
  CAST(IFNULL(@dbt_s_uptime, 0) AS UNSIGNED)                  AS uptime_seconds,
  @@GLOBAL.read_only                                          AS read_only,
  IFNULL(@dbt_v_super_read_only, 'n/a')                       AS super_read_only,
  @@GLOBAL.log_bin                                            AS log_bin,
  @@GLOBAL.binlog_format                                      AS binlog_format,
  CASE
    WHEN @dbt_v_gtid_mode IS NOT NULL                THEN @dbt_v_gtid_mode
    WHEN IFNULL(@dbt_v_gtid_slave_pos, '') <> ''
      OR IFNULL(@dbt_v_gtid_binlog_pos, '') <> ''    THEN 'mariadb-gtid-in-use'
    WHEN @dbt_is_mariadb                             THEN 'mariadb-gtid-unknown'
    ELSE 'n/a'
  END                                                         AS gtid,
  IFNULL(@dbt_is_replica, 0)                                  AS replica_configured,
  IFNULL(@dbt_binlog_dump_threads, 0)                         AS connected_replicas,
  @@GLOBAL.performance_schema                                 AS performance_schema,
  IFNULL(@dbt_sys_view_count, 0) > 0                          AS sys_present,
  IFNULL(@dbt_priv_process, 0)                                AS has_process_priv,
  IFNULL(@dbt_priv_repl_client, 0)                            AS has_replication_client_priv,
  IFNULL(@dbt_priv_mysql_schema, 0)                           AS has_mysql_schema_read,
  IFNULL(@dbt_priv_perf_schema, 0)                            AS has_perf_schema_read,
  IFNULL(@dbt_priv_super, 0)                                  AS has_super_priv,
  CURRENT_USER()                                              AS connected_as,
  @@GLOBAL.hostname                                           AS server_hostname,
  IFNULL(@dbt_vartab, '(none)')                               AS variables_source,
  IFNULL(@dbt_stattab, '(none)')                              AS status_source,
  IFNULL(@dbt_counter_conf, 'low')                            AS counter_confidence;

-- ---------------------------------------------------------------------------
-- Missing-privilege report — feeds XX-META-002
-- ---------------------------------------------------------------------------
-- One row per privilege this account lacks, naming exactly which checks go dark.
SELECT 'db-triage-privilege-gap' AS notice, missing, unlocks
FROM (
  SELECT 'PROCESS' AS missing,
         'MY-LOCK-001..006/009, MY-CONN-006/007, MY-REL-006, MY-SEC-008, MY-INFO-005: other sessions are invisible in PROCESSLIST' AS unlocks,
         IFNULL(@dbt_priv_process, 0) AS have
  UNION ALL SELECT 'REPLICATION CLIENT (MariaDB: BINLOG MONITOR / SLAVE MONITOR)',
         'MY-CAP-006 and SHOW BINARY LOGS / SHOW REPLICA STATUS fallbacks used by MY-REPL-001..004', IFNULL(@dbt_priv_repl_client, 0)
  UNION ALL SELECT 'SELECT ON mysql.*',
         'MY-SEC-001..004/006/007/012/013, MY-IDX-001/008: the account catalog and InnoDB persistent statistics', IFNULL(@dbt_priv_mysql_schema, 0)
  UNION ALL SELECT 'SELECT ON performance_schema.*',
         'MY-QRY-002/004..011, MY-IDX-001..005, MY-REPL-001..004/010/013, MY-CONN-005', IFNULL(@dbt_priv_perf_schema, 0)
) AS p
WHERE have = 0;
