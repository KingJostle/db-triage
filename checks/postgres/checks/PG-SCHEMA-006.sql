-- check: PG-SCHEMA-006
-- title: Rows accumulating in a DEFAULT partition
-- priority: 100
-- scope: relation
-- cost: 1
-- min_version: 11
-- thresholds: min_bytes, parent_fraction
WITH def AS (
  SELECT c.oid AS part_oid, n.nspname AS part_schema, c.relname AS part_name,
         pn.nspname AS parent_schema, pc.relname AS parent_name, pc.oid AS parent_oid,
         pg_total_relation_size(c.oid) AS part_bytes,
         coalesce(t.n_live_tup, greatest(c.reltuples, 0)::bigint) AS part_rows
  FROM pg_class c
  JOIN pg_namespace n  ON n.oid = c.relnamespace
  JOIN pg_inherits inh ON inh.inhrelid = c.oid
  JOIN pg_class pc     ON pc.oid = inh.inhparent
  JOIN pg_namespace pn ON pn.oid = pc.relnamespace
  LEFT JOIN pg_stat_user_tables t ON t.relid = c.oid
  WHERE c.relispartition
    AND pg_get_expr(c.relpartbound, c.oid) = 'DEFAULT'
),
scored AS (
  SELECT d.*,
         (SELECT sum(coalesce(st.n_live_tup, greatest(pc2.reltuples, 0)::bigint))
          FROM pg_inherits i2 JOIN pg_class pc2 ON pc2.oid = i2.inhrelid
          LEFT JOIN pg_stat_user_tables st ON st.relid = pc2.oid
          WHERE i2.inhparent = d.parent_oid) AS family_rows
  FROM def d
)
SELECT 'PG-SCHEMA-006'::text AS check_id,
       'relation'::text      AS scope,
       format('%I.%I.%I', current_database(), s.part_schema, s.part_name)::text AS object,
       format('The DEFAULT partition of %s.%s holds %s and %s rows, which is %s%% of the %s rows in the whole partition family (thresholds %s or %s%% of the parent). Rows land in the default partition when no other partition''s bound matches them, which almost always means the next period''s partition was never created. Two consequences: queries that should prune to one partition now also scan this one, and every future ATTACH PARTITION has to scan the entire default partition to prove no row belongs in the new one, holding an ACCESS EXCLUSIVE lock while it does.',
              s.parent_schema, s.parent_name,
              pg_size_pretty(s.part_bytes), to_char(s.part_rows, 'FM999,999,999,999'),
              round(100.0 * s.part_rows / nullif(s.family_rows, 0), 1)::text,
              to_char(s.family_rows, 'FM999,999,999,999'),
              pg_size_pretty(:'pg_schema_006_min_bytes'::bigint),
              round(100 * :'pg_schema_006_parent_fraction'::numeric)::text) AS details,
       json_build_object('parent_schema', s.parent_schema, 'parent_table', s.parent_name,
                         'default_partition', s.part_name,
                         'partition_bytes', s.part_bytes, 'partition_rows', s.part_rows,
                         'family_rows', s.family_rows,
                         'fraction_of_family', round(s.part_rows::numeric / nullif(s.family_rows, 0), 4),
                         'threshold_bytes', :'pg_schema_006_min_bytes'::bigint,
                         'threshold_fraction', :'pg_schema_006_parent_fraction'::numeric)::text AS evidence_json,
       'high'::text AS confidence
FROM scored s
WHERE s.part_bytes >= :'pg_schema_006_min_bytes'::bigint
   OR s.part_rows >= :'pg_schema_006_parent_fraction'::numeric * coalesce(s.family_rows, 0)
ORDER BY s.part_bytes DESC;
