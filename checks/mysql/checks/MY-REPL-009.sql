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
