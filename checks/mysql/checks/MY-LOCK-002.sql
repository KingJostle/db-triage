-- check: MY-LOCK-002
-- title: Transaction waiting on a row lock for over 30 seconds
-- priority: 50 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: lock_wait_warn_seconds=30;lock_wait_critical_seconds=300
-- reads: information_schema.INNODB_TRX, PROCESSLIST
-- Magnitude tier below MY-LOCK-001, separate ID so the tiers suppress
-- independently. 30 s is below the 50 s innodb_lock_wait_timeout default, so a
-- transaction seen here on a default-configured server is within seconds of
-- being rolled back with ER_LOCK_WAIT_TIMEOUT.
SELECT
  'MY-LOCK-002' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ') has waited ', TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()),
         ' s for a row lock (threshold ', COALESCE(@lock_wait_warn_seconds, 30),
         ' s; the P10 tier MY-LOCK-001 starts at ',
         COALESCE(@lock_wait_critical_seconds, 300), ' s). innodb_lock_wait_timeout = ',
         @@GLOBAL.innodb_lock_wait_timeout, ' s, so it will be rolled back with ER_LOCK_WAIT_TIMEOUT in ',
         GREATEST(@@GLOBAL.innodb_lock_wait_timeout - TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()), 0),
         ' s. Statement: ', SUBSTRING(IFNULL(t.trx_query, '(not visible)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'wait_seconds', TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()),
    'rows_locked', t.trx_rows_locked,
    'user', IFNULL(p.USER, 'unknown'),
    'innodb_lock_wait_timeout', @@GLOBAL.innodb_lock_wait_timeout,
    'threshold_seconds', COALESCE(@lock_wait_warn_seconds, 30),
    'measured', 'snapshot') AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
LEFT JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE t.trx_state = 'LOCK WAIT'
  AND t.trx_wait_started IS NOT NULL
  AND TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()) >= COALESCE(@lock_wait_warn_seconds, 30)
  AND TIMESTAMPDIFF(SECOND, t.trx_wait_started, NOW()) <  COALESCE(@lock_wait_critical_seconds, 300);
