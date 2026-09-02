-- check: PG-REL-008
-- title: Extension updates available
-- priority: 150
-- scope: database
-- cost: 0
SELECT 'PG-REL-008'::text AS check_id,
       'database'::text   AS scope,
       format('%I.extension:%s', current_database(), e.extname)::text AS object,
       format('Extension %s is installed at version %s in database %s while the files on this server provide %s. The binary and the SQL objects are therefore out of step: the shared library has been upgraded (usually by a package update) but ALTER EXTENSION %s UPDATE was never run, so any function signature, view or default that changed between the two versions is still the old one. That is where "the extension worked yesterday" comes from after a routine package upgrade. Schema %s, owner %s.',
              e.extname, e.extversion, current_database(), a.default_version,
              quote_ident(e.extname), n.nspname, pg_get_userbyid(e.extowner)) AS details,
       json_build_object('extname', e.extname, 'installed_version', e.extversion,
                         'default_version', a.default_version,
                         'schema', n.nspname, 'owner', pg_get_userbyid(e.extowner),
                         'database', current_database())::text AS evidence_json,
       'high'::text AS confidence
FROM pg_extension e
JOIN pg_available_extensions a ON a.name = e.extname
JOIN pg_namespace n            ON n.oid = e.extnamespace
WHERE a.default_version IS DISTINCT FROM e.extversion
ORDER BY e.extname;
