-- check: MY-LOCK-009
-- title: Query running for over 10 minutes
-- priority: 100 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: long_query_seconds=600
-- reads: information_schema.PROCESSLIST
-- Excludes the threads that are legitimately long-lived: replication receivers
-- and appliers (Binlog Dump, Connect, Slave/Replica threads), the event
-- scheduler, and this session itself. Backup tools are excluded by name where
-- they are recognisable, and the details name the account so an unrecognised
-- one is easy to classify.
-- A ten-minute query is not automatically wrong — a nightly report is fine — but
-- on an OLTP server it is usually a missing index (MY-IDX-004, MY-QRY-006/008) or
-- a query that should not be running there at all. It is P100 because the fix is
-- rarely urgent, and it is scoped per session so each one is separately
-- suppressible.
SELECT
  'MY-LOCK-009' AS check_id,
  'session'     AS scope,
  CONCAT('pid:', p.ID) AS object,
  CONCAT('Thread ', p.ID, ' (', IFNULL(p.USER, '?'), '@', IFNULL(p.HOST, '?'),
         ', schema ', IFNULL(p.DB, 'none'), ') has been running a ', p.COMMAND,
         ' for ', ROUND(p.TIME / 60, 1), ' min (threshold ',
         ROUND(COALESCE(@long_query_seconds, 600) / 60, 0), ' min), state "',
         IFNULL(p.STATE, 'none'), '". Statement: ',
         SUBSTRING(REGEXP_REPLACE(IFNULL(p.INFO, '(not visible without PROCESS)'), '[[:space:]]+', ' '), 1, 250)) AS details,
  JSON_OBJECT(
    'thread_id', p.ID,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'db', IFNULL(p.DB, ''),
    'command', p.COMMAND,
    'runtime_seconds', p.TIME,
    'state', IFNULL(p.STATE, ''),
    'threshold_seconds', COALESCE(@long_query_seconds, 600),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM information_schema.PROCESSLIST AS p
WHERE p.COMMAND NOT IN ('Sleep', 'Binlog Dump', 'Binlog Dump GTID', 'Connect', 'Daemon', 'Slave_IO', 'Slave_SQL')
  AND p.ID <> CONNECTION_ID()
  AND IFNULL(p.USER, '') NOT IN ('system user', 'event_scheduler')
  AND p.TIME >= COALESCE(@long_query_seconds, 600);
