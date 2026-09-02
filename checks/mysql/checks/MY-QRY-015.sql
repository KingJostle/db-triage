-- check: MY-QRY-015
-- title: Status snapshot
-- priority: 240 | category: QRY | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: the @dbt_s_* status bundle (01_session.sql §6)
-- Always emitted. Not a problem: the numbers a practitioner would ask for first,
-- in one row, so the rest of the report can be read in context.
-- Two kinds of number, deliberately labelled differently: the instantaneous ones
-- (Threads_running, current row-lock waits) are a SNAPSHOT and can miss a storm
-- entirely; the rates are averages SINCE RESTART and hide any recent change.
-- Neither is a substitute for monitoring, which is why MY-REL-006 checks whether
-- any exists.
SELECT
  'MY-QRY-015' AS check_id,
  'cluster'    AS scope,
  'status-snapshot' AS object,
  CONCAT('At snapshot: Threads_running = ', s.running, ', Threads_connected = ', s.connected,
         ', Innodb_row_lock_current_waits = ', s.lock_waits,
         ', average row-lock wait ', s.lock_time_avg, ' ms. ',
         'Rates since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago: ',
         ROUND(s.questions / GREATEST(@dbt_uptime_s, 1), 1), ' questions/s, ',
         ROUND(s.commits / GREATEST(@dbt_uptime_s, 1), 1), ' commits/s, ',
         ROUND(s.rollbacks / GREATEST(@dbt_uptime_s, 1), 2), ' rollbacks/s (',
         ROUND(100.0 * s.rollbacks / GREATEST(s.commits + s.rollbacks, 1), 1), '% of transactions), ',
         ROUND(s.data_reads / GREATEST(@dbt_uptime_s, 1), 1), ' InnoDB data reads/s, ',
         ROUND(s.data_writes / GREATEST(@dbt_uptime_s, 1), 1), ' InnoDB data writes/s, ',
         ROUND(s.slow / GREATEST(@dbt_uptime_s, 1) * 3600, 1), ' slow queries/h. ',
         'The instantaneous figures are one sample and can miss a storm; the rates are averages over the whole window and hide recent change. Neither replaces monitoring (MY-REL-006).') AS details,
  JSON_OBJECT(
    'threads_running', s.running,
    'threads_connected', s.connected,
    'innodb_row_lock_current_waits', s.lock_waits,
    'innodb_row_lock_time_avg_ms', s.lock_time_avg,
    'questions_per_second', ROUND(s.questions / GREATEST(@dbt_uptime_s, 1), 2),
    'commits_per_second', ROUND(s.commits / GREATEST(@dbt_uptime_s, 1), 3),
    'rollbacks_per_second', ROUND(s.rollbacks / GREATEST(@dbt_uptime_s, 1), 4),
    'rollback_pct', ROUND(100.0 * s.rollbacks / GREATEST(s.commits + s.rollbacks, 1), 2),
    'innodb_data_reads_per_second', ROUND(s.data_reads / GREATEST(@dbt_uptime_s, 1), 2),
    'innodb_data_writes_per_second', ROUND(s.data_writes / GREATEST(@dbt_uptime_s, 1), 2),
    'slow_queries_per_hour', ROUND(s.slow / GREATEST(@dbt_uptime_s, 1) * 3600, 2),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    CAST(IFNULL(@dbt_s_threads_running, 0) AS DECIMAL(20, 0))                 AS running,
    CAST(IFNULL(@dbt_s_threads_connected, 0) AS DECIMAL(20, 0))               AS connected,
    CAST(IFNULL(@dbt_s_innodb_row_lock_current_waits, 0) AS DECIMAL(20, 0))   AS lock_waits,
    CAST(IFNULL(@dbt_s_innodb_row_lock_time_avg, 0) AS DECIMAL(20, 0))        AS lock_time_avg,
    CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0))                       AS questions,
    CAST(IFNULL(@dbt_s_com_commit, 0) AS DECIMAL(30, 0))                      AS commits,
    CAST(IFNULL(@dbt_s_com_rollback, 0) AS DECIMAL(30, 0))                    AS rollbacks,
    CAST(IFNULL(@dbt_s_innodb_data_reads, 0) AS DECIMAL(30, 0))               AS data_reads,
    CAST(IFNULL(@dbt_s_innodb_data_writes, 0) AS DECIMAL(30, 0))              AS data_writes,
    CAST(IFNULL(@dbt_s_slow_queries, 0) AS DECIMAL(30, 0))                    AS slow
) AS s;
