-- check: MY-SCHEMA-002
-- title: InnoDB tables without a primary key
-- priority: 100 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_listed=20
-- reads: information_schema.TABLES, information_schema.STATISTICS (PRIMARY),
--        @@GLOBAL.binlog_format, @@GLOBAL.log_bin, @dbt_binlog_dump_threads
-- The lower-priority sibling of MY-SCHEMA-001: same defect, but binary logging
-- is off or set to STATEMENT, so the row-based-replication disaster (a full
-- table scan per row event on the replica) does not apply today. It applies the
-- moment anyone enables binary logging or attaches a replica, which is why this
-- is still reported rather than ignored.
-- The costs that apply regardless of replication: InnoDB assigns a hidden 6-byte
-- row id that every secondary index carries, rows have no useful clustering
-- order so range scans are random I/O, and several ALGORITHM=INPLACE online-DDL
-- paths are unavailable.
-- Detection is via information_schema.STATISTICS rather than TABLE_CONSTRAINTS
-- because it also reveals whether a usable unique NOT NULL index exists, which
-- is what the replication applier actually looks for.
SELECT
  'MY-SCHEMA-002' AS check_id,
  'relation'      AS scope,
  CONCAT(t.TABLE_SCHEMA, '.', t.TABLE_NAME) AS object,
  CONCAT('InnoDB table `', t.TABLE_SCHEMA, '`.`', t.TABLE_NAME, '` has no PRIMARY KEY',
         IF(IFNULL(k.unique_notnull, 0) > 0,
            CONCAT(' but does have ', k.unique_notnull,
                   ' unique NOT NULL index(es), which the row-based applier can use as a substitute'),
            ' and no unique NOT NULL index the row-based applier could use instead'),
         '. Size ', ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1048576, 1), ' MB, ~',
         FORMAT(IFNULL(t.TABLE_ROWS, 0), 0), ' rows, ', IFNULL(k.idx_count, 0), ' index(es). ',
         'log_bin = ', CAST(@@GLOBAL.log_bin AS CHAR), ', binlog_format = ',
         @@GLOBAL.binlog_format,
         '. Row-based replication is not in use here, so the replica full-scan hazard (MY-SCHEMA-001) does not apply yet — it starts applying the day binary logging is enabled or a replica is attached.') AS details,
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
  AND NOT (@@GLOBAL.log_bin = 1 AND UPPER(@@GLOBAL.binlog_format) IN ('ROW', 'MIXED'))
ORDER BY t.DATA_LENGTH + t.INDEX_LENGTH DESC
LIMIT 20;
