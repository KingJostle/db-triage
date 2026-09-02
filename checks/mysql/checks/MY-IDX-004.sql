-- check: MY-IDX-004
-- title: Large table with heavy full table scans
-- priority: 50 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: scan_table_bytes=1073741824;rows_full_scanned=10000000
-- reads: sys.schema_tables_with_full_table_scans (object_schema, object_name,
--        rows_full_scanned), information_schema.TABLES for size
-- Availability, verified: the view exists on MySQL 5.7+ and MariaDB 10.6+ with
-- the same columns. It is derived from
-- performance_schema.table_io_waits_summary_by_index_usage where INDEX_NAME IS
-- NULL — that is, reads that used no index at all.
-- Confidence is medium and the wording is careful, because a full scan is not
-- automatically wrong: on a small table it is the cheapest plan, and an
-- analytical query over a large table may legitimately scan it. What the numbers
-- here establish is volume — ten million rows read without an index on a table
-- over a gigabyte is a workload characteristic, not a one-off report.
-- The finding deliberately does NOT propose an index: db-triage points at the
-- table and at the statements (MY-QRY-006/008) and stops there, because
-- inventing an index definition from a scan count is how bad indexes get made.
SET @dbt_q := "
SELECT
  'MY-IDX-004' AS check_id,
  'relation'   AS scope,
  CONCAT(f.object_schema, '.', f.object_name) AS object,
  CONCAT('`', f.object_schema, '`.`', f.object_name, '` is ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2), ' GB and has had ',
         FORMAT(f.rows_full_scanned, 0),
         ' rows read WITHOUT USING AN INDEX since this server started ',
         ROUND(@dbt_uptime_s / 86400, 1), ' days ago (thresholds: ',
         ROUND(COALESCE(@scan_table_bytes, 1073741824) / 1073741824, 1), ' GB and ',
         FORMAT(COALESCE(@rows_full_scanned, 10000000), 0), ' rows). ',
         'The table has ', ix.n, ' index(es) defined. ',
         'A full scan is not automatically wrong — it is the cheapest plan on a small table and legitimate for analytics — but this volume on a table this size is a workload characteristic, not a one-off report. ',
         'MY-QRY-006 and MY-QRY-008 name the statements responsible. db-triage does not propose an index definition; the statements have to be read first.') AS details,
  JSON_OBJECT(
    'schema', f.object_schema, 'table', f.object_name,
    'rows_full_scanned', f.rows_full_scanned,
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'index_count', ix.n,
    'threshold_bytes', COALESCE(@scan_table_bytes, 1073741824),
    'threshold_rows', COALESCE(@rows_full_scanned, 10000000),
    'window_seconds', @dbt_uptime_s,
    'scope_note', 'counted on this instance only, since last restart') AS evidence_json,
  'medium' AS confidence
FROM sys.schema_tables_with_full_table_scans AS f
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = f.object_schema AND t.TABLE_NAME = f.object_name
LEFT JOIN (
  SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(DISTINCT INDEX_NAME) AS n
    FROM information_schema.STATISTICS GROUP BY TABLE_SCHEMA, TABLE_NAME
) AS ix ON ix.TABLE_SCHEMA = f.object_schema AND ix.TABLE_NAME = f.object_name
WHERE f.object_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@scan_table_bytes, 1073741824)
  AND f.rows_full_scanned >= COALESCE(@rows_full_scanned, 10000000)
ORDER BY f.rows_full_scanned DESC
LIMIT 20";
SET @dbt_q := IF(IFNULL(@dbt_sys_full_scans, 0) = 1, @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
