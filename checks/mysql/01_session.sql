-- db-triage — checks/mysql/01_session.sql
-- Session safety contract for MySQL / MariaDB (DESIGN.md §1.3), plus the
-- fork/version fact bundle every check file depends on.
--
-- Source this ONCE per connection, before any check batch. Every statement here
-- is read-only: session-scoped SET, PREPARE/EXECUTE of SELECTs, and SELECTs.
-- It never writes data, never touches GLOBAL scope, and never reads a password
-- hash value (only its emptiness is ever tested, and that happens in MY-SEC-001).
--
-- What it establishes
--   1. Read-only transaction semantics for the whole session.
--   2. A bounded statement runtime and a bounded lock wait.
--   3. An identifier so a DBA can find and cancel this run.
--   4. @dbt_* session facts: fork, numeric version, capability flags.
--   5. @dbt_v_* / @dbt_s_* bundles for global variables and status counters
--      whose *source table* or *existence* differs between MySQL and MariaDB.
--
-- Checks read universally-present settings inline as @@GLOBAL.<name>, and
-- fork/version-specific ones from the bundles below (NULL when absent, which
-- is how a check degrades instead of erroring).

/* db-triage/0.1.0 session setup */

-- ---------------------------------------------------------------------------
-- 1. Read-only, always
-- ---------------------------------------------------------------------------
-- MySQL 5.7+/MariaDB 10.0+. Any INSERT/UPDATE/DELETE/DDL in this session now
-- fails with ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION rather than succeeding.
SET SESSION TRANSACTION READ ONLY;

-- Deterministic parsing for our own statements. Removing ANSI_QUOTES matters:
-- the dynamic SQL below uses '...' string literals. This is SESSION scope only;
-- MY-SCHEMA-004 deliberately reads @@GLOBAL.sql_mode, never @@SESSION.sql_mode.
SET @dbt_global_sql_mode := @@GLOBAL.sql_mode;
SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION';

-- ---------------------------------------------------------------------------
-- 2. Bounded runtime
-- ---------------------------------------------------------------------------
-- Never queue behind a DDL or a long transaction holding a metadata lock.
SET SESSION lock_wait_timeout = 2;
SET SESSION innodb_lock_wait_timeout = 2;

-- Statement timeout. MySQL calls it max_execution_time (ms, SELECT only, 5.7.8+);
-- MariaDB calls it max_statement_time (seconds, double, 10.1+). Neither exists in
-- the other fork, so both are set through dynamic SQL gated on existence.
SET @dbt_is_mariadb := (VERSION() LIKE '%MariaDB%');
SET @dbt_stmt_timeout_ms := IFNULL(@dbt_stmt_timeout_ms, 10000);
SET @dbt_q := IF(@dbt_is_mariadb,
  CONCAT('SET SESSION max_statement_time = ', @dbt_stmt_timeout_ms / 1000),
  CONCAT('SET SESSION max_execution_time = ', @dbt_stmt_timeout_ms));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- ---------------------------------------------------------------------------
-- 3. Identifiable
-- ---------------------------------------------------------------------------
-- MySQL and MariaDB have no application_name. Three mechanisms, all read-only:
--   a. every generated statement carries a /* db-triage/<version> */ comment,
--      which appears verbatim in INFORMATION_SCHEMA.PROCESSLIST.INFO and in
--      performance_schema.events_statements_current.SQL_TEXT;
--   b. @dbt_marker is visible to a DBA on MySQL 8.0 through
--      performance_schema.user_variables_by_thread;
--   c. the SELECT below prints this session's CONNECTION_ID() and the exact
--      statement a DBA can run to cancel the run.
SET @dbt_tool_version := IFNULL(@dbt_tool_version, '0.1.0');
SET @dbt_run_id       := IFNULL(@dbt_run_id, DATE_FORMAT(UTC_TIMESTAMP(), '%Y%m%dT%H%i%sZ'));
SET @dbt_marker       := CONCAT('db-triage/', @dbt_tool_version, ' run ', @dbt_run_id);

SELECT
  'db-triage-session'                     AS notice,
  @dbt_marker                             AS marker,
  CONNECTION_ID()                         AS connection_id,
  CONCAT('KILL QUERY ', CONNECTION_ID())  AS how_to_cancel;

-- ---------------------------------------------------------------------------
-- 4. Session facts: fork, version, capabilities
-- ---------------------------------------------------------------------------
-- @@version examples this must survive:
--   8.0.36-0ubuntu0.22.04.1        MySQL on Ubuntu
--   8.4.2                          MySQL 8.4 LTS
--   9.1.0                          MySQL innovation
--   10.11.14-MariaDB-0ubuntu0.24.04.1-log
--   11.4.2-MariaDB-1:11.4.2+maria~ubu2404
--   5.7.44-log                     MySQL 5.7
--   8.0.35-27                      Percona Server
SET @dbt_vraw    := SUBSTRING_INDEX(SUBSTRING_INDEX(@@GLOBAL.version, '-', 1), '+', 1);
SET @dbt_vmajor  := CAST(SUBSTRING_INDEX(@dbt_vraw, '.', 1) AS UNSIGNED);
SET @dbt_vminor  := CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@dbt_vraw, '.', 2), '.', -1) AS UNSIGNED);
SET @dbt_vpatch  := CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(CONCAT(@dbt_vraw, '.0.0'), '.', 3), '.', -1) AS UNSIGNED);
-- Single comparable integer: 8.0.36 -> 80036, 10.11.14 -> 101114, 11.4.2 -> 110402.
SET @dbt_vnum    := CAST(@dbt_vmajor * 10000 + @dbt_vminor * 100 + LEAST(@dbt_vpatch, 99) AS UNSIGNED);
SET @dbt_fork    := IF(@dbt_is_mariadb, 'mariadb',
                    IF(@@GLOBAL.version_comment LIKE '%Percona%', 'percona', 'mysql'));
