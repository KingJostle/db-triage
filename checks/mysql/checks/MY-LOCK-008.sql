-- check: MY-LOCK-008
-- title: Table-level lock waits
-- priority: 150 | category: LOCK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: table_lock_wait_ratio=0.01;min_table_locks=10000
-- reads: @dbt_s_table_locks_waited, @dbt_s_table_locks_immediate
-- These counters only move for storage engines that take table-level locks —
-- in practice MyISAM, Aria and MEMORY — because InnoDB uses row locks and does
-- not increment them. A non-zero ratio is therefore a symptom whose cause is
-- MY-DUR-007 (non-transactional engines still in use), and the finding says so
-- rather than suggesting a lock-tuning fix that does not exist.
-- Both forks expose the counters identically.
SELECT
  'MY-LOCK-008' AS check_id,
  'cluster'     AS scope,
  'table-locks' AS object,
  CONCAT(FORMAT(l.waited, 0), ' of ', FORMAT(l.waited + l.immediate, 0),
         ' table lock requests had to wait since restart (',
         ROUND(100.0 * l.waited / (l.waited + l.immediate), 2), '%, threshold ',
         ROUND(100 * COALESCE(@table_lock_wait_ratio, 0.01), 1), '%). ',
         'InnoDB does not increment these counters, so the waits are on table-locking engines — see MY-DUR-007. ',
         'Non-InnoDB user tables found: ', t.n, '. ',
         'There is no lock-tuning fix for this; the fix is converting those tables to InnoDB.') AS details,
  JSON_OBJECT(
    'table_locks_waited', l.waited,
    'table_locks_immediate', l.immediate,
    'wait_ratio', ROUND(l.waited / (l.waited + l.immediate), 5),
    'threshold_ratio', COALESCE(@table_lock_wait_ratio, 0.01),
    'non_innodb_user_tables', t.n,
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_table_locks_waited, 0) AS DECIMAL(30, 0))    AS waited,
         CAST(IFNULL(@dbt_s_table_locks_immediate, 0) AS DECIMAL(30, 0)) AS immediate
) AS l,
(
  SELECT COUNT(*) AS n FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE' AND ENGINE IS NOT NULL AND ENGINE <> 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS t
WHERE l.waited + l.immediate >= COALESCE(@min_table_locks, 10000)
  AND l.waited / (l.waited + l.immediate) >= COALESCE(@table_lock_wait_ratio, 0.01);
