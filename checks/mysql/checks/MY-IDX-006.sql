-- check: MY-IDX-006
-- title: Table fragmentation (DATA_FREE) high
-- priority: 100 | category: IDX | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: fragmented_table_bytes=1073741824;data_free_ratio=0.30
-- reads: information_schema.TABLES (DATA_FREE, DATA_LENGTH, INDEX_LENGTH),
--        @@GLOBAL.innodb_file_per_table
-- CONFIDENCE IS LOW AND THAT IS NOT A HEDGE. DATA_FREE is coarse: it counts
-- fully free EXTENTS (1 MB units), not free space inside partly used pages, so
-- it understates real fragmentation on a table with many half-empty pages and
-- overstates it right after a bulk delete that has not been purged.
-- It is also meaningless unless innodb_file_per_table is ON: for a table inside
-- the shared tablespace, DATA_FREE reports the free space of the ENTIRE ibdata1
-- file, repeated identically for every such table. The check therefore requires
-- per-table tablespaces and says so (MY-SCHEMA-013 covers the other case).
-- On MySQL 8.0 the value additionally comes from the information_schema cache
-- and can be a day old.
-- The remedy — OPTIMIZE TABLE, or ALTER TABLE ... ENGINE=InnoDB — rebuilds the
-- table. db-triage never runs it, and on a live server it should be done through
-- pt-online-schema-change or gh-ost rather than in place.
SELECT
  'MY-IDX-006' AS check_id,
  'relation'   AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('`', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` reports DATA_FREE = ',
         ROUND(t.DATA_FREE / 1073741824, 2), ' GB against ',
         ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1073741824, 2),
         ' GB of data and indexes (', ROUND(100.0 * t.DATA_FREE / (t.DATA_LENGTH + t.INDEX_LENGTH), 0),
         '%, threshold ', ROUND(100 * COALESCE(@data_free_ratio, 0.30), 0), '%). ',
         'ESTIMATE ONLY: DATA_FREE counts whole free extents of 1 MB, not free space inside partly filled pages, so it understates fragmentation after many small deletes and overstates it right after a bulk delete that purge has not yet processed',
         IF(@dbt_is_mariadb, '. ',
            CONCAT('; on MySQL 8.0 it is also served from the information_schema cache and may be up to ',
                   ROUND(CAST(IFNULL(@dbt_v_information_schema_stats_expiry, 86400) AS DECIMAL(20, 0)) / 3600, 0),
                   ' h old. ')),
         'Reclaiming it means rebuilding the table (OPTIMIZE TABLE or ALTER TABLE ... ENGINE=InnoDB), which db-triage never runs and which should go through pt-online-schema-change or gh-ost on a live server.') AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA, 'table', t.TABLE_NAME,
    'data_free_bytes', t.DATA_FREE,
    'data_index_bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'ratio', ROUND(t.DATA_FREE / (t.DATA_LENGTH + t.INDEX_LENGTH), 4),
    'threshold_ratio', COALESCE(@data_free_ratio, 0.30),
    'innodb_file_per_table', CAST(@@GLOBAL.innodb_file_per_table AS CHAR),
    'estimate_basis', 'DATA_FREE whole free extents only') AS evidence_json,
  'low' AS confidence
FROM information_schema.TABLES AS t
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.ENGINE = 'InnoDB'
  AND @@GLOBAL.innodb_file_per_table = 1
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.DATA_LENGTH + t.INDEX_LENGTH >= COALESCE(@fragmented_table_bytes, 1073741824)
  AND t.DATA_FREE >= (t.DATA_LENGTH + t.INDEX_LENGTH) * COALESCE(@data_free_ratio, 0.30)
ORDER BY t.DATA_FREE DESC
LIMIT 20;
