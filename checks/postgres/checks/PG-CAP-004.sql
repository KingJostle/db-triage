-- check: PG-CAP-004
-- title: Database sizes
-- priority: 250
-- scope: database
-- cost: 0
SELECT 'PG-CAP-004'::text AS check_id,
       'database'::text   AS scope,
       d.datname::text    AS object,
       format('%s: %s (%s%% of the %s cluster total across %s databases). Tablespace %s, encoding %s, collation %s, connections %s, %s.',
              d.datname, pg_size_pretty(pg_database_size(d.oid)),
              round(100.0 * pg_database_size(d.oid) / nullif(sum(pg_database_size(d.oid)) OVER (), 0), 1)::text,
              pg_size_pretty(sum(pg_database_size(d.oid)) OVER ()),
              count(*) OVER (),
              t.spcname, pg_encoding_to_char(d.encoding), d.datcollate,
              CASE WHEN d.datconnlimit < 0 THEN 'unlimited' ELSE d.datconnlimit::text END,
              CASE WHEN d.datistemplate THEN 'template database'
                   WHEN NOT d.datallowconn THEN 'connections disallowed'
                   ELSE 'ordinary database' END) AS details,
       json_build_object('datname', d.datname, 'size_bytes', pg_database_size(d.oid),
                         'cluster_bytes', sum(pg_database_size(d.oid)) OVER (),
                         'tablespace', t.spcname, 'encoding', pg_encoding_to_char(d.encoding),
                         'datcollate', d.datcollate, 'datctype', d.datctype,
                         'datconnlimit', d.datconnlimit, 'datistemplate', d.datistemplate,
                         'datallowconn', d.datallowconn, 'owner', pg_get_userbyid(d.datdba))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_database d
JOIN pg_tablespace t ON t.oid = d.dattablespace
ORDER BY pg_database_size(d.oid) DESC;
