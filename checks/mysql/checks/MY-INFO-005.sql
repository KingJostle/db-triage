-- check: MY-INFO-005
-- title: Connection summary
-- priority: 250 | category: INFO | scope: cluster | cost: 0 | pass: inventory
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: (none)
-- reads: information_schema.PROCESSLIST
-- Always emitted. A SNAPSHOT, stated as such: one sample of who is connected,
-- from where, doing what. Its value is not the numbers but the shape — whether
-- connections arrive from three pooler hosts or three hundred application
-- processes (MY-CONN-006), whether one account holds everything (MY-SEC-008),
-- and whether the population is mostly idle (MY-CONN-007).
-- Requires PROCESS to see other accounts; without it this reports only this
-- session and says so.
SELECT
  'MY-INFO-005' AS check_id,
  'cluster'     AS scope,
  'connections' AS object,
  CONCAT(p.total, ' connection(s) at snapshot time from ', p.hosts,
         ' distinct client host(s) and ', p.users, ' account(s)',
         IF(IFNULL(@dbt_priv_process, 1) = 0,
            ' — NOTE: this account lacks PROCESS, so only its own session is visible and these numbers are not the server total', ''),
         '. By command: ', p.by_command,
         '. By account: ', p.by_user,
         '. Top client hosts: ', p.by_host,
         '. Schemas in use: ', IFNULL(p.by_db, 'none'),
         '. max_connections = ', @@GLOBAL.max_connections,
         ', Threads_connected = ', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
         ', Max_used_connections = ', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED), '.') AS details,
  JSON_OBJECT(
    'connections_at_snapshot', p.total,
    'distinct_hosts', p.hosts,
    'distinct_users', p.users,
    'by_command', p.by_command,
    'by_user', p.by_user,
    'by_host', p.by_host,
    'by_schema', IFNULL(p.by_db, ''),
    'max_connections', @@GLOBAL.max_connections,
    'threads_connected', CAST(IFNULL(@dbt_s_threads_connected, 0) AS UNSIGNED),
    'max_used_connections', CAST(IFNULL(@dbt_s_max_used_connections, 0) AS UNSIGNED),
    'has_process_privilege', IFNULL(@dbt_priv_process, 1),
    'measured', 'snapshot') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT COUNT(*) AS total,
         COUNT(DISTINCT SUBSTRING_INDEX(IFNULL(HOST, ''), ':', 1)) AS hosts,
         COUNT(DISTINCT USER) AS users,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(COMMAND, '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT COMMAND, COUNT(*) AS c FROM information_schema.PROCESSLIST GROUP BY COMMAND) AS t1) AS by_command,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(IFNULL(USER, '?'), '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT USER, COUNT(*) AS c FROM information_schema.PROCESSLIST GROUP BY USER ORDER BY c DESC LIMIT 10) AS t2) AS by_user,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(h, '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT SUBSTRING_INDEX(IFNULL(HOST, ''), ':', 1) AS h, COUNT(*) AS c
                    FROM information_schema.PROCESSLIST GROUP BY h ORDER BY c DESC LIMIT 10) AS t3) AS by_host,
         (SELECT SUBSTRING(GROUP_CONCAT(CONCAT(d, '=', c) ORDER BY c DESC SEPARATOR ', '), 1, 250)
            FROM (SELECT IFNULL(DB, '(none)') AS d, COUNT(*) AS c
                    FROM information_schema.PROCESSLIST GROUP BY d ORDER BY c DESC LIMIT 10) AS t4) AS by_db
  FROM information_schema.PROCESSLIST
) AS p;
