-- check: MY-SCHEMA-001
-- title: InnoDB tables without a primary key on a replicated source
-- priority: 20 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_listed=20
-- reads: information_schema.TABLES, information_schema.STATISTICS (PRIMARY),
--        @@GLOBAL.binlog_format, @@GLOBAL.log_bin, @dbt_binlog_dump_threads
-- THE genuinely MySQL-specific hazard, and the reason it outranks its
-- no-replication sibling MY-SCHEMA-002 by 80 priority points:
-- under row-based replication a replica applying an UPDATE or DELETE looks the
-- row up by primary key. With no primary key and no unique NOT NULL index there
-- is nothing to look it up by, so the applier falls back to a FULL TABLE SCAN
-- PER ROW EVENT. A single 100,000-row DELETE on a million-row table becomes
-- 100,000 full scans, and the replica goes from seconds behind to hours behind
-- while the source shows nothing wrong at all.
-- Secondary costs, mentioned because they justify the fix on their own: InnoDB
-- adds a hidden 6-byte row id that all secondary indexes carry, rows have no
-- useful clustering order, and several online-DDL paths are unavailable.
-- Detection is via information_schema.STATISTICS rather than TABLE_CONSTRAINTS
-- because it also reveals whether a usable unique NOT NULL index exists, which
-- is what the replication applier actually looks for.
SELECT
  'MY-SCHEMA-001' AS check_id,
  'relation'      AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('InnoDB table `', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` has no PRIMARY KEY',
         IF(IFNULL(k.unique_notnull, 0) > 0,
            CONCAT(' but does have ', k.unique_notnull,
                   ' unique NOT NULL index(es), which the row-based applier can use as a substitute'),
            ' and no unique NOT NULL index the row-based applier could use instead'),
         '. Size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1048576, 1), ' MB, ~',
         FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows, ', IFNULL(k.idx_count, 0), ' index(es). ',
         'binlog_format = ', @@GLOBAL.binlog_format, ', connected replicas: ',
         IFNULL(@dbt_binlog_dump_threads, 0),
         IF(IFNULL(k.unique_notnull, 0) > 0,
            '. Row lookups on the replica will use that unique index.',
            '. Every UPDATE and DELETE row event replayed on a replica scans this whole table once per row.')) AS details,
  JSON_OBJECT(
    'schema', t.TABLE_SCHEMA,
    'table', t.TABLE_NAME,
    'bytes', t.DATA_LENGTH + t.INDEX_LENGTH,
    'estimated_rows', IFNULL(t.TABLE_ROWS, 0),
    'index_count', IFNULL(k.idx_count, 0),
    'unique_notnull_indexes', IFNULL(k.unique_notnull, 0),
    'binlog_format', @@GLOBAL.binlog_format,
    'connected_replicas', IFNULL(@dbt_binlog_dump_threads, 0),
    'sizes_cached', IF(@dbt_is_mariadb, 0, 1)) AS evidence_json,
  'high' AS confidence
FROM information_schema.TABLES AS t
-- LEFT JOIN, not JOIN: a table with no indexes at all has NO rows in
-- information_schema.STATISTICS, and an inner join would silently drop exactly
-- the worst case — a table with neither a primary key nor any index.
LEFT JOIN (
  SELECT s.TABLE_SCHEMA, s.TABLE_NAME,
         COUNT(DISTINCT s.INDEX_NAME) AS idx_count,
         COUNT(DISTINCT IF(s.NON_UNIQUE = 0 AND s.NULLABLE = '', s.INDEX_NAME, NULL)) AS unique_notnull,
         MAX(s.INDEX_NAME = 'PRIMARY') AS has_pk
  FROM information_schema.STATISTICS AS s
  WHERE s.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY s.TABLE_SCHEMA, s.TABLE_NAME
) AS k ON k.TABLE_SCHEMA = t.TABLE_SCHEMA AND k.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.ENGINE = 'InnoDB'
  AND t.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND IFNULL(k.has_pk, 0) = 0
  AND @@GLOBAL.log_bin = 1
  AND UPPER(@@GLOBAL.binlog_format) IN ('ROW', 'MIXED')
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
