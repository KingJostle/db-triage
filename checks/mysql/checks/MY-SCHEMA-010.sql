-- check: MY-SCHEMA-010
-- title: Table with more than 1,000 partitions
-- priority: 150 | category: SCHEMA | scope: relation | cost: 1 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: max_partitions=1000
-- reads: information_schema.PARTITIONS
-- The opposite failure to MY-SCHEMA-009. Every partition is a separate InnoDB
-- table internally: its own file descriptor, its own entry in the table cache
-- (MY-MEM-008), and its own row in the data dictionary. A query that cannot
-- prune partitions opens all of them, and even one that can prune pays the
-- planning cost of considering them.
-- The hard limit is 8,192 partitions per table on both forks, so a table at
-- 1,000 is not near the ceiling but is well past the point where the table cache
-- and open-file limit start to matter, especially with several such tables.
SELECT
  'MY-SCHEMA-010' AS check_id,
  'relation'      AS scope,
  CONCAT(p.TABLE_SCHEMA, '.', p.TABLE_NAME) AS object,
  CONCAT('`', p.TABLE_SCHEMA, '`.`', p.TABLE_NAME, '` has ', p.n,
         ' partitions (threshold ', COALESCE(@max_partitions, 1000),
         ', hard limit 8192), totalling ', ROUND(p.bytes / 1073741824, 1),
         ' GB with a ', p.method, ' partition scheme. ',
         'Each partition is a separate InnoDB table internally, consuming a file descriptor and a table-cache entry: table_open_cache = ',
         @@GLOBAL.table_open_cache, ', open_files_limit = ', @@GLOBAL.open_files_limit,
         '. A query that cannot prune opens all of them. See MY-MEM-008 for whether the cache is already overflowing.') AS details,
  JSON_OBJECT(
    'schema', p.TABLE_SCHEMA,
    'table', p.TABLE_NAME,
    'partition_count', p.n,
    'partition_method', p.method,
    'bytes', p.bytes,
    'threshold', COALESCE(@max_partitions, 1000),
    'table_open_cache', @@GLOBAL.table_open_cache,
    'open_files_limit', @@GLOBAL.open_files_limit) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT TABLE_SCHEMA, TABLE_NAME, COUNT(*) AS n,
         MAX(PARTITION_METHOD) AS method,
         IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes
  FROM information_schema.PARTITIONS
  WHERE PARTITION_NAME IS NOT NULL
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  GROUP BY TABLE_SCHEMA, TABLE_NAME
) AS p
WHERE p.n >= COALESCE(@max_partitions, 1000);
