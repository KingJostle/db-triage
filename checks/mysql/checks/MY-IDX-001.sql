-- check: MY-IDX-001
-- title: Unused index of 1 GB or more
-- priority: 50 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*, SELECT ON mysql.*
-- thresholds: unused_index_bytes=1073741824;min_uptime_days=30
-- reads: sys.schema_unused_indexes, or performance_schema.table_io_waits_summary_by_index_usage
--        directly; mysql.innodb_index_stats (stat_name='size') x @@innodb_page_size for size
-- Availability, verified: sys.schema_unused_indexes exists on MySQL 5.7+ and
-- MariaDB 10.6+ with the same three columns (object_schema, object_name,
-- index_name). Where sys is absent the check reads
-- performance_schema.table_io_waits_summary_by_index_usage itself, which is what
-- the view is built on, so the result is identical.
-- Index SIZE is the harder half: information_schema has no per-index size at
-- all. mysql.innodb_index_stats carries a 'size' row per index measured in
-- PAGES, so bytes = size x innodb_page_size. That table is written by InnoDB's
-- persistent statistics and exists on both forks.
-- THE CAVEAT THAT MUST TRAVEL WITH THIS FINDING: index usage is counted PER
-- INSTANCE and only since the last restart. An index unused on this server may
-- be the one the reporting replica depends on. Never drop on this evidence
-- alone — check every replica, and check that uptime covers a full business
-- cycle including month-end. That is why min_uptime_days defaults to 30.
SET @dbt_q_sys := "
SELECT
  'MY-IDX-001' AS check_id,
  'index'      AS scope,
  CONCAT(u.object_schema, '.', u.object_name, '.', u.index_name) AS object,
  CONCAT('Index `', u.index_name, '` on `', u.object_schema, '`.`', u.object_name,
         '` has been read ZERO times since this server started ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago, and occupies ',
         ROUND(sz.bytes / 1073741824, 2), ' GB (', FORMAT(sz.pages, 0), ' pages x ',
         @@GLOBAL.innodb_page_size, ' bytes; threshold ',
         ROUND(COALESCE(@unused_index_bytes, 1073741824) / 1073741824, 1), ' GB). ',
         'It is still maintained on every INSERT, UPDATE and DELETE to the table. ',
         'VERIFY BEFORE DROPPING: this counter is per instance and resets on restart, so an index unused here may be the one a reporting replica relies on, and ',
         ROUND(@dbt_uptime_s / 86400, 1),
         ' days may not include month-end or quarter-end reporting.') AS details,
  JSON_OBJECT(
    'schema', u.object_schema, 'table', u.object_name, 'index', u.index_name,
    'index_bytes', sz.bytes, 'index_pages', sz.pages,
    'innodb_page_size', @@GLOBAL.innodb_page_size,
    'threshold_bytes', COALESCE(@unused_index_bytes, 1073741824),
    'uptime_days', ROUND(@dbt_uptime_s / 86400, 2),
    'scope_note', 'usage counted on this instance only, since last restart') AS evidence_json,
  IF(@dbt_uptime_s >= COALESCE(@min_uptime_days, 30) * 86400, 'medium', 'low') AS confidence
FROM sys.schema_unused_indexes AS u
JOIN (
  SELECT database_name, table_name, index_name,
         stat_value AS pages, stat_value * @@GLOBAL.innodb_page_size AS bytes
    FROM mysql.innodb_index_stats
   WHERE stat_name = 'size'
) AS sz
  ON sz.database_name = u.object_schema
 AND sz.table_name    = u.object_name
 AND sz.index_name    = u.index_name
WHERE u.object_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND u.index_name <> 'PRIMARY'
  AND sz.bytes >= COALESCE(@unused_index_bytes, 1073741824)
ORDER BY sz.bytes DESC
LIMIT 20";

SET @dbt_q_ps := REPLACE(@dbt_q_sys, 'sys.schema_unused_indexes AS u', "(
  SELECT OBJECT_SCHEMA AS object_schema, OBJECT_NAME AS object_name, INDEX_NAME AS index_name
    FROM performance_schema.table_io_waits_summary_by_index_usage
   WHERE INDEX_NAME IS NOT NULL
     AND INDEX_NAME <> 'PRIMARY'
     AND COUNT_STAR = 0
     AND OBJECT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS u");

SET @dbt_q := CASE
  WHEN IFNULL(@dbt_has_innodb_index_stats, 0) = 0 OR IFNULL(@dbt_priv_mysql_schema, 0) = 0 THEN 'DO 1'
  WHEN IFNULL(@dbt_sys_unused_idx, 0) = 1  THEN @dbt_q_sys
  WHEN IFNULL(@dbt_has_index_usage, 0) = 1 THEN @dbt_q_ps
  ELSE 'DO 1'
END;
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
