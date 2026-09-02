-- check: MY-MEM-005
-- title: Implicit temporary tables spilling to disk
-- priority: 100 | category: MEM | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: disk_tmp_ratio=0.25;disk_tmp_per_hour=1000
-- reads: @dbt_s_created_tmp_tables, @dbt_s_created_tmp_disk_tables,
--        @@GLOBAL.tmp_table_size, @@GLOBAL.max_heap_table_size, @dbt_v_temptable_max_ram
-- MySQL-specific hazard with no PostgreSQL analogue: Postgres spills per operator
-- against work_mem, MySQL materialises whole intermediate results as tables and
-- moves them to disk wholesale when they exceed the limit.
-- Version divergence: MySQL 8.0 replaced the MEMORY engine for internal temp
-- tables with TempTable, governed by temptable_max_ram (default 1 GB) rather
-- than tmp_table_size, and spills to mmapped files or InnoDB; MariaDB still uses
-- max_heap_table_size / tmp_table_size and aria/innodb on disk. Both limits are
-- reported so the right lever is obvious.
-- The usual real cause is a TEXT/BLOB column in a GROUP BY or ORDER BY, which
-- forces on-disk regardless of size on MySQL 5.7 and MariaDB.
SELECT
  'MY-MEM-005' AS check_id,
  'cluster'    AS scope,
  'internal-temp-tables' AS object,
  CONCAT(FORMAT(t.disk, 0), ' of ', FORMAT(t.total, 0),
         ' internal temporary tables (', ROUND(100.0 * t.disk / t.total, 1),
         '%, threshold ', ROUND(100 * COALESCE(@disk_tmp_ratio, 0.25), 0),
         '%) were written to disk since restart, ', ROUND(t.disk_per_hour, 0),
         '/h over ', ROUND(@dbt_uptime_s / 3600, 1), ' h. ',
         'tmp_table_size = ', ROUND(@@GLOBAL.tmp_table_size / 1048576, 1),
         ' MB, max_heap_table_size = ', ROUND(@@GLOBAL.max_heap_table_size / 1048576, 1), ' MB',
         IF(@dbt_v_temptable_max_ram IS NOT NULL,
            CONCAT(', temptable_max_ram = ', ROUND(@dbt_v_temptable_max_ram / 1048576, 0),
                   ' MB (MySQL 8.0 uses TempTable, so this is the limit that matters)'),
            ' (this fork uses the MEMORY engine for internal temp tables)'),
         '. Raising the limits is per-session memory; a TEXT/BLOB column in GROUP BY or ORDER BY forces disk regardless of size, so check MY-QRY-007 for the statements responsible.') AS details,
  JSON_OBJECT(
    'created_tmp_tables', t.total,
    'created_tmp_disk_tables', t.disk,
    'disk_ratio', ROUND(t.disk / t.total, 4),
    'disk_per_hour', ROUND(t.disk_per_hour, 1),
    'threshold_ratio', COALESCE(@disk_tmp_ratio, 0.25),
    'tmp_table_size', @@GLOBAL.tmp_table_size,
    'max_heap_table_size', @@GLOBAL.max_heap_table_size,
    'temptable_max_ram', IFNULL(@dbt_v_temptable_max_ram, 'n/a')) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_created_tmp_tables, 0) AS DECIMAL(30, 0))      AS total,
         CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS DECIMAL(30, 0)) AS disk,
         CAST(IFNULL(@dbt_s_created_tmp_disk_tables, 0) AS DECIMAL(30, 0)) / @dbt_uptime_h AS disk_per_hour
) AS t
WHERE t.total > 0
  AND t.disk / t.total >= COALESCE(@disk_tmp_ratio, 0.25)
  AND t.disk_per_hour >= COALESCE(@disk_tmp_per_hour, 1000);
