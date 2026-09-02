-- check: PG-QRY-015
-- title: compute_query_id off
-- priority: 150
-- scope: setting
-- cost: 0
-- min_version: 14
SELECT 'PG-QRY-015'::text          AS check_id,
       'setting'::text             AS scope,
       'compute_query_id'::text    AS object,
       format('compute_query_id = %s and no query-id provider is active, so pg_stat_activity.query_id is null and %%Q in log_line_prefix produces nothing. Without a query id there is no way to join a slow line in the log, or a session seen in pg_stat_activity, to its row in pg_stat_statements: every correlation has to be done by matching query text by hand. On "auto" the id is computed only when an extension asks for it; pg_stat_statements does ask, so "auto" is enough when it is loaded - here it is %s. Setting it to "on" costs one hash per parse. log_line_prefix = %s.',
              s.setting,
              CASE WHEN current_setting('shared_preload_libraries') LIKE '%pg_stat_statements%'
                   THEN 'loaded' ELSE 'not loaded' END,
              quote_literal(current_setting('log_line_prefix'))) AS details,
       json_build_object('compute_query_id', s.setting, 'source', s.source,
                         'pgss_preloaded', current_setting('shared_preload_libraries') LIKE '%pg_stat_statements%',
                         'log_line_prefix', current_setting('log_line_prefix'))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.name = 'compute_query_id'
  AND (s.setting = 'off'
       OR (s.setting = 'auto' AND current_setting('shared_preload_libraries') NOT LIKE '%pg_stat_statements%'));
