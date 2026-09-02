-- check: MY-MEM-007
-- title: Worst-case memory commitment exceeds host RAM
-- priority: 50 | category: MEM | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: commitment_ratio=1.0
-- reads: @@GLOBAL.innodb_buffer_pool_size, innodb_log_buffer_size, key_buffer_size,
--        max_connections, sort/join/read/read_rnd buffers, binlog_cache_size,
--        thread_stack, tmp_table_size, @dbt_ram_bytes
-- The arithmetic MySQL never does for you: a fixed global part plus a per-session
-- part multiplied by max_connections. It is a genuine WORST case — most sessions
-- never allocate their sort or join buffer, and MySQL 8.0's TempTable pool is
-- shared rather than per session — so it overstates typical usage on purpose.
-- Priority follows what is known: P50 when RAM was supplied and the number really
-- does exceed it, P100 when RAM is unknown and the figure is reported for the
-- operator to compare. The registry carries both rows via platform_priority; the
-- confidence field carries the same distinction.
SELECT
  'MY-MEM-007' AS check_id,
  'cluster'    AS scope,
  'memory-commitment' AS object,
  CONCAT('Worst-case memory commitment is ', ROUND(m.total / 1073741824, 1), ' GB: ',
         ROUND(m.fixed / 1073741824, 2), ' GB fixed (buffer pool ',
         ROUND(@@GLOBAL.innodb_buffer_pool_size / 1073741824, 2),
         ' GB + log buffer + key buffer) plus ', @@GLOBAL.max_connections,
         ' connections x ', ROUND(m.per_conn / 1048576, 1), ' MB per session. ',
         IF(@dbt_ram_bytes IS NULL,
            'Host RAM was not supplied, so this cannot be compared to anything — set baseline.ram_gb in .db-triage.yml.',
            CONCAT('Host RAM is ', ROUND(@dbt_ram_bytes / 1073741824, 1), ' GB, so the worst case is ',
                   ROUND(100.0 * m.total / @dbt_ram_bytes, 0), '% of it.')),
         ' This is a ceiling, not a forecast: most sessions never allocate their sort or join buffer. Peak connections so far: ',
         FORMAT(CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED), 0), '.') AS details,
  JSON_OBJECT(
    'worst_case_bytes', m.total,
    'fixed_bytes', m.fixed,
    'per_connection_bytes', m.per_conn,
    'max_connections', @@GLOBAL.max_connections,
    'max_used_connections', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED),
    'ram_bytes', IFNULL(@dbt_ram_bytes, 'unknown'),
    'threshold_ratio', COALESCE(@commitment_ratio, 1.0)) AS evidence_json,
  IF(@dbt_ram_bytes IS NULL, 'low', 'medium') AS confidence
FROM (
  SELECT f.fixed, p.per_conn, f.fixed + p.per_conn * @@GLOBAL.max_connections AS total
  FROM (SELECT CAST(@@GLOBAL.innodb_buffer_pool_size AS DECIMAL(30, 0))
             + @@GLOBAL.innodb_log_buffer_size
             + @@GLOBAL.key_buffer_size AS fixed) AS f,
       (SELECT CAST(@@GLOBAL.sort_buffer_size AS DECIMAL(30, 0))
             + @@GLOBAL.join_buffer_size
             + @@GLOBAL.read_buffer_size
             + @@GLOBAL.read_rnd_buffer_size
             + @@GLOBAL.binlog_cache_size
             + @@GLOBAL.thread_stack
             + @@GLOBAL.tmp_table_size AS per_conn) AS p
) AS m
WHERE @dbt_ram_bytes IS NULL
   OR m.total >= @dbt_ram_bytes * COALESCE(@commitment_ratio, 1.0);
