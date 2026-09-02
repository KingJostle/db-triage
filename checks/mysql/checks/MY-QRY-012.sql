-- check: MY-QRY-012
-- title: Join and scan counters high
-- priority: 100 | category: QRY | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: full_join_ratio=0.01;scan_ratio=0.20;min_questions=100000
-- reads: @dbt_s_select_full_join, @dbt_s_select_scan, @dbt_s_select_range_check,
--        @dbt_s_questions
-- Server-wide counters, available identically on both forks and — unlike the
-- digest table — not dependent on performance_schema. That makes this the
-- fallback signal when MY-QRY-001 has fired.
-- Select_full_join counts joins performed with NO index on the joined table.
-- These are the expensive ones: MySQL's block nested loop reads the whole inner
-- table for each batch of outer rows, so cost grows with the product of the
-- table sizes. Even 1% of statements doing this is usually one query in a hot
-- path. MySQL 8.0.20+ replaced BNL with hash join for many of these, which makes
-- them faster but no less a sign of a missing index.
-- Select_scan counts full scans of the FIRST table in a join, which is far more
-- often legitimate — a small lookup table, a deliberate report — hence the much
-- higher 20% threshold and the softer wording.
SELECT
  'MY-QRY-012' AS check_id,
  'cluster'    AS scope,
  IF(q.full_join_ratio >= COALESCE(@full_join_ratio, 0.01), 'Select_full_join', 'Select_scan') AS object,
  CONCAT('Over ', FORMAT(q.questions, 0), ' statements since restart ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago: ',
         CONCAT_WS('; ',
           IF(q.full_join_ratio >= COALESCE(@full_join_ratio, 0.01),
              CONCAT('Select_full_join = ', FORMAT(q.full_join, 0), ' (',
                     ROUND(100 * q.full_join_ratio, 2),
                     '%) — joins performed with no index on the joined table, where cost grows with the product of the table sizes'), NULL),
           IF(q.scan_ratio >= COALESCE(@scan_ratio, 0.20),
              CONCAT('Select_scan = ', FORMAT(q.scan_n, 0), ' (',
                     ROUND(100 * q.scan_ratio, 1),
                     '%) — full scans of the first table in a join, which is often legitimate for small lookup tables and reports'), NULL),
           IF(q.range_check > 0,
              CONCAT('Select_range_check = ', FORMAT(q.range_check, 0),
                     ' — the optimizer had to re-decide the index for each outer row, which means no usable key on the join column'), NULL)),
         '. These counters do not need performance_schema, so they are the fallback when MY-QRY-001 has fired; MY-QRY-006 and MY-QRY-008 name the statements when it has not.') AS details,
  JSON_OBJECT(
    'questions', q.questions,
    'select_full_join', q.full_join,
    'select_scan', q.scan_n,
    'select_range_check', q.range_check,
    'full_join_ratio', ROUND(q.full_join_ratio, 5),
    'scan_ratio', ROUND(q.scan_ratio, 5),
    'threshold_full_join_ratio', COALESCE(@full_join_ratio, 0.01),
    'threshold_scan_ratio', COALESCE(@scan_ratio, 0.20),
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT
    GREATEST(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)), 1) AS questions,
    CAST(IFNULL(@dbt_s_select_full_join, 0) AS DECIMAL(30, 0))       AS full_join,
    CAST(IFNULL(@dbt_s_select_scan, 0) AS DECIMAL(30, 0))            AS scan_n,
    CAST(IFNULL(@dbt_s_select_range_check, 0) AS DECIMAL(30, 0))     AS range_check,
    CAST(IFNULL(@dbt_s_select_full_join, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)), 1) AS full_join_ratio,
    CAST(IFNULL(@dbt_s_select_scan, 0) AS DECIMAL(30, 0))
      / GREATEST(CAST(IFNULL(@dbt_s_questions, 0) AS DECIMAL(30, 0)), 1) AS scan_ratio
) AS q
WHERE q.questions >= COALESCE(@min_questions, 100000)
  AND (q.full_join_ratio >= COALESCE(@full_join_ratio, 0.01)
       OR q.scan_ratio >= COALESCE(@scan_ratio, 0.20));
