-- check: MY-BAK-003
-- title: Binary log retention shorter than one day
-- priority: 20 | category: BAK | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: min_retention_seconds=86400
-- reads: @dbt_v_binlog_expire_logs_seconds, @dbt_v_expire_logs_days, @@GLOBAL.log_bin
-- Variable divergence, all four combinations occur in the field:
--   MySQL 5.7            expire_logs_days only (days, integer)
--   MySQL 8.0            binlog_expire_logs_seconds (default 2592000) AND the
--                        deprecated expire_logs_days; the seconds one wins
--   MySQL 8.4            expire_logs_days removed
--   MariaDB 10.6+        both exist; expire_logs_days accepts fractions
-- Both are read from the bundle so a fork that lacks one yields NULL instead of
-- an "Unknown system variable" error. Effective retention = the seconds setting
-- when it is non-zero, else days x 86400.
-- Retention shorter than the backup interval means PITR has holes: a restore of
-- last night's full backup has no binlogs to roll forward from.
SELECT
  'MY-BAK-003' AS check_id,
  'setting'    AS scope,
  IF(r.secs_set > 0, 'binlog_expire_logs_seconds', 'expire_logs_days') AS object,
  CONCAT('Binary logs are purged after ', ROUND(r.eff / 3600, 1), ' h (',
         IF(r.secs_set > 0,
            CONCAT('binlog_expire_logs_seconds = ', r.secs_set),
            CONCAT('expire_logs_days = ', r.days_set)),
         '), which is less than the ', ROUND(COALESCE(@min_retention_seconds, 86400) / 3600, 0),
         ' h minimum. A restore from a nightly full backup has no binary logs to roll forward, so point-in-time recovery has a gap for part of every day.') AS details,
  JSON_OBJECT(
    'effective_retention_seconds', r.eff,
    'binlog_expire_logs_seconds', r.secs_set,
    'expire_logs_days', r.days_set,
    'threshold_seconds', COALESCE(@min_retention_seconds, 86400)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)) AS secs_set,
    CAST(IFNULL(@dbt_v_expire_logs_days, 0) AS DECIMAL(20, 6))           AS days_set,
    IF(CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)) > 0,
       CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)),
       CAST(IFNULL(@dbt_v_expire_logs_days, 0) AS DECIMAL(20, 6)) * 86400) AS eff
) AS r
WHERE @@GLOBAL.log_bin = 1
  AND r.eff > 0
  AND r.eff < COALESCE(@min_retention_seconds, 86400);
