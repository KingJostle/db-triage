-- check: MY-IDX-009
-- title: Wide composite indexes
-- priority: 150 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: wide_index_columns=6;idx_table_bytes=104857600
-- reads: information_schema.STATISTICS (SEQ_IN_INDEX, SUB_PART),
--        information_schema.COLUMNS for the declared widths
-- Hygiene, reported with the numbers that decide whether it matters.
-- In InnoDB every secondary index entry also carries the full primary key, so a
-- six-column index on a table with a composite primary key is wider still. Three
-- consequences: fewer entries per 16 KB page so more pages to read, more buffer
-- pool consumed by the index, and more work on every write.
-- The leftmost-prefix rule also means a six-column index can only be used by a
-- query that constrains the first column, so the trailing columns earn their
-- width only if queries actually reach them — which the catalog cannot tell you.
-- Hard limits worth knowing and reported alongside: 16 columns per index and
-- 3072 bytes of key length on both forks (767 bytes with COMPACT/REDUNDANT row
-- format, see MY-SCHEMA-012).
SELECT
  'MY-IDX-009' AS check_id,
  'index'      AS scope,
  CONCAT(x.sch, '.', x.tbl, '.', x.idx) AS object,
  CONCAT('Index `', x.idx, '` on `', x.sch, '`.`', x.tbl, '` spans ', x.ncols,
         ' columns (', x.cols, '; threshold ', COALESCE(@wide_index_columns, 6),
         ', hard limit 16). Declared key width ~', x.declared_bytes,
         ' bytes of the 3072-byte limit. Table ',
         ROUND(x.bytes / 1048576, 0), ' MB. ',
         'InnoDB appends the full primary key to every secondary index entry, so the stored entry is wider than the declared columns: fewer entries per 16 KB page, more pages read per lookup, more buffer pool consumed, more work on every write. ',
         'Because of the leftmost-prefix rule this index is only usable by queries that constrain `',
         x.first_col, '`, and the trailing columns earn their width only if queries reach them — which the catalog cannot show. Check MY-QRY-004 for what actually runs.') AS details,
  JSON_OBJECT(
    'schema', x.sch, 'table', x.tbl, 'index', x.idx,
    'column_count', x.ncols, 'columns', x.cols,
    'declared_key_bytes', x.declared_bytes,
    'first_column', x.first_col,
    'table_bytes', x.bytes,
    'threshold_columns', COALESCE(@wide_index_columns, 6)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT s.TABLE_SCHEMA AS sch, s.TABLE_NAME AS tbl, s.INDEX_NAME AS idx,
         MAX(s.SEQ_IN_INDEX) AS ncols,
         SUBSTRING(GROUP_CONCAT(s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX SEPARATOR ', '), 1, 300) AS cols,
         SUBSTRING_INDEX(GROUP_CONCAT(s.COLUMN_NAME ORDER BY s.SEQ_IN_INDEX SEPARATOR ','), ',', 1) AS first_col,
         IFNULL(SUM(IFNULL(s.SUB_PART, IFNULL(c.CHARACTER_OCTET_LENGTH, 8))), 0) AS declared_bytes,
         MAX(t.DATA_LENGTH + t.INDEX_LENGTH) AS bytes
    FROM information_schema.STATISTICS AS s
    JOIN information_schema.TABLES AS t
      ON t.TABLE_SCHEMA = s.TABLE_SCHEMA AND t.TABLE_NAME = s.TABLE_NAME
    LEFT JOIN information_schema.COLUMNS AS c
      ON c.TABLE_SCHEMA = s.TABLE_SCHEMA AND c.TABLE_NAME = s.TABLE_NAME
     AND c.COLUMN_NAME = s.COLUMN_NAME
   WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
   GROUP BY s.TABLE_SCHEMA, s.TABLE_NAME, s.INDEX_NAME
) AS x
WHERE x.ncols >= COALESCE(@wide_index_columns, 6)
  AND x.bytes >= COALESCE(@idx_table_bytes, 104857600)
ORDER BY x.ncols DESC, x.bytes DESC
LIMIT 20;
