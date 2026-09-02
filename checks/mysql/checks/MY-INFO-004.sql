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
