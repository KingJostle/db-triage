-- check: MY-QRY-011
-- title: Statements failing or warning frequently
-- priority: 150 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: error_ratio=0.05;min_executions=1000
-- reads: performance_schema.events_statements_summary_by_digest (SUM_ERRORS, SUM_WARNINGS)
-- Read directly from the digest table rather than from sys.statements_with_errors_or_warnings
-- so the threshold is explicit and the fork/version differences in that view do
-- not matter.
-- A statement erroring five percent of the time is doing real work and throwing
-- it away: the server pays the full parse, plan and partial execution cost and
-- the application gets an exception. Duplicate-key errors used as an upsert
-- idiom are the common benign case and are named in the finding so the reviewer
-- can dismiss them quickly.
-- WARNINGS matter more than they look on a server that failed MY-SCHEMA-004:
-- without strict SQL mode, silent truncation IS a warning, so a high warning
-- count there is data loss being reported and ignored.
SET @dbt_q := "
SELECT
  'MY-QRY-011' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT('Statement in ', IFNULL(d.SCHEMA_NAME, '(no schema)'), ' executed ',
         FORMAT(d.COUNT_STAR, 0), ' time(s) with ', FORMAT(d.SUM_ERRORS, 0),
         ' error(s) (', ROUND(100.0 * d.SUM_ERRORS / d.COUNT_STAR, 1),
         '%, threshold ', ROUND(100 * COALESCE(@error_ratio, 0.05), 0), '%) and ',
         FORMAT(d.SUM_WARNINGS, 0), ' warning(s). ',
         'Each failed execution still costs a parse, a plan and partial execution before it is thrown away. ',
         'A duplicate-key error rate is often a deliberate insert-or-update idiom and can be dismissed; ',
         IF(@dbt_global_sql_mode NOT LIKE '%STRICT%',
            'note that this server is NOT in strict SQL mode (MY-SCHEMA-004), so a high warning count here is silent truncation being reported and ignored. ',
            ''),
         'Window: since restart ', ROUND(@dbt_uptime_s / 86400, 1), ' days ago. Statement: ',
         SUBSTRING(d.DIGEST_TEXT, 1, 250)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', IFNULL(d.SCHEMA_NAME, ''),
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'errors', d.SUM_ERRORS,
    'warnings', d.SUM_WARNINGS,
    'error_ratio', ROUND(d.SUM_ERRORS / d.COUNT_STAR, 4),
    'threshold_ratio', COALESCE(@error_ratio, 0.05),
    'strict_sql_mode', IF(@dbt_global_sql_mode LIKE '%STRICT%', 1, 0),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM performance_schema.events_statements_summary_by_digest AS d
WHERE d.DIGEST IS NOT NULL
  AND IFNULL(d.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
  AND d.COUNT_STAR >= COALESCE(@min_executions, 1000)
  AND d.SUM_ERRORS >= d.COUNT_STAR * COALESCE(@error_ratio, 0.05)
ORDER BY d.SUM_ERRORS DESC
LIMIT 10";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
