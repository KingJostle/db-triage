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
