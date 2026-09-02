-- check: PG-SEC-010
-- title: Roles with elevated attributes
-- priority: 230
-- scope: role
-- cost: 0
SELECT 'PG-SEC-010'::text AS check_id,
       'role'::text       AS scope,
       r.rolname::text    AS object,
       format('Login role %s holds %s. %s Password: %s. Valid until: %s. Member of: %s.',
              r.rolname,
              array_to_string(ARRAY[
                CASE WHEN r.rolcreaterole  THEN 'CREATEROLE' END,
                CASE WHEN r.rolcreatedb    THEN 'CREATEDB' END,
                CASE WHEN r.rolreplication THEN 'REPLICATION' END,
                CASE WHEN r.rolbypassrls   THEN 'BYPASSRLS' END], ', '),
              array_to_string(ARRAY[
                CASE WHEN r.rolcreaterole  THEN 'CREATEROLE can create and alter other roles, and before PostgreSQL 16 could grant itself membership in almost any of them.' END,
                CASE WHEN r.rolreplication THEN 'REPLICATION can open a replication connection and stream the entire cluster, bypassing every table-level grant.' END,
                CASE WHEN r.rolbypassrls   THEN 'BYPASSRLS ignores every row-level security policy.' END], ' '),
              CASE WHEN r.rolpassword IS NULL THEN 'not set' ELSE 'set' END,
              coalesce(r.rolvaliduntil::text, 'no expiry'),
              coalesce((SELECT string_agg(g.rolname, ', ' ORDER BY g.rolname)
                        FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid
                        WHERE m.member = r.oid), 'nothing')) AS details,
       json_build_object('rolname', r.rolname, 'rolcreaterole', r.rolcreaterole,
                         'rolcreatedb', r.rolcreatedb, 'rolreplication', r.rolreplication,
                         'rolbypassrls', r.rolbypassrls,
                         'has_password', (r.rolpassword IS NOT NULL),
                         'rolvaliduntil', r.rolvaliduntil,
                         'member_of', (SELECT string_agg(g.rolname, ';' ORDER BY g.rolname)
                                       FROM pg_auth_members m JOIN pg_roles g ON g.oid = m.roleid
                                       WHERE m.member = r.oid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_roles r
WHERE r.rolcanlogin AND NOT r.rolsuper
  AND (r.rolcreaterole OR r.rolcreatedb OR r.rolreplication OR r.rolbypassrls)
ORDER BY r.rolname;
