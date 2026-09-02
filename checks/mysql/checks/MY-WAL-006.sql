-- check: MY-WAL-006
-- title: Buffer pool dirty page ratio high
-- priority: 150 | category: WAL | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: dirty_ratio=0.75
-- reads: @dbt_s_innodb_buffer_pool_pages_dirty, @dbt_s_innodb_buffer_pool_pages_total,
--        @@GLOBAL.innodb_max_dirty_pages_pct
-- A snapshot, not a rate: this is the state at the moment the check ran, which
-- is why the details say so. Dirty pages above innodb_max_dirty_pages_pct mean
-- the page cleaners are behind the write rate; InnoDB responds by flushing
-- synchronously in the foreground, which users feel as latency spikes.
-- Both forks expose these counters identically.
SELECT
  'MY-WAL-006' AS check_id,
  'cluster'    AS scope,
  'buffer-pool-dirty-pages' AS object,
  CONCAT(FORMAT(p.dirty, 0), ' of ', FORMAT(p.total, 0),
         ' buffer pool pages are dirty at snapshot time (',
         ROUND(100.0 * p.dirty / p.total, 1), '%, threshold ',
         ROUND(100 * COALESCE(@dirty_ratio, 0.75), 0), '%; innodb_max_dirty_pages_pct = ',
         @@GLOBAL.innodb_max_dirty_pages_pct,
         '). The page cleaners are behind the write rate, so InnoDB starts flushing in the foreground and writers wait. See MY-WAL-001 for redo sizing and MY-WAL-005 for the flush rate cap.') AS details,
  JSON_OBJECT(
    'dirty_pages', p.dirty,
    'total_pages', p.total,
    'dirty_ratio', ROUND(p.dirty / p.total, 4),
    'threshold_ratio', COALESCE(@dirty_ratio, 0.75),
    'innodb_max_dirty_pages_pct', @@GLOBAL.innodb_max_dirty_pages_pct,
    'measured', 'snapshot') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_dirty, 0) AS DECIMAL(30, 0)) AS dirty,
         CAST(IFNULL(@dbt_s_innodb_buffer_pool_pages_total, 0) AS DECIMAL(30, 0)) AS total
) AS p
WHERE p.total > 0
  AND p.dirty / p.total >= COALESCE(@dirty_ratio, 0.75);
