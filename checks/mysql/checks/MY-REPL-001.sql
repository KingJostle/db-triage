-- check: MY-REPL-001
-- title: Replication stopped with an error
-- priority: 1 | category: REPL | scope: replica | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: SELECT ON performance_schema.*
-- thresholds: (none)
-- reads: @dbt_repl_io_state / @dbt_repl_sql_state / @dbt_repl_err_* (01_session.sql §6c)
-- Fork divergence is resolved in 01_session.sql. On MariaDB the receiver (I/O)
-- thread state is not readable from SQL at all, so @dbt_repl_io_state is NULL
-- and the details say which threads were actually observed rather than implying
-- a clean receiver. The applier state and its last error ARE readable on both.
-- A replica stopped with an error is a failover target that is silently stale:
-- the monitoring dashboards still show the host up, and the data is frozen at
-- the moment the error hit.
SELECT
  'MY-REPL-001' AS check_id,
  'replica'     AS scope,
  IFNULL(@dbt_repl_source, 'replication') AS object,
  CONCAT('Replication from ', IFNULL(@dbt_repl_source, 'the configured source'),
         ' is stopped with error ', @dbt_repl_err_no, ': ',
         SUBSTRING(IFNULL(@dbt_repl_err_msg, '(no message recorded)'), 1, 300),
         ' (last error at ', IFNULL(CAST(@dbt_repl_err_ts AS CHAR), 'unknown'), '). ',
         'Applier thread: ', IFNULL(@dbt_repl_sql_state, 'not reported'), '; ',
         'receiver thread: ', IFNULL(@dbt_repl_io_state,
            'not readable from SQL on this fork — check SHOW SLAVE STATUS / SHOW REPLICA STATUS'),
         '. This replica has not applied anything since; it is not a usable failover target.') AS details,
  JSON_OBJECT(
    'source', IFNULL(@dbt_repl_source, 'unknown'),
    'io_thread_state', IFNULL(@dbt_repl_io_state, 'unreadable'),
    'sql_thread_state', IFNULL(@dbt_repl_sql_state, 'unreadable'),
    'last_error_number', @dbt_repl_err_no,
    'last_error_message', SUBSTRING(IFNULL(@dbt_repl_err_msg, ''), 1, 500),
    'last_error_timestamp', CAST(@dbt_repl_err_ts AS CHAR),
    'channels', @dbt_repl_channels) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE IFNULL(@dbt_is_replica, 0) = 1
  AND IFNULL(@dbt_repl_err_no, 0) <> 0
  AND (IFNULL(@dbt_repl_sql_state, 'ON') <> 'ON' OR IFNULL(@dbt_repl_io_state, 'ON') <> 'ON');
