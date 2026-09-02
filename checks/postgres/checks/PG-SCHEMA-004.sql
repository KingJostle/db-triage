-- check: PG-SCHEMA-004
-- title: REPLICA IDENTITY FULL on published tables
-- priority: 150
-- scope: relation
-- cost: 1
-- min_version: 10
-- run_on: primary
SELECT 'PG-SCHEMA-004'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), pt.schemaname, pt.tablename)::text AS object,
       format('Table %s.%s is published by %s with REPLICA IDENTITY FULL. Every UPDATE and DELETE writes the complete old row into WAL, not just the key, so WAL volume scales with row width rather than with the change; and the subscriber matches rows by comparing every column, which is a sequential scan per change unless it has an index that happens to help. Size %s, %s estimated rows, %s writes since the statistics reset. If the table has a primary key or a unique, non-partial, NOT NULL index, REPLICA IDENTITY DEFAULT or USING INDEX is both smaller and faster.',
              pt.schemaname, pt.tablename, pt.pubname,
              pg_size_pretty(pg_total_relation_size(c.oid)),
              to_char(greatest(c.reltuples, 0)::bigint, 'FM999,999,999,999'),
              to_char(coalesce(t.n_tup_upd + t.n_tup_del, 0), 'FM999,999,999,999')) AS details,
       json_build_object('schema', pt.schemaname, 'table', pt.tablename, 'publication', pt.pubname,
                         'relreplident', c.relreplident::text,
                         'total_bytes', pg_total_relation_size(c.oid),
                         'reltuples', greatest(c.reltuples, 0)::bigint,
                         'updates_and_deletes', coalesce(t.n_tup_upd + t.n_tup_del, 0),
                         'has_primary_key', EXISTS (SELECT 1 FROM pg_index i
                                                    WHERE i.indrelid = c.oid AND i.indisprimary AND i.indisvalid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_publication_tables pt
JOIN pg_namespace n ON n.nspname = pt.schemaname
JOIN pg_class c     ON c.relname = pt.tablename AND c.relnamespace = n.oid
LEFT JOIN pg_stat_user_tables t ON t.relid = c.oid
WHERE c.relreplident = 'f'
ORDER BY pg_total_relation_size(c.oid) DESC;
