-- check: MY-CAP-004
-- title: Schema sizes
-- priority: 250 | category: CAP | scope: schema | cost: 1 | pass: inventory
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: information_schema.TABLES grouped by schema
-- Always emitted. Environment inventory, so the report doubles as documentation
-- of what this instance actually holds.
-- CACHE CAVEAT, carried in every finding that uses these numbers: on MySQL 8.0
-- the DATA_LENGTH, INDEX_LENGTH, DATA_FREE and TABLE_ROWS columns are served
-- from a cache refreshed at most every information_schema_stats_expiry seconds
-- (default 86400), so they can be a day stale. MariaDB reads them live from the
-- storage engine. db-triage never runs ANALYZE TABLE to refresh them, because
-- that is a write.
-- TABLE_ROWS is an InnoDB ESTIMATE from index dives in all cases, not a count,
-- and can be off by a large factor on a table with wide rows.
SELECT
  'MY-CAP-004' AS check_id,
  'schema'     AS scope,
  x.sch        AS object,
  CONCAT('Schema `', x.sch, '`: ', ROUND(x.total / 1073741824, 2), ' GB total (',
         ROUND(x.data / 1073741824, 2), ' GB data, ', ROUND(x.idx / 1073741824, 2),
         ' GB index, ', ROUND(x.free / 1073741824, 2), ' GB reported free), ',
         x.tables, ' table(s), ~', FORMAT(x.rows_est, 0), ' rows estimated. ',
         'Engines: ', x.engines, '. Collations: ', x.collations, '. ',
         'Sizes are ', IF(@dbt_is_mariadb, 'read live from the storage engine',
            CONCAT('from the information_schema cache, up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20, 0)) / 3600, 0),
                   ' h stale')),
         '; row counts are InnoDB estimates in all cases, not counts.') AS details,
  JSON_OBJECT(
    'schema', x.sch,
    'total_bytes', x.total,
    'data_bytes', x.data,
    'index_bytes', x.idx,
    'data_free_bytes', x.free,
    'table_count', x.tables,
    'estimated_rows', x.rows_est,
    'engines', x.engines,
    'collations', x.collations,
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT TABLE_SCHEMA AS sch,
         IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS total,
         IFNULL(SUM(DATA_LENGTH), 0) AS data,
         IFNULL(SUM(INDEX_LENGTH), 0) AS idx,
         IFNULL(SUM(DATA_FREE), 0)   AS free,
         COUNT(*) AS tables,
         IFNULL(SUM(TABLE_ROWS), 0) AS rows_est,
         SUBSTRING(GROUP_CONCAT(DISTINCT ENGINE SEPARATOR ', '), 1, 120) AS engines,
         SUBSTRING(GROUP_CONCAT(DISTINCT TABLE_COLLATION SEPARATOR ', '), 1, 200) AS collations
  FROM information_schema.TABLES
  WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA
) AS x
ORDER BY x.total DESC;
