-- check: MY-SCHEMA-006
-- title: AUTO_INCREMENT at or above 70 percent exhausted
-- priority: 50 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: autoinc_critical_ratio=0.90;autoinc_warn_ratio=0.70
-- reads: sys.schema_auto_increment_columns, with an information_schema fallback
-- Verified present with identical columns on MySQL 5.7+/8.x and MariaDB 10.6+
-- (sys.schema_auto_increment_columns: max_value, auto_increment,
-- auto_increment_ratio). The fallback computes the same figures from
-- information_schema.COLUMNS + TABLES for servers with no sys schema.
-- Magnitude tier below MY-SCHEMA-005, with its own ID so suppressing the noisy
-- tier can never hide the urgent one.
-- The failure mode: when the counter
-- reaches the column type's maximum, MySQL does NOT wrap and does NOT raise an
-- overflow error. It hands out the maximum value again, so the insert fails with
-- ER_DUP_ENTRY — a duplicate-key error on a surrogate key, which reads like an
-- application bug and is routinely misdiagnosed for hours.
-- The fix (ALTER to a wider type) rewrites the whole table, so a 90%-full
-- 500 GB table needs a maintenance window planned now, not when it fills.
SET @dbt_q_sys := "
SELECT
  'MY-SCHEMA-006' AS check_id,
  'relation'      AS scope,
  CONCAT(a.table_schema, '.', a.table_name, '.', a.column_name) AS object,
  CONCAT('`', a.table_schema, '`.`', a.table_name, '`.', a.column_name, ' (',
         a.column_type, ') is at ', FORMAT(a.auto_increment, 0), ' of a maximum ',
         FORMAT(a.max_value, 0), ' — ', ROUND(100 * a.auto_increment_ratio, 1),
         '% used (threshold ', ROUND(100 * COALESCE(@autoinc_warn_ratio, 0.70), 0), '%). ',
         'At the maximum, MySQL reissues that same value rather than wrapping or overflowing, so inserts fail with a DUPLICATE KEY error on a surrogate key. ',
         'Table size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB, so widening the column rewrites that much data — plan the window now.') AS details,
  JSON_OBJECT(
    'schema', a.table_schema,
    'table', a.table_name,
    'column', a.column_name,
    'column_type', a.column_type,
    'auto_increment', a.auto_increment,
    'max_value', a.max_value,
    'ratio', ROUND(a.auto_increment_ratio, 4),
    'threshold_ratio', COALESCE(@autoinc_warn_ratio, 0.70),
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH) AS evidence_json,
  'high' AS confidence
FROM sys.schema_auto_increment_columns AS a
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = a.table_schema AND t.TABLE_NAME = a.table_name
WHERE a.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND a.auto_increment_ratio >= COALESCE(@autoinc_warn_ratio, 0.70)
  AND a.auto_increment_ratio <  COALESCE(@autoinc_critical_ratio, 0.90)
ORDER BY a.auto_increment_ratio DESC
LIMIT 20";

SET @dbt_q_fb := "
SELECT
  'MY-SCHEMA-006' AS check_id,
  'relation'      AS scope,
  CONCAT(x.TABLE_SCHEMA, '.', x.TABLE_NAME, '.', x.COLUMN_NAME) AS object,
  CONCAT('`', x.TABLE_SCHEMA, '`.`', x.TABLE_NAME, '`.', x.COLUMN_NAME, ' (',
         x.COLUMN_TYPE, ') is at ', FORMAT(x.auto_increment, 0), ' of a maximum ',
         FORMAT(x.max_value, 0), ' — ', ROUND(100 * x.auto_increment / x.max_value, 1),
         '% used (threshold ', ROUND(100 * COALESCE(@autoinc_warn_ratio, 0.70), 0),
         '%). Computed from information_schema because this server has no sys schema. ',
         'At the maximum, inserts fail with a DUPLICATE KEY error rather than an overflow.') AS details,
  JSON_OBJECT(
    'schema', x.TABLE_SCHEMA, 'table', x.TABLE_NAME, 'column', x.COLUMN_NAME,
    'column_type', x.COLUMN_TYPE, 'auto_increment', x.auto_increment,
    'max_value', x.max_value, 'ratio', ROUND(x.auto_increment / x.max_value, 4),
    'threshold_ratio', COALESCE(@autoinc_warn_ratio, 0.70),
    'source', 'information_schema fallback') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE,
         IFNULL(t.AUTO_INCREMENT, 0) AS auto_increment,
         CASE
           WHEN c.DATA_TYPE = 'tinyint'   THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 255, 127)
           WHEN c.DATA_TYPE = 'smallint'  THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 65535, 32767)
           WHEN c.DATA_TYPE = 'mediumint' THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 16777215, 8388607)
           WHEN c.DATA_TYPE = 'int'       THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 4294967295, 2147483647)
           WHEN c.DATA_TYPE = 'bigint'    THEN IF(c.COLUMN_TYPE LIKE '%unsigned%', 18446744073709551615, 9223372036854775807)
           ELSE NULL
         END AS max_value
  FROM information_schema.COLUMNS AS c
  JOIN information_schema.TABLES AS t
    ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
  WHERE c.EXTRA LIKE '%auto_increment%'
    AND c.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS x
WHERE x.max_value IS NOT NULL
  AND x.auto_increment >= x.max_value * COALESCE(@autoinc_warn_ratio, 0.70)
  AND x.auto_increment <  x.max_value * COALESCE(@autoinc_critical_ratio, 0.90)
ORDER BY x.auto_increment / x.max_value DESC
LIMIT 20";

SET @dbt_q := IF(IFNULL(@dbt_sys_autoinc, 0) = 1, @dbt_q_sys, @dbt_q_fb);
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
