-- check: MY-REL-008
-- title: Error log verbosity reduced
-- priority: 150 | category: REL | scope: setting | cost: 0 | pass: fast
-- engine: mysql,mariadb | requires: (none)
-- thresholds: min_verbosity=2
-- reads: @dbt_v_log_error_verbosity (MySQL 5.7+), @dbt_v_log_warnings (MariaDB)
-- Fork divergence in both name and scale, which is why both come from the bundle:
--   MySQL 5.7+   log_error_verbosity: 1 = errors only, 2 = errors + warnings
--                (the default), 3 = + notes
--   MariaDB      log_warnings: 0 = errors only, 1 = + a few warnings (the
--                default), 2 = + aborted connections and access-denied, 3+ = more
-- The two scales are not comparable, so each is judged against its own default
-- and the finding says which variable it read.
-- At the lowest setting the error log records almost nothing: no aborted
-- connection detail (MY-CONN-004 then has counters with no explanation), no
-- InnoDB warnings short of a hard error, and on MySQL none of the messages
-- MY-CORR-001 and MY-CORR-002 look for. The log is the only record that survives
-- a restart, and turning it down is usually done to quieten disk noise from
-- something that deserved fixing instead.
SELECT
  'MY-REL-008' AS check_id,
  'setting'    AS scope,
  IF(@dbt_v_log_error_verbosity IS NOT NULL, 'log_error_verbosity', 'log_warnings') AS object,
  CONCAT(IF(@dbt_v_log_error_verbosity IS NOT NULL,
            CONCAT('log_error_verbosity = ', @dbt_v_log_error_verbosity,
                   ' (MySQL scale: 1 = errors only, 2 = errors and warnings — the default, 3 = also notes)'),
            CONCAT('log_warnings = ', @dbt_v_log_warnings,
                   ' (MariaDB scale: 0 = errors only, 1 = the default, 2 = also aborted connections and access-denied)')),
         '. At this level the error log records almost nothing beyond hard failures: no aborted-connection detail (so MY-CONN-004 gives counters with no explanation), no InnoDB warnings short of an error, and ',
         IF(@dbt_is_mariadb,
            'no access-denied records for a security review.',
            'none of the messages MY-CORR-001 and MY-CORR-002 search for.'),
         ' The error log is the only diagnostic record that survives a restart. log_error = ',
         @@GLOBAL.log_error, '.') AS details,
  JSON_OBJECT(
    'log_error_verbosity', IFNULL(@dbt_v_log_error_verbosity, 'n/a'),
    'log_warnings', IFNULL(@dbt_v_log_warnings, 'n/a'),
    'log_error', @@GLOBAL.log_error,
    'fork', @dbt_fork,
    'threshold', COALESCE(@min_verbosity, 2)) AS evidence_json,
  'high' AS confidence
FROM DUAL
WHERE (@dbt_v_log_error_verbosity IS NOT NULL
       AND CAST(@dbt_v_log_error_verbosity AS SIGNED) < COALESCE(@min_verbosity, 2))
   OR (@dbt_v_log_error_verbosity IS NULL AND @dbt_v_log_warnings IS NOT NULL
       AND CAST(@dbt_v_log_warnings AS SIGNED) < 1);
