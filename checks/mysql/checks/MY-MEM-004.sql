-- check: MY-MEM-004
-- title: Buffer pool read miss rate high
-- priority: 100 | category: MEM | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: miss_ratio=0.05;min_read_requests=10000000
-- reads: @dbt_s_innodb_buffer_pool_reads, @dbt_s_innodb_buffer_pool_read_requests
-- Innodb_buffer_pool_reads counts logical reads that had to go to disk;
-- read_requests counts all logical reads. The ratio is a since-restart average,
-- so it hides both the warm-up after a restart and any recent change — hence
-- the confidence tracking the counter window and the explicit window in the text.
-- The 10 M request floor keeps a freshly started server from firing on a handful
-- of reads that were all misses.
SELECT
  'MY-MEM-004' AS check_id,
  'cluster'    AS scope,
  'buffer-pool-hit-rate' AS object,
  CONCAT(ROUND(100.0 * r.misses / r.reqs, 2), '% of ', FORMAT(r.reqs, 0),
         ' logical reads went to disk since restart ', ROUND(@dbt_uptime_s / 86400, 1),
         ' days ago (threshold ', ROUND(100 * COALESCE(@miss_ratio, 0.05), 1), '%). ',
         'Buffer pool is ', ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB. This is an average over the whole window, so a recent regression is diluted and a warm-up after restart is included. ',
         'innodb_buffer_pool_dump_at_shutdown = ', @@GLOBAL.innodb_buffer_pool_dump_at_shutdown, '.') AS details,
  JSON_OBJECT(
    'buffer_pool_reads', r.misses,
    'buffer_pool_read_requests', r.reqs,
    'miss_ratio', ROUND(r.misses / r.reqs, 5),
    'threshold_ratio', COALESCE(@miss_ratio, 0.05),
    'innodb_buffer_pool_size', @@GLOBAL.innodb_buffer_pool_size,
    'window_seconds', @dbt_uptime_s) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_innodb_buffer_pool_reads, 0) AS DECIMAL(30, 0))         AS misses,
         CAST(IFNULL(@dbt_s_innodb_buffer_pool_read_requests, 0) AS DECIMAL(30, 0)) AS reqs
) AS r
WHERE r.reqs >= COALESCE(@min_read_requests, 10000000)
  AND r.misses / r.reqs >= COALESCE(@miss_ratio, 0.05);
