-- check: PG-INFO-011
-- title: Tablespaces
-- priority: 250
-- scope: cluster
-- cost: 0
SELECT 'PG-INFO-011'::text AS check_id,
       'cluster'::text     AS scope,
       t.spcname::text     AS object,
       format('Tablespace %s, owner %s, size %s, location %s. %s database(s) have it as their default. Options: %s. %s',
              t.spcname, pg_get_userbyid(t.spcowner),
              pg_size_pretty(pg_tablespace_size(t.oid)),
              coalesce(nullif(pg_tablespace_location(t.oid), ''), 'inside the data directory'),
              (SELECT count(*) FROM pg_database d WHERE d.dattablespace = t.oid),
              coalesce(array_to_string(t.spcoptions, ', '), 'none (inherits random_page_cost and seq_page_cost from the server)'),
              CASE WHEN pg_tablespace_location(t.oid) <> ''
                   THEN 'A tablespace outside the data directory is usually a different volume, with its own free space, its own latency and its own failure mode - and it must exist and be mounted before the server will start.'
                   ELSE '' END) AS details,
       json_build_object('spcname', t.spcname, 'owner', pg_get_userbyid(t.spcowner),
                         'size_bytes', pg_tablespace_size(t.oid),
                         'location', pg_tablespace_location(t.oid),
                         'spcoptions', array_to_string(t.spcoptions, ';'),
                         'default_for_databases', (SELECT count(*) FROM pg_database d WHERE d.dattablespace = t.oid),
                         'is_external', pg_tablespace_location(t.oid) <> '')::text AS evidence_json,
       'high'::text AS confidence
FROM pg_tablespace t
ORDER BY pg_tablespace_size(t.oid) DESC;
