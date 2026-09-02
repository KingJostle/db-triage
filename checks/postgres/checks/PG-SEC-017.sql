-- check: PG-SEC-017
-- title: Untrusted procedural languages or risky extensions installed
-- priority: 150
-- scope: database
-- cost: 0
SELECT 'PG-SEC-017'::text AS check_id,
       'database'::text   AS scope,
       format('%I.language:%s', current_database(), l.lanname)::text AS object,
       format('Untrusted procedural language %s is installed in database %s. Code written in an untrusted language runs as the operating-system account that owns the server, outside every SQL permission check: it can read and write files, open sockets and run programs. Only superusers can create functions in it by default, so this is a review row rather than a defect - confirm that %s function(s) in this language are all ones you meant to have. EXECUTE on the language handler is granted to: %s.',
              l.lanname, current_database(),
              (SELECT count(*) FROM pg_proc p WHERE p.prolang = l.oid),
              coalesce(array_to_string(l.lanacl, ', '), 'superusers only (no explicit ACL)')) AS details,
       json_build_object('kind', 'language', 'lanname', l.lanname,
                         'function_count', (SELECT count(*) FROM pg_proc p WHERE p.prolang = l.oid),
                         'lanacl', array_to_string(l.lanacl, ';'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_language l
WHERE NOT l.lanpltrusted AND l.lanispl;

SELECT 'PG-SEC-017'::text AS check_id,
       'database'::text   AS scope,
       format('%I.extension:%s', current_database(), e.extname)::text AS object,
       format('Extension %s (version %s, schema %s) is installed in database %s. %s Confirm it is still needed and that EXECUTE on its functions is not held by PUBLIC.',
              e.extname, e.extversion, n.nspname, current_database(),
              CASE e.extname
                WHEN 'file_fdw'  THEN 'file_fdw reads arbitrary files on the server host as the server account and exposes them as tables.'
                WHEN 'adminpack' THEN 'adminpack lets a client write and read files in the data directory over a normal SQL connection.'
                WHEN 'dblink'    THEN 'dblink opens outbound connections from the server; if EXECUTE is held by PUBLIC it can be used to reach services the client cannot reach directly, and to authenticate as the server to local trust rules.'
                WHEN 'postgres_fdw' THEN 'postgres_fdw opens outbound connections from the server to other PostgreSQL servers using credentials stored in user mappings.'
                ELSE 'Review its capabilities against who can execute it.' END) AS details,
       json_build_object('kind', 'extension', 'extname', e.extname, 'extversion', e.extversion,
                         'schema', n.nspname, 'owner', pg_get_userbyid(e.extowner))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE e.extname IN ('adminpack', 'file_fdw', 'dblink', 'postgres_fdw');
