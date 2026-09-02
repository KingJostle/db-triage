-- check: MY-MEM-001
-- title: InnoDB buffer pool at the shipped default
-- priority: 20 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: default_pool_bytes=134217728
-- reads: @@GLOBAL.innodb_buffer_pool_size, @dbt_v_innodb_dedicated_server
-- 128 MB is the shipped default on both forks and it is sized for a laptop.
-- Version divergence: MySQL 8.0 added innodb_dedicated_server, which sizes the
-- pool from detected RAM at startup; when that is ON the 128 MB reading means
-- the host really has under ~1 GB of RAM, so the check is suppressed and the
-- host-sizing question belongs to MY-MEM-002 instead. MariaDB has no such
-- variable (verified absent on 10.11), so the bundle returns NULL there and the
-- suppression never applies.
-- Managed platforms always size the pool from the instance class, so seeing this
-- almost always means an unreviewed self-managed install.
SELECT
  'MY-MEM-001' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_size' AS object,
  CONCAT('innodb_buffer_pool_size = ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1048576, 0),
         ' MB, the shipped default. InnoDB data and indexes total ',
         ROUND(s.bytes / 1073741824, 2), ' GB across ', s.tables,
         ' tables, so ', IF(s.bytes > 0, ROUND(100.0 * @@GLOBAL.innodb_buffer_pool_size / s.bytes, 1), 0),
         '% of the working set can be cached. ',
         'innodb_dedicated_server = ', IFNULL(@dbt_v_innodb_dedicated_server, 'not available on this fork'),
         '. Changing the pool size is dynamic on MySQL 5.7+ and MariaDB 10.2+, but it resizes in innodb_buffer_pool_chunk_size steps and briefly holds a global mutex.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'innodb_data_bytes', s.bytes,
    'table_count', s.tables,
    'innodb_dedicated_server', IFNULL(@dbt_v_innodb_dedicated_server, 'n/a'),
    'ram_bytes', IFNULL(@dbt_ram_bytes, 'unknown')) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT IFNULL(SUM(DATA_LENGTH + INDEX_LENGTH), 0) AS bytes, COUNT(*) AS tables
  FROM information_schema.TABLES
  WHERE ENGINE = 'InnoDB'
    AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
) AS s
WHERE @@GLOBAL.innodb_buffer_pool_size <= COALESCE(@default_pool_bytes, 134217728)
  AND UPPER(IFNULL(@dbt_v_innodb_dedicated_server, 'OFF')) NOT IN ('ON', '1');
