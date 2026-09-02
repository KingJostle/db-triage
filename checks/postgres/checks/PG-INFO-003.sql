-- check: PG-INFO-003
-- title: Installed extensions
-- priority: 250
-- scope: database
-- cost: 0
SELECT 'PG-INFO-003'::text AS check_id,
       'database'::text    AS scope,
       format('%I.extension:%s', current_database(), e.extname)::text AS object,
       format('%s version %s in schema %s, owned by %s. Server provides %s%s. %s%s',
              e.extname, e.extversion, n.nspname, pg_get_userbyid(e.extowner),
              coalesce(a.default_version, 'no version'),
              CASE WHEN a.default_version IS DISTINCT FROM e.extversion THEN ' (an update is available, PG-REL-008)' ELSE '' END,
              coalesce(nullif(a.comment, ''), 'No description.'),
              CASE WHEN current_setting('shared_preload_libraries') LIKE '%' || e.extname || '%'
                   THEN ' Loaded via shared_preload_libraries.' ELSE '' END) AS details,
       json_build_object('extname', e.extname, 'installed_version', e.extversion,
                         'default_version', a.default_version, 'schema', n.nspname,
                         'owner', pg_get_userbyid(e.extowner),
                         'preloaded', current_setting('shared_preload_libraries') LIKE '%' || e.extname || '%',
                         'update_available', a.default_version IS DISTINCT FROM e.extversion,
                         'comment', a.comment, 'database', current_database())::text AS evidence_json,
       'high'::text AS confidence
FROM pg_extension e
JOIN pg_namespace n            ON n.oid = e.extnamespace
LEFT JOIN pg_available_extensions a ON a.name = e.extname
ORDER BY e.extname;
