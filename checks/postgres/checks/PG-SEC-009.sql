-- check: PG-SEC-009
-- title: Superuser roles
-- priority: 230
-- scope: role
-- cost: 0
SELECT 'PG-SEC-009'::text AS check_id,
       'role'::text       AS scope,
       r.rolname::text    AS object,
       format('Superuser with login: %s. Attributes: %s. Password: %s. Valid until: %s. Connection limit: %s. Currently connected: %s session(s). A superuser bypasses all permission checks; this row exists so a reviewer signs off on the list rather than discovering it.',
              r.rolname,
              array_to_string(ARRAY[
                CASE WHEN r.rolcreaterole  THEN 'CREATEROLE' END,
                CASE WHEN r.rolcreatedb    THEN 'CREATEDB' END,
                CASE WHEN r.rolreplication THEN 'REPLICATION' END,
                CASE WHEN r.rolbypassrls   THEN 'BYPASSRLS' END,
                CASE WHEN r.rolinherit     THEN 'INHERIT' END], ', '),
              CASE WHEN r.rolpassword IS NULL THEN 'not set' ELSE 'set' END,
              coalesce(r.rolvaliduntil::text, 'no expiry'),
              CASE WHEN r.rolconnlimit < 0 THEN 'unlimited' ELSE r.rolconnlimit::text END,
              (SELECT count(*) FROM pg_stat_activity a WHERE a.usename = r.rolname)) AS details,
       json_build_object('rolname', r.rolname, 'rolcreaterole', r.rolcreaterole,
                         'rolcreatedb', r.rolcreatedb, 'rolreplication', r.rolreplication,
                         'rolbypassrls', r.rolbypassrls, 'rolinherit', r.rolinherit,
                         'has_password', (r.rolpassword IS NOT NULL),
                         'rolvaliduntil', r.rolvaliduntil, 'rolconnlimit', r.rolconnlimit,
                         'current_sessions', (SELECT count(*) FROM pg_stat_activity a WHERE a.usename = r.rolname))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_roles r
WHERE r.rolsuper AND r.rolcanlogin
  AND r.rolname NOT IN ('rdsadmin', 'cloudsqladmin', 'cloudsqlsuperuser', 'azure_superuser',
                        'supabase_admin', 'neon_superuser', 'tsdbadmin', 'crunchy_superuser')
ORDER BY r.rolname;
