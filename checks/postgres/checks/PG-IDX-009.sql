-- check: PG-IDX-009
-- title: Unindexed foreign key (small table)
-- priority: 150
-- scope: relation
-- cost: 1
-- thresholds: min_bytes, parent_writes_per_day, min_child_rows, top_n
--
-- The remainder tier: a child below PG-IDX-008's size threshold whose parent is
-- not write-active enough, on a child not populated enough, to reach
-- PG-IDX-018. Every one of these is still a missing index and still worth an
-- afternoon, but none of them is costing anything measurable today, which is
-- why this row sits at P150 and says how many there are rather than listing
-- hundreds of them.
WITH stats_window AS (
  SELECT greatest(extract(epoch FROM now() - coalesce(sd.stats_reset,
                                                      pg_postmaster_start_time())) / 86400.0,
                  1.0 / 24.0) AS days
  FROM pg_stat_database sd
  WHERE sd.datname = current_database()
),
fk AS (
  SELECT con.oid AS conoid, con.conname, con.conrelid, con.confrelid, con.conkey,
         cn.nspname AS child_schema, cc.relname AS child_table,
         pn.nspname AS parent_schema, pc.relname AS parent_table,
         pg_relation_size(con.conrelid) AS child_bytes,
         CASE WHEN cc.reltuples >= 0 THEN cc.reltuples::bigint ELSE NULL END AS child_rows,
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
  SELECT fk.*, w.days, fk.parent_writes / w.days AS parent_writes_per_day
  FROM fk CROSS JOIN stats_window w
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = fk.conrelid AND i.indisvalid
      AND (string_to_array(i.indkey::text, ' '))[1:cardinality(fk.conkey)]
          = (SELECT array_agg(x::text ORDER BY o) FROM unnest(fk.conkey) WITH ORDINALITY AS u(x, o))
  )
),
mild AS (
  SELECT u.*, count(*) OVER () AS total_mild
  FROM unindexed u
  WHERE u.child_bytes < :'pg_idx_009_min_bytes'::bigint
    AND NOT (u.parent_writes_per_day >= :'pg_idx_009_parent_writes_per_day'::bigint
             AND coalesce(u.child_rows, 0) >= :'pg_idx_009_min_child_rows'::bigint)
)
SELECT 'PG-IDX-009'::text AS check_id,
       'relation'::text AS scope,
       format('%I.%I.%I', current_database(), m.child_schema, m.child_table)::text AS object,
       format('Foreign key %s on %s.%s (%s) references %s.%s and has no index whose leading columns match it. Nothing is measurably costing you here yet: the child is %s, below the %s that would make this PG-IDX-008, and it misses PG-IDX-018 as well because %s. This is one of %s unindexed foreign key(s) in this database at this tier; the %s largest are listed. Fix when convenient: CREATE INDEX CONCURRENTLY ON %s.%s (%s).',
              m.conname, m.child_schema, m.child_table, m.child_columns,
              m.parent_schema, m.parent_table,
              pg_size_pretty(m.child_bytes),
              pg_size_pretty(:'pg_idx_009_min_bytes'::bigint),
              concat_ws(' and ',
                CASE WHEN m.parent_writes_per_day < :'pg_idx_009_parent_writes_per_day'::bigint
                     THEN format('the parent takes about %s updates and deletes a day, below the %s that tier needs',
                                 to_char(round(m.parent_writes_per_day), 'FM999,999,999,999'),
                                 to_char(:'pg_idx_009_parent_writes_per_day'::bigint, 'FM999,999,999,999')) END,
                CASE WHEN coalesce(m.child_rows, 0) < :'pg_idx_009_min_child_rows'::bigint
                     THEN format('the child holds %s rows, below the %s that tier needs',
                                 coalesce(to_char(m.child_rows, 'FM999,999,999,999'), 'an unknown number of'),
                                 to_char(:'pg_idx_009_min_child_rows'::bigint, 'FM999,999,999,999')) END),
              to_char(m.total_mild, 'FM999,999,999'),
              least(m.total_mild, :'pg_idx_009_top_n'::int)::text,
              quote_ident(m.child_schema), quote_ident(m.child_table), m.child_columns) AS details,
       json_build_object('constraint', m.conname,
                         'child_schema', m.child_schema, 'child_table', m.child_table,
                         'child_columns', m.child_columns,
                         'parent_schema', m.parent_schema, 'parent_table', m.parent_table,
                         'child_bytes', m.child_bytes, 'child_rows', m.child_rows,
                         'parent_writes', m.parent_writes,
                         'parent_writes_per_day', round(m.parent_writes_per_day, 1),
                         'stats_window_days', round(m.days, 2),
                         'unindexed_fk_total', m.total_mild,
                         'listed', least(m.total_mild, :'pg_idx_009_top_n'::int),
                         'threshold_child_bytes', :'pg_idx_009_min_bytes'::bigint,
                         'threshold_parent_writes_per_day', :'pg_idx_009_parent_writes_per_day'::bigint,
                         'threshold_min_child_rows', :'pg_idx_009_min_child_rows'::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM mild m
ORDER BY m.child_bytes DESC, m.child_schema, m.child_table, m.conname
LIMIT :'pg_idx_009_top_n'::int;
