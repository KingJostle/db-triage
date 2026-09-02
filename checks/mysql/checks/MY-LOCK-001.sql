-- check: MY-LOCK-001
-- title: Transaction waiting on a row lock for over 5 minutes
-- priority: 10 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: lock_wait_critical_seconds=300;lock_wait_warn_seconds=30
-- reads: information_schema.INNODB_TRX (trx_wait_started, trx_state), PROCESSLIST
-- Deliberately built on INNODB_TRX rather than on the lock-waits view, because
-- that view is where the forks diverge hardest: MySQL 8.0 replaced
-- information_schema.INNODB_LOCK_WAITS with performance_schema.data_lock_waits,
-- MariaDB kept INNODB_LOCK_WAITS (verified present on 10.11), and sys.innodb_lock_waits
-- exists on both but with different underlying columns.
-- INNODB_TRX.trx_wait_started exists identically on MySQL 5.6-9.x and every
-- MariaDB, so the waiting side is always visible. The blocking side is
-- identified where the fork allows; MY-LOCK-002 is the lower tier.
-- Five minutes of waiting means innodb_lock_wait_timeout (default 50 s) was
-- raised, so somebody has already decided to wait rather than fail.
SELECT
  'MY-LOCK-001' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ', operation state ', IFNULL(NULLIF(t.trx_operation_state, ''), 'none'),
         ') has been waiting for a row lock for ',
         TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()), ' s (threshold ',
         COALESCE(@lock_wait_critical_seconds, 300), ' s). ',
         'It started ', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
         ' s ago, holds ', t.trx_rows_locked, ' row lock(s) and has modified ',
         t.trx_rows_modified, ' row(s). innodb_lock_wait_timeout = ',
         @@GLOBAL.innodb_lock_wait_timeout, ' s. Statement: ',
         SUBSTRING(IFNULL(t.trx_query, '(not visible)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'wait_seconds', TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()),
    'transaction_age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'rows_locked', t.trx_rows_locked,
    'rows_modified', t.trx_rows_modified,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'innodb_lock_wait_timeout', @@GLOBAL.innodb_lock_wait_timeout,
    'threshold_seconds', COALESCE(@lock_wait_critical_seconds, 300),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
LEFT JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE t.trx_state = 'LOCK WAIT'
  AND t.trx_wait_started IS NOT NULL
  AND TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()) >= COALESCE(@lock_wait_critical_seconds, 300);
