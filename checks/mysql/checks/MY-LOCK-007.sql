-- check: MY-LOCK-007
-- title: Deadlocks occurring regularly
-- priority: 150 | category: LOCK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: deadlocks_per_day=1;min_deadlocks=7
-- reads: information_schema.INNODB_METRICS lock_deadlocks (via @dbt_lock_deadlocks),
--        @dbt_s_innodb_deadlocks (MariaDB status variable), @@GLOBAL.innodb_print_all_deadlocks
-- Two sources because the forks differ: MySQL exposes deadlocks only through
-- INNODB_METRICS.lock_deadlocks; MariaDB exposes both that and the
-- Innodb_deadlocks status variable. The metric's enable-flag column also differs
-- (STATUS vs ENABLED), which 01_session.sql resolves.
-- Deadlocks are not corruption and not necessarily a bug: InnoDB detects the
-- cycle and rolls back the cheaper transaction, which the application should
-- retry. They are reported at P150 because a rising rate signals an access-order
-- problem, and because most applications do not actually retry.
-- innodb_print_all_deadlocks=OFF means only the most recent one is inspectable
-- via SHOW ENGINE INNODB STATUS, so diagnosis requires waiting for the next one.
SELECT
  'MY-LOCK-007' AS check_id,
  'cluster'     AS scope,
  'deadlocks'   AS object,
  CONCAT(FORMAT(d.n, 0), ' deadlock(s) since restart, ', ROUND(d.per_day, 1),
         '/day over ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days (threshold ', COALESCE(@deadlocks_per_day, 1), '/day, minimum ',
         COALESCE(@min_deadlocks, 7), ' total). Source: ', d.src, '. ',
         'innodb_print_all_deadlocks = ', @@GLOBAL.innodb_print_all_deadlocks,
         IF(@@GLOBAL.innodb_print_all_deadlocks IN (0, 'OFF'),
            ' — only the most recent deadlock is inspectable, so diagnosing the pattern means waiting for the next one.',
            ' — full deadlock details are in the error log.'),
         ' InnoDB rolls back the cheaper transaction; the application must retry it, and many do not.') AS details,
  JSON_OBJECT(
    'deadlocks', d.n,
    'per_day', ROUND(d.per_day, 3),
    'source', d.src,
    'threshold_per_day', COALESCE(@deadlocks_per_day, 1),
    'innodb_print_all_deadlocks', CAST(@@GLOBAL.innodb_print_all_deadlocks AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(COALESCE(NULLIF(@dbt_lock_deadlocks, 0), @dbt_s_innodb_deadlocks, 0) AS DECIMAL(30, 0)) AS n,
    CAST(COALESCE(NULLIF(@dbt_lock_deadlocks, 0), @dbt_s_innodb_deadlocks, 0) AS DECIMAL(30, 0)) / @dbt_uptime_d AS per_day,
    IF(IFNULL(@dbt_lock_deadlocks, 0) > 0,
       'information_schema.INNODB_METRICS.lock_deadlocks',
       'Innodb_deadlocks status variable') AS src
) AS d
WHERE d.n >= COALESCE(@min_deadlocks, 7)
  AND d.per_day >= COALESCE(@deadlocks_per_day, 1);
