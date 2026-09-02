-- check: MY-REPL-004
-- title: Replica lag over 30 seconds
-- priority: 50 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: lag_warn_seconds=30;lag_critical_seconds=300
-- reads: @dbt_repl_lag_s / @dbt_repl_lag_src
-- Magnitude tier below MY-REPL-003, own ID so the tiers suppress independently.
-- Same MariaDB limitation: no SQL-readable lag, so this never fires there.
SELECT
  'MY-REPL-004' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replica is ', FORMAT(@dbt_repl_lag_s, 0), ' s behind ',
         IFNULL(@dbt_repl_source, 'its source'),
         ' (threshold ', COALESCE(@lag_warn_seconds, 30), ' s; the P5 tier MY-REPL-003 starts at ',
         COALESCE(@lag_critical_seconds, 300), ' s). Measured from: ', @dbt_repl_lag_src,
         '. Read-your-writes traffic routed here will see stale rows.') AS details,
  JSON_OBJECT(
    'lag_seconds', @dbt_repl_lag_s,
    'threshold_seconds', COALESCE(@lag_warn_seconds, 30),
    'lag_source', @dbt_repl_lag_src,
    'source', IFNULL(@dbt_repl_source, 'unknown')) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND @dbt_repl_lag_s IS NOT NULL
  AND @dbt_repl_lag_s >= COALESCE(@lag_warn_seconds, 30)
  AND @dbt_repl_lag_s <  COALESCE(@lag_critical_seconds, 300);
