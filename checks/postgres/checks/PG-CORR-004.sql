-- check: PG-CORR-004
-- title: Data checksums disabled
-- priority: 50
-- scope: cluster
-- cost: 0
SELECT 'PG-CORR-004'::text     AS check_id,
       'cluster'::text         AS scope,
       'data_checksums'::text  AS object,
       format('data_checksums = off. Pages carry no checksum, so storage-level corruption is detected only when it happens to break a structure Postgres validates: a torn page, a flipped bit inside a value, or a silently truncated read returns wrong answers instead of an error. Cluster holds %s across %s databases. Enabling requires pg_checksums with the cluster shut down (PostgreSQL 12 and newer) or a dump and reload. full_page_writes = %s.',
              pg_size_pretty((SELECT sum(pg_database_size(oid)) FROM pg_database)),
              (SELECT count(*) FROM pg_database WHERE datallowconn),
              current_setting('full_page_writes')) AS details,
       json_build_object('data_checksums', 'off',
                         'cluster_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database),
                         'database_count', (SELECT count(*) FROM pg_database WHERE datallowconn),
                         'full_page_writes', current_setting('full_page_writes'),
                         'server_version_num', current_setting('server_version_num')::int)::text AS evidence_json,
       'high'::text AS confidence
WHERE current_setting('data_checksums') = 'off';