SET @dbt_ps_on   := (@@GLOBAL.performance_schema = 1);

-- Capability probes. One cheap information_schema read; every table-existence
-- gate in the check files reads these instead of repeating the lookup.
SELECT
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'global_variables'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'GLOBAL_VARIABLES'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'global_status'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'GLOBAL_STATUS'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'SYSTEM_VARIABLES'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'variables_info'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'persisted_variables'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'error_log'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'replication_connection_status'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'replication_connection_configuration'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'replication_applier_status'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'replication_applier_status_by_worker'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'replication_group_members'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'replication_applier_filters'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'data_lock_waits'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'host_cache'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'table_io_waits_summary_by_index_usage'),
  MAX(TABLE_SCHEMA = 'performance_schema' AND TABLE_NAME = 'events_statements_summary_by_digest'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'INNODB_LOCK_WAITS'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'INNODB_TABLES'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'INNODB_SYS_TABLES'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'INNODB_SYS_TABLESPACES'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'INNODB_METRICS'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'USER_STATISTICS'),
  MAX(TABLE_SCHEMA = 'information_schema' AND TABLE_NAME = 'FILES'),
  MAX(TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'innodb_index_stats'),
  MAX(TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'innodb_table_stats'),
  MAX(TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'global_priv'),
  MAX(TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'user'),
  MAX(TABLE_SCHEMA = 'mysql' AND TABLE_NAME = 'component')
INTO
  @dbt_has_ps_gvars, @dbt_has_is_gvars, @dbt_has_ps_gstatus, @dbt_has_is_gstatus,
  @dbt_has_is_sysvars, @dbt_has_variables_info, @dbt_has_persisted_variables,
  @dbt_has_error_log, @dbt_has_repl_conn_status, @dbt_has_repl_conn_config,
  @dbt_has_repl_applier, @dbt_has_repl_worker, @dbt_has_group_members,
  @dbt_has_applier_filters, @dbt_has_data_lock_waits, @dbt_has_host_cache,
  @dbt_has_index_usage, @dbt_has_digest, @dbt_has_is_lock_waits,
  @dbt_has_innodb_tables, @dbt_has_innodb_sys_tables, @dbt_has_innodb_sys_tablespaces,
  @dbt_has_innodb_metrics, @dbt_has_user_statistics, @dbt_has_is_files,
  @dbt_has_innodb_index_stats, @dbt_has_innodb_table_stats,
  @dbt_has_global_priv, @dbt_has_mysql_user, @dbt_has_mysql_component
FROM information_schema.TABLES
WHERE TABLE_SCHEMA IN ('information_schema', 'performance_schema', 'mysql');

-- sys-schema views used by the IDX / SCHEMA / QRY checks. MariaDB ships sys from
-- 10.6 but not every view; MySQL 5.7+ ships all of them. Absent view => the check
-- takes its information_schema / performance_schema fallback path.
SELECT
  MAX(TABLE_NAME = 'schema_unused_indexes'),
  MAX(TABLE_NAME = 'schema_redundant_indexes'),
  MAX(TABLE_NAME = 'schema_auto_increment_columns'),
  MAX(TABLE_NAME = 'schema_tables_with_full_table_scans'),
  MAX(TABLE_NAME = 'schema_table_statistics'),
  MAX(TABLE_NAME = 'statement_analysis'),
  MAX(TABLE_NAME = 'statements_with_errors_or_warnings'),
  MAX(TABLE_NAME = 'innodb_lock_waits'),
  COUNT(*)
INTO
  @dbt_sys_unused_idx, @dbt_sys_redundant_idx, @dbt_sys_autoinc,
  @dbt_sys_full_scans, @dbt_sys_table_stats, @dbt_sys_stmt_analysis,
  @dbt_sys_stmt_errors, @dbt_sys_lock_waits, @dbt_sys_view_count
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'sys';

-- Is this instance a replica? True when a replication connection is configured.
-- Works on both forks: performance_schema.replication_connection_configuration
-- exists in MySQL 5.7+ and MariaDB 10.5+ and is empty on a non-replica.
SET @dbt_is_replica := 0;
SET @dbt_q := IF(@dbt_has_repl_conn_config,
  'SELECT COUNT(*) > 0 INTO @dbt_is_replica FROM performance_schema.replication_connection_configuration',
  'SET @dbt_is_replica := 0');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- Does anything replicate FROM this instance right now? A connected replica holds
-- a "Binlog Dump" / "Binlog Dump GTID" thread. This is the only fork-portable,
-- SQL-readable evidence; SHOW REPLICAS / SHOW SLAVE HOSTS cannot be selected from.
SELECT COUNT(*) INTO @dbt_binlog_dump_threads
FROM information_schema.PROCESSLIST
WHERE COMMAND LIKE 'Binlog Dump%';

SET @dbt_replication_configured :=
  (@dbt_is_replica = 1 OR @dbt_binlog_dump_threads > 0 OR @@GLOBAL.log_bin = 1);

-- ---------------------------------------------------------------------------
-- 5. Global-variable bundle (@dbt_v_*)
-- ---------------------------------------------------------------------------
-- Source table differs by fork:
--   MySQL 5.7+/8.x/8.4/9.x : performance_schema.global_variables
--                            (information_schema.GLOBAL_VARIABLES was removed in 8.0)
--   MariaDB 10.4-11.x      : information_schema.GLOBAL_VARIABLES
--                            (its performance_schema has no global_variables)
-- Anything not present on this server stays NULL; every check that reads one of
-- these treats NULL as "not applicable on this fork/version" and emits no row.
SET @dbt_vartab := IF(@dbt_has_ps_gvars, 'performance_schema.global_variables',
                   IF(@dbt_has_is_gvars, 'information_schema.GLOBAL_VARIABLES', NULL));
