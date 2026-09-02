-- check: PG-IDX-001
-- title: Invalid index
-- priority: 50
-- scope: index
-- cost: 1
SELECT 'PG-IDX-001'::text AS check_id,
       'index'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, ic.relname)::text AS object,
       format('Index %s on %s.%s is %s. It is still maintained on every insert, update and delete of the table, it is never used by the planner, and %s Size %s against a table of %s. Definition: %s. This is almost always the debris of a CREATE INDEX CONCURRENTLY that failed or was interrupted. Fix: REINDEX INDEX CONCURRENTLY %s.%s on PostgreSQL 12 and newer, or DROP INDEX CONCURRENTLY and recreate it.',
              ic.relname, n.nspname, tc.relname,
              CASE WHEN NOT i.indisready THEN 'not ready (indisready = false, so it is not even receiving new entries)'
                   ELSE 'invalid (indisvalid = false)' END,
              CASE WHEN i.indisunique
                   THEN 'because it is unique it still rejects conflicting inserts, so it changes behaviour without providing any benefit.'
                   ELSE 'it provides nothing in return.' END,
              pg_size_pretty(pg_relation_size(i.indexrelid)),
              pg_size_pretty(pg_relation_size(i.indrelid)),
              pg_get_indexdef(i.indexrelid),
              quote_ident(n.nspname), quote_ident(ic.relname)) AS details,
       json_build_object('schema', n.nspname, 'table', tc.relname, 'index', ic.relname,
                         'indisvalid', i.indisvalid, 'indisready', i.indisready,
                         'indisunique', i.indisunique, 'indisprimary', i.indisprimary,
                         'index_bytes', pg_relation_size(i.indexrelid),
                         'table_bytes', pg_relation_size(i.indrelid),
                         'indexdef', pg_get_indexdef(i.indexrelid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_index i
JOIN pg_class ic     ON ic.oid = i.indexrelid
JOIN pg_class tc     ON tc.oid = i.indrelid
JOIN pg_namespace n  ON n.oid = ic.relnamespace
WHERE (NOT i.indisvalid OR NOT i.indisready)
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY pg_relation_size(i.indexrelid) DESC;
