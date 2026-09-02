-- check: MY-REPL-003
-- title: Replica lag over 5 minutes
-- priority: 5 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql | min_version: 8.0 | requires: SELECT ON performance_schema.*
-- thresholds: lag_critical_seconds=300;lag_warn_seconds=30
-- reads: @dbt_repl_lag_s / @dbt_repl_lag_src (01_session.sql §6c)
-- Lag source, in the design's preference order: the applier's
-- APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP when a transaction is in
-- flight, otherwise LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP. Those
-- columns exist only in MySQL 8.0+; MariaDB has no SQL-readable lag at all, so
-- on MariaDB @dbt_repl_lag_s is NULL and this check emits nothing rather than a
-- false all-clear. Seconds_Behind_Source is deliberately not used even where it
-- exists: it reads 0 while the receiver thread is far behind, and NULL when
-- replication is stopped.
-- Confidence is medium, never high: on an idle source the last-applied
-- timestamp measures how long the source has been quiet, not how far behind
-- this replica is. The details say which of the two readings was used.
SELECT
  'MY-REPL-003' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replica is ', FORMAT(@dbt_repl_lag_s, 0), ' s (',
         ROUND(@dbt_repl_lag_s / 60, 1), ' min) behind ',
         IFNULL(@dbt_repl_source, 'its source'),
         ', past the ', COALESCE(@lag_critical_seconds, 300), ' s threshold. ',
         'Measured from: ', @dbt_repl_lag_src, '. ',
         'Parallel appliers: ', IFNULL(COALESCE(@dbt_v_replica_parallel_workers,
                                                @dbt_v_slave_parallel_workers), 'unknown'),
         '. A failover now would lose or replay this much work.') AS details,
  JSON_OBJECT(
    'lag_seconds', @dbt_repl_lag_s,
    'threshold_seconds', COALESCE(@lag_critical_seconds, 300),
    'lag_source', @dbt_repl_lag_src,
    'source', IFNULL(@dbt_repl_source, 'unknown'),
    'parallel_workers', COALESCE(@dbt_v_replica_parallel_workers, @dbt_v_slave_parallel_workers)) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND @dbt_repl_lag_s IS NOT NULL
  AND @dbt_repl_lag_s >= COALESCE(@lag_critical_seconds, 300);
