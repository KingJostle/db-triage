-- check: PG-LOCK-008
-- title: Deadlocks occurring regularly
-- priority: 150
-- scope: database
-- cost: 0
-- thresholds: deadlocks_per_day, min_deadlocks
WITH w AS (
  SELECT d.datname, d.deadlocks, d.stats_reset,
         greatest(extract(epoch FROM now() - coalesce(d.stats_reset, pg_postmaster_start_time())) / 86400.0, 0.01) AS days
  FROM pg_stat_database d WHERE d.datname IS NOT NULL
)
SELECT 'PG-LOCK-008'::text AS check_id,
       'database'::text    AS scope,
       w.datname::text     AS object,
       format('%s deadlocks in database %s over %s days (%s per day, thresholds %s per day and %s total), counted since %s. A deadlock is always an application lock-ordering bug: two transactions took the same locks in different orders and PostgreSQL killed one of them. The victim gets an error, so the cost is user-visible even though the server is fine. log_lock_waits = %s and deadlock_timeout = %s control whether the server logs the graph you need to find the pair of statements.',
              to_char(w.deadlocks, 'FM999,999,999'), w.datname, round(w.days, 1)::text,
              round(w.deadlocks / w.days, 2)::text,
              :'pg_lock_008_deadlocks_per_day'::text, :'pg_lock_008_min_deadlocks'::text,
              coalesce(w.stats_reset::text, 'the last statistics reset'),
              current_setting('log_lock_waits'), current_setting('deadlock_timeout')) AS details,
       json_build_object('datname', w.datname, 'deadlocks', w.deadlocks,
                         'window_days', round(w.days, 2),
                         'deadlocks_per_day', round(w.deadlocks / w.days, 3),
                         'threshold_per_day', :'pg_lock_008_deadlocks_per_day'::numeric,
                         'threshold_total', :'pg_lock_008_min_deadlocks'::bigint,
                         'stats_reset', w.stats_reset,
                         'log_lock_waits', current_setting('log_lock_waits'),
                         'deadlock_timeout', current_setting('deadlock_timeout'))::text AS evidence_json,
       'medium'::text AS confidence
FROM w
WHERE w.deadlocks >= :'pg_lock_008_min_deadlocks'::bigint
  AND w.deadlocks / w.days >= :'pg_lock_008_deadlocks_per_day'::numeric
ORDER BY w.deadlocks DESC;
