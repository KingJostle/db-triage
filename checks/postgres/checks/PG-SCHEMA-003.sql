-- check: PG-SCHEMA-003
-- title: Tables without a primary key or unique index
-- priority: 150
-- scope: relation
-- cost: 1
-- thresholds: top_n
SELECT 'PG-SCHEMA-003'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Table %s.%s has no primary key and no valid unique index. Size %s, %s estimated rows, %s index(es). Without one: logical replication cannot replicate UPDATE or DELETE from it (PG-REPL-013 fires if it is published), there is no way to address a single row from outside the database, duplicates cannot be prevented or found cheaply, and most ORMs and CDC tools degrade or refuse. This is P150 because a table can legitimately be an append-only log; it is worth confirming that this one is.',
              n.nspname, c.relname,
              pg_size_pretty(pg_total_relation_size(c.oid)),
              to_char(greatest(c.reltuples, 0)::bigint, 'FM999,999,999,999'),
              (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid)) AS details,
       json_build_object('schema', n.nspname, 'table', c.relname,
                         'total_bytes', pg_total_relation_size(c.oid),
                         'reltuples', greatest(c.reltuples, 0)::bigint,
                         'index_count', (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid),
                         'relreplident', c.relreplident::text,
                         'is_published', EXISTS (SELECT 1 FROM pg_publication_tables pt
                                                 WHERE pt.schemaname = n.nspname AND pt.tablename = c.relname))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND NOT EXISTS (SELECT 1 FROM pg_index i
                  WHERE i.indrelid = c.oid AND i.indisvalid AND (i.indisprimary OR i.indisunique))
  AND NOT EXISTS (SELECT 1 FROM pg_inherits inh WHERE inh.inhrelid = c.oid)
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT :'pg_schema_003_top_n'::int;
