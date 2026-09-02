-- check: MY-CONN-007
-- title: Most connections are sleeping
-- priority: 100 | category: CONN | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: sleep_ratio=0.80;min_conns=100;long_wait_timeout=28800
-- reads: information_schema.PROCESSLIST, @@GLOBAL.wait_timeout
-- Snapshot, and the details say so. A high sleeping ratio is normal for a
-- pooled application and is only reported when it combines with a long
-- wait_timeout, because that is the combination where an abandoned connection
-- occupies a slot (and its per-session buffers, MY-MEM-006/007) for up to eight
-- hours after the client forgot about it.
-- Requires PROCESS to see other accounts' threads; without it PROCESSLIST shows
-- only this session and the min_conns floor keeps the check silent.
SELECT
  'MY-CONN-007' AS check_id,
  'cluster'     AS scope,
  'connection-pool' AS object,
  CONCAT(p.sleeping, ' of ', p.total, ' connections (',
         ROUND(100.0 * p.sleeping / p.total, 0),
         '%) are idle at snapshot time, with wait_timeout = ', @@GLOBAL.wait_timeout,
         ' s (', ROUND(@@GLOBAL.wait_timeout / 3600, 1),
         ' h) and interactive_timeout = ', @@GLOBAL.interactive_timeout, ' s. ',
         'Longest idle: ', p.max_sleep, ' s. Each idle connection holds a slot out of ',
         @@GLOBAL.max_connections, ' and its per-session buffers. ',
         'Top idle accounts: ', p.top_users, '.') AS details,
  JSON_OBJECT(
    'sleeping', p.sleeping,
    'total', p.total,
    'sleep_ratio', ROUND(p.sleeping / p.total, 3),
    'max_sleep_seconds', p.max_sleep,
    'wait_timeout', @@GLOBAL.wait_timeout,
    'interactive_timeout', @@GLOBAL.interactive_timeout,
    'max_connections', @@GLOBAL.max_connections,
    'measured', 'snapshot') AS evidence_json,
  'medium' AS confidence
FROM (
  SELECT COUNT(*) AS total,
         SUM(COMMAND = 'Sleep') AS sleeping,
         MAX(IF(COMMAND = 'Sleep', TIME, 0)) AS max_sleep,
         SUBSTRING(GROUP_CONCAT(DISTINCT IF(COMMAND = 'Sleep', USER, NULL) SEPARATOR ', '), 1, 200) AS top_users
  FROM information_schema.PROCESSLIST
) AS p
WHERE p.total >= COALESCE(@min_conns, 100)
  AND p.sleeping / p.total >= COALESCE(@sleep_ratio, 0.80)
  AND @@GLOBAL.wait_timeout >= COALESCE(@long_wait_timeout, 28800);
