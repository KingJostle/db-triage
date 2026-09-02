-- check: PG-LOCK-010
-- title: Active query running more than 10 minutes
-- priority: 100
-- scope: session
-- cost: 0
-- min_version: 10
-- thresholds: query_seconds
SELECT 'PG-LOCK-010'::text AS check_id,
       'session'::text     AS scope,
       ('pid:' || a.pid)::text AS object,
       format('pid %s (%s / %s, from %s, database %s) has been running one statement for %s (threshold %s). Wait state: %s. Transaction open for %s, xmin age %s. Maintenance statements and backup application names are excluded, so this is either analytics that legitimately takes this long or a query that has found a bad plan. Statement: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'),
              coalesce(nullif(a.application_name, ''), 'no application_name'),
              coalesce(host(a.client_addr), 'local socket'), coalesce(a.datname, '?'),
              justify_interval(date_trunc('second', now() - a.query_start)),
              (:'pg_lock_010_query_seconds'::int || ' seconds')::interval,
              coalesce(a.wait_event_type || '/' || a.wait_event, 'running on CPU'),
              coalesce(justify_interval(date_trunc('second', now() - a.xact_start))::text, 'n/a'),
              coalesce(age(a.backend_xmin)::text, 'not set'),
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)) AS details,
       json_build_object('pid', a.pid, 'usename', a.usename, 'application_name', a.application_name,
                         'datname', a.datname, 'client_addr', host(a.client_addr),
                         'query_seconds', round(extract(epoch FROM now() - a.query_start))::bigint,
                         'threshold_seconds', :'pg_lock_010_query_seconds'::int,
                         'wait_event_type', a.wait_event_type, 'wait_event', a.wait_event,
                         'backend_xmin_age', CASE WHEN a.backend_xmin IS NULL THEN NULL ELSE age(a.backend_xmin) END,
                         'sampled_at', now())::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_activity a
WHERE a.backend_type = 'client backend' AND a.state = 'active'
  AND a.query_start IS NOT NULL
  AND now() - a.query_start >= (:'pg_lock_010_query_seconds'::int || ' seconds')::interval
  AND coalesce(a.query, '') !~* '^\s*(VACUUM|ANALYZE|CREATE\s+(UNIQUE\s+)?INDEX|REINDEX|CLUSTER|COPY)'
  AND coalesce(a.application_name, '') !~* '(basebackup|pg_dump|pg_restore|walreceiver|db-triage)'
ORDER BY a.query_start;
