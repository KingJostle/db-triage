-- check: PG-IDX-014
-- title: Wide B-tree indexes
-- priority: 150
-- scope: index
-- cost: 1
-- min_version: 11
-- thresholds: min_key_columns, min_bytes
SELECT 'PG-IDX-014'::text AS check_id,
       'index'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, ic.relname)::text AS object,
       format('Index %s on %s.%s has %s key columns (threshold %s) and occupies %s. Every key column appears in every leaf entry and in every internal page, so the index is wide, its fan-out is low and its depth is higher than it needs to be. Only queries whose predicate matches a leading prefix can use it, which is what PG-IDX-005 looks for from the other side. Recorded scans: %s. Definition: %s. If the trailing columns are only there to make the index covering, INCLUDE columns (PostgreSQL 11 and newer) give the same benefit without widening the key.',
              ic.relname, n.nspname, tc.relname, i.indnkeyatts,
              :'pg_idx_014_min_key_columns'::text,
              pg_size_pretty(pg_relation_size(i.indexrelid)),
              coalesce(s.idx_scan::text, 'unknown'),
              pg_get_indexdef(i.indexrelid)) AS details,
       json_build_object('schema', n.nspname, 'table', tc.relname, 'index', ic.relname,
                         'key_columns', i.indnkeyatts, 'total_columns', i.indnatts,
                         'index_bytes', pg_relation_size(i.indexrelid),
                         'idx_scan', s.idx_scan,
                         'threshold_key_columns', :'pg_idx_014_min_key_columns'::int,
                         'threshold_bytes', :'pg_idx_014_min_bytes'::bigint,
                         'indexdef', pg_get_indexdef(i.indexrelid))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_index i
JOIN pg_class ic    ON ic.oid = i.indexrelid
JOIN pg_class tc    ON tc.oid = i.indrelid
JOIN pg_namespace n ON n.oid = ic.relnamespace
JOIN pg_am am       ON am.oid = ic.relam AND am.amname = 'btree'
LEFT JOIN pg_stat_user_indexes s ON s.indexrelid = i.indexrelid
WHERE i.indisvalid
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND i.indnkeyatts >= :'pg_idx_014_min_key_columns'::int
  AND pg_relation_size(i.indexrelid) >= :'pg_idx_014_min_bytes'::bigint
ORDER BY pg_relation_size(i.indexrelid) DESC;
