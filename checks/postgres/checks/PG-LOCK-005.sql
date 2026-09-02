-- check: PG-LOCK-005
-- title: Client transaction open for more than 1 hour
-- priority: 20
-- scope: session
-- cost: 0
-- min_version: 10
-- thresholds: xact_seconds
SELECT 'PG-LOCK-005'::text AS check_id,
       'session'::text     AS scope,
       ('pid:' || a.pid)::text AS object,
       format('pid %s (%s / %s, from %s, database %s) has had a transaction open for %s (threshold %s), currently in state "%s". Its xmin is %s XIDs old, which is the floor below which vacuum cannot clean anywhere in the cluster (see PG-VAC-005). Maintenance statements (VACUUM, CREATE INDEX, REINDEX, CLUSTER, COPY) and base backups are excluded from this check, so this is application work. Current statement: %s',
              a.pid, coalesce(nullif(a.usename, ''), '?'),
              coalesce(nullif(a.application_name, ''), 'no application_name'),
              coalesce(host(a.client_addr), 'local socket'), coalesce(a.datname, '?'),
              justify_interval(date_trunc('second', now() - a.xact_start)),
              (:'pg_lock_005_xact_seconds'::int || ' seconds')::interval,
              coalesce(a.state, '?'),
              coalesce(age(a.backend_xmin)::text, 'not set'),
              left(regexp_replace(coalesce(a.query, ''), '\s+', ' ', 'g'), 200)) AS details,
       json_build_object('pid', a.pid, 'state', a.state, 'usename', a.usename,
                         'application_name', a.application_name, 'datname', a.datname,
                         'xact_seconds', round(extract(epoch FROM now() - a.xact_start))::bigint,
                         'threshold_seconds', :'pg_lock_005_xact_seconds'::int,
                         'backend_xmin_age', CASE WHEN a.backend_xmin IS NULL THEN NULL ELSE age(a.backend_xmin) END,
                         'sampled_at', now())::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_activity a
WHERE a.backend_type = 'client backend'
  AND a.xact_start IS NOT NULL
  AND now() - a.xact_start >= (:'pg_lock_005_xact_seconds'::int || ' seconds')::interval
  AND coalesce(a.query, '') !~* '^\s*(VACUUM|ANALYZE|CREATE\s+(UNIQUE\s+)?INDEX|REINDEX|CLUSTER|COPY|ALTER\s+TABLE\s+\S+\s+SET\s+STATISTICS)'
  AND coalesce(a.application_name, '') !~* '(basebackup|pg_dump|pg_restore|walreceiver|db-triage)'
ORDER BY a.xact_start;
