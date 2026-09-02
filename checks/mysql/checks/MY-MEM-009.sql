-- check: MY-MEM-009
-- title: Query cache enabled
-- priority: 50 | category: MEM | scope: setting | cost: 0 | pass: fast
-- engine: mariadb | requires: (none)
-- thresholds: threads_running=8
-- reads: @dbt_v_query_cache_type, @dbt_v_query_cache_size, @dbt_s_threads_running
-- Version divergence: the query cache was deprecated in MySQL 5.7.20 and REMOVED
-- in MySQL 8.0, so both variables are absent there and the bundle returns NULL —
-- this check then emits nothing. It remains present and OFF-by-default in
-- MariaDB, which is the only fork where it can still be found switched on.
-- The mechanism is a single global mutex: every read consults it and every write
-- to any table invalidates every cached result for that table. On a server with
-- real concurrency it converts parallel work into a queue, and the effect grows
-- with core count. There is no PostgreSQL analogue.
SELECT
  'MY-MEM-009' AS check_id,
  'setting'    AS scope,
  'query_cache_type' AS object,
  CONCAT('query_cache_type = ', @dbt_v_query_cache_type, ' with query_cache_size = ',
         ROUND(CAST(@dbt_v_query_cache_size AS DECIMAL(30, 0)) / 1048576, 1), ' MB. ',
         'Every read takes the single global query cache mutex and every write invalidates all cached results for the tables it touches, so throughput falls as concurrency rises. ',
         'Threads_running at snapshot: ', IFNULL(@dbt_s_threads_running, 'unknown'),
         '. Removed entirely in MySQL 8.0; MariaDB keeps it OFF by default.') AS details,
  JSON_OBJECT(
    'query_cache_type', @dbt_v_query_cache_type,
    'query_cache_size', CAST(@dbt_v_query_cache_size AS UNSIGNED),
    'threads_running', CAST(IFNULL(@dbt_s_threads_running, 0) AS UNSIGNED),
    'fork', @dbt_fork) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE @dbt_v_query_cache_type IS NOT NULL
  AND UPPER(@dbt_v_query_cache_type) NOT IN ('OFF', '0')
  AND CAST(IFNULL(@dbt_v_query_cache_size, 0) AS DECIMAL(30, 0)) > 0;
