-- check: PG-REL-012
-- title: restart_after_crash disabled
-- priority: 100
-- scope: setting
-- cost: 0
SELECT 'PG-REL-012'::text            AS check_id,
       'setting'::text               AS scope,
       'restart_after_crash'::text   AS object,
       format('restart_after_crash = off (source %s). If any backend dies abnormally, the postmaster shuts the whole cluster down and leaves it down instead of running crash recovery and coming back. That is the correct setting when an external cluster manager - Patroni, repmgr, a Kubernetes operator - needs to make the failover decision itself, and it is an outage waiting to happen when nothing external is watching. Record the supervisor in .db-triage.yml as baseline.supervisor to silence this. Uptime %s, %s connection(s) now.',
              s.source,
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend')) AS details,
       json_build_object('restart_after_crash', s.setting, 'source', s.source,
                         'uptime_seconds', round(extract(epoch FROM now() - pg_postmaster_start_time()))::bigint,
                         'in_recovery', pg_is_in_recovery(),
                         'replication_slots', (SELECT count(*) FROM pg_replication_slots))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_settings s
WHERE s.name = 'restart_after_crash' AND s.setting = 'off';
