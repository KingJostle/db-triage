-- check: PG-IDX-015
-- title: Single-column index on a very low-cardinality column
-- priority: 150
-- scope: index
-- cost: 1
-- thresholds: max_distinct, min_bytes
SELECT 'PG-IDX-015'::text AS check_id,
       'index'::text      AS scope,
       format('%I.%I.%I', current_database(), n.nspname, ic.relname)::text AS object,
       format('Index %s on %s.%s(%s) covers a column with only %s distinct values, on a table of %s. An index whose most common value covers %s%% of the table cannot help the planner for that value - a sequential scan is cheaper - so it earns its keep only for the rare values. Index size %s, recorded scans %s. If the queries always filter for one particular value, a partial index (CREATE INDEX ... WHERE col = ...) is a fraction of the size and is maintained only for the rows that match.',
              ic.relname, n.nspname, tc.relname, st.attname,
              st.n_distinct::text,
              pg_size_pretty(pg_relation_size(i.indrelid)),
              round(100 * coalesce(st.most_common_freqs[1], 0))::text,
              pg_size_pretty(pg_relation_size(i.indexrelid)),
              coalesce(s.idx_scan::text, 'unknown')) AS details,
       json_build_object('schema', n.nspname, 'table', tc.relname, 'index', ic.relname,
                         'column', st.attname, 'n_distinct', st.n_distinct,
                         'most_common_freq', st.most_common_freqs[1],
                         'index_bytes', pg_relation_size(i.indexrelid),
                         'table_bytes', pg_relation_size(i.indrelid),
                         'idx_scan', s.idx_scan,
                         'threshold_distinct', :'pg_idx_015_max_distinct'::numeric,
                         'threshold_bytes', :'pg_idx_015_min_bytes'::bigint)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_index i
JOIN pg_class ic    ON ic.oid = i.indexrelid
JOIN pg_class tc    ON tc.oid = i.indrelid
JOIN pg_namespace n ON n.oid = tc.relnamespace
JOIN pg_am am       ON am.oid = ic.relam AND am.amname = 'btree'
JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
JOIN pg_stats st    ON st.schemaname = n.nspname AND st.tablename = tc.relname AND st.attname = a.attname
LEFT JOIN pg_stat_user_indexes s ON s.indexrelid = i.indexrelid
WHERE i.indisvalid AND i.indnatts = 1 AND i.indexprs IS NULL AND i.indpred IS NULL
  AND NOT i.indisunique AND NOT i.indisprimary
  AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND st.n_distinct > 0 AND st.n_distinct <= :'pg_idx_015_max_distinct'::numeric
  AND pg_relation_size(i.indrelid) >= :'pg_idx_015_min_bytes'::bigint
ORDER BY pg_relation_size(i.indexrelid) DESC;
