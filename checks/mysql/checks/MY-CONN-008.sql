-- check: MY-CONN-008
-- title: Thread cache misses
-- priority: 150 | category: CONN | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: thread_miss_ratio=0.01;min_connections=100000
-- reads: @dbt_s_threads_created, @dbt_s_connections, @@GLOBAL.thread_cache_size
-- Threads_created / Connections is the fraction of connections that needed a new
-- OS thread rather than a cached one. MySQL 8.0 auto-sizes thread_cache_size
-- from max_connections, so this rarely fires there; MariaDB's default formula is
-- more conservative and a connection-per-request application can outrun it.
-- The 100,000-connection floor exists because on a low-traffic server every
-- connection legitimately creates a thread and the ratio means nothing.
SELECT
  'MY-CONN-008' AS check_id,
  'setting'     AS scope,
  'thread_cache_size' AS object,
  CONCAT(FORMAT(t.created, 0), ' threads created for ', FORMAT(t.conns, 0),
         ' connections since restart (', ROUND(100.0 * t.created / t.conns, 2),
         '%, threshold ', ROUND(100 * COALESCE(@thread_miss_ratio, 0.01), 1),
         '%) with thread_cache_size = ', @@GLOBAL.thread_cache_size,
         '. Each miss is an OS thread creation and stack allocation (thread_stack = ',
         ROUND(@@GLOBAL.thread_stack / 1024, 0), ' KB) on the connection path. ',
         'Threads_cached now: ', CAST(IFNULL(@dbt_s_threads_cached, 0) AS UNSIGNED),
         '. The deeper fix is connection pooling in the application.') AS details,
  JSON_OBJECT(
    'threads_created', t.created,
    'connections', t.conns,
    'miss_ratio', ROUND(t.created / t.conns, 5),
    'threshold_ratio', COALESCE(@thread_miss_ratio, 0.01),
    'thread_cache_size', @@GLOBAL.thread_cache_size,
    'threads_cached', CAST(IFNULL(@dbt_s_threads_cached, 0) AS UNSIGNED)) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM (
  SELECT CAST(IFNULL(@dbt_s_threads_created, 0) AS DECIMAL(30, 0)) AS created,
         GREATEST(CAST(IFNULL(@dbt_s_connections, 0) AS DECIMAL(30, 0)), 1) AS conns
) AS t
WHERE t.conns >= COALESCE(@min_connections, 100000)
  AND t.created / t.conns >= COALESCE(@thread_miss_ratio, 0.01);
