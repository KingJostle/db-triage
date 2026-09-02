-- check: PG-IDX-012
-- title: Write-heavy table with many indexes
-- priority: 100
-- scope: relation
-- cost: 1
-- thresholds: min_indexes, min_writes
SELECT 'PG-IDX-012'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), t.schemaname, t.relname)::text AS object,
       format('Table %s.%s carries %s indexes (threshold %s) and has taken %s writes since the statistics reset (threshold %s): %s inserts, %s updates, %s deletes. Every insert, and every update that cannot be heap-only, writes an entry into all %s indexes; heap-only updates are %s%% of updates here (PG-VAC-012 measures that). Heap %s, indexes %s. %s of these indexes have never been scanned (PG-IDX-002/003 lists them).',
              t.schemaname, t.relname, c.idx_count, :'pg_idx_012_min_indexes'::text,
              to_char(t.n_tup_ins + t.n_tup_upd + t.n_tup_del, 'FM999,999,999,999'),
              to_char(:'pg_idx_012_min_writes'::bigint, 'FM999,999,999,999'),
              to_char(t.n_tup_ins, 'FM999,999,999,999'),
              to_char(t.n_tup_upd, 'FM999,999,999,999'),
              to_char(t.n_tup_del, 'FM999,999,999,999'),
              c.idx_count,
              round(100.0 * t.n_tup_hot_upd / nullif(t.n_tup_upd, 0), 1)::text,
              pg_size_pretty(pg_table_size(t.relid)),
              pg_size_pretty(pg_indexes_size(t.relid)),
              c.unused_count) AS details,
       json_build_object('schema', t.schemaname, 'table', t.relname,
                         'index_count', c.idx_count, 'unused_index_count', c.unused_count,
                         'writes', t.n_tup_ins + t.n_tup_upd + t.n_tup_del,
                         'n_tup_ins', t.n_tup_ins, 'n_tup_upd', t.n_tup_upd, 'n_tup_del', t.n_tup_del,
                         'n_tup_hot_upd', t.n_tup_hot_upd,
                         'table_bytes', pg_table_size(t.relid),
                         'indexes_bytes', pg_indexes_size(t.relid),
                         'threshold_indexes', :'pg_idx_012_min_indexes'::int,
                         'threshold_writes', :'pg_idx_012_min_writes'::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_user_tables t
CROSS JOIN LATERAL (
  SELECT count(*) AS idx_count,
         count(*) FILTER (WHERE coalesce(si.idx_scan, 0) = 0) AS unused_count
  FROM pg_index i
  LEFT JOIN pg_stat_user_indexes si ON si.indexrelid = i.indexrelid
  WHERE i.indrelid = t.relid AND i.indisvalid
) c
WHERE c.idx_count >= :'pg_idx_012_min_indexes'::int
  AND t.n_tup_ins + t.n_tup_upd + t.n_tup_del >= :'pg_idx_012_min_writes'::bigint
ORDER BY t.n_tup_ins + t.n_tup_upd + t.n_tup_del DESC;
