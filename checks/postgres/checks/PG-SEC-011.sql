-- check: PG-SEC-011
-- title: Non-superuser roles with server file access
-- priority: 100
-- scope: role
-- cost: 0
-- min_version: 11
SELECT 'PG-SEC-011'::text AS check_id,
       'role'::text       AS scope,
       m.member_name::text AS object,
       format('Role %s is a member of %s. %s That is equivalent to a superuser in practice, without appearing in the superuser list (PG-SEC-009). Login: %s. Currently connected: %s session(s).',
              m.member_name, m.granted_role,
              CASE m.granted_role
                WHEN 'pg_read_server_files' THEN 'It can read any file the server account can read, including postgresql.conf, pg_hba.conf, the server''s TLS private key, and anything else on the host filesystem.'
                WHEN 'pg_write_server_files' THEN 'It can write any file the server account can write, which includes overwriting configuration and libraries the server loads.'
                WHEN 'pg_execute_server_program' THEN 'It can run arbitrary programs on the host as the server account through COPY ... FROM PROGRAM.'
                ELSE '' END,
              m.can_login,
              (SELECT count(*) FROM pg_stat_activity a WHERE a.usename = m.member_name)) AS details,
       json_build_object('role', m.member_name, 'granted_role', m.granted_role,
                         'can_login', m.can_login,
                         'current_sessions', (SELECT count(*) FROM pg_stat_activity a WHERE a.usename = m.member_name))::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT member.rolname AS member_name, grantee.rolname AS granted_role, member.rolcanlogin AS can_login
  FROM pg_auth_members am
  JOIN pg_roles grantee ON grantee.oid = am.roleid
  JOIN pg_roles member  ON member.oid  = am.member
  WHERE grantee.rolname IN ('pg_read_server_files', 'pg_write_server_files', 'pg_execute_server_program')
    AND NOT member.rolsuper
) m
ORDER BY m.member_name, m.granted_role;
