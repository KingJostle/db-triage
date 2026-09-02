-- check: MY-MEM-010
-- title: Single buffer pool instance with a large pool
-- priority: 150 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: large_pool_bytes=8589934592
-- reads: @dbt_v_innodb_buffer_pool_instances, @@GLOBAL.innodb_buffer_pool_size
-- Version divergence, and the reason this must come from the bundle: MariaDB
-- 10.6 REMOVED innodb_buffer_pool_instances entirely (verified absent on 10.11)
-- because its buffer pool no longer partitions that way, and MySQL 8.0
-- auto-sizes it from the pool size. So this can only fire on MySQL 5.7, on
-- MariaDB 10.5 and earlier, or where someone pinned it to 1 by hand.
-- With one instance, every page lookup contends on one buffer pool mutex; the
-- classic guidance is one instance per GB up to the core count.
SELECT
  'MY-MEM-010' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_instances' AS object,
  CONCAT('innodb_buffer_pool_instances = ', @dbt_v_innodb_buffer_pool_instances,
         ' for a ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 1),
         ' GB buffer pool (threshold ',
         ROUND(COALESCE(@large_pool_bytes, 8589934592) / 1073741824, 0),
         ' GB). All page lookups contend on one buffer pool mutex. ',
         'Fork note: MySQL 8.0 auto-sizes this and MariaDB 10.6+ removed the setting, so this only applies to MySQL 5.7 / MariaDB 10.5 and earlier, or an explicit override.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_instances', CAST(@dbt_v_innodb_buffer_pool_instances AS UNSIGNED),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'threshold_bytes', COALESCE(@large_pool_bytes, 8589934592),
    'cpu_count', IFNULL(@dbt_cpu_count, 'unknown')) AS evidence_json,
  'medium' AS confidence
FROM DUAL
WHERE @dbt_v_innodb_buffer_pool_instances IS NOT NULL
  AND CAST(@dbt_v_innodb_buffer_pool_instances AS SIGNED) = 1
  AND @@GLOBAL.innodb_buffer_pool_size >= COALESCE(@large_pool_bytes, 8589934592);
