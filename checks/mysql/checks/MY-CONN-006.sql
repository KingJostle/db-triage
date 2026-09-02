-- check: MY-CONN-006
-- title: max_connections very high with no thread pool and no evidence of a pooler
-- priority: 50 | category: CONN | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: high_max_connections=1000;pooler_host_concentration=0.80;pooler_max_hosts=3
-- reads: @@GLOBAL.max_connections, @dbt_v_thread_handling,
--        information_schema.PLUGINS (thread_pool), information_schema.PROCESSLIST
-- Fork divergence: MariaDB and Percona Server implement the thread pool in the
-- server and expose thread_handling = 'pool-of-threads'; MySQL Community has no
-- thread pool at all (it is an Enterprise plugin, visible in
-- information_schema.PLUGINS as thread_pool). Both are checked, and
-- thread_handling comes from the bundle because stock MySQL lacks the variable.
-- The heuristic: a genuine pooler (ProxySQL, RDS Proxy, HAProxy, pgbouncer's
-- MySQL equivalents) concentrates connections into a handful of source hosts.
-- Many source hosts plus a four-figure max_connections means every application
-- process connects directly, and MySQL's one-thread-per-connection model turns
-- a connection storm into a scheduling collapse. Confidence is medium: an
-- application fleet on a small number of hosts looks identical to a pooler.
SELECT
  'MY-CONN-006' AS check_id,
  'setting'     AS scope,
  'max_connections' AS object,
  CONCAT('max_connections = ', @@GLOBAL.max_connections,
         ' with no thread pool (thread_handling = ',
         IFNULL(@dbt_v_thread_handling, 'not available; MySQL Community has no in-server thread pool'),
         ', thread_pool plugin ', IF(p.thread_pool_active > 0, 'ACTIVE', 'not installed'),
         ') and no evidence of a connection pooler: ', h.hosts,
         ' distinct client host(s) hold ', h.conns, ' connections, the busiest ',
         COALESCE(@pooler_max_hosts, 3), ' accounting for ',
         ROUND(100.0 * h.top_conns / GREATEST(h.conns, 1), 0),
         '% (a pooler would concentrate above ',
         ROUND(100 * COALESCE(@pooler_host_concentration, 0.80), 0), '%). ',
         'MySQL runs one thread per connection, so a connection storm becomes a scheduling problem long before it becomes a memory problem — see MY-MEM-007 for the memory ceiling this implies.') AS details,
  JSON_OBJECT(
    'max_connections', @@GLOBAL.max_connections,
    'thread_handling', IFNULL(@dbt_v_thread_handling, 'n/a'),
    'thread_pool_plugin_active', p.thread_pool_active,
    'distinct_client_hosts', h.hosts,
    'connections', h.conns,
    'top_host_share', ROUND(h.top_conns / GREATEST(h.conns, 1), 3),
    'threshold_max_connections', COALESCE(@high_max_connections, 1000),
    'threshold_concentration', COALESCE(@pooler_host_concentration, 0.80)) AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT
    COUNT(DISTINCT SUBSTRING_INDEX(HOST, ':', 1)) AS hosts,
    COUNT(*)                                      AS conns,
    (SELECT IFNULL(SUM(c), 0) FROM (
        SELECT COUNT(*) AS c
        FROM information_schema.PROCESSLIST
        WHERE HOST IS NOT NULL AND HOST <> ''
        GROUP BY SUBSTRING_INDEX(HOST, ':', 1)
        ORDER BY c DESC
        LIMIT 3) AS t)                            AS top_conns
  FROM information_schema.PROCESSLIST
  WHERE HOST IS NOT NULL AND HOST <> ''
) AS h,
(
  SELECT SUM(PLUGIN_NAME = 'thread_pool' AND PLUGIN_STATUS = 'ACTIVE') AS thread_pool_active
  FROM information_schema.PLUGINS
) AS p
WHERE @@GLOBAL.max_connections >= COALESCE(@high_max_connections, 1000)
  AND LOWER(IFNULL(@dbt_v_thread_handling, '')) NOT LIKE '%pool%'
  AND IFNULL(p.thread_pool_active, 0) = 0
  AND h.conns > 0
  AND h.top_conns / GREATEST(h.conns, 1) < COALESCE(@pooler_host_concentration, 0.80);
