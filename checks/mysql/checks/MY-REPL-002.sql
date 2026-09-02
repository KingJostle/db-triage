-- check: MY-REPL-002
-- title: Replication threads stopped without an error
-- priority: 10 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: @dbt_repl_io_state / @dbt_repl_sql_state / @dbt_repl_err_no
-- No error recorded means somebody ran STOP REPLICA (STOP SLAVE) and did not
-- start it again — a maintenance window that was never closed, or a script that
-- exited early. Separated from MY-REPL-001 because the fix is different: there
-- is nothing to diagnose, only something to restart, after confirming why.
-- MariaDB caveat as in MY-REPL-001: the receiver thread is invisible to SQL, so
-- a MariaDB replica whose applier is running but whose receiver is stopped will
-- NOT fire here. That gap is listed in reference/checks-mysql.md.
SELECT
  'MY-REPL-002' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replication from ', IFNULL(@dbt_repl_source, 'the configured source'),
         ' is not running and no error is recorded, so it was stopped deliberately. ',
         'Applier thread: ', IFNULL(@dbt_repl_sql_state, 'not reported'), '; ',
         'receiver thread: ', IFNULL(@dbt_repl_io_state,
            'not readable from SQL on this fork'),
         '. Relay logs and the source binary logs keep accumulating while it is stopped; if the source purges a log this replica still needs, it will need a rebuild.') AS details,
  JSON_OBJECT(
    'source', IFNULL(@dbt_repl_source, 'unknown'),
    'io_thread_state', IFNULL(@dbt_repl_io_state, 'unreadable'),
    'sql_thread_state', IFNULL(@dbt_repl_sql_state, 'unreadable'),
    'last_error_number', IFNULL(@dbt_repl_err_no, 0),
    'channels', @dbt_repl_channels) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND IFNULL(@dbt_repl_err_no, 0) = 0
  AND (IFNULL(@dbt_repl_sql_state, 'ON') <> 'ON' OR IFNULL(@dbt_repl_io_state, 'ON') <> 'ON');
