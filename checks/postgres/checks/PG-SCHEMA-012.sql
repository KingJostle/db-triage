-- check: PG-SCHEMA-012
-- title: Legacy inheritance-based partitioning
-- priority: 200
-- scope: relation
-- cost: 1
-- min_version: 10
SELECT 'PG-SCHEMA-012'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Table %s.%s is the parent of %s child table(s) through table inheritance, not declarative partitioning: it has no entry in pg_partitioned_table. Children total %s. Row routing therefore depends on triggers or rules that the application or a migration installed, pruning depends on constraint_exclusion (currently %s) finding usable CHECK constraints rather than on partition bounds, and there is no ATTACH or DETACH PARTITION. Inventory row: this pattern still works, and converting it is a planned migration rather than a fix.',
              n.nspname, c.relname, cnt.n, pg_size_pretty(cnt.total_bytes),
              current_setting('constraint_exclusion')) AS details,
       json_build_object('schema', n.nspname, 'table', c.relname,
                         'child_count', cnt.n, 'children_bytes', cnt.total_bytes,
                         'constraint_exclusion', current_setting('constraint_exclusion'),
                         'trigger_count', (SELECT count(*) FROM pg_trigger tg
                                           WHERE tg.tgrelid = c.oid AND NOT tg.tgisinternal))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL (
  SELECT count(*) AS n, coalesce(sum(pg_total_relation_size(i.inhrelid)), 0) AS total_bytes
  FROM pg_inherits i WHERE i.inhparent = c.oid
) cnt
WHERE cnt.n > 0
  AND NOT EXISTS (SELECT 1 FROM pg_partitioned_table p WHERE p.partrelid = c.oid)
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY cnt.total_bytes DESC;
