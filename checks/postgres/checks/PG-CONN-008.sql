-- check: PG-CONN-008
-- title: Sessions currently waiting on locks
-- priority: 50
-- scope: cluster
-- cost: 0
-- min_version: 10
-- thresholds: waiting_sessions
WITH w AS (
  SELECT count(*) AS waiting,
         string_agg(DISTINCT coalesce(wait_event, 'unknown'), ', ') AS events,
         max(now() - state_change) AS longest
  FROM pg_stat_activity
  WHERE wait_event_type = 'Lock' AND backend_type = 'client backend'
)
SELECT 'PG-CONN-008'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('%s client sessions are waiting on a lock at snapshot time (threshold %s). Lock types being waited on: %s. The longest has been waiting %s. This is a single sample, so it may be a pile-up in progress or a coincidence; PG-LOCK-001 and PG-LOCK-002 identify the chain and the session at the root of it. deadlock_timeout = %s, log_lock_waits = %s.',
              w.waiting, :'pg_conn_008_waiting_sessions'::text,
              coalesce(w.events, 'none'),
              coalesce(justify_interval(w.longest)::text, 'unknown'),
              current_setting('deadlock_timeout'), current_setting('log_lock_waits')) AS details,
       json_build_object('waiting_sessions', w.waiting,
                         'threshold', :'pg_conn_008_waiting_sessions'::int,
                         'wait_events', w.events,
                         'longest_wait_seconds', round(extract(epoch FROM w.longest))::bigint,
                         'deadlock_timeout', current_setting('deadlock_timeout'),
                         'log_lock_waits', current_setting('log_lock_waits'),
                         'sampled_at', now())::text AS evidence_json,
       'high'::text AS confidence
FROM w
WHERE w.waiting >= :'pg_conn_008_waiting_sessions'::int;
