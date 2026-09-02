-- check: MY-MEM-003
-- title: Buffer pool over 80 percent of host RAM
-- priority: 100 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: os
-- thresholds: pool_ram_ceiling=0.80
-- reads: @@GLOBAL.innodb_buffer_pool_size, @dbt_ram_bytes
-- Requires RAM, which no MySQL variable reports. The runner supplies it from
-- /proc/meminfo or .db-triage.yml baseline.ram_gb; without it this check emits
-- nothing rather than guessing, and the runner records it skipped with reason
-- `os`. MY-MEM-007 computes the full worst-case commitment, of which the pool
-- is only the fixed part.
-- The buffer pool is not the server's whole footprint: add the log buffer, the
-- per-connection buffers, the temptable pool and the OS page cache the redo and
-- binary logs need. Crossing 80% of RAM is where hosts start swapping, and a
-- swapping buffer pool is slower than no buffer pool.
SELECT
  'MY-MEM-003' AS check_id,
  'setting'    AS scope,
  'innodb_buffer_pool_size' AS object,
  CONCAT('Buffer pool is ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB of ', ROUND(@dbt_ram_bytes / 1073741824, 1), ' GB host RAM (',
         ROUND(100.0 * @@GLOBAL.innodb_buffer_pool_size / @dbt_ram_bytes, 1),
         '%, threshold ', ROUND(100 * COALESCE(@pool_ram_ceiling, 0.80), 0), '%). ',
         'That leaves ', ROUND((@dbt_ram_bytes - @@GLOBAL.innodb_buffer_pool_size) / 1073741824, 2),
         ' GB for up to ', @@GLOBAL.max_connections,
         ' connections'' per-session buffers, the redo log buffer and the OS page cache. See MY-MEM-007 for the worst-case total.') AS details,
  JSON_OBJECT(
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'ram_bytes', @dbt_ram_bytes,
    'ratio', ROUND(@@GLOBAL.innodb_buffer_pool_size / @dbt_ram_bytes, 4),
    'threshold_ratio', COALESCE(@pool_ram_ceiling, 0.80),
    'max_connections', @@GLOBAL.max_connections) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @dbt_ram_bytes IS NOT NULL
  AND @dbt_ram_bytes > 0
  AND @@GLOBAL.innodb_buffer_pool_size >= @dbt_ram_bytes * COALESCE(@pool_ram_ceiling, 0.80);
