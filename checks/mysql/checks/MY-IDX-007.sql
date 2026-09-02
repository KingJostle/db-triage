-- check: MY-IDX-007
-- title: Single-column index on a very low-cardinality column
-- priority: 150 | category: IDX | scope: index | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: low_cardinality=3;idx_table_bytes=104857600
-- reads: information_schema.STATISTICS (CARDINALITY), information_schema.TABLES
-- CARDINALITY is an ESTIMATE produced by InnoDB's index dives
-- (innodb_stats_persistent_sample_pages, default 20), not a count, and it is
-- stale until statistics are recalculated — which is why this is P150 with
-- medium confidence rather than a firm recommendation, and why MY-IDX-008 checks
-- whether those statistics are stale at all.
-- The mechanism: an index on a column with three distinct values over a million
-- rows selects a third of the table per lookup. The optimizer costs that as
-- worse than a table scan — because with InnoDB's clustered layout every
-- secondary-index hit is a second lookup into the primary key — so the index is
-- never chosen, yet it is still maintained on every write.
-- Two legitimate exceptions the finding names rather than assumes away: a
-- skewed distribution where the rare value is the one queried, and use as the
-- leading column of a composite index (excluded here by construction).
SELECT
  'MY-IDX-007' AS check_id,
  'index'      AS scope,
  CONCAT(s.TABLE_SCHEMA, '.', s.TABLE_NAME, '.', s.INDEX_NAME) AS object,
  CONCAT('Index `', s.INDEX_NAME, '` on `', s.TABLE_SCHEMA, '`.`', s.TABLE_NAME,
         '`.', s.COLUMN_NAME, ' is a single-column index with an estimated cardinality of ',
         s.CARDINALITY, ' distinct value(s) over ~', FORMAT(IFNULL(t.TABLE_ROWS, 0), 0),
         ' rows (threshold ', COALESCE(@low_cardinality, 3), '; table ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1048576, 0), ' MB). ',
         'A lookup selects roughly ', ROUND(100.0 / GREATEST(s.CARDINALITY, 1), 0),
         '% of the table, and because InnoDB stores secondary indexes as pointers into the clustered primary key, each hit costs a second lookup — so the optimizer will usually prefer a table scan and never use this index, while every write still maintains it. ',
         'CARDINALITY is an InnoDB estimate from index dives, not a count (see MY-IDX-008 for whether it is stale). ',
         'It may still be correct to keep this if the distribution is skewed and the rare value is the one queried.') AS details,
  JSON_OBJECT(
    'schema', s.TABLE_SCHEMA, 'table', s.TABLE_NAME,
    'index', s.INDEX_NAME, 'column', s.COLUMN_NAME,
    'cardinality_estimate', s.CARDINALITY,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'table_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'threshold_cardinality', COALESCE(@low_cardinality, 3),
    'estimate_basis', 'InnoDB index dive sample') AS evidence_json,
  'medium' AS confidence
FROM information_schema.STATISTICS AS s
JOIN information_schema.TABLES AS t
  ON t.TABLE_SCHEMA = s.TABLE_SCHEMA AND t.TABLE_NAME = s.TABLE_NAME
WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND s.INDEX_NAME <> 'PRIMARY'
  AND s.NON_UNIQUE = 1
  AND s.SEQ_IN_INDEX = 1
  AND s.CARDINALITY IS NOT NULL
  AND s.CARDINALITY <= COALESCE(@low_cardinality, 3)
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@idx_table_bytes, 104857600)
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS AS s2
     WHERE s2.TABLE_SCHEMA = s.TABLE_SCHEMA AND s2.TABLE_NAME = s.TABLE_NAME
       AND s2.INDEX_NAME = s.INDEX_NAME AND s2.SEQ_IN_INDEX > 1)
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
