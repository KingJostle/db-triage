-- check: MY-LOCK-004
-- title: Idle transaction holding locks for over an hour
-- priority: 10 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: idle_txn_critical_seconds=3600;idle_txn_warn_seconds=300
-- reads: information_schema.INNODB_TRX joined to PROCESSLIST (COMMAND='Sleep')
-- The MySQL analogue of PostgreSQL's idle-in-transaction backend, and worse in
-- one respect: MySQL has no idle_in_transaction_session_timeout equivalent
-- before MySQL 8.0's innodb_lock_wait_timeout-unrelated
-- `wait_timeout` (which does not apply mid-transaction), so nothing reclaims it.
-- MariaDB has idle_transaction_timeout / idle_write_transaction_timeout, which
-- is why the details name them when the fork supports them.
-- An idle transaction holding row locks is strictly worse than a busy one: it is
-- doing no work, blocking others, and pinning purge. The usual cause is an
-- application that opened a transaction, made a network call, and never came back.
SELECT
  'MY-LOCK-004' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ') is IDLE (COMMAND = Sleep for ', p.TIME, ' s) but still open after ',
         ROUND(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) / 3600, 2),
         ' h, holding ', t.trx_rows_locked, ' row lock(s) and ',
         t.trx_rows_modified, ' modified row(s) (threshold ',
         ROUND(COALESCE(@idle_txn_critical_seconds, 3600) / 3600, 1), ' h). ',
         'Nothing will clean this up: wait_timeout does not apply mid-transaction. ',
         IF(@dbt_is_mariadb,
            'MariaDB offers idle_transaction_timeout / idle_write_transaction_timeout as a guard.',
            'MySQL has no idle-in-transaction timeout; the application must close it.'),
         ' Last statement: ', SUBSTRING(IFNULL(p.INFO, '(none recorded)'), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'transaction_age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'idle_seconds', p.TIME,
    'rows_locked', t.trx_rows_locked,
    'rows_modified', t.trx_rows_modified,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'threshold_seconds', COALESCE(@idle_txn_critical_seconds, 3600)) AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE p.COMMAND = 'Sleep'
  AND t.trx_rows_locked > 0
  AND TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) >= COALESCE(@idle_txn_critical_seconds, 3600);
