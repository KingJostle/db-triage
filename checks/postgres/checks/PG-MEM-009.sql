-- check: PG-MEM-009
-- title: temp_file_limit unlimited
-- priority: 100
-- scope: setting
-- cost: 0
SELECT 'PG-MEM-009'::text        AS check_id,
       'setting'::text           AS scope,
       'temp_file_limit'::text   AS object,
       format('temp_file_limit = -1 (unlimited), source %s. A single sort, hash join or CTE materialisation that under-estimates its input can write until the data volume is full, at which point every write in the cluster fails and, if pg_wal shares the volume, the server PANICs. The cluster already writes %s of temporary files per day (PG-CAP-008 measures it). A limit sized so one query cannot fill the volume turns that outage into one failed query with "temporary file size exceeds temp_file_limit". work_mem = %s.',
              s.source,
              coalesce(pg_size_pretty((SELECT (sum(temp_bytes) / greatest(extract(epoch FROM now() - coalesce(min(stats_reset), pg_postmaster_start_time())) / 86400.0, 0.01))::bigint
                                       FROM pg_stat_database)), 'an unknown amount'),
              current_setting('work_mem')) AS details,
       json_build_object('temp_file_limit', -1, 'source', s.source,
                         'work_mem', current_setting('work_mem'),
                         'temp_bytes_total', (SELECT sum(temp_bytes) FROM pg_stat_database))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'temp_file_limit' AND s.setting::bigint = -1;
