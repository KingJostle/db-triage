-- check: PG-IDX-013
-- title: Index footprint more than twice the heap on a large table
-- priority: 150
-- scope: relation
-- cost: 1
-- thresholds: min_bytes, index_multiple
SELECT 'PG-IDX-013'::text AS check_id,
       'relation'::text   AS scope,
       format('%I.%I.%I', current_database(), n.nspname, c.relname)::text AS object,
       format('Table %s.%s has %s of indexes against %s of heap (%sx, threshold %sx) across %s indexes. That is not wrong on its own - a covering index or a wide composite key legitimately costs this - but it is the shape that PG-IDX-002 (unused), PG-IDX-004 (duplicate), PG-IDX-005 (overlapping) and PG-IDX-006 (bloated) usually produce together. %s of the indexes have never been scanned. Largest three: %s.',
              n.nspname, c.relname,
              pg_size_pretty(pg_indexes_size(c.oid)), pg_size_pretty(pg_table_size(c.oid)),
              round(pg_indexes_size(c.oid)::numeric / nullif(pg_table_size(c.oid), 0), 1)::text,
              :'pg_idx_013_index_multiple'::text,
              (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid AND i.indisvalid),
              (SELECT count(*) FROM pg_index i
               LEFT JOIN pg_stat_user_indexes si ON si.indexrelid = i.indexrelid
               WHERE i.indrelid = c.oid AND i.indisvalid AND coalesce(si.idx_scan, 0) = 0),
              coalesce((SELECT string_agg(format('%s (%s)', ic.relname, pg_size_pretty(pg_relation_size(ic.oid))), ', ')
                        FROM (SELECT ic2.oid, ic2.relname FROM pg_index i2
                              JOIN pg_class ic2 ON ic2.oid = i2.indexrelid
                              WHERE i2.indrelid = c.oid AND i2.indisvalid
                              ORDER BY pg_relation_size(ic2.oid) DESC LIMIT 3) ic), 'none')) AS details,
       json_build_object('schema', n.nspname, 'table', c.relname,
                         'table_bytes', pg_table_size(c.oid),
                         'indexes_bytes', pg_indexes_size(c.oid),
                         'index_multiple', round(pg_indexes_size(c.oid)::numeric / nullif(pg_table_size(c.oid), 0), 2),
                         'threshold_multiple', :'pg_idx_013_index_multiple'::numeric,
                         'threshold_bytes', :'pg_idx_013_min_bytes'::bigint,
                         'index_count', (SELECT count(*) FROM pg_index i WHERE i.indrelid = c.oid AND i.indisvalid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND pg_table_size(c.oid) >= :'pg_idx_013_min_bytes'::bigint
  AND pg_indexes_size(c.oid) >= :'pg_idx_013_index_multiple'::numeric * pg_table_size(c.oid)
ORDER BY pg_indexes_size(c.oid) DESC;
