-- check: PG-REPL-014
-- title: Synchronous standby with high flush lag
-- priority: 50
-- scope: replica
-- cost: 0
-- min_version: 10
-- run_on: primary
-- thresholds: flush_lag_seconds
SELECT 'PG-REPL-014'::text AS check_id,
       'replica'::text     AS scope,
       coalesce(nullif(r.application_name, ''), 'pid:' || r.pid::text)::text AS object,
       format('Synchronous standby %s at %s has flush_lag %s (threshold %s). synchronous_commit = %s, so every commit on this primary waits for that standby to flush before returning: this lag is added directly to application commit latency. write_lag %s, replay_lag %s, state %s.',
              coalesce(nullif(r.application_name, ''), 'unnamed'),
              coalesce(host(r.client_addr), 'local socket'),
              r.flush_lag::text,
              (:'pg_repl_014_flush_lag_seconds'::numeric || ' seconds')::interval::text,
              current_setting('synchronous_commit'),
              coalesce(r.write_lag::text, 'null'), coalesce(r.replay_lag::text, 'null'), r.state) AS details,
       json_build_object('application_name', r.application_name, 'sync_state', r.sync_state,
                         'flush_lag_seconds', round(extract(epoch FROM r.flush_lag), 3),
                         'write_lag_seconds', round(extract(epoch FROM r.write_lag), 3),
                         'replay_lag_seconds', round(extract(epoch FROM r.replay_lag), 3),
                         'threshold_seconds', :'pg_repl_014_flush_lag_seconds'::numeric,
                         'synchronous_commit', current_setting('synchronous_commit'),
                         'client_addr', host(r.client_addr))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_replication r
WHERE r.sync_state IN ('sync', 'quorum')
  AND r.flush_lag >= (:'pg_repl_014_flush_lag_seconds'::numeric || ' seconds')::interval
ORDER BY r.flush_lag DESC;
