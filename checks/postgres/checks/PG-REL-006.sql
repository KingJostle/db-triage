-- check: PG-REL-006
-- title: Slow-query logging disabled
-- priority: 100
-- scope: setting
-- cost: 0
SELECT 'PG-REL-006'::text                  AS check_id,
       'setting'::text                     AS scope,
       'log_min_duration_statement'::text  AS object,
       format('log_min_duration_statement = -1 (source %s) and auto_explain is not loaded. No statement is ever logged for being slow, so when someone reports that "the application was slow at 3am" there is nothing on the server to look at afterwards: pg_stat_statements (%s here) gives cumulative totals, not the individual slow execution, its parameters or its timestamp. A threshold of 250 to 1000 ms costs one log line per slow statement; on a busy server log_min_duration_sample plus log_statement_sample_rate (PostgreSQL 13 and newer) bound the volume. log_statement = %s, log_destination = %s.',
              s.source,
              CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements')
                   THEN 'installed' ELSE 'not installed' END,
              current_setting('log_statement'), current_setting('log_destination')) AS details,
       json_build_object('log_min_duration_statement', s.setting, 'source', s.source,
                         'auto_explain_loaded', current_setting('shared_preload_libraries') LIKE '%auto_explain%',
                         'pgss_installed', EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'),
                         'log_statement', current_setting('log_statement'),
                         'log_destination', current_setting('log_destination'),
                         'logging_collector', current_setting('logging_collector'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'log_min_duration_statement' AND s.setting::int = -1
  AND current_setting('shared_preload_libraries') NOT LIKE '%auto_explain%';
