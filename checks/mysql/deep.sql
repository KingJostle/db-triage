-- db-triage — checks/mysql/deep.sql
-- GENERATED FILE — do not hand-edit. Regenerated from
-- checks/registry-mysql.csv and checks/mysql/checks/*.sql.
--
-- HOW TO RUN (one session, in this order):
--   mysql --batch --raw --force "$DSN" \
--     -e "source checks/mysql/01_session.sql; \
--         source checks/mysql/00_preflight.sql; \
--         source checks/mysql/deep.sql"
-- or, equivalently, concatenate the three files and pipe them in.
--
-- 01_session.sql MUST run first: it establishes the read-only
-- transaction, the statement and lock timeouts, the run marker, and
-- every @dbt_* fact these checks read. 00_preflight.sql sets the
-- platform fingerprint and privilege flags that gate several checks.
--
-- --force (or ON_ERROR_STOP off) is required so that a privilege error
-- on one check does not abort the batch; each error appears adjacent to
-- its own @@CHECK marker and is attributed to that check.
--
-- Every check emits the fixed column set:
--   check_id, scope, object, details, evidence_json, confidence
-- bracketed by '@@CHECK <id>' and '@@END' marker rows.
--
-- Thresholds: each check reads COALESCE(@<key>, <default>), so the
-- runner overrides one by issuing SET @<key> := <value>; before the
-- batch. The threshold keys are in the registry's `thresholds` column.
--
-- Contents: deep pass, 2 checks, ordered by priority ascending so that
-- if the batch is interrupted the worst findings are already in hand.
-- P1   MY-CORR-001    InnoDB corruption messages in the error log
-- P20  MY-CORR-002    Crash-recovery messages in the error log

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CORR-001' AS marker;
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
SELECT '@@END' AS marker;

-- --------------------------------------------------------------------------
SELECT '@@CHECK MY-CORR-002' AS marker;
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
SELECT '@@END' AS marker;

