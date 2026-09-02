-- check: PG-SEC-008
-- title: Application connections running as superuser
-- priority: 50
-- scope: role
-- cost: 0
-- min_version: 10
-- thresholds: min_connections
WITH conns AS (
  SELECT a.usename, count(*) AS n,
         count(*) FILTER (WHERE a.client_addr IS NOT NULL) AS remote,
         string_agg(DISTINCT coalesce(nullif(a.application_name, ''), 'no application_name'), ', ') AS apps,
         string_agg(DISTINCT coalesce(host(a.client_addr), 'local socket'), ', ') AS addrs
  FROM pg_stat_activity a
  JOIN pg_roles r ON r.rolname = a.usename
  WHERE a.backend_type = 'client backend'
    AND r.rolsuper
    AND coalesce(a.application_name, '') !~* '^(psql|pgAdmin|DBeaver|DataGrip|db-triage|pgcli|TablePlus|Postico)'
  GROUP BY a.usename
)
SELECT 'PG-SEC-008'::text AS check_id,
       'role'::text       AS scope,
       c.usename::text    AS object,
       format('Superuser role %s has %s concurrent connection(s), %s of them from a non-local address (%s), with application names: %s. A superuser bypasses every permission check, every row-level security policy and every event trigger, and can read and write files as the server account. An application connecting this way turns any SQL-injection bug into host compromise. Thresholds: %s concurrent connections, or any remote connection.',
              c.usename, c.n, c.remote, c.addrs, c.apps, :'pg_sec_008_min_connections'::text) AS details,
       json_build_object('role', c.usename, 'connections', c.n, 'remote_connections', c.remote,
                         'application_names', c.apps, 'client_addrs', c.addrs,
                         'threshold_connections', :'pg_sec_008_min_connections'::int,
                         'sampled_at', now())::text AS evidence_json,
       'medium'::text AS confidence
FROM conns c
WHERE c.n >= :'pg_sec_008_min_connections'::int OR c.remote > 0
ORDER BY c.n DESC;