SET @dbt_stattab := IF(@dbt_has_ps_gstatus, 'performance_schema.global_status',
                    IF(@dbt_has_is_gstatus, 'information_schema.GLOBAL_STATUS', NULL));

-- variables bundle: repl
SET @dbt_q := IF(@dbt_vartab IS NULL, 'DO 1', CONCAT('SELECT\n   MAX(IF(n = ''gtid_mode'', v, NULL)),\n   MAX(IF(n = ''gtid_strict_mode'', v, NULL)),\n   MAX(IF(n = ''gtid_executed'', v, NULL)),\n   MAX(IF(n = ''gtid_purged'', v, NULL)),\n   MAX(IF(n = ''gtid_binlog_pos'', v, NULL)),\n   MAX(IF(n = ''gtid_slave_pos'', v, NULL)),\n   MAX(IF(n = ''gtid_current_pos'', v, NULL)),\n   MAX(IF(n = ''super_read_only'', v, NULL)),\n   MAX(IF(n = ''server_uuid'', v, NULL)),\n   MAX(IF(n = ''replica_parallel_workers'', v, NULL)),\n   MAX(IF(n = ''slave_parallel_workers'', v, NULL)),\n   MAX(IF(n = ''replica_skip_errors'', v, NULL)),\n   MAX(IF(n = ''slave_skip_errors'', v, NULL)),\n   MAX(IF(n = ''replica_exec_mode'', v, NULL)),\n   MAX(IF(n = ''slave_exec_mode'', v, NULL)),\n   MAX(IF(n = ''master_info_repository'', v, NULL)),\n   MAX(IF(n = ''relay_log_info_repository'', v, NULL)),\n   MAX(IF(n = ''relay_log_recovery'', v, NULL)),\n   MAX(IF(n = ''binlog_row_metadata'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_master_enabled'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_source_enabled'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_slave_enabled'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_replica_enabled'', v, NULL)),\n   MAX(IF(n = ''replicate_do_db'', v, NULL)),\n   MAX(IF(n = ''replicate_ignore_db'', v, NULL)),\n   MAX(IF(n = ''replicate_do_table'', v, NULL)),\n   MAX(IF(n = ''replicate_ignore_table'', v, NULL)),\n   MAX(IF(n = ''replicate_wild_do_table'', v, NULL)),\n   MAX(IF(n = ''replicate_wild_ignore_table'', v, NULL)),\n   MAX(IF(n = ''replicate_rewrite_db'', v, NULL))\n INTO\n   @dbt_v_gtid_mode,\n   @dbt_v_gtid_strict_mode,\n   @dbt_v_gtid_executed,\n   @dbt_v_gtid_purged,\n   @dbt_v_gtid_binlog_pos,\n   @dbt_v_gtid_slave_pos,\n   @dbt_v_gtid_current_pos,\n   @dbt_v_super_read_only,\n   @dbt_v_server_uuid,\n   @dbt_v_replica_parallel_workers,\n   @dbt_v_slave_parallel_workers,\n   @dbt_v_replica_skip_errors,\n   @dbt_v_slave_skip_errors,\n   @dbt_v_replica_exec_mode,\n   @dbt_v_slave_exec_mode,\n   @dbt_v_master_info_repository,\n   @dbt_v_relay_log_info_repository,\n   @dbt_v_relay_log_recovery,\n   @dbt_v_binlog_row_metadata,\n   @dbt_v_rpl_semi_sync_master_enabled,\n   @dbt_v_rpl_semi_sync_source_enabled,\n   @dbt_v_rpl_semi_sync_slave_enabled,\n   @dbt_v_rpl_semi_sync_replica_enabled,\n   @dbt_v_replicate_do_db,\n   @dbt_v_replicate_ignore_db,\n   @dbt_v_replicate_do_table,\n   @dbt_v_replicate_ignore_table,\n   @dbt_v_replicate_wild_do_table,\n   @dbt_v_replicate_wild_ignore_table,\n   @dbt_v_replicate_rewrite_db\n FROM (SELECT LOWER(VARIABLE_NAME) AS n, VARIABLE_VALUE AS v FROM ', @dbt_vartab, ') AS s'));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- variables bundle: binlog
SET @dbt_q := IF(@dbt_vartab IS NULL, 'DO 1', CONCAT('SELECT\n   MAX(IF(n = ''binlog_expire_logs_seconds'', v, NULL)),\n   MAX(IF(n = ''expire_logs_days'', v, NULL)),\n   MAX(IF(n = ''log_bin_basename'', v, NULL)),\n   MAX(IF(n = ''log_bin_index'', v, NULL)),\n   MAX(IF(n = ''binlog_transaction_dependency_tracking'', v, NULL))\n INTO\n   @dbt_v_binlog_expire_logs_seconds,\n   @dbt_v_expire_logs_days,\n   @dbt_v_log_bin_basename,\n   @dbt_v_log_bin_index,\n   @dbt_v_binlog_transaction_dependency_tracking\n FROM (SELECT LOWER(VARIABLE_NAME) AS n, VARIABLE_VALUE AS v FROM ', @dbt_vartab, ') AS s'));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- variables bundle: innodb
SET @dbt_q := IF(@dbt_vartab IS NULL, 'DO 1', CONCAT('SELECT\n   MAX(IF(n = ''innodb_redo_log_capacity'', v, NULL)),\n   MAX(IF(n = ''innodb_log_file_size'', v, NULL)),\n   MAX(IF(n = ''innodb_log_files_in_group'', v, NULL)),\n   MAX(IF(n = ''innodb_buffer_pool_instances'', v, NULL)),\n   MAX(IF(n = ''innodb_dedicated_server'', v, NULL)),\n   MAX(IF(n = ''innodb_flush_method'', v, NULL)),\n   MAX(IF(n = ''innodb_checksum_algorithm'', v, NULL)),\n   MAX(IF(n = ''innodb_undo_tablespaces'', v, NULL)),\n   MAX(IF(n = ''innodb_undo_directory'', v, NULL)),\n   MAX(IF(n = ''innodb_temp_data_file_path'', v, NULL)),\n   MAX(IF(n = ''innodb_page_cleaners'', v, NULL)),\n   MAX(IF(n = ''innodb_log_write_ahead_size'', v, NULL))\n INTO\n   @dbt_v_innodb_redo_log_capacity,\n   @dbt_v_innodb_log_file_size,\n   @dbt_v_innodb_log_files_in_group,\n   @dbt_v_innodb_buffer_pool_instances,\n   @dbt_v_innodb_dedicated_server,\n   @dbt_v_innodb_flush_method,\n   @dbt_v_innodb_checksum_algorithm,\n   @dbt_v_innodb_undo_tablespaces,\n   @dbt_v_innodb_undo_directory,\n   @dbt_v_innodb_temp_data_file_path,\n   @dbt_v_innodb_page_cleaners,\n   @dbt_v_innodb_log_write_ahead_size\n FROM (SELECT LOWER(VARIABLE_NAME) AS n, VARIABLE_VALUE AS v FROM ', @dbt_vartab, ') AS s'));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- variables bundle: misc
SET @dbt_q := IF(@dbt_vartab IS NULL, 'DO 1', CONCAT('SELECT\n   MAX(IF(n = ''query_cache_type'', v, NULL)),\n   MAX(IF(n = ''query_cache_size'', v, NULL)),\n   MAX(IF(n = ''thread_handling'', v, NULL)),\n   MAX(IF(n = ''sql_require_primary_key'', v, NULL)),\n   MAX(IF(n = ''require_secure_transport'', v, NULL)),\n   MAX(IF(n = ''have_ssl'', v, NULL)),\n   MAX(IF(n = ''tls_version'', v, NULL)),\n   MAX(IF(n = ''log_error_verbosity'', v, NULL)),\n   MAX(IF(n = ''log_warnings'', v, NULL)),\n   MAX(IF(n = ''log_slow_extra'', v, NULL)),\n   MAX(IF(n = ''log_slow_verbosity'', v, NULL)),\n   MAX(IF(n = ''temptable_max_ram'', v, NULL)),\n   MAX(IF(n = ''default_password_lifetime'', v, NULL)),\n   MAX(IF(n = ''userstat'', v, NULL)),\n   MAX(IF(n = ''max_execution_time'', v, NULL)),\n   MAX(IF(n = ''max_statement_time'', v, NULL)),\n   MAX(IF(n = ''performance_schema_digests_size'', v, NULL)),\n   MAX(IF(n = ''table_definition_cache'', v, NULL)),\n   MAX(IF(n = ''innodb_adaptive_hash_index'', v, NULL)),\n   MAX(IF(n = ''information_schema_stats_expiry'', v, NULL)),\n   MAX(IF(n = ''innodb_stats_on_metadata'', v, NULL))\n INTO\n   @dbt_v_query_cache_type,\n   @dbt_v_query_cache_size,\n   @dbt_v_thread_handling,\n   @dbt_v_sql_require_primary_key,\n   @dbt_v_require_secure_transport,\n   @dbt_v_have_ssl,\n   @dbt_v_tls_version,\n   @dbt_v_log_error_verbosity,\n   @dbt_v_log_warnings,\n   @dbt_v_log_slow_extra,\n   @dbt_v_log_slow_verbosity,\n   @dbt_v_temptable_max_ram,\n   @dbt_v_default_password_lifetime,\n   @dbt_v_userstat,\n   @dbt_v_max_execution_time,\n   @dbt_v_max_statement_time,\n   @dbt_v_performance_schema_digests_size,\n   @dbt_v_table_definition_cache,\n   @dbt_v_innodb_adaptive_hash_index,\n   @dbt_v_information_schema_stats_expiry,\n   @dbt_v_innodb_stats_on_metadata\n FROM (SELECT LOWER(VARIABLE_NAME) AS n, VARIABLE_VALUE AS v FROM ', @dbt_vartab, ') AS s'));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- ---------------------------------------------------------------------------
-- 6. Status-counter bundle (@dbt_s_*)
-- ---------------------------------------------------------------------------
-- MySQL 8.0 removed information_schema.GLOBAL_STATUS; MySQL 5.7 errors on it
-- unless show_compatibility_56=ON. performance_schema.global_status is therefore
-- preferred and information_schema.GLOBAL_STATUS is the MariaDB-era fallback.
SET @dbt_q := IF(@dbt_stattab IS NULL, 'DO 1', CONCAT('SELECT\n   MAX(IF(n = ''uptime'', v, NULL)),\n   MAX(IF(n = ''threads_connected'', v, NULL)),\n   MAX(IF(n = ''threads_running'', v, NULL)),\n   MAX(IF(n = ''threads_created'', v, NULL)),\n   MAX(IF(n = ''threads_cached'', v, NULL)),\n   MAX(IF(n = ''max_used_connections'', v, NULL)),\n   MAX(IF(n = ''connections'', v, NULL)),\n   MAX(IF(n = ''aborted_connects'', v, NULL)),\n   MAX(IF(n = ''aborted_clients'', v, NULL)),\n   MAX(IF(n = ''connection_errors_max_connections'', v, NULL)),\n   MAX(IF(n = ''created_tmp_tables'', v, NULL)),\n   MAX(IF(n = ''created_tmp_disk_tables'', v, NULL)),\n   MAX(IF(n = ''innodb_buffer_pool_reads'', v, NULL)),\n   MAX(IF(n = ''innodb_buffer_pool_read_requests'', v, NULL)),\n   MAX(IF(n = ''innodb_buffer_pool_pages_dirty'', v, NULL)),\n   MAX(IF(n = ''innodb_buffer_pool_pages_total'', v, NULL)),\n   MAX(IF(n = ''innodb_log_waits'', v, NULL)),\n   MAX(IF(n = ''innodb_os_log_written'', v, NULL)),\n   MAX(IF(n = ''innodb_row_lock_current_waits'', v, NULL)),\n   MAX(IF(n = ''innodb_row_lock_time_avg'', v, NULL)),\n   MAX(IF(n = ''innodb_data_reads'', v, NULL)),\n   MAX(IF(n = ''innodb_data_writes'', v, NULL)),\n   MAX(IF(n = ''innodb_checkpoint_age'', v, NULL)),\n   MAX(IF(n = ''innodb_checkpoint_max_age'', v, NULL)),\n   MAX(IF(n = ''innodb_deadlocks'', v, NULL)),\n   MAX(IF(n = ''binlog_cache_use'', v, NULL))\n INTO\n   @dbt_s_uptime,\n   @dbt_s_threads_connected,\n   @dbt_s_threads_running,\n   @dbt_s_threads_created,\n   @dbt_s_threads_cached,\n   @dbt_s_max_used_connections,\n   @dbt_s_connections,\n   @dbt_s_aborted_connects,\n   @dbt_s_aborted_clients,\n   @dbt_s_connection_errors_max_connections,\n   @dbt_s_created_tmp_tables,\n   @dbt_s_created_tmp_disk_tables,\n   @dbt_s_innodb_buffer_pool_reads,\n   @dbt_s_innodb_buffer_pool_read_requests,\n   @dbt_s_innodb_buffer_pool_pages_dirty,\n   @dbt_s_innodb_buffer_pool_pages_total,\n   @dbt_s_innodb_log_waits,\n   @dbt_s_innodb_os_log_written,\n   @dbt_s_innodb_row_lock_current_waits,\n   @dbt_s_innodb_row_lock_time_avg,\n   @dbt_s_innodb_data_reads,\n   @dbt_s_innodb_data_writes,\n   @dbt_s_innodb_checkpoint_age,\n   @dbt_s_innodb_checkpoint_max_age,\n   @dbt_s_innodb_deadlocks,\n   @dbt_s_binlog_cache_use\n FROM (SELECT LOWER(VARIABLE_NAME) AS n, VARIABLE_VALUE AS v FROM ', @dbt_stattab, ') AS s'));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
SET @dbt_q := IF(@dbt_stattab IS NULL, 'DO 1', CONCAT('SELECT\n   MAX(IF(n = ''binlog_cache_disk_use'', v, NULL)),\n   MAX(IF(n = ''table_open_cache_overflows'', v, NULL)),\n   MAX(IF(n = ''opened_tables'', v, NULL)),\n   MAX(IF(n = ''open_tables'', v, NULL)),\n   MAX(IF(n = ''open_files'', v, NULL)),\n   MAX(IF(n = ''table_locks_waited'', v, NULL)),\n   MAX(IF(n = ''table_locks_immediate'', v, NULL)),\n   MAX(IF(n = ''select_full_join'', v, NULL)),\n   MAX(IF(n = ''select_scan'', v, NULL)),\n   MAX(IF(n = ''select_range_check'', v, NULL)),\n   MAX(IF(n = ''questions'', v, NULL)),\n   MAX(IF(n = ''com_commit'', v, NULL)),\n   MAX(IF(n = ''com_rollback'', v, NULL)),\n   MAX(IF(n = ''sort_merge_passes'', v, NULL)),\n   MAX(IF(n = ''ssl_accepts'', v, NULL)),\n   MAX(IF(n = ''slow_queries'', v, NULL)),\n   MAX(IF(n = ''handler_read_rnd_next'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_master_status'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_source_status'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_master_no_tx'', v, NULL)),\n   MAX(IF(n = ''rpl_semi_sync_source_no_tx'', v, NULL)),\n   MAX(IF(n = ''slaves_connected'', v, NULL)),\n   MAX(IF(n = ''slave_connections'', v, NULL)),\n   MAX(IF(n = ''performance_schema_digest_lost'', v, NULL)),\n   MAX(IF(n = ''performance_schema_index_stat_lost'', v, NULL))\n INTO\n   @dbt_s_binlog_cache_disk_use,\n   @dbt_s_table_open_cache_overflows,\n   @dbt_s_opened_tables,\n   @dbt_s_open_tables,\n   @dbt_s_open_files,\n   @dbt_s_table_locks_waited,\n   @dbt_s_table_locks_immediate,\n   @dbt_s_select_full_join,\n   @dbt_s_select_scan,\n   @dbt_s_select_range_check,\n   @dbt_s_questions,\n   @dbt_s_com_commit,\n   @dbt_s_com_rollback,\n   @dbt_s_sort_merge_passes,\n   @dbt_s_ssl_accepts,\n   @dbt_s_slow_queries,\n   @dbt_s_handler_read_rnd_next,\n   @dbt_s_rpl_semi_sync_master_status,\n   @dbt_s_rpl_semi_sync_source_status,\n   @dbt_s_rpl_semi_sync_master_no_tx,\n   @dbt_s_rpl_semi_sync_source_no_tx,\n   @dbt_s_slaves_connected,\n   @dbt_s_slave_connections,\n   @dbt_s_performance_schema_digest_lost,\n   @dbt_s_performance_schema_index_stat_lost\n FROM (SELECT LOWER(VARIABLE_NAME) AS n, VARIABLE_VALUE AS v FROM ', @dbt_stattab, ') AS s'));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- ---------------------------------------------------------------------------
-- 6b. InnoDB metrics readback
-- ---------------------------------------------------------------------------
-- information_schema.INNODB_METRICS exists on both forks but names the
-- enable-flag column differently: MySQL 5.6+/8.x call it STATUS ('enabled' /
-- 'disabled'); MariaDB calls it ENABLED (1/0). Both are read here once so
-- MY-UNDO-001/002 and MY-LOCK-007 can stay single-statement checks.
-- A disabled metric reports COUNT = 0, which is indistinguishable from a real
-- zero, hence @dbt_metrics_enabled: checks that read these counters suppress
-- themselves when it is 0 rather than reporting a false all-clear.
SET @dbt_hll := NULL;
SET @dbt_lock_deadlocks := NULL;
SET @dbt_metrics_enabled := NULL;
SET @dbt_q := IF(IFNULL(@dbt_has_innodb_metrics, 0) = 0, 'DO 1', IF(@dbt_is_mariadb,
  "SELECT MAX(IF(NAME = 'trx_rseg_history_len', `COUNT`, NULL)),
          MAX(IF(NAME = 'lock_deadlocks', `COUNT`, NULL)),
          MAX(IF(NAME = 'trx_rseg_history_len', ENABLED, NULL))
     INTO @dbt_hll, @dbt_lock_deadlocks, @dbt_metrics_enabled
     FROM information_schema.INNODB_METRICS
    WHERE NAME IN ('trx_rseg_history_len', 'lock_deadlocks')",
  "SELECT MAX(IF(NAME = 'trx_rseg_history_len', `COUNT`, NULL)),
          MAX(IF(NAME = 'lock_deadlocks', `COUNT`, NULL)),
          MAX(IF(NAME = 'trx_rseg_history_len', STATUS = 'enabled', NULL))
     INTO @dbt_hll, @dbt_lock_deadlocks, @dbt_metrics_enabled
     FROM information_schema.INNODB_METRICS
    WHERE NAME IN ('trx_rseg_history_len', 'lock_deadlocks')"));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- ---------------------------------------------------------------------------
-- 6c. Normalised replica status
-- ---------------------------------------------------------------------------
-- This is the single largest MySQL/MariaDB divergence in the whole catalog, so
-- it is resolved once here and MY-REPL-001..006/011/013 read the result.
--
-- What each fork actually exposes to SQL (verified on MariaDB 10.11.14; MySQL
-- column names from the 8.0/8.4 reference manual):
--
--   table                                        MySQL 5.7+   MariaDB 10.5+
--   replication_connection_configuration         yes          yes
--     GTID column                                AUTO_POSITION USING_GTID
--   replication_connection_status  (I/O thread)  yes          ABSENT
--   replication_applier_status     (SQL thread)  yes          yes
--   replication_applier_status_by_coordinator    yes          yes
--   replication_applier_status_by_worker         yes          yes
--     LAST_APPLIED_TRANSACTION_* timestamps      8.0+         ABSENT
--
-- Consequences, stated rather than papered over:
--   * The I/O (receiver) thread state is UNREADABLE from SQL on MariaDB. Only
--     SHOW SLAVE STATUS / SHOW ALL SLAVES STATUS reports it, and a SHOW cannot
--     be selected from. @dbt_repl_io_state stays NULL there and MY-REPL-001/002
--     say so in their details instead of implying the receiver is healthy.
--   * Replica LAG is likewise unreadable from SQL on MariaDB (no applier
--     timestamps, and Seconds_Behind_Master lives only in SHOW SLAVE STATUS).
--     @dbt_repl_lag_s stays NULL and MY-REPL-003/004 emit nothing rather than
--     reporting a lag of zero.
--   * MySQL 8.0.22 renamed SHOW SLAVE STATUS to SHOW REPLICA STATUS and 8.4
--     removed the old spelling; none of that matters here because these checks
--     never issue a SHOW.
SET @dbt_repl_io_state       := NULL;
SET @dbt_repl_sql_state      := NULL;
SET @dbt_repl_err_no         := NULL;
SET @dbt_repl_err_msg        := NULL;
SET @dbt_repl_err_ts         := NULL;
SET @dbt_repl_lag_s          := NULL;
SET @dbt_repl_lag_src        := 'unavailable';
SET @dbt_repl_using_gtid     := NULL;
SET @dbt_repl_source         := NULL;
SET @dbt_repl_retry_interval := NULL;
SET @dbt_repl_retry_count    := NULL;
SET @dbt_repl_heartbeat      := NULL;
SET @dbt_repl_channels       := 0;

-- Do the MySQL 8.0 applier timestamp columns exist? They are what makes a real
-- lag figure possible; their absence is what makes MariaDB lag unreadable.
SELECT COUNT(*) INTO @dbt_has_repl_lag_cols
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'performance_schema'
  AND TABLE_NAME = 'replication_applier_status_by_worker'
  AND COLUMN_NAME = 'LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP';

-- (a) connection configuration: source endpoint, GTID mode, retry/heartbeat.
SET @dbt_q := IF(IFNULL(@dbt_is_replica, 0) = 0 OR IFNULL(@dbt_has_repl_conn_config, 0) = 0, 'DO 1',
  IF(@dbt_is_mariadb,
    "SELECT COUNT(*), MAX(CONCAT(HOST, ':', PORT)), MAX(USING_GTID),
            MAX(CONNECTION_RETRY_INTERVAL), MAX(CONNECTION_RETRY_COUNT), MAX(HEARTBEAT_INTERVAL)
       INTO @dbt_repl_channels, @dbt_repl_source, @dbt_repl_using_gtid,
            @dbt_repl_retry_interval, @dbt_repl_retry_count, @dbt_repl_heartbeat
       FROM performance_schema.replication_connection_configuration",
    "SELECT COUNT(*), MAX(CONCAT(HOST, ':', PORT)), MAX(IF(AUTO_POSITION = 1, 'AUTO_POSITION', 'NO')),
            MAX(CONNECTION_RETRY_INTERVAL), MAX(CONNECTION_RETRY_COUNT), MAX(HEARTBEAT_INTERVAL)
       INTO @dbt_repl_channels, @dbt_repl_source, @dbt_repl_using_gtid,
            @dbt_repl_retry_interval, @dbt_repl_retry_count, @dbt_repl_heartbeat
       FROM performance_schema.replication_connection_configuration"));
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- (b) receiver (I/O) thread — MySQL only.
SET @dbt_q := IF(IFNULL(@dbt_is_replica, 0) = 0 OR IFNULL(@dbt_has_repl_conn_status, 0) = 0, 'DO 1',
  "SELECT MIN(SERVICE_STATE), MAX(LAST_ERROR_NUMBER), MAX(LAST_ERROR_MESSAGE), MAX(LAST_ERROR_TIMESTAMP)
     INTO @dbt_repl_io_state, @dbt_repl_err_no, @dbt_repl_err_msg, @dbt_repl_err_ts
     FROM performance_schema.replication_connection_status");
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- (c) applier (SQL) thread state — both forks.
SET @dbt_q := IF(IFNULL(@dbt_is_replica, 0) = 0 OR IFNULL(@dbt_has_repl_applier, 0) = 0, 'DO 1',
  "SELECT MIN(SERVICE_STATE) INTO @dbt_repl_sql_state
     FROM performance_schema.replication_applier_status");
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- (d) applier errors. MySQL puts them on the coordinator when
-- replica_parallel_workers > 0 and on the single worker otherwise; MariaDB
-- populates both. Take whichever is set, without overwriting an I/O error.
SET @dbt_q := IF(IFNULL(@dbt_is_replica, 0) = 0 OR IFNULL(@dbt_has_repl_worker, 0) = 0, 'DO 1',
  "SELECT COALESCE(NULLIF(@dbt_repl_err_no, 0), NULLIF(MAX(LAST_ERROR_NUMBER), 0), @dbt_repl_err_no),
          COALESCE(NULLIF(@dbt_repl_err_msg, ''), NULLIF(MAX(LAST_ERROR_MESSAGE), ''), @dbt_repl_err_msg),
          COALESCE(@dbt_repl_err_ts, MAX(LAST_ERROR_TIMESTAMP))
     INTO @dbt_repl_err_no, @dbt_repl_err_msg, @dbt_repl_err_ts
     FROM performance_schema.replication_applier_status_by_worker");
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- (e) lag — MySQL 8.0+ only. Preference order per DESIGN §5.2:
--   1. the transaction being applied right now (a true "how far behind" figure);
--   2. the last transaction applied (on an idle source this is elapsed time
--      since the source last committed, NOT lag — hence the 'medium' confidence
--      and the wording MY-REPL-003/004 use).
SET @dbt_q := IF(IFNULL(@dbt_is_replica, 0) = 0 OR IFNULL(@dbt_has_repl_lag_cols, 0) = 0, 'DO 1',
  "SELECT
     COALESCE(
       MAX(TIMESTAMPDIFF(SECOND, NULLIF(APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP, 0), NOW())),
       MAX(TIMESTAMPDIFF(SECOND, NULLIF(LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP, 0), NOW()))),
     IF(MAX(NULLIF(APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP, 0)) IS NOT NULL,
        'performance_schema applying-transaction timestamp',
        'performance_schema last-applied-transaction timestamp (reads as idle time when the source is quiet)')
   INTO @dbt_repl_lag_s, @dbt_repl_lag_src
   FROM performance_schema.replication_applier_status_by_worker");
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

-- ---------------------------------------------------------------------------
-- 6d. Normalised account source (@dbt_acct_src)
-- ---------------------------------------------------------------------------
-- A SQL fragment, not a table: every MY-SEC check substitutes it for the token
-- ACCTSRC in its own statement. Defined once because the account catalog is the
-- second-largest fork divergence after replication.
--
--   MySQL 5.7/8.x/8.4/9.x : mysql.user is a real table. The credential lives in
--     authentication_string; the pre-5.7 Password column is GONE from 8.0.
--     account_locked ('Y'/'N') and password_lifetime are real columns.
--   MariaDB 10.4+ : mysql.user is a VIEW over mysql.global_priv, which stores
--     everything except User/Host inside a JSON document. Both Password and
--     authentication_string exist on the view; account locking lives in the JSON
--     as $.account_locked and there is no password_lifetime column at all.
--     MariaDB also writes the literal string 'invalid' as the credential when an
--     authentication method is deliberately unusable (the default root account
--     does this, authenticating through unix_socket instead), so 'invalid' must
--     count as "no usable password" and NOT as a real credential.
--
-- PRIVACY (DESIGN §1.3): has_credential is a 0/1 derived from emptiness only.
-- No password hash is ever selected into a finding, an evidence object, or a
-- report. auth_marker carries at most the literal word 'invalid'.
--
-- The *_priv columns have identical names on both forks, so the privilege
-- expressions below need no branch.
SET @dbt_acct_priv_cols := "
    u.Select_priv, u.Insert_priv, u.Update_priv, u.Delete_priv, u.Create_priv,
    u.Drop_priv, u.Reload_priv, u.Shutdown_priv, u.Process_priv, u.File_priv,
    u.Grant_priv, u.References_priv, u.Index_priv, u.Alter_priv, u.Show_db_priv,
    u.Super_priv, u.Create_tmp_table_priv, u.Lock_tables_priv, u.Execute_priv,
    u.Repl_slave_priv, u.Repl_client_priv, u.Create_view_priv, u.Show_view_priv,
    u.Create_routine_priv, u.Alter_routine_priv, u.Create_user_priv,
    u.Event_priv, u.Trigger_priv, u.Create_tablespace_priv,
    (u.Select_priv = 'Y' AND u.Insert_priv = 'Y' AND u.Update_priv = 'Y'
     AND u.Delete_priv = 'Y' AND u.Create_priv = 'Y' AND u.Drop_priv = 'Y'
     AND u.Alter_priv = 'Y' AND u.Index_priv = 'Y' AND u.Create_user_priv = 'Y'
     AND u.Super_priv = 'Y') AS has_all_privs,
    CONCAT_WS(', ',
      IF(u.Super_priv = 'Y', 'SUPER', NULL),
      IF(u.File_priv = 'Y', 'FILE', NULL),
      IF(u.Process_priv = 'Y', 'PROCESS', NULL),
      IF(u.Grant_priv = 'Y', 'GRANT OPTION', NULL),
      IF(u.Shutdown_priv = 'Y', 'SHUTDOWN', NULL),
      IF(u.Reload_priv = 'Y', 'RELOAD', NULL),
      IF(u.Create_user_priv = 'Y', 'CREATE USER', NULL),
      IF(u.Repl_slave_priv = 'Y', 'REPLICATION SLAVE', NULL)) AS priv_list";

SET @dbt_acct_src := IF(@dbt_is_mariadb,
  CONCAT("SELECT u.User AS acct_user, u.Host AS acct_host,
    IFNULL(NULLIF(u.plugin, ''), 'mysql_native_password') AS acct_plugin,
    IF(u.authentication_string NOT IN ('', 'invalid') OR u.Password NOT IN ('', 'invalid'), 1, 0) AS has_credential,
    IF(u.authentication_string = 'invalid' OR u.Password = 'invalid', 'invalid', '') AS auth_marker,
    IFNULL(CAST(JSON_VALUE(g.Priv, '$.account_locked') AS UNSIGNED), 0) AS account_locked,
    CAST(NULL AS SIGNED) AS password_lifetime,
    IF(u.is_role = 'Y', 1, 0) AS is_role,", @dbt_acct_priv_cols, "
    FROM mysql.user AS u
    LEFT JOIN mysql.global_priv AS g ON g.User = u.User AND g.Host = u.Host"),
  CONCAT("SELECT u.User AS acct_user, u.Host AS acct_host,
    IFNULL(NULLIF(u.plugin, ''), 'caching_sha2_password') AS acct_plugin,
    IF(u.authentication_string <> '', 1, 0) AS has_credential,
    '' AS auth_marker,
    IF(u.account_locked = 'Y', 1, 0) AS account_locked,
    u.password_lifetime AS password_lifetime,
    0 AS is_role,", @dbt_acct_priv_cols, "
    FROM mysql.user AS u"));

-- Platform-managed accounts that every SEC check excludes: they are created by
-- the vendor, cannot be dropped, and firing on them trains people to ignore the
-- security section.
SET @dbt_acct_system := "('mysql.sys', 'mysql.session', 'mysql.infoschema', 'mariadb.sys',
  'rdsadmin', 'rdsrepladmin', 'cloudsqladmin', 'cloudsqlreplica', 'cloudsqlimport',
  'cloudsqlobservabilityadmin', 'azure_superuser', 'azure_pg_admin', 'sys_maint', 'PUBLIC')";

-- ---------------------------------------------------------------------------
-- 7. Post-conditions
-- ---------------------------------------------------------------------------
-- Uptime is the one status counter every rate-based check divides by. If it is
-- NULL the bundle source was wrong or unreadable; fall back to the other table
-- once, then give up (rate checks then emit nothing rather than nonsense).
SET @dbt_q := IF(@dbt_s_uptime IS NULL AND @dbt_has_is_gstatus AND @dbt_stattab <> 'information_schema.GLOBAL_STATUS',
  'SELECT VARIABLE_VALUE INTO @dbt_s_uptime FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = ''Uptime''',
  'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;

SET @dbt_uptime_s   := CAST(IFNULL(@dbt_s_uptime, 0) AS UNSIGNED);
SET @dbt_uptime_h   := GREATEST(@dbt_uptime_s / 3600, 0.0001);
SET @dbt_uptime_d   := GREATEST(@dbt_uptime_s / 86400, 0.0001);
-- Counter windows shorter than 24 h make every rate meaningless; 7 days is the
-- point at which weekly workload cycles are represented at least once.
SET @dbt_counter_conf := IF(@dbt_uptime_s < 86400, 'low',
                         IF(@dbt_uptime_s < 604800, 'medium', 'high'));

-- Optional inputs the runner may set BEFORE sourcing this file (from
-- .db-triage.yml baseline:). NULL means "unknown"; checks that need them say so
-- rather than guessing.
SET @dbt_ram_bytes   := @dbt_ram_bytes;
SET @dbt_cpu_count   := @dbt_cpu_count;
SET @dbt_disk_total_bytes := @dbt_disk_total_bytes;
SET @dbt_storage     := @dbt_storage;      -- hdd | ssd | nvme | cloud | unknown
SET @dbt_cdc_consumers := @dbt_cdc_consumers;
SET @dbt_platform    := IFNULL(@dbt_platform, 'unknown');

SELECT
  'db-triage-facts'                          AS notice,
  @dbt_fork                                  AS fork,
  @@GLOBAL.version                           AS version,
  @dbt_vnum                                  AS version_num,
  @dbt_uptime_s                              AS uptime_seconds,
  @dbt_ps_on                                 AS performance_schema,
  @dbt_sys_view_count                        AS sys_views,
  @dbt_is_replica                            AS is_replica,
  @dbt_binlog_dump_threads                   AS connected_replicas,
  IFNULL(@dbt_vartab,  '(none)')             AS variables_source,
  IFNULL(@dbt_stattab, '(none)')             AS status_source,
  @dbt_counter_conf                          AS counter_confidence;
