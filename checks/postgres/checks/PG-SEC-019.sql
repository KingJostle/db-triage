-- check: PG-SEC-019
-- title: Login roles with expired passwords
-- priority: 200
-- scope: role
-- cost: 0
SELECT 'PG-SEC-019'::text AS check_id,
       'role'::text       AS scope,
       r.rolname::text    AS object,
       format('Login role %s has rolvaliduntil = %s, which passed %s ago. The role can no longer authenticate with a password, but it still exists and still holds every grant it was given, so it will silently come back to life the moment someone extends the expiry. Attributes: %s. Grants: member of %s. Currently connected: %s session(s).',
              r.rolname, r.rolvaliduntil,
              justify_interval(date_trunc('second', now() - r.rolvaliduntil)),
              coalesce(nullif(array_to_string(ARRAY[
                CASE WHEN r.rolsuper       THEN 'SUPERUSER' END,
                CASE WHEN r.rolcreaterole  THEN 'CREATEROLE' END,
                CASE WHEN r.rolcreatedb    THEN 'CREATEDB' END,
                CASE WHEN r.rolreplication THEN 'REPLICATION' END], ', '), ''), 'none'),
              coalesce((SELECT string_agg(g.rolname, ', ' ORDER BY g.rolname)
                        FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid
                        WHERE m.member = r.oid), 'nothing'),
              (SELECT count(*) FROM pg_stat_activity a WHERE a.usename = r.rolname)) AS details,
       json_build_object('rolname', r.rolname, 'rolvaliduntil', r.rolvaliduntil,
                         'expired_days', round(extract(epoch FROM now() - r.rolvaliduntil) / 86400)::int,
                         'rolsuper', r.rolsuper,
                         'member_of', (SELECT string_agg(g.rolname, ';' ORDER BY g.rolname)
                                       FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid
                                       WHERE m.member = r.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_roles r
WHERE r.rolcanlogin AND r.rolvaliduntil IS NOT NULL AND r.rolvaliduntil < now()
ORDER BY r.rolvaliduntil;
