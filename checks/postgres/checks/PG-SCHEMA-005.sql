-- check: PG-SCHEMA-005
-- title: Very large table not partitioned
-- priority: 100
-- scope: relation
-- cost: 1
-- min_version: 10
-- thresholds: min_bytes
SELECT 'PG-SCHEMA-005'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Table %s.%s is %s total (%s heap, %s indexes, %s toast) with %s estimated rows, and is neither partitioned nor a partition. Every operation that has to touch the whole relation - a vacuum, a freeze, an index build, a REINDEX, an ALTER TABLE that rewrites - is one long single operation on this table, and deleting old rows means a DELETE plus a vacuum rather than a DROP of a partition. relfrozenxid age is %s. This is advisory: partitioning is a schema change with real cost, and it pays only when there is a natural range key and a retention policy.',
              n.nspname, c.relname,
              pg_size_pretty(pg_total_relation_size(c.oid)),
              pg_size_pretty(pg_table_size(c.oid)),
              pg_size_pretty(pg_indexes_size(c.oid)),
              pg_size_pretty(coalesce(pg_total_relation_size(c.reltoastrelid), 0)),
              to_char(greatest(c.reltuples, 0)::bigint, 'FM999,999,999,999'),
              to_char(age(c.relfrozenxid), 'FM999,999,999,999')) AS details,
       json_build_object('schema', n.nspname, 'table', c.relname,
                         'total_bytes', pg_total_relation_size(c.oid),
                         'heap_bytes', pg_table_size(c.oid),
                         'index_bytes', pg_indexes_size(c.oid),
                         'toast_bytes', coalesce(pg_total_relation_size(c.reltoastrelid), 0),
                         'reltuples', greatest(c.reltuples, 0)::bigint,
                         'relfrozenxid_age', age(c.relfrozenxid),
                         'threshold_bytes', :'pg_schema_005_min_bytes'::bigint)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
  AND pg_total_relation_size(c.oid) >= :'pg_schema_005_min_bytes'::bigint
ORDER BY pg_total_relation_size(c.oid) DESC;
