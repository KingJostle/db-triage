-- check: PG-REL-007
-- title: Diagnostic logging off
-- priority: 150
-- scope: setting
-- cost: 0
WITH gaps AS (
  SELECT array_remove(ARRAY[
    CASE WHEN current_setting('log_checkpoints') = 'off'
         THEN 'log_checkpoints = off (no record of when checkpoints ran, how long they took, or how many buffers they wrote - the default before PostgreSQL 15)' END,
    CASE WHEN current_setting('log_lock_waits') = 'off'
         THEN 'log_lock_waits = off (a session that waits longer than deadlock_timeout for a lock is never logged, so blocking chains leave no trace after the fact)' END,
    CASE WHEN (SELECT setting::int FROM pg_settings WHERE name = 'log_autovacuum_min_duration') = -1
         THEN 'log_autovacuum_min_duration = -1 (no autovacuum run is ever logged, so there is no way to see which tables it works on or how long it takes)' END,
    CASE WHEN (SELECT setting::int FROM pg_settings WHERE name = 'log_temp_files') = -1
         THEN 'log_temp_files = -1 (temp-file spills are counted in pg_stat_database but never attributed to a statement in the log)' END,
    CASE WHEN current_setting('log_line_prefix') NOT LIKE '%\%m%'
         THEN 'log_line_prefix has no %m (log lines carry no timestamp)' END,
    CASE WHEN current_setting('log_line_prefix') NOT LIKE '%\%p%'
         THEN 'log_line_prefix has no %p (log lines carry no process id, so lines from one session cannot be grouped)' END
  ], NULL) AS missing
)
SELECT 'PG-REL-007'::text AS check_id,
       'setting'::text    AS scope,
       'logging'::text    AS object,
       format('%s diagnostic logging setting(s) leave a gap: %s. None of these costs measurable performance; each one is evidence that will not exist the next time something goes wrong at 3am. Current log_line_prefix: %s.',
              cardinality(g.missing),
              array_to_string(g.missing, '; '),
              quote_literal(current_setting('log_line_prefix'))) AS details,
       json_build_object('missing', array_to_string(g.missing, ';'),
                         'log_checkpoints', current_setting('log_checkpoints'),
                         'log_lock_waits', current_setting('log_lock_waits'),
                         'log_autovacuum_min_duration', current_setting('log_autovacuum_min_duration'),
                         'log_temp_files', current_setting('log_temp_files'),
                         'log_line_prefix', current_setting('log_line_prefix'))::text AS evidence_json,
       'high'::text AS confidence
FROM gaps g
WHERE cardinality(g.missing) > 0;
