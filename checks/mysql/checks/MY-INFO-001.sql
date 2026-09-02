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
