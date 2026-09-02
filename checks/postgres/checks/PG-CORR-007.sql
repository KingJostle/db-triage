-- check: PG-CORR-007
-- title: No integrity-verification tooling installed (amcheck)
-- priority: 100
-- scope: database
-- cost: 0
-- min_version: 10
SELECT 'PG-CORR-007'::text  AS check_id,
       'database'::text     AS scope,
       current_database()::text AS object,
       format('amcheck is available on this server (version %s) but is not installed in database %s. Nothing here can verify that a B-tree index still agrees with its heap; a collation change (PG-CORR-006), a storage fault, or a bad restore is discovered by a user getting wrong answers. data_checksums = %s. This database holds %s across %s indexes.',
              a.default_version, current_database(), current_setting('data_checksums'),
              pg_size_pretty(pg_database_size(current_database())),
              (SELECT count(*) FROM pg_index)) AS details,
       json_build_object('amcheck_available_version', a.default_version,
                         'amcheck_installed', false,
                         'data_checksums', current_setting('data_checksums'),
                         'database_bytes', pg_database_size(current_database()),
                         'index_count', (SELECT count(*) FROM pg_index))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_available_extensions a
WHERE a.name = 'amcheck'
  AND NOT EXISTS (SELECT 1 FROM pg_extension e WHERE e.extname = 'amcheck');
