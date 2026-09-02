-- check: PG-WAL-007
-- title: WAL buffers overflowing
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 14
-- run_on: primary
-- thresholds: full_ratio, min_full
SELECT 'PG-WAL-007'::text  AS check_id,
       'cluster'::text     AS scope,
       'wal_buffers'::text AS object,
       format('wal_buffers_full = %s against wal_write = %s (%s%%, thresholds %s%% and %s occurrences) since %s. Each of those is a backend that had to flush WAL itself because the shared WAL buffer was full, which serialises writers behind an I/O. wal_buffers = %s; raising it needs a restart. wal_bytes since reset: %s.',
              to_char(w.wal_buffers_full, 'FM999,999,999,999'),
              to_char(w.wal_write, 'FM999,999,999,999'),
              round(100.0 * w.wal_buffers_full / nullif(w.wal_write, 0), 1)::text,
              round(100 * :'pg_wal_007_full_ratio'::numeric)::text,
              to_char(:'pg_wal_007_min_full'::bigint, 'FM999,999,999,999'),
              coalesce(w.stats_reset::text, 'the last statistics reset'),
              current_setting('wal_buffers'),
              pg_size_pretty(w.wal_bytes::bigint)) AS details,
       json_build_object('wal_buffers_full', w.wal_buffers_full, 'wal_write', w.wal_write,
                         'full_ratio', round(w.wal_buffers_full::numeric / nullif(w.wal_write, 0), 4),
                         'threshold_ratio', :'pg_wal_007_full_ratio'::numeric,
                         'threshold_min_full', :'pg_wal_007_min_full'::bigint,
                         'wal_bytes', w.wal_bytes::bigint, 'stats_reset', w.stats_reset,
                         'wal_buffers', current_setting('wal_buffers'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_wal w
WHERE NOT pg_is_in_recovery()
  AND w.wal_buffers_full >= :'pg_wal_007_min_full'::bigint
  AND w.wal_buffers_full::numeric / nullif(w.wal_write, 0) >= :'pg_wal_007_full_ratio'::numeric;
