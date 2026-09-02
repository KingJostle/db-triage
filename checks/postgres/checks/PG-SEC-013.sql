-- check: PG-SEC-013
-- title: PUBLIC can CREATE in schema public
-- priority: 100
-- scope: schema
-- cost: 0
SELECT 'PG-SEC-013'::text AS check_id,
       'schema'::text     AS scope,
       format('%I.public', current_database())::text AS object,
       format('PUBLIC holds CREATE on schema public in database %s, so every role that can connect can create objects there. Combined with a search_path that puts public before pg_catalog - which is the default - any such role can define a function or operator that shadows a built-in one and have it executed by other users, including superusers. That is CVE-2018-1058. PostgreSQL 15 removed this grant for new databases; a database created earlier, or restored from an earlier dump, keeps it. Current ACL on schema public: %s. Roles that can log in: %s.',
              current_database(),
              coalesce(array_to_string(n.nspacl, ', '), 'default (owner only)'),
              (SELECT count(*) FROM pg_roles WHERE rolcanlogin)) AS details,
       json_build_object('schema', 'public', 'database', current_database(),
                         'nspacl', array_to_string(n.nspacl, ';'),
                         'owner', pg_get_userbyid(n.nspowner),
                         'login_roles', (SELECT count(*) FROM pg_roles WHERE rolcanlogin),
                         'server_version_num', current_setting('server_version_num')::int)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_namespace n
WHERE n.nspname = 'public'
  AND EXISTS (SELECT 1 FROM aclexplode(n.nspacl) a
              WHERE a.grantee = 0 AND a.privilege_type = 'CREATE');
