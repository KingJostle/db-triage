-- check: PG-QRY-001
-- title: pg_stat_statements not available
-- priority: 100
-- scope: database
-- cost: 0
SELECT 'PG-QRY-001'::text AS check_id,
       'database'::text   AS scope,
       current_database()::text AS object,
       format('pg_stat_statements is %s. Without it there is no per-statement view of this workload at all: PG-QRY-003 through PG-QRY-016 cannot run, and the only evidence about what the server spends its time on is the aggregate counters in pg_stat_database and whatever the slow-query log has captured (log_min_duration_statement = %s). %s Collecting it costs a small fixed amount of shared memory and a hash lookup per statement.',
              CASE WHEN NOT p.preloaded THEN 'not in shared_preload_libraries'
                   WHEN NOT p.available THEN 'preloaded but not present as an available extension'
                   ELSE format('preloaded but not created in database %s', current_database()) END,
              current_setting('log_min_duration_statement'),
              CASE WHEN NOT p.preloaded
                   THEN 'Adding it to shared_preload_libraries requires a server restart, then CREATE EXTENSION pg_stat_statements in each database you want to observe.'
                   ELSE 'The library is already loaded, so only CREATE EXTENSION pg_stat_statements is needed here - no restart.' END) AS details,
       json_build_object('preloaded', p.preloaded, 'available', p.available, 'installed', p.installed,
                         'shared_preload_libraries', current_setting('shared_preload_libraries'),
                         'log_min_duration_statement', current_setting('log_min_duration_statement'),
                         'database', current_database())::text AS evidence_json,
       'high'::text AS confidence
FROM (
  SELECT current_setting('shared_preload_libraries') LIKE '%pg_stat_statements%' AS preloaded,
         EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_stat_statements') AS available,
         EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') AS installed
) p
WHERE NOT p.installed OR NOT p.preloaded;
