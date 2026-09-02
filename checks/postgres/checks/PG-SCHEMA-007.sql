-- check: PG-SCHEMA-007
-- title: Partitioned table with more than 1,000 partitions
-- priority: 150
-- scope: relation
-- cost: 1
-- min_version: 10
-- thresholds: max_partitions
SELECT 'PG-SCHEMA-007'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Partitioned table %s.%s has %s direct partitions (threshold %s), totalling %s. The planner takes a lock on every partition it cannot prune away, and it does that per query: with this many children, planning time and lock-manager traffic become visible on short queries even when execution is fast. Queries that cannot prune - anything with a non-constant partition key predicate, or a prepared generic plan - touch all of them. Consider a coarser partition interval, or sub-partitioning so pruning happens in two cheap steps.',
              n.nspname, c.relname, cnt.n, :'pg_schema_007_max_partitions'::text,
              pg_size_pretty(cnt.total_bytes)) AS details,
       json_build_object('schema', n.nspname, 'table', c.relname,
                         'partition_count', cnt.n, 'total_bytes', cnt.total_bytes,
                         'partition_strategy', p.partstrat::text,
                         'threshold', :'pg_schema_007_max_partitions'::int)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n           ON n.oid = c.relnamespace
JOIN pg_partitioned_table p   ON p.partrelid = c.oid
CROSS JOIN LATERAL (
  SELECT count(*) AS n, coalesce(sum(pg_total_relation_size(i.inhrelid)), 0) AS total_bytes
  FROM pg_inherits i WHERE i.inhparent = c.oid
) cnt
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND cnt.n >= :'pg_schema_007_max_partitions'::int
ORDER BY cnt.n DESC;
