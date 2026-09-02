-- check: MY-LOCK-003
-- title: Transaction open for over an hour
-- priority: 20 | category: LOCK | scope: session | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: PROCESS
-- thresholds: long_txn_seconds=3600
-- reads: information_schema.INNODB_TRX (trx_started), PROCESSLIST
-- INNODB_TRX exists with these column names on every supported MySQL and
-- MariaDB, so no version gate is needed.
-- A long transaction is the usual root cause of MY-UNDO-001/002: its read view
-- pins the history list, so purge cannot reclaim ANY undo newer than it, no
-- matter how much has since been committed and deleted. It also holds every lock
-- it has taken, and on MySQL it blocks the metadata-lock queue behind any DDL
-- (MY-LOCK-006). Transactions that merely sit idle are MY-LOCK-004/005.
SELECT
  'MY-LOCK-003' AS check_id,
  'session'     AS scope,
  CONCAT('trx:', t.trx_id) AS object,
  CONCAT('Transaction ', t.trx_id, ' (thread ', t.trx_mysql_thread_id,
         ', account ', IFNULL(p.USER, 'unknown'), '@', IFNULL(p.HOST, 'unknown'),
         ', state ', t.trx_state, ') has been open for ',
         ROUND(TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) / 3600, 2), ' h (started ',
         t.trx_started, ', threshold ', ROUND(COALESCE(@long_txn_seconds, 3600) / 3600, 1),
         ' h). It holds ', t.trx_rows_locked, ' row lock(s), has modified ',
         t.trx_rows_modified, ' row(s), and its read view prevents purge from reclaiming any undo generated since it started — history list length is now ',
         FORMAT(IFNULL(@dbt_hll, 0), 0), '. Current statement: ',
         SUBSTRING(IFNULL(NULLIF(t.trx_query, ''), IFNULL(p.INFO, '(idle — see MY-LOCK-004)')), 1, 200)) AS details,
  JSON_OBJECT(
    'trx_id', t.trx_id,
    'thread_id', t.trx_mysql_thread_id,
    'age_seconds', TIMESTAMPDIFF(SECOND, t.trx_started, NOW()),
    'trx_started', CAST(t.trx_started AS CHAR),
    'trx_state', t.trx_state,
    'rows_locked', t.trx_rows_locked,
    'rows_modified', t.trx_rows_modified,
    'user', IFNULL(p.USER, 'unknown'),
    'host', IFNULL(p.HOST, 'unknown'),
    'command', IFNULL(p.COMMAND, 'unknown'),
    'history_list_length', IFNULL(@dbt_hll, 0),
    'threshold_seconds', COALESCE(@long_txn_seconds, 3600)) AS evidence_json,
  'high' AS confidence
FROM information_schema.INNODB_TRX AS t
LEFT JOIN information_schema.PROCESSLIST AS p ON p.ID = t.trx_mysql_thread_id
WHERE TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) >= COALESCE(@long_txn_seconds, 3600);
