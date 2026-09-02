-- check: PG-MEM-004
-- title: work_mem at the default with heavy temp-file spill
-- priority: 100
-- scope: setting
-- cost: 0
-- thresholds: work_mem_bytes, temp_bytes_per_day, temp_files_per_day
WITH win AS (
  SELECT sum(d.temp_bytes)::numeric AS temp_bytes, sum(d.temp_files)::numeric AS temp_files,
         greatest(extract(epoch FROM now() - coalesce(min(d.stats_reset), pg_postmaster_start_time())) / 86400.0, 0.01) AS days,
         min(d.stats_reset) AS stats_reset
  FROM pg_stat_database d WHERE d.datname IS NOT NULL
)
SELECT 'PG-MEM-004'::text AS check_id,
       'setting'::text    AS scope,
       'work_mem'::text   AS object,
       format('work_mem = %s (threshold %s) while the cluster wrote %s of temporary files in %s files over %s days: %s per day and %s files per day (thresholds %s per day, %s files per day). Every one of those is a sort, hash or materialise that did not fit in work_mem and went to disk. Counted from pg_stat_database since %s. Raise work_mem for the roles that run the heavy queries (ALTER ROLE ... SET work_mem), not globally - the global value multiplies by max_connections in PG-MEM-003.',
              current_setting('work_mem'),
              pg_size_pretty(:'pg_mem_004_work_mem_bytes'::bigint),
              pg_size_pretty(w.temp_bytes::bigint), to_char(w.temp_files, 'FM999,999,999,999'),
              round(w.days, 1)::text,
              pg_size_pretty((w.temp_bytes / w.days)::bigint),
              to_char(round(w.temp_files / w.days), 'FM999,999,999'),
              pg_size_pretty(:'pg_mem_004_temp_bytes_per_day'::bigint),
              to_char(:'pg_mem_004_temp_files_per_day'::bigint, 'FM999,999,999'),
              coalesce(w.stats_reset::text, 'the last statistics reset')) AS details,
       json_build_object('work_mem_bytes', (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem'),
                         'threshold_work_mem_bytes', :'pg_mem_004_work_mem_bytes'::bigint,
                         'temp_bytes', w.temp_bytes::bigint, 'temp_files', w.temp_files::bigint,
                         'window_days', round(w.days, 2),
                         'temp_bytes_per_day', (w.temp_bytes / w.days)::bigint,
                         'temp_files_per_day', round(w.temp_files / w.days)::bigint,
                         'threshold_bytes_per_day', :'pg_mem_004_temp_bytes_per_day'::bigint,
                         'threshold_files_per_day', :'pg_mem_004_temp_files_per_day'::bigint,
                         'stats_reset', w.stats_reset)::text AS evidence_json,
       'medium'::text AS confidence
FROM win w
WHERE (SELECT setting::bigint * 1024 FROM pg_settings WHERE name = 'work_mem') <= :'pg_mem_004_work_mem_bytes'::bigint
  AND (w.temp_bytes / w.days >= :'pg_mem_004_temp_bytes_per_day'::bigint
    OR w.temp_files / w.days >= :'pg_mem_004_temp_files_per_day'::bigint);
