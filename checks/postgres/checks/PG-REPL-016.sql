-- check: PG-REPL-016
-- title: hot_standby_feedback on with long-running standby queries
-- priority: 150
-- scope: cluster
-- cost: 0
-- run_on: standby
-- thresholds: query_seconds
SELECT 'PG-REPL-016'::text AS check_id,
       'cluster'::text     AS scope,
       ('pid:' || a.pid)::text AS object,
       format('hot_standby_feedback = on and pid %s (%s / %s) has been running a query for %s (threshold %s). While that query runs, this standby reports its oldest xmin back to the primary, which stops the primary from vacuuming anything newer: the cost of not cancelling this query is bloat and a rising xmin horizon on the primary (PG-VAC-005 there, not here). Query: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'), coalesce(nullif(a.application_name, ''), 'no application_name'),
              justify_interval(date_trunc('second', now() - a.query_start)),
              (:'pg_repl_016_query_seconds'::int || ' seconds')::interval,
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)) AS details,
       json_build_object('pid', a.pid, 'usename', a.usename, 'application_name', a.application_name,
                         'query_seconds', round(extract(epoch FROM now() - a.query_start))::bigint,
                         'threshold_seconds', :'pg_repl_016_query_seconds'::int,
                         'backend_xmin_age', CASE WHEN a.backend_xmin IS NULL THEN NULL ELSE age(a.backend_xmin) END,
                         'hot_standby_feedback', current_setting('hot_standby_feedback'),
                         'client_addr', host(a.client_addr))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_activity a
WHERE pg_is_in_recovery()
  AND current_setting('hot_standby_feedback') = 'on'
  AND a.state = 'active' AND a.backend_type = 'client backend'
  AND a.query_start IS NOT NULL
  AND now() - a.query_start >= (:'pg_repl_016_query_seconds'::int || ' seconds')::interval
ORDER BY a.query_start;
