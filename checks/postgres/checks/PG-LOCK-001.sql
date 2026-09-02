-- check: PG-LOCK-001
-- title: Blocking chain: session blocked more than 5 minutes
-- priority: 10
-- scope: session
-- cost: 0
-- min_version: 9.6
-- thresholds: blocked_seconds
SELECT 'PG-LOCK-001'::text AS check_id,
       'session'::text  AS scope,
       ('pid:' || a.pid)::text AS object,
       format('pid %s (%s / %s, from %s) has been blocked for %s (threshold %s) waiting on %s. It is blocked by pid(s) %s. Root blocker pid %s: state %s, transaction open since %s (%s), application %s, query: %s. Blocked query: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'),
              coalesce(nullif(a.application_name, ''), 'no application_name'),
              coalesce(host(a.client_addr), 'local socket'),
              justify_interval(date_trunc('second', now() - a.state_change)),
              (:'pg_lock_001_blocked_seconds'::int || ' seconds')::interval,
              coalesce(a.wait_event_type || '/' || a.wait_event, 'a lock'),
              array_to_string(pg_blocking_pids(a.pid), ', '),
              b.pid, coalesce(b.state, '?'),
              coalesce(b.xact_start::text, 'no transaction'),
              coalesce(justify_interval(date_trunc('second', now() - b.xact_start))::text, 'n/a'),
              coalesce(nullif(b.application_name, ''), 'no application_name'),
              left(regexp_replace(coalesce(b.query, ''), '\s+', ' ', 'g'), 200),
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)) AS details,
       json_build_object('blocked_pid', a.pid, 'blocked_seconds', round(extract(epoch FROM now() - a.state_change))::bigint,
                         'threshold_seconds', :'pg_lock_001_blocked_seconds'::int,
                         'blocking_pids', pg_blocking_pids(a.pid),
                         'root_blocker_pid', b.pid, 'root_blocker_state', b.state,
                         'root_blocker_xact_seconds', round(extract(epoch FROM now() - b.xact_start))::bigint,
                         'root_blocker_application', b.application_name,
                         'wait_event_type', a.wait_event_type, 'wait_event', a.wait_event,
                         'blocked_usename', a.usename, 'blocked_database', a.datname,
                         'sampled_at', now())::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_activity a
LEFT JOIN LATERAL (
  SELECT * FROM pg_stat_activity x
  WHERE x.pid = (pg_blocking_pids(a.pid))[1]
) b ON true
WHERE cardinality(pg_blocking_pids(a.pid)) > 0
  AND a.state_change IS NOT NULL
  AND now() - a.state_change >= (:'pg_lock_001_blocked_seconds'::int || ' seconds')::interval
ORDER BY a.state_change;
