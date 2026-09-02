-- check: MY-CONN-009
-- title: Server saturated at snapshot time
-- priority: 50 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: running_per_core=2;running_absolute=64
-- reads: @dbt_s_threads_running, @dbt_cpu_count
-- Threads_running is the number of threads not idle right now — the closest
-- MySQL gets to a run queue. Above roughly two per core, threads are waiting on
-- each other rather than on work, and latency rises much faster than throughput
-- falls. Core count is not readable from any MySQL variable; the runner supplies
-- it from .db-triage.yml baseline.cpus or nproc. Without it the check falls back
-- to an absolute figure of 64, which is deliberately conservative, and says so.
-- One sample can catch a one-off spike or miss a storm entirely; deep mode
-- re-samples, and the details label this as a snapshot either way.
SELECT
  'MY-CONN-009' AS check_id,
  'cluster'     AS scope,
  'threads_running' AS object,
  CONCAT('Threads_running = ', r.running, ' at snapshot time',
         IF(@dbt_cpu_count IS NULL,
            CONCAT(', against an absolute threshold of ', COALESCE(@running_absolute, 64),
                   ' because the host core count was not supplied (set baseline.cpus)'),
            CONCAT(' on ', @dbt_cpu_count, ' cores — ', ROUND(r.running / @dbt_cpu_count, 1),
                   ' per core, threshold ', COALESCE(@running_per_core, 2), ')')),
         '. Threads_connected = ', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
         ', Innodb_row_lock_current_waits = ',
         CAST(IFNULL(@dbt_s_innodb_row_lock_current_waits, 0) AS UNSIGNED),
         '. A single sample can catch a spike or miss one; MY-LOCK-001/002/006 say whether the threads are waiting on locks.') AS details,
  JSON_OBJECT(
    'threads_running', r.running,
    'threads_connected', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
    'cpu_count', IFNULL(@dbt_cpu_count, 'unknown'),
    'row_lock_current_waits', CAST(IFNULL(@dbt_s_innodb_row_lock_current_waits, 0) AS UNSIGNED),
    'threshold_per_core', COALESCE(@running_per_core, 2),
    'threshold_absolute', COALESCE(@running_absolute, 64),
    'measured', 'snapshot') AS evidence_json,
  IF(@dbt_cpu_count IS NULL, 'low', 'medium') AS confidence
FROM (SELECT CAST(IFNULL(@dbt_s_threads_running, 0) AS DECIMAL(20, 0)) AS running) AS r
WHERE (@dbt_cpu_count IS NOT NULL AND r.running >= @dbt_cpu_count * COALESCE(@running_per_core, 2))
   OR (@dbt_cpu_count IS NULL     AND r.running >= COALESCE(@running_absolute, 64));
