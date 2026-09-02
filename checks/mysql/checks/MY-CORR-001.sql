-- check: MY-CORR-001
-- title: InnoDB corruption messages in the error log
-- priority: 1 | category: CORR | scope: host | cost: 2 | pass: deep
-- engine: mysql | requires: SELECT ON performance_schema.*
-- thresholds: lookback_hours=168
-- reads: performance_schema.error_log
-- Availability, verified: performance_schema.error_log exists only in MySQL
-- 8.0.22 and later. MariaDB 10.11 has no equivalent table at all — the error log
-- is a file and nothing but the OS can read it — so on MariaDB this check emits
-- nothing and the runner records it as skipped with reason `version`. The file
-- path for a manual read is @@GLOBAL.log_error, reported by MY-INFO-001.
-- The wording is deliberately "reported", never "corrupt": these strings are
-- InnoDB telling you it could not trust a page, which is also what a failing
-- disk controller or a bad backup restore looks like.
SET @dbt_corr_pat := 'Database page corruption|checksum mismatch|is corrupted|Assertion failure|Tablespace .* is missing|log sequence number .* is in the future|Corrupt|cannot be decrypted|space header page consists of zero bytes';

SET @dbt_q := "
SELECT
  'MY-CORR-001' AS check_id,
  'host'        AS scope,
  'error-log'   AS object,
  CONCAT(e.n, ' InnoDB integrity message(s) in the error log in the last ',
         COALESCE(@lookback_hours, 168), ' h, first at ', e.first_seen,
         ', most recent at ', e.last_seen, '. Sample: ', e.sample) AS details,
  JSON_OBJECT(
    'match_count', e.n,
    'first_seen', e.first_seen,
    'last_seen', e.last_seen,
    'lookback_hours', COALESCE(@lookback_hours, 168),
    'sample', e.sample) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS n,
         MIN(LOGGED) AS first_seen,
         MAX(LOGGED) AS last_seen,
         SUBSTRING(GROUP_CONCAT(DISTINCT SUBSTRING(DATA, 1, 160) SEPARATOR ' | '), 1, 600) AS sample
    FROM performance_schema.error_log
   WHERE LOGGED >= NOW() - INTERVAL COALESCE(@lookback_hours, 168) HOUR
     AND DATA REGEXP @dbt_corr_pat
) AS e
WHERE e.n > 0";
SET @dbt_q := IF(IFNULL(@dbt_has_error_log, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
