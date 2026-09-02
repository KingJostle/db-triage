-- check: MY-WAL-001
-- title: Redo log capacity below one hour of writes
-- priority: 50 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: redo_hours=1;min_write_rate_bytes_per_hour=10485760;small_capacity_bytes=104857600
-- reads: @dbt_v_innodb_redo_log_capacity (MySQL 8.0.30+),
--        @dbt_v_innodb_log_file_size x @dbt_v_innodb_log_files_in_group (older MySQL, MariaDB),
--        @dbt_s_innodb_os_log_written, @dbt_uptime_s
-- Version divergence: MySQL 8.0.30 introduced innodb_redo_log_capacity (default
-- 100 MB) and deprecated the file-size x file-count arithmetic. MariaDB 10.5
-- REMOVED innodb_log_files_in_group entirely (there is one file), so on MariaDB
-- capacity is innodb_log_file_size alone. Both readings come from the bundle and
-- the fallback chain covers 5.7, 8.0 pre-.30, 8.0.30+, 8.4, 9.x and MariaDB.
-- Sizing rule (Percona's): the redo log should hold roughly an hour of writes.
-- When it cannot, checkpoints become continuous, InnoDB switches to aggressive
-- adaptive flushing, and throughput collapses in bursts rather than degrading
-- smoothly. Rate is bytes written since restart divided by uptime, so its
-- confidence follows the counter window (@dbt_counter_conf).
SELECT
  'MY-WAL-001' AS check_id,
  'setting'    AS scope,
  IF(@dbt_v_innodb_redo_log_capacity IS NOT NULL, 'innodb_redo_log_capacity', 'innodb_log_file_size') AS object,
  CONCAT('Redo capacity is ', ROUND(c.capacity / 1048576, 0), ' MB (',
         c.how, ') while redo is written at ', ROUND(c.rate_h / 1048576, 1),
         ' MB/h averaged over ', ROUND(@dbt_uptime_s / 3600, 1),
         ' h of uptime. That is ', ROUND(c.capacity / GREATEST(c.rate_h, 1), 2),
         ' h of headroom, below the ', COALESCE(@redo_hours, 1),
         ' h target. Checkpointing becomes continuous and InnoDB flushes aggressively, which shows up as write stalls rather than steady slowdown.') AS details,
  JSON_OBJECT(
    'redo_capacity_bytes', c.capacity,
    'capacity_source', c.how,
    'redo_bytes_per_hour', ROUND(c.rate_h),
    'hours_of_headroom', ROUND(c.capacity / GREATEST(c.rate_h, 1), 3),
    'threshold_hours', COALESCE(@redo_hours, 1),
    'uptime_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CASE
      WHEN @dbt_v_innodb_redo_log_capacity IS NOT NULL
        THEN CAST(@dbt_v_innodb_redo_log_capacity AS DECIMAL(30, 0))
      ELSE CAST(IFNULL(@dbt_v_innodb_log_file_size, 0) AS DECIMAL(30, 0))
         * GREATEST(CAST(IFNULL(@dbt_v_innodb_log_files_in_group, 1) AS SIGNED), 1)
    END AS capacity,
    CASE
      WHEN @dbt_v_innodb_redo_log_capacity IS NOT NULL THEN 'innodb_redo_log_capacity'
      WHEN @dbt_v_innodb_log_files_in_group IS NOT NULL THEN 'innodb_log_file_size x innodb_log_files_in_group'
      ELSE 'innodb_log_file_size (MariaDB 10.5+ has a single redo file)'
    END AS how,
    CAST(IFNULL(@dbt_s_innodb_os_log_written, 0) AS DECIMAL(30, 0)) / @dbt_uptime_h AS rate_h
) AS c
WHERE c.capacity > 0
  AND c.rate_h >= COALESCE(@min_write_rate_bytes_per_hour, 10485760)
  AND c.capacity < c.rate_h * COALESCE(@redo_hours, 1);
