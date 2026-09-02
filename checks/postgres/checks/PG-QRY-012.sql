-- check: PG-QRY-012
-- title: track_io_timing disabled
-- priority: 150
-- scope: setting
-- cost: 0
SELECT 'PG-QRY-012'::text        AS check_id,
       'setting'::text           AS scope,
       'track_io_timing'::text   AS object,
       format('track_io_timing = off (source %s). Every I/O-time column is therefore zero: blk_read_time and blk_write_time in pg_stat_database, the corresponding columns in pg_stat_statements, and the "I/O Timings" line in EXPLAIN (ANALYZE, BUFFERS). Without them there is no way to tell a query that is slow because it is waiting on storage from one that is slow because it is burning CPU, which is the first fork in any performance investigation. Measure the cost on this host with pg_test_timing before enabling it; on modern hardware with a TSC clocksource it is a few nanoseconds per call. track_functions = %s, track_activities = %s.',
              s.source, current_setting('track_functions'), current_setting('track_activities')) AS details,
       json_build_object('track_io_timing', s.setting, 'source', s.source,
                         'track_functions', current_setting('track_functions'),
                         'track_activities', current_setting('track_activities'),
                         'pgss_installed', EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'track_io_timing' AND s.setting = 'off';
