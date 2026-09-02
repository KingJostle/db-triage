-- check: MY-MEM-012
-- title: innodb_flush_method not O_DIRECT on Linux
-- priority: 150 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: large_pool_bytes=4294967296
-- reads: @dbt_v_innodb_flush_method, @@GLOBAL.version_compile_os,
--        @@GLOBAL.innodb_buffer_pool_size
-- Read from the bundle because the variable does not exist on Windows builds and
-- its accepted values differ by fork: MySQL 8.0.14+ adds O_DIRECT_NO_FSYNC and
-- 8.0.26 makes it the default on Linux; MariaDB keeps O_DIRECT as the practical
-- choice and adds fsync/littlesync/nosync variants.
-- Without O_DIRECT every InnoDB page lives twice: once in the buffer pool and
-- once in the OS page cache. On a host where the pool is already several GB that
-- is a straight waste of RAM, and it makes MY-MEM-003/007 understate real usage.
-- Only judged on Linux, because O_DIRECT is a no-op or unavailable elsewhere.
SELECT
  'MY-MEM-012' AS check_id,
  'setting'    AS scope,
  'innodb_flush_method' AS object,
  CONCAT('innodb_flush_method = ', @dbt_v_innodb_flush_method, ' on ',
         @@GLOBAL.version_compile_os, ' with a ',
         ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 1),
         ' GB buffer pool. Pages are cached both by InnoDB and by the OS page cache, so up to that much RAM again is spent holding a second copy. ',
         'O_DIRECT (or O_DIRECT_NO_FSYNC where the filesystem allows it) removes the duplicate.') AS details,
  JSON_OBJECT(
    'innodb_flush_method', @dbt_v_innodb_flush_method,
    'version_compile_os', @@GLOBAL.version_compile_os,
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'threshold_bytes', COALESCE(@large_pool_bytes, 4294967296)) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE @dbt_v_innodb_flush_method IS NOT NULL
  AND LOWER(@@GLOBAL.version_compile_os) LIKE '%linux%'
  AND UPPER(@dbt_v_innodb_flush_method) NOT IN ('O_DIRECT', 'O_DIRECT_NO_FSYNC')
  AND @@GLOBAL.innodb_buffer_pool_size >= COALESCE(@large_pool_bytes, 4294967296);
