-- check: PG-SCHEMA-011
-- title: Unpopulated materialized view
-- priority: 150
-- scope: relation
-- cost: 1
SELECT 'PG-SCHEMA-011'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Materialized view %s.%s was created WITH NO DATA and has never been refreshed. Any query against it fails immediately with "materialized view %s has not been populated". Owner %s, %s index(es) defined on it. Fix with REFRESH MATERIALIZED VIEW %s.%s - which is a write, and takes an ACCESS EXCLUSIVE lock unless it is refreshed CONCURRENTLY, which in turn needs a unique index.',
              n.nspname, c.relname, c.relname,
              pg_get_userbyid(c.relowner),
              (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid),
              quote_ident(n.nspname), quote_ident(c.relname)) AS details,
       json_build_object('schema', n.nspname, 'matview', c.relname,
                         'owner', pg_get_userbyid(c.relowner),
                         'relispopulated', c.relispopulated,
                         'index_count', (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid),
                         'has_unique_index', EXISTS (SELECT 1 FROM pg_index i
                                                     WHERE i.indrelid = c.oid AND i.indisunique))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'm' AND NOT c.relispopulated
ORDER BY n.nspname, c.relname;
