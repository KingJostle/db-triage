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
