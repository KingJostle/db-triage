-- check: MY-QRY-005
-- title: Top 10 statements by average latency
-- priority: 240 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_n=10
-- reads: performance_schema.events_statements_summary_by_digest
-- P240 workload profile: not a problem, the raw material for the next step.
-- Ranked by average time with a 100-execution floor, so a single unlucky execution cannot top the list. This is the list a user complaint maps onto: the statements that are individually slow, as opposed to MY-QRY-004's statements that are collectively expensive.
-- Column availability verified on MariaDB 10.11: SCHEMA_NAME, DIGEST,
-- DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT, AVG_TIMER_WAIT, SUM_ROWS_SENT,
-- SUM_ROWS_EXAMINED, SUM_CREATED_TMP_DISK_TABLES, SUM_NO_INDEX_USED, SUM_ERRORS,
-- FIRST_SEEN and LAST_SEEN all exist on MySQL 5.7+/8.x and MariaDB 10.5+.
-- MySQL 8.0-only columns (QUERY_SAMPLE_TEXT, QUANTILE_*, SUM_CPU_TIME) are
-- deliberately not used so one query serves both forks.
-- Timer units are PICOSECONDS on both forks; divide by 1e12 for seconds.
-- WINDOW: everything here is cumulative since the last server restart or
-- TRUNCATE of the digest table — ${dbt_uptime} below states it in the finding.
-- Percentages are understated whenever MY-QRY-002 reports lost digests.
SET @dbt_q := "
SELECT
  'MY-QRY-005' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT(d.sch, ' — executed ', FORMAT(d.COUNT_STAR, 0),
         ' time(s), total ', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 1), ' s (',
         ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 1), '% of all statement time), ',
         'avg ', ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, ',
         'rows examined/sent ', FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0),
         ' (ratio ', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 1), '), ',
         'no-index scans ', FORMAT(d.SUM_NO_INDEX_USED, 0),
         ', disk temp tables ', FORMAT(d.SUM_CREATED_TMP_DISK_TABLES, 0),
         ', errors ', FORMAT(d.SUM_ERRORS, 0),
         '. First seen ', d.FIRST_SEEN, ', last seen ', d.LAST_SEEN,
         ' (window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago). ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 300)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', d.sch,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'total_seconds', ROUND(d.SUM_TIMER_WAIT / 1000000000000, 3),
    'pct_of_total_time', ROUND(100.0 * d.SUM_TIMER_WAIT / GREATEST(d.grand_total, 1), 2),
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'examined_per_sent', ROUND(d.SUM_ROWS_EXAMINED / GREATEST(d.SUM_ROWS_SENT, 1), 2),
    'no_index_used', d.SUM_NO_INDEX_USED,
    'disk_tmp_tables', d.SUM_CREATED_TMP_DISK_TABLES,
    'errors', d.SUM_ERRORS,
    'first_seen', CAST(d.FIRST_SEEN AS CHAR),
    'last_seen', CAST(d.LAST_SEEN AS CHAR),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT s.*, IFNULL(s.SCHEMA_NAME, '(no schema)') AS sch,
         (SELECT SUM(SUM_TIMER_WAIT) FROM performance_schema.events_statements_summary_by_digest) AS grand_total
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
     AND s.COUNT_STAR >= 100
   ORDER BY s.AVG_TIMER_WAIT DESC
   LIMIT 10
) AS d";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
