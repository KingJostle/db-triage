-- check: MY-CONN-002
-- title: Connections at or above 70 percent of max_connections
-- priority: 50 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: conn_warn_ratio=0.70;conn_critical_ratio=0.90
-- reads: as MY-CONN-001
-- Magnitude tier below MY-CONN-001, separate ID so the tiers suppress
-- independently. 70% is the point at which a normal daily peak plus one
-- application restart storm reaches the ceiling.
SELECT
  'MY-CONN-002' AS check_id,
  'cluster'     AS scope,
  'max_connections' AS object,
  CONCAT('Connections are at ', c.now_n, ' now, peak ', c.peak,
         ' since restart, against max_connections = ', @@GLOBAL.max_connections,
         ' (', ROUND(100.0 * GREATEST(c.now_n, c.peak) / @@GLOBAL.max_connections, 0),
         '%, threshold ', ROUND(100 * COALESCE(@conn_warn_ratio, 0.70), 0),
         '%; the P5 tier MY-CONN-001 starts at ',
         ROUND(100 * COALESCE(@conn_critical_ratio, 0.90), 0), '%). ',
         'Headroom is ', @@GLOBAL.max_connections - GREATEST(c.now_n, c.peak),
         ' connections — roughly one application restart.') AS details,
  JSON_OBJECT(
    'threads_connected', c.now_n,
    'max_used_connections', c.peak,
    'max_connections', @@GLOBAL.max_connections,
    'ratio', ROUND(GREATEST(c.now_n, c.peak) / @@GLOBAL.max_connections, 4),
    'threshold_ratio', COALESCE(@conn_warn_ratio, 0.70)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_threads_connected, 0) AS DECIMAL(20, 0))    AS now_n,
         CAST(IFNULL(@dbt_s_max_used_connections, 0) AS DECIMAL(20, 0)) AS peak
) AS c
WHERE GREATEST(c.now_n, c.peak) >= @@GLOBAL.max_connections * COALESCE(@conn_warn_ratio, 0.70)
  AND GREATEST(c.now_n, c.peak) <  @@GLOBAL.max_connections * COALESCE(@conn_critical_ratio, 0.90);
