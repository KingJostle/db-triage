-- check: PG-CAP-005
-- title: Largest 20 relations
-- priority: 250
-- scope: relation
-- cost: 1
-- thresholds: top_n
SELECT 'PG-CAP-005'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('%s %s.%s: %s total = %s heap + %s indexes + %s toast. %s estimated rows, %s index(es), relfrozenxid age %s. Last vacuum %s, last analyze %s.',
              CASE c.relkind WHEN 'r' THEN 'Table' WHEN 'p' THEN 'Partitioned table'
                             WHEN 'm' THEN 'Materialized view' WHEN 'i' THEN 'Index'
                             ELSE c.relkind::text END,
              n.nspname, c.relname,
              pg_size_pretty(pg_total_relation_size(c.oid)),
              pg_size_pretty(pg_table_size(c.oid) - coalesce(pg_total_relation_size(c.reltoastrelid), 0)),
              pg_size_pretty(pg_indexes_size(c.oid)),
              pg_size_pretty(coalesce(pg_total_relation_size(c.reltoastrelid), 0)),
              to_char(greatest(c.reltuples, 0)::bigint, 'FM999,999,999,999'),
              (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid),
              to_char(age(c.relfrozenxid), 'FM999,999,999,999'),
              coalesce(greatest(t.last_vacuum, t.last_autovacuum)::text, 'never'),
              coalesce(greatest(t.last_analyze, t.last_autoanalyze)::text, 'never')) AS details,
       json_build_object('schema', n.nspname, 'relname', c.relname, 'relkind', c.relkind,
                         'total_bytes', pg_total_relation_size(c.oid),
                         'heap_bytes', pg_table_size(c.oid) - coalesce(pg_total_relation_size(c.reltoastrelid), 0),
                         'index_bytes', pg_indexes_size(c.oid),
                         'toast_bytes', coalesce(pg_total_relation_size(c.reltoastrelid), 0),
                         'reltuples', greatest(c.reltuples, 0)::bigint,
                         'index_count', (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid),
                         'relfrozenxid_age', age(c.relfrozenxid),
                         'last_vacuum', greatest(t.last_vacuum, t.last_autovacuum),
                         'last_analyze', greatest(t.last_analyze, t.last_autoanalyze))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_stat_user_tables t ON t.relid = c.oid
WHERE c.relkind IN ('r', 'p', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT :'pg_cap_005_top_n'::int;
