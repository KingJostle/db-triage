-- check: MY-WAL-003
-- title: Binary log cache spilling to disk
-- priority: 150 | category: WAL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: spill_ratio=0.01;min_cache_uses=10000
-- reads: @dbt_s_binlog_cache_use, @dbt_s_binlog_cache_disk_use, @@GLOBAL.binlog_cache_size
-- Every transaction buffers its row events in binlog_cache_size of memory before
-- commit; anything larger spills to a temporary file on disk and is read back at
-- commit time. A high spill ratio means large transactions, which are also the
-- transactions that block purge (MY-UNDO-001) and serialise replica appliers.
-- Raising binlog_cache_size is per-session memory, so it multiplies by
-- concurrency — the better fix is usually smaller transactions.
SELECT
  'MY-WAL-003' AS check_id,
  'setting'    AS scope,
  'binlog_cache_size' AS object,
  CONCAT(FORMAT(b.disk, 0), ' of ', FORMAT(b.uses, 0),
         ' transactions (', ROUND(100.0 * b.disk / b.uses, 2),
         '%) spilled their binary log events to disk since restart, past the ',
         ROUND(100 * COALESCE(@spill_ratio, 0.01), 2), '% threshold. ',
         'binlog_cache_size = ', ROUND(@@GLOBAL.binlog_cache_size / 1024, 0),
         ' KB per session. Raising it costs that much memory per concurrent writing session; splitting the large transactions costs nothing and also helps MY-UNDO-001 and replica apply latency.') AS details,
  JSON_OBJECT(
    'binlog_cache_use', b.uses,
    'binlog_cache_disk_use', b.disk,
    'spill_ratio', ROUND(b.disk / b.uses, 5),
    'binlog_cache_size', @@GLOBAL.binlog_cache_size,
    'threshold_ratio', COALESCE(@spill_ratio, 0.01)) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_binlog_cache_use, 0) AS DECIMAL(30, 0))      AS uses,
         CAST(IFNULL(@dbt_s_binlog_cache_disk_use, 0) AS DECIMAL(30, 0)) AS disk
) AS b
WHERE b.uses >= COALESCE(@min_cache_uses, 10000)
  AND b.disk / b.uses >= COALESCE(@spill_ratio, 0.01);
