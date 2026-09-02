-- check: MY-WAL-002
-- title: Redo log buffer waits
-- priority: 100 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: log_waits_per_hour=1
-- reads: @dbt_s_innodb_log_waits, @@GLOBAL.innodb_log_buffer_size
-- Innodb_log_waits counts the times a transaction had to wait for the redo log
-- buffer to be flushed because it was full. Every one of those is a writer
-- stalled on a resource that costs nothing but memory to enlarge. Both forks
-- expose the counter identically.
SELECT
  'MY-WAL-002' AS check_id,
  'setting'    AS scope,
  'innodb_log_buffer_size' AS object,
  CONCAT('Innodb_log_waits = ', FORMAT(w.waits, 0), ' since restart (',
         ROUND(w.per_hour, 2), '/h over ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h). Transactions are stalling because the ',
         ROUND(@@GLOBAL.innodb_log_buffer_size / 1048576, 1),
         ' MB redo log buffer filled before it could be flushed. This is a memory-only fix and needs no restart on MySQL 8.0+ (innodb_log_buffer_size is dynamic there; MariaDB still requires a restart).') AS details,
  JSON_OBJECT(
    'innodb_log_waits', w.waits,
    'waits_per_hour', ROUND(w.per_hour, 3),
    'innodb_log_buffer_size', @@GLOBAL.innodb_log_buffer_size,
    'uptime_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_log_waits, 0) AS DECIMAL(30, 0)) AS waits,
         CAST(IFNULL(@dbt_s_innodb_log_waits, 0) AS DECIMAL(30, 0)) / @dbt_uptime_h AS per_hour
) AS w
WHERE w.waits > 0
  AND w.per_hour >= COALESCE(@log_waits_per_hour, 1);
