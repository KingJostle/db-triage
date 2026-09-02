-- check: MY-REPL-008
-- title: Replication errors are being skipped
-- priority: 50 | category: REPL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: (none)
-- reads: @dbt_v_replica_skip_errors / @dbt_v_slave_skip_errors,
--        @dbt_v_replica_exec_mode / @dbt_v_slave_exec_mode
-- Name divergence: MySQL 8.0.26+ renamed slave_skip_errors to
-- replica_skip_errors and slave_exec_mode to replica_exec_mode, keeping the old
-- names as deprecated aliases until 8.4 removed them. MariaDB keeps only the
-- slave_* spelling. Both spellings are read from the bundle and COALESCEd, so
-- the check works on 5.7, 8.0, 8.4, 9.x and every MariaDB.
-- Either setting makes replication continue past an error instead of stopping,
-- which converts a loud failure into silent, permanent divergence. IDEMPOTENT
-- exec mode turns duplicate-key and not-found row events into no-ops.
SELECT
  'MY-REPL-008' AS check_id,
  'setting'     AS scope,
  IF(LOWER(IFNULL(v.skip, '')) NOT IN ('', 'off'), 'replica_skip_errors', 'replica_exec_mode') AS object,
  CONCAT('Replication is configured to continue past errors: ',
         CONCAT_WS('; ',
           IF(LOWER(IFNULL(v.skip, '')) NOT IN ('', 'off'),
              CONCAT('skip_errors = ', v.skip), NULL),
           IF(UPPER(IFNULL(v.mode, 'STRICT')) = 'IDEMPOTENT',
              'exec_mode = IDEMPOTENT (duplicate-key and row-not-found events are silently ignored)', NULL)),
         '. Rows that fail to apply are dropped without stopping the applier, so this replica diverges from its source and nothing reports it. ',
         'A checksum tool (pt-table-checksum, mariadb-check) is the only way to find out what is already different.') AS details,
  JSON_OBJECT(
    'skip_errors', IFNULL(v.skip, 'n/a'),
    'exec_mode', IFNULL(v.mode, 'n/a'),
    'is_replica', IFNULL(@dbt_is_replica, 0)) AS evidence_json,
  'high' AS confidence
FROM (
  SELECT COALESCE(@dbt_v_replica_skip_errors, @dbt_v_slave_skip_errors) AS skip,
         COALESCE(@dbt_v_replica_exec_mode, @dbt_v_slave_exec_mode)     AS mode
) AS v
WHERE LOWER(IFNULL(v.skip, '')) NOT IN ('', 'off')
   OR UPPER(IFNULL(v.mode, 'STRICT')) = 'IDEMPOTENT';
