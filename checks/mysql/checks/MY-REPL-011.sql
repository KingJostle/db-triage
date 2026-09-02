-- check: MY-REPL-011
-- title: Single-threaded replica applier while lagging
-- priority: 100 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: lag_warn_seconds=30
-- reads: @dbt_v_replica_parallel_workers / @dbt_v_slave_parallel_workers, @dbt_repl_lag_s
-- Name divergence: MySQL 8.0.26+ replica_parallel_workers (default 4 from
-- 8.0.27), older MySQL and all MariaDB slave_parallel_workers (default 0).
-- Both spellings are COALESCEd from the bundle.
-- Derived: only fires when lag is already measurable, so a healthy replica that
-- happens to run one applier thread is not nagged. Where lag is unreadable
-- (MariaDB, see MY-REPL-003) this check cannot fire either — that gap is
-- documented rather than worked around with a guess.
SELECT
  'MY-REPL-011' AS check_id,
  'setting'     AS scope,
  IF(@dbt_v_replica_parallel_workers IS NOT NULL, 'replica_parallel_workers', 'slave_parallel_workers') AS object,
  CONCAT('Replica is ', FORMAT(@dbt_repl_lag_s, 0), ' s behind and applies transactions with ',
         w.workers, ' worker thread(s). ',
         'A single applier serialises everything the source committed in parallel, so lag grows under any write burst. ',
         'binlog_transaction_dependency_tracking on the source = ',
         IFNULL(@dbt_v_binlog_transaction_dependency_tracking, 'not readable here'),
         ' (WRITESET lets replicas parallelise much more aggressively).') AS details,
  JSON_OBJECT(
    'parallel_workers', w.workers,
    'lag_seconds', @dbt_repl_lag_s,
    'threshold_seconds', COALESCE(@lag_warn_seconds, 30),
    'dependency_tracking', IFNULL(@dbt_v_binlog_transaction_dependency_tracking, 'n/a')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT CAST(COALESCE(@dbt_v_replica_parallel_workers, @dbt_v_slave_parallel_workers, 0) AS SIGNED) AS workers
) AS w
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND @dbt_repl_lag_s IS NOT NULL
  AND @dbt_repl_lag_s >= COALESCE(@lag_warn_seconds, 30)
  AND w.workers <= 1;
