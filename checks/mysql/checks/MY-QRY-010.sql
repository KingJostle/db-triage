-- check: MY-QRY-010
-- title: One statement digest dominates total latency
-- priority: 100 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: dominance_ratio=0.25;min_executions=1000
-- reads: performance_schema.events_statements_summary_by_digest
-- Derived from the same data as MY-QRY-004 but stated as a finding rather than a
-- list, because a single digest taking a quarter of all statement time is a
-- structural fact about the workload: it means one query is the server's
-- capacity limit, and tuning anything else first is wasted effort.
-- The percentage is understated whenever MY-QRY-002 reports lost digests, and
-- the window is since restart, so both are named in the details.
SET @dbt_q := "
SELECT
  'MY-QRY-010' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT('A single statement digest accounts for ',
         ROUND(100.0 * d.SUM_TIMER_WAIT / d.grand_total, 1),
         '% of all statement execution time on this server (threshold ',
         ROUND(100 * COALESCE(@dominance_ratio, 0.25), 0), '%), over ',
         FORMAT(d.COUNT_STAR, 0), ' executions totalling ',
         ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s, averaging ',
         ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms each. ',
         'Rows examined per row sent: ',
         ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1),
         '. This one statement is the server''s capacity limit; tuning anything else first has a smaller ceiling than fixing this. ',
         'Window: since restart ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days ago. The percentage is understated if MY-QRY-002 reported lost digests. ',
         'Schema ', IFNULL(d.SCHEMA_NAME, '(none)'), '. Statement: ',
         SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', IFNULL(d.SCHEMA_NAME, ''),
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / d.grand_total, 2),
    'threshold_ratio', COALESCE(@dominance_ratio, 0.25),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
) AS d
WHERE d.grand_total > 0
  AND d.COUNT_STAR >= COALESCE(@min_executions, 1000)
  AND d.SUM_TIMER_WAIT >= d.grand_total * COALESCE(@dominance_ratio, 0.25)";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
