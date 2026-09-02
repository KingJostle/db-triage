-- check: PG-WAL-005
-- title: Background writer hitting its per-round limit
-- priority: 150
-- scope: cluster
-- cost: 0
-- run_on: primary
-- thresholds: maxwritten_per_day
WITH win AS (
  SELECT b.maxwritten_clean, b.buffers_clean, b.buffers_alloc, b.stats_reset,
         greatest(extract(epoch FROM now() - coalesce(b.stats_reset, pg_postmaster_start_time())) / 86400.0, 0.01) AS days
  FROM pg_stat_bgwriter b
)
SELECT 'PG-WAL-005'::text          AS check_id,
       'cluster'::text             AS scope,
       'bgwriter_lru_maxpages'::text AS object,
       format('The background writer stopped early on %s cleaning rounds over %s days (%s per day, threshold %s per day) because it reached bgwriter_lru_maxpages = %s. It cleaned %s buffers in total against %s allocations. Every buffer it does not clean in advance is one a backend has to write itself (PG-WAL-004). bgwriter_delay = %s.',
              to_char(w.maxwritten_clean, 'FM999,999,999,999'), round(w.days, 1)::text,
              to_char(round(w.maxwritten_clean / w.days), 'FM999,999,999,999'),
              :'pg_wal_005_maxwritten_per_day'::text,
              (SELECT setting FROM pg_settings WHERE name = 'bgwriter_lru_maxpages'),
              to_char(w.buffers_clean, 'FM999,999,999,999'),
              to_char(w.buffers_alloc, 'FM999,999,999,999'),
              current_setting('bgwriter_delay')) AS details,
       json_build_object('maxwritten_clean', w.maxwritten_clean, 'buffers_clean', w.buffers_clean,
                         'buffers_alloc', w.buffers_alloc, 'window_days', round(w.days, 2),
                         'maxwritten_per_day', round(w.maxwritten_clean / w.days)::bigint,
                         'threshold_per_day', :'pg_wal_005_maxwritten_per_day'::bigint,
                         'bgwriter_lru_maxpages', (SELECT setting::int FROM pg_settings WHERE name = 'bgwriter_lru_maxpages'),
                         'bgwriter_delay', current_setting('bgwriter_delay'),
                         'stats_reset', w.stats_reset)::text AS evidence_json,
       'medium'::text AS confidence
FROM win w
WHERE NOT pg_is_in_recovery()
  AND w.maxwritten_clean / w.days >= :'pg_wal_005_maxwritten_per_day'::numeric;
