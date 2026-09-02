-- check: PG-IDX-002
-- title: Unused index 1 GB or larger
-- priority: 50
-- scope: index
-- cost: 1
-- thresholds: min_bytes, stats_age_days
WITH win AS (
  SELECT greatest(extract(epoch FROM now() - coalesce(
           (SELECT min(stats_reset) FROM pg_stat_database WHERE datname = current_database()),
           pg_postmaster_start_time())) / 86400.0, 0.01) AS days
)
SELECT 'PG-IDX-002'::text AS check_id,
       'index'::text    AS scope,
       format('%I.%I.%I', current_database(), s.schemaname, s.indexrelname)::text AS object,
       format('Index %s on %s.%s has been scanned 0 times in %s days of collected statistics (threshold: size >= %s%s). Size %s, table %s, %s writes to the table since the reset - every one of those maintained this index for nothing. Definition: %s. Usage counters are per instance: an index unused here may be serving a read replica, so verify on every standby before dropping. The reversible first step is ALTER INDEX %s.%s SET (deprecated) - there is no such option, so in practice: drop it in a transaction you are prepared to roll back, or rename it and watch for errors, then DROP INDEX CONCURRENTLY.',
              s.indexrelname, s.schemaname, s.relname,
              round(w.days, 1)::text,
              pg_size_pretty(:'pg_idx_002_min_bytes'::bigint), ' and statistics at least 30 days old',
              pg_size_pretty(pg_relation_size(s.indexrelid)),
              pg_size_pretty(pg_relation_size(s.relid)),
              to_char(coalesce(t.n_tup_ins + t.n_tup_upd + t.n_tup_del, 0), 'FM999,999,999,999'),
              pg_get_indexdef(s.indexrelid),
              quote_ident(s.schemaname), quote_ident(s.indexrelname)) AS details,
       json_build_object('schema', s.schemaname, 'table', s.relname, 'index', s.indexrelname,
                         'idx_scan', s.idx_scan,
                         'index_bytes', pg_relation_size(s.indexrelid),
                         'table_bytes', pg_relation_size(s.relid),
                         'threshold_bytes', :'pg_idx_002_min_bytes'::bigint,
                         'stats_window_days', round(w.days, 2),
                         'table_writes', coalesce(t.n_tup_ins + t.n_tup_upd + t.n_tup_del, 0),
                         'indexdef', pg_get_indexdef(s.indexrelid),
                         'indisunique', i.indisunique, 'indisprimary', i.indisprimary)::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_user_indexes s
JOIN pg_index i           ON i.indexrelid = s.indexrelid
LEFT JOIN pg_stat_user_tables t ON t.relid = s.relid
CROSS JOIN win w
WHERE s.idx_scan = 0
  AND NOT i.indisunique AND NOT i.indisprimary AND NOT i.indisreplident
  AND i.indisvalid
  AND NOT EXISTS (SELECT 1 FROM pg_constraint con WHERE con.conindid = s.indexrelid)
  AND pg_relation_size(s.indexrelid) >= :'pg_idx_002_min_bytes'::bigint
  AND w.days >= :'pg_idx_002_stats_age_days'::numeric
ORDER BY pg_relation_size(s.indexrelid) DESC
LIMIT 50;
