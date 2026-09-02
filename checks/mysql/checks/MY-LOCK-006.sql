-- check: MY-LOCK-006
-- title: Sessions waiting for a metadata lock
-- priority: 50 | category: LOCK | scope: cluster | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: mdl_wait_seconds=30
-- reads: information_schema.PROCESSLIST (STATE = 'Waiting for table metadata lock')
-- MySQL-specific pile-up with no PostgreSQL analogue in this shape. The
-- mechanism: an ALTER TABLE needs an exclusive metadata lock; a long-running
-- transaction that merely SELECTed from the table holds a shared one and will
-- not release it until it commits. The ALTER queues — and because MDL requests
-- are served in order, EVERY subsequent query on that table queues behind the
-- ALTER, including plain SELECTs that would otherwise have run fine.
-- The result is a table that goes from healthy to completely unavailable in one
-- step, with no lock wait timeout firing (lock_wait_timeout defaults to 1 year
-- (31536000 s) on both forks).
-- The PROCESSLIST STATE string is identical on MySQL 5.6-9.x and MariaDB, which
-- is why this is portable without a version gate;
-- performance_schema.metadata_locks (MySQL 5.7+, present on MariaDB 10.11) gives
-- the blocking side and is used by the reference doc's confirmation query.
SELECT
  'MY-LOCK-006' AS check_id,
  'cluster'     AS scope,
  'metadata-locks' AS object,
  CONCAT(w.waiters, ' session(s) are waiting for a table metadata lock, the longest for ',
         w.max_wait, ' s (threshold ', COALESCE(@mdl_wait_seconds, 30), ' s). ',
         'Waiting on: ', w.tables, '. ',
         'MDL requests are granted in order, so every query on those tables now queues behind the DDL at the head of the line — including SELECTs. ',
         'lock_wait_timeout = ', @@GLOBAL.lock_wait_timeout,
         ' s, so this will not clear itself in any useful time. ',
         'The blocker is normally a long or idle transaction: see MY-LOCK-003/004.') AS details,
  JSON_OBJECT(
    'waiting_sessions', w.waiters,
    'max_wait_seconds', w.max_wait,
    'tables', w.tables,
    'lock_wait_timeout', @@GLOBAL.lock_wait_timeout,
    'threshold_seconds', COALESCE(@mdl_wait_seconds, 30),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COUNT(*) AS waiters,
         MAX(TIME) AS max_wait,
         SUBSTRING(GROUP_CONCAT(DISTINCT CONCAT(IFNULL(DB, '?'), ' / ',
           SUBSTRING(REGEXP_REPLACE(IFNULL(INFO, '(no statement)'), '[[:space:]]+', ' '), 1, 80))
           SEPARATOR '; '), 1, 500) AS tables
  FROM information_schema.PROCESSLIST
  WHERE STATE = 'Waiting for table metadata lock'
) AS w
WHERE w.waiters > 0
  AND w.max_wait >= COALESCE(@mdl_wait_seconds, 30);
