-- check: PG-CFG-002
-- title: Per-database and per-role setting overrides
-- priority: 200
-- scope: setting
-- cost: 0
SELECT 'PG-CFG-002'::text AS check_id,
       'setting'::text    AS scope,
       format('%s/%s', coalesce(d.datname, 'all databases'), coalesce(r.rolname, 'all roles'))::text AS object,
       format('An override applies to %s in %s: %s. These do not appear in postgresql.conf and do not show up in pg_settings for any other session, so a server that looks correctly configured can still behave differently for one application. Overrides of synchronous_commit, work_mem, statement_timeout, search_path and role attributes are the ones that most often surprise.',
              coalesce('role ' || r.rolname, 'every role'),
              coalesce('database ' || d.datname, 'every database'),
              array_to_string(s.setconfig, '; ')) AS details,
       json_build_object('database', d.datname, 'role', r.rolname,
                         'settings', array_to_string(s.setconfig, ';'),
                         'setting_count', cardinality(s.setconfig))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_db_role_setting s
LEFT JOIN pg_database d ON d.oid = s.setdatabase
LEFT JOIN pg_roles r    ON r.oid = s.setrole
ORDER BY coalesce(d.datname, ''), coalesce(r.rolname, '');
