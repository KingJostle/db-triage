-- check: PG-REPL-010
-- title: Standby streaming without a slot while wal_keep_size is 0
-- priority: 50
-- scope: replica
-- cost: 0
-- min_version: 9.4
-- run_on: primary
WITH keepsize AS (
  SELECT coalesce((SELECT setting::bigint FROM pg_settings WHERE name = 'wal_keep_size'),
                  (SELECT setting::bigint FROM pg_settings WHERE name = 'wal_keep_segments'), 0) AS keep,
         coalesce((SELECT name FROM pg_settings WHERE name IN ('wal_keep_size', 'wal_keep_segments')), 'wal_keep_size') AS keep_name
)
SELECT 'PG-REPL-010'::text AS check_id,
       'replica'::text     AS scope,
       coalesce(nullif(r.application_name, ''), 'pid:' || r.pid::text)::text AS object,
       format('Standby %s at %s is streaming without a replication slot while %s = 0. The primary keeps only the WAL its own checkpoints have not yet recycled, so any network interruption longer than the checkpoint interval (checkpoint_timeout = %s, max_wal_size = %s) leaves the standby asking for a segment that no longer exists, and it must be rebuilt from a fresh base backup. Existing slots: %s.',
              coalesce(nullif(r.application_name, ''), 'unnamed'),
              coalesce(host(r.client_addr), 'local socket'), k.keep_name,
              current_setting('checkpoint_timeout'),
              current_setting('max_wal_size'),
              coalesce((SELECT string_agg(slot_name, ', ') FROM pg_replication_slots), 'none')) AS details,
       json_build_object('application_name', r.application_name, 'client_addr', host(r.client_addr),
                         'pid', r.pid, 'state', r.state, 'sync_state', r.sync_state,
                         'wal_keep_setting', k.keep_name, 'wal_keep_value', k.keep,
                         'slot_count', (SELECT count(*) FROM pg_replication_slots))::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_replication r CROSS JOIN keepsize k
WHERE NOT pg_is_in_recovery()
  AND k.keep = 0
  AND NOT EXISTS (SELECT 1 FROM pg_replication_slots s WHERE s.active_pid = r.pid);
