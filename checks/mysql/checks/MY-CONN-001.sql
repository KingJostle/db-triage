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
