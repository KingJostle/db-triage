-- check: PG-REL-005
-- title: Server restarted within the last 24 hours
-- priority: 10
-- scope: cluster
-- cost: 0
-- thresholds: uptime_seconds
SELECT 'PG-REL-005'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('The postmaster started at %s, %s ago (threshold %s). Two consequences for this report: every counter-based finding covers only that window, so rates are unreliable and "0 scans since reset" means nothing yet - those findings are marked confidence low. And the restart itself is worth explaining: a planned restart for a configuration change looks identical from here to a crash and automatic recovery (PG-REL-011 reads the log for that, in the deep pass) or to an OOM kill. %s setting(s) are currently marked pending_restart, which would mean the restart has not yet applied everything someone intended.',
              pg_postmaster_start_time(),
              justify_interval(date_trunc('second', now() - pg_postmaster_start_time())),
              (:'pg_rel_005_uptime_seconds'::int || ' seconds')::interval,
              (SELECT count(*) FROM pg_settings WHERE pending_restart)) AS details,
       json_build_object('postmaster_start_time', pg_postmaster_start_time(),
                         'uptime_seconds', round(extract(epoch FROM now() - pg_postmaster_start_time()))::bigint,
                         'threshold_seconds', :'pg_rel_005_uptime_seconds'::int,
                         'pending_restart_settings', (SELECT count(*) FROM pg_settings WHERE pending_restart),
                         'earliest_stats_reset', (SELECT min(stats_reset) FROM pg_stat_database),
                         'in_recovery', pg_is_in_recovery())::text AS evidence_json,
       'high'::text AS confidence
WHERE now() - pg_postmaster_start_time() < (:'pg_rel_005_uptime_seconds'::int || ' seconds')::interval;
