-- check: PG-IDX-010
-- title: Large table with heavy sequential scans
-- priority: 50
-- scope: relation
-- cost: 1
-- thresholds: min_bytes, min_seq_scans, rows_per_scan, seq_fraction, top_n
SELECT 'PG-IDX-010'::text AS check_id,
       'relation'::text AS scope,
       format('%I.%I.%I', current_database(), t.schemaname, t.relname)::text AS object,
       format('Table %s.%s (%s) has had %s sequential scans and %s index scans since the statistics reset, reading an average of %s rows per sequential scan. Sequential scans are %s%% of all scans (thresholds: size %s, %s scans, %s rows per scan, %s%% of scans). Something queries this table without a usable index, or with a predicate the planner cannot use. Confidence is medium: a nightly export or an analytics job legitimately reads the whole table, and this counter cannot tell those apart from a missing index. PG-QRY-003 and PG-QRY-005 show which statements dominate.',
              t.schemaname, t.relname,
              pg_size_pretty(pg_relation_size(t.relid)),
              to_char(t.seq_scan, 'FM999,999,999,999'),
              to_char(coalesce(t.idx_scan, 0), 'FM999,999,999,999'),
              to_char(round(t.seq_tup_read::numeric / nullif(t.seq_scan, 0)), 'FM999,999,999,999'),
              round(100.0 * t.seq_scan / nullif(t.seq_scan + coalesce(t.idx_scan, 0), 0), 1)::text,
              pg_size_pretty(:'pg_idx_010_min_bytes'::bigint),
              :'pg_idx_010_min_seq_scans'::text,
              to_char(:'pg_idx_010_rows_per_scan'::bigint, 'FM999,999,999,999'),
              round(100 * :'pg_idx_010_seq_fraction'::numeric)::text) AS details,
       json_build_object('schema', t.schemaname, 'table', t.relname,
                         'seq_scan', t.seq_scan, 'idx_scan', coalesce(t.idx_scan, 0),
                         'seq_tup_read', t.seq_tup_read,
                         'rows_per_seq_scan', round(t.seq_tup_read::numeric / nullif(t.seq_scan, 0))::bigint,
                         'seq_fraction', round(t.seq_scan::numeric / nullif(t.seq_scan + coalesce(t.idx_scan, 0), 0), 4),
                         'relation_bytes', pg_relation_size(t.relid),
                         'index_count', (SELECT count(*) FROM pg_index i WHERE i.indrelid = t.relid),
                         'threshold_bytes', :'pg_idx_010_min_bytes'::bigint,
                         'threshold_seq_scans', :'pg_idx_010_min_seq_scans'::bigint,
                         'threshold_rows_per_scan', :'pg_idx_010_rows_per_scan'::bigint,
                         'threshold_seq_fraction', :'pg_idx_010_seq_fraction'::numeric)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_user_tables t
WHERE pg_relation_size(t.relid) >= :'pg_idx_010_min_bytes'::bigint
  AND t.seq_scan >= :'pg_idx_010_min_seq_scans'::bigint
  AND t.seq_tup_read::numeric / nullif(t.seq_scan, 0) >= :'pg_idx_010_rows_per_scan'::bigint
  AND t.seq_scan::numeric / nullif(t.seq_scan + coalesce(t.idx_scan, 0), 0) >= :'pg_idx_010_seq_fraction'::numeric
ORDER BY t.seq_tup_read DESC
LIMIT :'pg_idx_010_top_n'::int;
