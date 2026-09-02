-- check: MY-SCHEMA-009
-- title: Very large table not partitioned
-- priority: 150 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: large_table_bytes=214748364800
-- reads: information_schema.TABLES, information_schema.PARTITIONS
-- Advisory, and deliberately at P150: partitioning is not a performance feature
-- and applying it to the wrong table makes things worse. What it does buy is
-- O(1) deletion of old data — DROP PARTITION instead of a DELETE that generates
-- undo, bloats the history list (MY-UNDO-001) and never returns the space.
-- On a 200 GB table with a retention policy that is a large difference; on a
-- 200 GB table that is all live data it is not, which is why the finding asks
-- rather than tells, and why it reports whether the table has an obvious
-- time-based partition key candidate.
-- Caveat carried in the text: on MySQL 8.0 these sizes come from the
-- information_schema cache and may be up to information_schema_stats_expiry old.
SELECT
  'MY-SCHEMA-009' AS check_id,
  'relation'      AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('`', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` is ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 1), ' GB (~',
         FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows) in a single partition (threshold ',
         ROUND(COALESCE(@large_table_bytes, 214748364800) / 1073741824, 0), ' GB). ',
         'Date/time columns that could serve as a partition key: ',
         IFNULL(c.date_cols, 'none — partitioning by range would need a synthetic column'),
         '. Partitioning is not a performance feature; what it buys is DROP PARTITION instead of a bulk DELETE, which on a table this size is the difference between an instant metadata operation and hours of undo generation that never returns the space. ',
         'Only worth doing if this table has a retention policy.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA,
    'table', t.TABLE_NAME,
    'bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'partition_count', 1,
    'candidate_partition_columns', IFNULL(c.date_cols, ''),
    'threshold_bytes', COALESCE(@large_table_bytes, 214748364800),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'medium' AS confidence
FROM information_schema.TABLES AS t
LEFT JOIN (
  SELECT TABLE_SCHEMA, TABLE_NAME,
         SUBSTRING(GROUP_CONCAT(COLUMN_NAME SEPARATOR ', '), 1, 150) AS date_cols
  FROM information_schema.COLUMNS
  WHERE DATA_TYPE IN ('date', 'datetime', 'timestamp')
  GROUP BY TABLE_SCHEMA, TABLE_NAME
) AS c ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@large_table_bytes, 214748364800)
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.PARTITIONS AS p
    WHERE p.TABLE_SCHEMA = t.TABLE_SCHEMA AND p.TABLE_NAME = t.TABLE_NAME
      AND p.PARTITION_NAME IS NOT NULL)
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
