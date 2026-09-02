-- check: MY-LOCK-005
-- title: Idle transaction holding locks for over 5 minutes
-- priority: 50 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: idle_txn_warn_seconds=300;idle_txn_critical_seconds=3600
-- reads: information_schema.INNODB_TRX joined to PROCESSLIST
-- Magnitude tier below MY-LOCK-004, separate ID for independent suppression.
SELECT
  'MY-LOCK-005' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ') is idle for ', p.TIME, ' s with the transaction open ',
         TIMESTAMPDIFF(SECOND, t.trx_started, NOW()), ' s and ',
         t.trx_rows_locked, ' row lock(s) held (threshold ',
         COALESCE(@idle_txn_warn_seconds, 300), ' s; the P10 tier MY-LOCK-004 starts at ',
         COALESCE(@idle_txn_critical_seconds, 3600), ' s). Last statement: ',
         SUBSTRING(IFNULL(p.INFO, '(none recorded)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'transaction_age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'idle_seconds', p.TIME,
    'rows_locked', t.trx_rows_locked,
    'user', IFNULL(p.USER, 'unknown'),
    'threshold_seconds', COALESCE(@idle_txn_warn_seconds, 300)) AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE p.COMMAND = 'Sleep'
  AND t.trx_rows_locked > 0
  AND TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) >= COALESCE(@idle_txn_warn_seconds, 300)
  AND TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) <  COALESCE(@idle_txn_critical_seconds, 3600);
