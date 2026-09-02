-- check: PG-IDX-009
-- title: Unindexed foreign key (small table)
-- priority: 150
-- scope: relation
-- cost: 1
-- thresholds: min_bytes, parent_writes, top_n
WITH fk AS (
  SELECT con.oid AS conoid, con.conname, con.conrelid, con.confrelid, con.conkey,
         cn.nspname AS child_schema, cc.relname AS child_table,
         pn.nspname AS parent_schema, pc.relname AS parent_table,
         pg_relation_size(con.conrelid) AS child_bytes,
         coalesce(pt.n_tup_del + pt.n_tup_upd, 0) AS parent_writes,
         (SELECT string_agg(a.attname, ', ' ORDER BY k.ord)
          FROM unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum) AS child_columns
  FROM pg_constraint con
  JOIN pg_class cc      ON cc.oid = con.conrelid
  JOIN pg_namespace cn  ON cn.oid = cc.relnamespace
  JOIN pg_class pc      ON pc.oid = con.confrelid
  JOIN pg_namespace pn  ON pn.oid = pc.relnamespace
  LEFT JOIN pg_stat_user_tables pt ON pt.relid = con.confrelid
  WHERE con.contype = 'f'
    AND cn.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
),
unindexed AS (
  SELECT fk.* FROM fk
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = fk.conrelid AND i.indisvalid
      AND (string_to_array(i.indkey::text, ' '))[1:cardinality(fk.conkey)]
          = (SELECT array_agg(x::text ORDER BY o) FROM unnest(fk.conkey) WITH ORDINALITY AS u(x, o))
  )
)
SELECT 'PG-IDX-009'::text AS check_id,
       'relation'::text AS scope,
       format('%I.%I.%I', current_database(), u.child_schema, u.child_table)::text AS object,
       format('Foreign key %s on %s.%s (%s) references %s.%s and has no index whose leading columns match it. Child table %s, parent has had %s updates and deletes since the statistics reset. Every DELETE or key UPDATE on the parent has to sequentially scan the child under a lock to check the constraint, and ON DELETE CASCADE makes that scan happen per parent row. Thresholds: child size >= %s or parent writes >= %s. Fix: CREATE INDEX CONCURRENTLY ON %s.%s (%s).',
              u.conname, u.child_schema, u.child_table, u.child_columns,
              u.parent_schema, u.parent_table,
              pg_size_pretty(u.child_bytes),
              to_char(u.parent_writes, 'FM999,999,999,999'),
              pg_size_pretty(:'pg_idx_009_min_bytes'::bigint),
              to_char(:'pg_idx_009_parent_writes'::bigint, 'FM999,999,999,999'),
              quote_ident(u.child_schema), quote_ident(u.child_table), u.child_columns) AS details,
       json_build_object('constraint', u.conname,
                         'child_schema', u.child_schema, 'child_table', u.child_table,
                         'child_columns', u.child_columns,
                         'parent_schema', u.parent_schema, 'parent_table', u.parent_table,
                         'child_bytes', u.child_bytes, 'parent_writes', u.parent_writes,
                         'threshold_child_bytes', :'pg_idx_009_min_bytes'::bigint,
                         'threshold_parent_writes', :'pg_idx_009_parent_writes'::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM unindexed u
WHERE u.child_bytes < :'pg_idx_009_min_bytes'::bigint
    AND u.parent_writes < :'pg_idx_009_parent_writes'::bigint
ORDER BY u.child_bytes DESC
LIMIT :'pg_idx_009_top_n'::int;
