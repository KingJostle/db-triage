-- check: MY-CORR-002
-- title: Crash-recovery messages in the error log
-- priority: 20 | category: CORR | scope: host | cost: 2 | pass: deep
-- engine: mysql | requires: SELECT ON performance_schema.*
-- thresholds: lookback_hours=168
-- reads: performance_schema.error_log
-- Same availability gate as MY-CORR-001 (MySQL 8.0.22+ only; MariaDB has no
-- SQL-readable error log). Separated from MY-CORR-001 at P20 because a crash is
-- evidence of an event, not of damage: InnoDB recovering cleanly is the system
-- working. What it changes is the meaning of every counter-based finding in the
-- report, which is why the restart itself is also reported by MY-REL-005.
SET @dbt_crash_pat := 'Starting crash recovery|was not shut down normally|mysqld got signal|Attempting backtrace|InnoDB: Starting an apply batch|Out of memory|The InnoDB memory heap|forcing InnoDB recovery';

SET @dbt_q := "
SELECT
  'MY-CORR-002' AS check_id,
  'host'        AS scope,
  'error-log'   AS object,
  CONCAT(e.n, ' crash or unclean-shutdown message(s) in the error log in the last ',
         COALESCE(@lookback_hours, 168), ' h; most recent ', e.last_seen,
         ' (uptime is ', ROUND(@dbt_uptime_s / 3600, 1), ' h). Sample: ', e.sample,
         '. Counter-based findings elsewhere in this report measure only the period since that restart.') AS details,
  JSON_OBJECT(
    'match_count', e.n,
    'first_seen', e.first_seen,
    'last_seen', e.last_seen,
    'uptime_seconds', @dbt_uptime_s,
    'sample', e.sample) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         MIN(LOGGED) AS first_seen,
         MAX(LOGGED) AS last_seen,
         SUBSTRING(GROUP_CONCAT(DISTINCT SUBSTRING(DATA, 1, 160) SEPARATOR ' | '), 1, 600) AS sample
    FROM performance_schema.error_log
   WHERE LOGGED >= NOW() - INTERVAL COALESCE(@lookback_hours, 168) HOUR
     AND DATA REGEXP @dbt_crash_pat
) AS e
WHERE e.n > 0";
SET @dbt_q := IF(IFNULL(@dbt_has_error_log, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
