-- check: PG-REPL-007
-- title: Streaming replica lag moderate
-- priority: 50
-- scope: replica
-- cost: 0
-- min_version: 10
-- run_on: primary
-- thresholds: lag_bytes, lag_seconds, lag_bytes_high, lag_seconds_high
SELECT 'PG-REPL-007'::text AS check_id,
       'replica'::text  AS scope,
       coalesce(nullif(r.application_name, ''), 'pid:' || r.pid::text)::text AS object,
       format('Standby %s at %s is %s behind on replay and %s behind in time (thresholds %s / %s). state = %s, sync_state = %s. sent %s, write %s, flush %s, replay %s. write_lag %s, flush_lag %s, replay_lag %s. A failover to this standby now would lose everything after its replay position, and promoting it would first have to apply the backlog.',
              coalesce(nullif(r.application_name, ''), 'unnamed'),
              coalesce(host(r.client_addr), 'local socket'),
              pg_size_pretty(greatest(pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn), 0)::bigint),
              coalesce(justify_interval(r.replay_lag)::text, 'an unknown interval'),
              pg_size_pretty(:'pg_repl_007_lag_bytes'::bigint),
              (:'pg_repl_007_lag_seconds'::int || ' seconds')::interval::text,
              r.state, r.sync_state,
              r.sent_lsn::text, r.write_lsn::text, r.flush_lsn::text, r.replay_lsn::text,
              coalesce(r.write_lag::text, 'null'), coalesce(r.flush_lag::text, 'null'),
              coalesce(r.replay_lag::text, 'null')) AS details,
       json_build_object('application_name', r.application_name, 'client_addr', host(r.client_addr),
                         'state', r.state, 'sync_state', r.sync_state, 'pid', r.pid,
                         'lag_bytes', greatest(pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn), 0)::bigint,
                         'replay_lag_seconds', round(extract(epoch FROM r.replay_lag))::bigint,
                         'write_lag_seconds', round(extract(epoch FROM r.write_lag))::bigint,
                         'flush_lag_seconds', round(extract(epoch FROM r.flush_lag))::bigint,
                         'threshold_bytes', :'pg_repl_007_lag_bytes'::bigint,
                         'threshold_seconds', :'pg_repl_007_lag_seconds'::int,
                         'sent_lsn', r.sent_lsn::text, 'replay_lsn', r.replay_lsn::text,
                         'backend_start', r.backend_start)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_replication r
WHERE (greatest(pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn), 0) >= :'pg_repl_007_lag_bytes'::bigint
       OR r.replay_lag >= (:'pg_repl_007_lag_seconds'::int || ' seconds')::interval)
  AND NOT (greatest(pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn), 0) >= :'pg_repl_007_lag_bytes_high'::bigint
           OR r.replay_lag >= (:'pg_repl_007_lag_seconds_high'::int || ' seconds')::interval)
ORDER BY pg_wal_lsn_diff(r.sent_lsn, r.replay_lsn) DESC NULLS LAST;
