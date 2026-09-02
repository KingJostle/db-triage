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
