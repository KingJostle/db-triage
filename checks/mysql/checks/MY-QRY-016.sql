-- check: MY-QRY-016
-- title: Per-account workload profile (MariaDB user statistics)
-- priority: 240 | category: QRY | scope: role | cost: 1 | pass: inventory
-- engine: mariadb | requires: (none)
-- thresholds: top_n=15
-- reads: information_schema.USER_STATISTICS, @dbt_v_userstat
-- NOT in the design's §5.2 table. Added because MariaDB's userstat feature has
-- no MySQL or PostgreSQL equivalent and answers a question the digest tables
-- cannot: WHICH ACCOUNT is responsible for the load. The digest table aggregates
-- by statement text across all accounts, so a shared application user and a
-- runaway reporting job are indistinguishable there.
-- Availability: information_schema.USER_STATISTICS exists on MariaDB 10.x
-- (verified on 10.11) and on Percona Server. It is EMPTY unless the userstat
-- variable is ON, which it is not by default — hence the gate on @dbt_v_userstat
-- as well as on the table, and the note in the finding when it is off.
-- Oracle MySQL has no equivalent at all, so the check is engine=mariadb.
-- CPU_TIME and BUSY_TIME are in seconds and are cumulative since the counters
-- were last flushed, which on a server nobody has flushed means since restart.
SET @dbt_q := "
SELECT
  'MY-QRY-016' AS check_id,
  'role'       AS scope,
  u.USER       AS object,
  CONCAT('Account ''', u.USER, ''': ', FORMAT(u.TOTAL_CONNECTIONS, 0),
         ' connection(s) since counters were reset, ', u.CONCURRENT_CONNECTIONS,
         ' concurrent now, ', ROUND(u.BUSY_TIME, 1), ' s busy / ',
         ROUND(u.CPU_TIME, 1), ' s CPU. ',
         'Rows read ', FORMAT(u.ROWS_READ, 0), ', sent ', FORMAT(u.ROWS_SENT, 0),
         ' (ratio ', ROUND(u.ROWS_READ / GREATEST(u.ROWS_SENT, 1), 1), '), ',
         'inserted ', FORMAT(u.ROWS_INSERTED, 0), ', updated ', FORMAT(u.ROWS_UPDATED, 0),
         ', deleted ', FORMAT(u.ROWS_DELETED, 0), '. ',
         'Commands: ', FORMAT(u.SELECT_COMMANDS, 0), ' select, ',
         FORMAT(u.UPDATE_COMMANDS, 0), ' update, ', FORMAT(u.OTHER_COMMANDS, 0), ' other. ',
         'Transactions: ', FORMAT(u.COMMIT_TRANSACTIONS, 0), ' committed, ',
         FORMAT(u.ROLLBACK_TRANSACTIONS, 0), ' rolled back. ',
         'Denied connections ', u.DENIED_CONNECTIONS, ', access denied ', u.ACCESS_DENIED,
         ', lost connections ', u.LOST_CONNECTIONS, ', TLS connections ',
         FORMAT(u.TOTAL_SSL_CONNECTIONS, 0), ' of ', FORMAT(u.TOTAL_CONNECTIONS, 0), '. ',
         'This is the per-account view the statement digest cannot give: digests aggregate by statement text across every account, so a shared application user and a runaway report look identical there.') AS details,
  JSON_OBJECT(
    'user', u.USER,
    'total_connections', u.TOTAL_CONNECTIONS,
    'concurrent_connections', u.CONCURRENT_CONNECTIONS,
    'busy_seconds', ROUND(u.BUSY_TIME, 2),
    'cpu_seconds', ROUND(u.CPU_TIME, 2),
    'rows_read', u.ROWS_READ,
    'rows_sent', u.ROWS_SENT,
    'read_per_sent', ROUND(u.ROWS_READ / GREATEST(u.ROWS_SENT, 1), 2),
    'rows_inserted', u.ROWS_INSERTED,
    'rows_updated', u.ROWS_UPDATED,
    'rows_deleted', u.ROWS_DELETED,
    'select_commands', u.SELECT_COMMANDS,
    'update_commands', u.UPDATE_COMMANDS,
    'commit_transactions', u.COMMIT_TRANSACTIONS,
    'rollback_transactions', u.ROLLBACK_TRANSACTIONS,
    'denied_connections', u.DENIED_CONNECTIONS,
    'access_denied', u.ACCESS_DENIED,
    'ssl_connections', u.TOTAL_SSL_CONNECTIONS,
    'bytes_received', u.BYTES_RECEIVED,
    'bytes_sent', u.BYTES_SENT,
    'binlog_bytes_written', u.BINLOG_BYTES_WRITTEN) AS evidence_json,
  @dbt_counter_conf AS confidence
FROM information_schema.USER_STATISTICS AS u
ORDER BY u.BUSY_TIME DESC
LIMIT 15";
SET @dbt_q := IF(IFNULL(@dbt_has_user_statistics, 0) = 1
                 AND UPPER(IFNULL(@dbt_v_userstat, 'OFF')) IN ('ON', '1'), @dbt_q, 'DO 1');
PREPARE dbt_stmt FROM @dbt_q; EXECUTE dbt_stmt; DEALLOCATE PREPARE dbt_stmt;
