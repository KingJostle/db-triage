-- check: PG-DUR-004
-- title: synchronous_commit weaker than the synchronous-standby expectation
-- priority: 100
-- scope: setting
-- cost: 0
-- min_version: 9.6
-- run_on: primary
SELECT 'PG-DUR-004'::text         AS check_id,
       'setting'::text            AS scope,
       'synchronous_commit'::text AS object,
       format('Standby %s is in sync_state = %s while synchronous_commit = %s. At that level the primary waits only for the standby to %s, not to flush WAL to its own durable storage, so a crash of the standby host can lose transactions the primary already reported as safely replicated. synchronous_standby_names = %s.',
              coalesce(nullif(r.application_name, ''), 'unnamed'), r.sync_state, s.setting,
              CASE s.setting WHEN 'remote_write' THEN 'receive the WAL into its operating-system cache'
                             WHEN 'local' THEN 'nothing at all: only the primary flush is awaited'
                             ELSE s.setting END,
              coalesce(nullif(current_setting('synchronous_standby_names'), ''), '(empty)')) AS details,
       json_build_object('synchronous_commit', s.setting, 'source', s.source,
                         'standby', r.application_name, 'sync_state', r.sync_state,
                         'synchronous_standby_names', current_setting('synchronous_standby_names'),
                         'flush_lsn', r.flush_lsn::text, 'write_lsn', r.write_lsn::text)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
JOIN pg_stat_replication r ON r.sync_state IN ('sync', 'quorum')
WHERE s.name = 'synchronous_commit' AND s.setting IN ('local', 'remote_write');
