-- check: PG-REPL-011
-- title: Standby query conflicts high
-- priority: 50
-- scope: database
-- cost: 0
-- run_on: standby
-- thresholds: conflicts_per_day
WITH win AS (
  SELECT greatest(extract(epoch FROM now() - coalesce(
           (SELECT min(stats_reset) FROM pg_stat_database), pg_postmaster_start_time())) / 86400.0, 0.01) AS days
)
SELECT 'PG-REPL-011'::text AS check_id,
       'database'::text    AS scope,
       c.datname::text     AS object,
       format('%s recovery conflicts in database %s over %s days (%s per day, threshold %s per day): %s tablespace, %s lock, %s snapshot, %s bufferpin, %s deadlock. Queries on this standby are being cancelled to let WAL replay proceed. max_standby_streaming_delay = %s, hot_standby_feedback = %s.',
              to_char(c.confl_tablespace + c.confl_lock + c.confl_snapshot + c.confl_bufferpin + c.confl_deadlock, 'FM999,999,999'),
              c.datname, round(win.days, 1)::text,
              round((c.confl_tablespace + c.confl_lock + c.confl_snapshot + c.confl_bufferpin + c.confl_deadlock) / win.days, 1)::text,
              :'pg_repl_011_conflicts_per_day'::text,
              c.confl_tablespace, c.confl_lock, c.confl_snapshot, c.confl_bufferpin, c.confl_deadlock,
              current_setting('max_standby_streaming_delay'),
              current_setting('hot_standby_feedback')) AS details,
       json_build_object('datname', c.datname,
                         'confl_tablespace', c.confl_tablespace, 'confl_lock', c.confl_lock,
                         'confl_snapshot', c.confl_snapshot, 'confl_bufferpin', c.confl_bufferpin,
                         'confl_deadlock', c.confl_deadlock,
                         'window_days', round(win.days, 2),
                         'conflicts_per_day', round((c.confl_tablespace + c.confl_lock + c.confl_snapshot
                                                   + c.confl_bufferpin + c.confl_deadlock) / win.days, 2),
                         'threshold_per_day', :'pg_repl_011_conflicts_per_day'::numeric,
                         'max_standby_streaming_delay', current_setting('max_standby_streaming_delay'),
                         'hot_standby_feedback', current_setting('hot_standby_feedback'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_database_conflicts c CROSS JOIN win
WHERE pg_is_in_recovery()
  AND (c.confl_tablespace + c.confl_lock + c.confl_snapshot + c.confl_bufferpin + c.confl_deadlock) / win.days
      >= :'pg_repl_011_conflicts_per_day'::numeric
ORDER BY (c.confl_tablespace + c.confl_lock + c.confl_snapshot + c.confl_bufferpin + c.confl_deadlock) DESC;
