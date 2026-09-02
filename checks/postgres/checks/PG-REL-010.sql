-- check: PG-REL-010
-- title: Settings changed but awaiting restart
-- priority: 100
-- scope: setting
-- cost: 0
-- min_version: 9.5
SELECT 'PG-REL-010'::text AS check_id,
       'setting'::text    AS scope,
       s.name::text       AS object,
       format('%s is set to %s in %s but the running server is still using %s: the change needs a restart and has not had one. The server has been up for %s. Anyone reading postgresql.conf, or an infrastructure-as-code diff, will believe the new value is live. %s',
              s.name, coalesce(s.setting, '(null)'),
              coalesce(s.sourcefile || ':' || s.sourceline::text, s.source),
              coalesce(s.reset_val, '(null)'),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              CASE WHEN s.name IN ('shared_buffers', 'max_connections', 'wal_level', 'max_wal_senders',
                                   'max_replication_slots', 'max_worker_processes', 'shared_preload_libraries',
                                   'max_prepared_transactions', 'huge_pages', 'wal_buffers')
                   THEN 'This one changes what the server can do, not only how fast it does it.'
                   ELSE '' END) AS details,
       json_build_object('setting', s.name, 'pending_value', s.setting, 'running_value', s.reset_val,
                         'source', s.source, 'sourcefile', s.sourcefile, 'sourceline', s.sourceline,
                         'context', s.context,
                         'uptime_seconds', round(extract(epoch FROM now() - pg_postmaster_start_time()))::bigint)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_settings s
WHERE s.pending_restart
ORDER BY s.name;
