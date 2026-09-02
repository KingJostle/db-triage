-- check: MY-QRY-014
-- title: Plan-hostile patterns in top statement digests
-- priority: 150 | category: QRY | scope: query | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: top_digests=200;min_executions=100
-- reads: performance_schema.events_statements_summary_by_digest (DIGEST_TEXT)
-- CONFIDENCE IS LOW BY CONSTRUCTION AND THIS CHECK IS NEVER PROMOTED INTO
-- "Fix first". It is a regular-expression match on normalised statement text,
-- which means it can be wrong in both directions: a leading-wildcard LIKE
-- against a 50-row table is fine, and a plan-hostile query written in a way the
-- pattern does not match is missed entirely. Treat every row as a question.
-- Patterns and why each defeats an index:
--   LIKE '%...'         a B-tree can only seek on a known prefix, so a leading
--                       wildcard forces a scan of the whole index or table
--   ORDER BY RAND()     assigns a random value to every candidate row, then
--                       sorts all of them, to return one
--   function(column)    any expression around an indexed column makes the index
--                       unusable, unless it exactly matches a functional index
--                       (MySQL 8.0.13+; MariaDB has no functional indexes)
--   LIMIT n OFFSET big  MySQL reads and discards every skipped row; keyset
--                       pagination reads only what it returns
--   NOT IN (subquery)   historically materialised and re-evaluated per row
--   OR across columns   often prevents a single index from being used
-- DIGEST_TEXT is already normalised (literals replaced by ?), so no user data is
-- read or echoed by these patterns.
SET @dbt_q := "
SELECT
  'MY-QRY-014' AS check_id,
  'query'      AS scope,
  CONCAT('digest:', LEFT(d.DIGEST, 16)) AS object,
  CONCAT('Statement in ', IFNULL(d.SCHEMA_NAME, '(no schema)'),
         ' matches plan-hostile pattern(s): ', d.patterns,
         '. Executed ', FORMAT(d.COUNT_STAR, 0), ' time(s), avg ',
         ROUND(d.AVG_TIMER_WAIT / 1000000000, 2), ' ms, rows examined/sent ',
         FORMAT(d.SUM_ROWS_EXAMINED, 0), '/', FORMAT(d.SUM_ROWS_SENT, 0), '. ',
         'THIS IS A TEXT PATTERN MATCH, NOT AN EXECUTION PLAN: a leading-wildcard LIKE on a 50-row lookup table is perfectly fine, and a differently-written plan-hostile query is missed entirely. Confirm with EXPLAIN before changing anything. ',
         'Statement: ', SUBSTRING(d.DIGEST_TEXT, 1, 250)) AS details,
  JSON_OBJECT(
    'digest', d.DIGEST,
    'schema', IFNULL(d.SCHEMA_NAME, ''),
    'patterns', d.patterns,
    'digest_text', SUBSTRING(d.DIGEST_TEXT, 1, 1000),
    'exec_count', d.COUNT_STAR,
    'avg_ms', ROUND(d.AVG_TIMER_WAIT / 1000000000, 3),
    'rows_examined', d.SUM_ROWS_EXAMINED,
    'rows_sent', d.SUM_ROWS_SENT,
    'basis', 'regular expression on normalised digest text') AS evidence_json,
  'low' AS confidence
FROM (
  SELECT s.DIGEST, s.SCHEMA_NAME, s.DIGEST_TEXT, s.COUNT_STAR, s.AVG_TIMER_WAIT,
         s.SUM_ROWS_EXAMINED, s.SUM_ROWS_SENT,
         CONCAT_WS(', ',
           IF(s.DIGEST_TEXT REGEXP 'LIKE[[:space:]]*\\\\?', 'leading-wildcard LIKE (only if the literal starts with %)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'ORDER[[:space:]]+BY[[:space:]]+RAND', 'ORDER BY RAND()', NULL),
           IF(s.DIGEST_TEXT REGEXP 'OFFSET[[:space:]]*\\\\?|LIMIT[[:space:]]*\\\\?[[:space:]]*,', 'LIMIT with OFFSET (deep pagination reads and discards every skipped row)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'NOT[[:space:]]+IN[[:space:]]*\\\\([[:space:]]*SELECT', 'NOT IN (subquery)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'WHERE[^;]*(UPPER|LOWER|DATE|CONCAT|SUBSTRING|COALESCE|IFNULL|CAST)[[:space:]]*\\\\(`', 'function applied to a column in WHERE', NULL),
           IF(s.DIGEST_TEXT REGEXP 'SELECT[[:space:]]+\\\\*[[:space:]]+FROM', 'SELECT * (defeats covering indexes and moves unused columns)', NULL),
           IF(s.DIGEST_TEXT REGEXP 'COLLATE', 'explicit COLLATE in the statement (an index on the column cannot be used, see MY-SCHEMA-014)', NULL)) AS patterns
    FROM performance_schema.events_statements_summary_by_digest AS s
   WHERE s.DIGEST IS NOT NULL
     AND s.COUNT_STAR >= COALESCE(@min_executions, 100)
     AND IFNULL(s.SCHEMA_NAME, '') NOT IN ('performance_schema', 'information_schema', 'mysql', 'sys')
   ORDER BY s.SUM_TIMER_WAIT DESC
   LIMIT 200
) AS d
WHERE d.patterns <> ''
ORDER BY d.COUNT_STAR DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_has_digest, 0) = 1 AND IFNULL(@dbt_priv_perf_schema, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
