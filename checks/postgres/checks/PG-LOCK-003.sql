-- check: PG-LOCK-003
-- title: Idle in transaction for more than 1 hour
-- priority: 10
-- scope: session
-- cost: 0
-- min_version: 10
-- thresholds: idle_seconds
SELECT 'PG-LOCK-003'::text AS check_id,
       'session'::text  AS scope,
       ('pid:' || a.pid)::text AS object,
       format('pid %s (%s / %s, from %s, database %s) has been in state "%s" for %s (threshold %s). Its transaction opened at %s and has been open for %s. It holds every lock the transaction has taken and pins the xmin horizon at age %s, so vacuum cannot remove any row version newer than that anywhere in the cluster (PG-VAC-005), and any DDL that needs a lock on the same objects queues behind it. Last statement: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'),
              coalesce(nullif(a.application_name, ''), 'no application_name'),
              coalesce(host(a.client_addr), 'local socket'), coalesce(a.datname, '?'),
              a.state, justify_interval(date_trunc('second', now() - a.state_change)),
              (:'pg_lock_003_idle_seconds'::int || ' seconds')::interval,
              coalesce(a.xact_start::text, 'unknown'),
              coalesce(justify_interval(date_trunc('second', now() - a.xact_start))::text, 'unknown'),
              coalesce(age(a.backend_xmin)::text, 'none held'),
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)) AS details,
       json_build_object('pid', a.pid, 'state', a.state, 'usename', a.usename,
                         'application_name', a.application_name, 'datname', a.datname,
                         'client_addr', host(a.client_addr),
                         'idle_seconds', round(extract(epoch FROM now() - a.state_change))::bigint,
                         'threshold_seconds', :'pg_lock_003_idle_seconds'::int,
                         'xact_seconds', round(extract(epoch FROM now() - a.xact_start))::bigint,
                         'backend_xmin_age', CASE WHEN a.backend_xmin IS NULL THEN NULL ELSE age(a.backend_xmin) END,
                         'sampled_at', now())::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_activity a
WHERE a.state LIKE 'idle in transaction%'
  AND a.state_change IS NOT NULL
  AND now() - a.state_change >= (:'pg_lock_003_idle_seconds'::int || ' seconds')::interval
ORDER BY a.state_change;
