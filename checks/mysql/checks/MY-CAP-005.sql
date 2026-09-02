-- check: MY-CAP-005
-- title: Largest 20 tables
-- priority: 250 | category: CAP | scope: relation | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: top_n=20
-- reads: information_schema.TABLES
-- Always emitted. Same cache and estimate caveats as MY-CAP-004, restated
-- because these rows are read on their own.
-- Index-to-data ratio is included because it is the cheapest signal of an
-- over-indexed table: above roughly 1.0 the indexes cost more space than the
-- rows do, which is worth reading next to MY-IDX-001/003/005.
SELECT
  'MY-CAP-005' AS check_id,
  'relation'   AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('`', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '`: ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2), ' GB (',
         ROUND(t.DATA_LENGTH / 1073741824, 2), ' GB data + ',
         ROUND(t.INDEX_LENGTH / 1073741824, 2), ' GB index, ratio ',
         ROUND(t.INDEX_LENGTH / GREATEST(t.DATA_LENGTH, 1), 2),
         '), ~', FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows estimated, ',
         'engine ', t.ENGINE, ', row format ', IFNULL(t.ROW_FORMAT, 'unknown'),
         ', collation ', IFNULL(t.TABLE_COLLATION, 'n/a'),
         ', DATA_FREE ', ROUND(t.DATA_FREE / 1073741824, 2), ' GB, created ',
         IFNULL(CAST(t.CREATE_TIME AS CHAR), 'unknown'), '. ',
         IF(t.INDEX_LENGTH > t.DATA_LENGTH,
            'Indexes occupy more space than the rows do — read with MY-IDX-001, MY-IDX-003 and MY-IDX-005. ', ''),
         'Sizes are ', IF(@dbt_is_mariadb, 'live', 'cached (up to information_schema_stats_expiry old)'),
         '; row counts are estimates.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA, 'table', t.TABLE_NAME,
    'total_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'data_bytes', t.DATA_LENGTH,
    'index_bytes', t.INDEX_LENGTH,
    'index_to_data_ratio', ROUND(t.INDEX_LENGTH / GREATEST(t.DATA_LENGTH, 1), 3),
    'data_free_bytes', t.DATA_FREE,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'engine', t.ENGINE,
    'row_format', IFNULL(t.ROW_FORMAT, ''),
    'collation', IFNULL(t.TABLE_COLLATION, ''),
    'created', CAST(t.CREATE_TIME AS CHAR),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'medium' AS confidence
FROM information_schema.TABLES AS t
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'sys')
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
