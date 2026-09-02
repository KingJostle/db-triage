-- check: PG-IDX-018
-- title: Unindexed foreign key on a write-active parent
-- priority: 100
-- scope: relation
-- cost: 1
-- thresholds: max_bytes, parent_writes_per_day, min_child_rows, top_n
--
-- The write-activity tier of the unindexed-foreign-key family. The child table
-- is below PG-IDX-008's size threshold, so the scan is not expensive because of
-- the table's size; it is expensive because it happens often enough, on enough
-- rows, to add up.
--
-- Two gates, both required, and both deliberately not the lifetime counter this
-- check used to read:
--
--   parent_writes_per_day  n_tup_upd + n_tup_del on the PARENT divided by the
--                          age of the statistics, so the number means the same
--                          thing on a cluster whose counters were reset last
--                          night and on one whose counters are four months old.
--                          A lifetime count of 1,000 is satisfied by four
--                          months of near-idleness - eight writes a day - which
--                          is what put 108 eight-kilobyte tables into a P50
--                          band in the field.
--   min_child_rows         the child must hold enough rows for the sequential
--                          scan to cost anything. reltuples is used as-is; a
--                          child that has never been analyzed reports -1 (0
--                          before PostgreSQL 14) and is deliberately not
--                          evaluated here - PG-VAC-004 is the check for that.
--
-- The two together are the finding: 10,000 parent writes a day against a child
-- of 100,000 rows is on the order of 100 seconds a day of pure constraint-check
-- scanning, plus a KEY SHARE lock on the child for each one.
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
  SELECT fk.*, w.days,
         fk.parent_writes / w.days AS parent_writes_per_day
  FROM fk CROSS JOIN stats_window w
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = fk.conrelid AND i.indisvalid
      AND (string_to_array(i.indkey::text, ' '))[1:cardinality(fk.conkey)]
          = (SELECT array_agg(x::text ORDER BY o) FROM unnest(fk.conkey) WITH ORDINALITY AS u(x, o))
  )
)
SELECT 'PG-IDX-018'::text AS check_id,
       'relation'::text AS scope,
       format('%I.%I.%I', current_database(), u.child_schema, u.child_table)::text AS object,
       format('Foreign key %s on %s.%s (%s) references %s.%s and has no index whose leading columns match it. The child is only %s, but it holds about %s rows and the parent takes %s updates and deletes a day (%s over the %s of statistics available), so the constraint check sequentially scans the child that often. Thresholds: %s parent writes a day and %s child rows, on a child below the %s that would make this PG-IDX-008 instead. Fix: CREATE INDEX CONCURRENTLY ON %s.%s (%s).',
              u.conname, u.child_schema, u.child_table, u.child_columns,
              u.parent_schema, u.parent_table,
              pg_size_pretty(u.child_bytes),
              to_char(u.child_rows, 'FM999,999,999,999'),
              to_char(round(u.parent_writes_per_day), 'FM999,999,999,999'),
              to_char(u.parent_writes, 'FM999,999,999,999'),
              CASE WHEN u.days >= 2 THEN to_char(round(u.days), 'FM999,999') || ' days'
                   WHEN round(u.days * 24) = 1 THEN '1 hour'
                   ELSE to_char(round(u.days * 24), 'FM999,999') || ' hours' END,
              to_char(:'pg_idx_018_parent_writes_per_day'::bigint, 'FM999,999,999,999'),
              to_char(:'pg_idx_018_min_child_rows'::bigint, 'FM999,999,999,999'),
              pg_size_pretty(:'pg_idx_018_max_bytes'::bigint),
              quote_ident(u.child_schema), quote_ident(u.child_table), u.child_columns) AS details,
       json_build_object('constraint', u.conname,
                         'child_schema', u.child_schema, 'child_table', u.child_table,
                         'child_columns', u.child_columns,
                         'parent_schema', u.parent_schema, 'parent_table', u.parent_table,
                         'child_bytes', u.child_bytes, 'child_rows', u.child_rows,
                         'parent_writes', u.parent_writes,
                         'parent_writes_per_day', round(u.parent_writes_per_day, 1),
                         'stats_window_days', round(u.days, 2),
                         'threshold_max_child_bytes', :'pg_idx_018_max_bytes'::bigint,
                         'threshold_parent_writes_per_day', :'pg_idx_018_parent_writes_per_day'::bigint,
                         'threshold_min_child_rows', :'pg_idx_018_min_child_rows'::bigint)::text AS evidence_json,
       CASE WHEN u.days < 1 THEN 'low' WHEN u.days < 7 THEN 'medium' ELSE 'high' END::text AS confidence
FROM unindexed u
WHERE u.child_bytes < :'pg_idx_018_max_bytes'::bigint
  AND u.parent_writes_per_day >= :'pg_idx_018_parent_writes_per_day'::bigint
  AND u.child_rows >= :'pg_idx_018_min_child_rows'::bigint
ORDER BY u.parent_writes_per_day DESC, u.child_rows DESC
LIMIT :'pg_idx_018_top_n'::int;
