-- check: PG-REPL-008
-- title: Standby not streaming
-- priority: 5
-- scope: cluster
-- cost: 0
-- min_version: 9.6
-- run_on: standby
-- thresholds: replay_gap_bytes
WITH w AS (SELECT * FROM pg_stat_wal_receiver),
     p AS (SELECT pg_last_wal_receive_lsn() AS recv, pg_last_wal_replay_lsn() AS replay,
                  pg_last_xact_replay_timestamp() AS last_xact)
SELECT 'PG-REPL-008'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('This standby is not keeping up with its source. WAL receiver: %s. restore_command: %s. Last received LSN %s, last replayed LSN %s, gap %s (threshold %s). Last replayed transaction committed at %s%s. Until this is fixed the standby is stale as a failover target and stale as a read replica.',
              CASE WHEN w.pid IS NULL THEN 'not running'
                   ELSE format('pid %s, status %s, source %s, last message %s',
                               w.pid, w.status, coalesce(w.sender_host, '?'),
                               coalesce(w.last_msg_receipt_time::text, 'never')) END,
              coalesce(nullif(current_setting('restore_command'), ''), '(empty)'),
              coalesce(p.recv::text, 'none'), coalesce(p.replay::text, 'none'),
              coalesce(pg_size_pretty(greatest(pg_wal_lsn_diff(p.recv, p.replay), 0)::bigint), 'unknown'),
              pg_size_pretty(:'pg_repl_008_replay_gap_bytes'::bigint),
              coalesce(p.last_xact::text, 'unknown'),
              coalesce(' (' || justify_interval(date_trunc('second', now() - p.last_xact))::text || ' ago)', '')) AS details,
       json_build_object('receiver_pid', w.pid, 'receiver_status', w.status,
                         'sender_host', w.sender_host, 'last_msg_receipt_time', w.last_msg_receipt_time,
                         'restore_command', current_setting('restore_command'),
                         'last_wal_receive_lsn', p.recv::text, 'last_wal_replay_lsn', p.replay::text,
                         'replay_gap_bytes', greatest(pg_wal_lsn_diff(p.recv, p.replay), 0)::bigint,
                         'threshold_bytes', :'pg_repl_008_replay_gap_bytes'::bigint,
                         'last_xact_replay_timestamp', p.last_xact)::text AS evidence_json,
       'high'::text AS confidence
FROM p LEFT JOIN w ON true
WHERE pg_is_in_recovery()
  AND ((w.pid IS NULL OR w.status IS DISTINCT FROM 'streaming')
        AND coalesce(nullif(trim(current_setting('restore_command')), ''), '') = ''
       OR greatest(pg_wal_lsn_diff(p.recv, p.replay), 0) >= :'pg_repl_008_replay_gap_bytes'::bigint);
