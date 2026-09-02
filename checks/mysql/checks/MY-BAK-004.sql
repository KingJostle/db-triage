-- check: MY-BAK-004
-- title: Binary logs never expire
-- priority: 50 | category: BAK | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- platform_skip: rds;aurora;cloudsql;azure
-- thresholds: (none)
-- reads: @dbt_v_binlog_expire_logs_seconds, @dbt_v_expire_logs_days, @@GLOBAL.log_bin
-- Both retention variables zero means PURGE BINARY LOGS is the only thing that
-- ever removes a binlog file. That is a disk-full outage with a long fuse, and
-- the fuse burns faster the busier the server gets. Pairs with MY-CAP-006
-- (binlog volume) and MY-CAP-001/002 (filesystem headroom).
-- MariaDB 10.6+ and MySQL 5.7 both default expire_logs_days to 0; MySQL 8.0
-- defaults binlog_expire_logs_seconds to 2592000 (30 days), so a zero there was
-- set on purpose.
SELECT
  'MY-BAK-004' AS check_id,
  'setting'    AS scope,
  'binlog-retention' AS object,
  CONCAT('Binary logging is ON and no retention is configured: ',
         'binlog_expire_logs_seconds = ', IFNULL(@dbt_v_binlog_expire_logs_seconds, 'n/a'),
         ', expire_logs_days = ', IFNULL(@dbt_v_expire_logs_days, 'n/a'),
         '. Binary logs accumulate until the filesystem fills or someone runs PURGE BINARY LOGS by hand. ',
         'log_bin_basename = ', IFNULL(@dbt_v_log_bin_basename, 'unknown'), '.') AS details,
  JSON_OBJECT(
    'binlog_expire_logs_seconds', IFNULL(@dbt_v_binlog_expire_logs_seconds, 'n/a'),
    'expire_logs_days', IFNULL(@dbt_v_expire_logs_days, 'n/a'),
    'log_bin_basename', IFNULL(@dbt_v_log_bin_basename, 'unknown'),
    'platform', @dbt_platform) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @@GLOBAL.log_bin = 1
  AND CAST(IFNULL(@dbt_v_binlog_expire_logs_seconds, 0) AS DECIMAL(20, 3)) = 0
  AND CAST(IFNULL(@dbt_v_expire_logs_days, 0) AS DECIMAL(20, 6)) = 0;
