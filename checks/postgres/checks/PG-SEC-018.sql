-- check: PG-SEC-018
-- title: Login roles with no password set
-- priority: 230
-- scope: role
-- cost: 0
-- requires: superuser
-- pg_authid.rolpassword is tested for NULL only. Its value is never read into a
-- column, a details string, or the evidence object.
SELECT 'PG-SEC-018'::text AS check_id,
       'role'::text       AS scope,
       a.rolname::text    AS object,
       format('Login role %s has no password set. That is correct when it authenticates by peer, cert, LDAP, GSSAPI or an IAM plugin, and it is a problem when it means the role was created and forgotten, or when a pg_hba rule would let it in with trust (PG-SEC-001/007). Attributes: %s. Valid until: %s. Currently connected: %s session(s). db-triage never reads the password column itself - only whether it is null.',
              a.rolname,
              coalesce(nullif(array_to_string(ARRAY[
                CASE WHEN a.rolsuper       THEN 'SUPERUSER' END,
                CASE WHEN a.rolcreaterole  THEN 'CREATEROLE' END,
                CASE WHEN a.rolcreatedb    THEN 'CREATEDB' END,
                CASE WHEN a.rolreplication THEN 'REPLICATION' END,
                CASE WHEN a.rolbypassrls   THEN 'BYPASSRLS' END], ', '), ''), 'none'),
              coalesce(a.rolvaliduntil::text, 'no expiry'),
              (SELECT count(*) FROM pg_stat_activity s WHERE s.usename = a.rolname)) AS details,
       json_build_object('rolname', a.rolname, 'has_password', false,
                         'rolsuper', a.rolsuper, 'rolcreaterole', a.rolcreaterole,
                         'rolcreatedb', a.rolcreatedb, 'rolreplication', a.rolreplication,
                         'rolbypassrls', a.rolbypassrls, 'rolvaliduntil', a.rolvaliduntil,
                         'current_sessions', (SELECT count(*) FROM pg_stat_activity s WHERE s.usename = a.rolname))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_authid a
WHERE a.rolcanlogin AND a.rolpassword IS NULL
ORDER BY a.rolsuper DESC, a.rolname;
