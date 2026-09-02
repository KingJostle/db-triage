-- check: PG-CAP-008
-- title: Temp-file volume high
-- priority: 100
-- scope: database
-- cost: 0
-- thresholds: temp_bytes_per_day
WITH w AS (
  SELECT d.datname, d.temp_bytes, d.temp_files, d.stats_reset,
         greatest(extract(epoch FROM now() - coalesce(d.stats_reset, pg_postmaster_start_time())) / 86400.0, 0.01) AS days
  FROM pg_stat_database d WHERE d.datname IS NOT NULL
)
SELECT 'PG-CAP-008'::text AS check_id,
       'database'::text   AS scope,
       w.datname::text    AS object,
       format('Database %s wrote %s of temporary files in %s files over %s days: %s per day (threshold %s per day), average %s per file. Counted since %s. Every one of those bytes was written to and read back from the data volume by a sort, hash or materialise that did not fit in work_mem (%s) - it is both I/O the queries did not need and disk that could fill the volume, since temp_file_limit is %s (PG-MEM-009). PG-MEM-004 covers the setting, PG-QRY-009 names the statements.',
              w.datname, pg_size_pretty(w.temp_bytes),
              to_char(w.temp_files, 'FM999,999,999,999'), round(w.days, 1)::text,
              pg_size_pretty((w.temp_bytes / w.days)::bigint),
              pg_size_pretty(:'pg_cap_008_temp_bytes_per_day'::bigint),
              pg_size_pretty((w.temp_bytes / greatest(w.temp_files, 1))::bigint),
              coalesce(w.stats_reset::text, 'the last statistics reset'),
              current_setting('work_mem'), current_setting('temp_file_limit')) AS details,
       json_build_object('datname', w.datname, 'temp_bytes', w.temp_bytes, 'temp_files', w.temp_files,
                         'window_days', round(w.days, 2),
                         'temp_bytes_per_day', (w.temp_bytes / w.days)::bigint,
                         'threshold_bytes_per_day', :'pg_cap_008_temp_bytes_per_day'::bigint,
                         'avg_temp_file_bytes', (w.temp_bytes / greatest(w.temp_files, 1))::bigint,
                         'work_mem', current_setting('work_mem'),
                         'temp_file_limit', current_setting('temp_file_limit'),
                         'stats_reset', w.stats_reset)::text AS evidence_json,
       'medium'::text AS confidence
FROM w
WHERE w.temp_bytes / w.days >= :'pg_cap_008_temp_bytes_per_day'::bigint
ORDER BY w.temp_bytes DESC;
