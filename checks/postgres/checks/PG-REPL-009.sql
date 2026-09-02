-- check: PG-REPL-009
-- title: Slot WAL retention unbounded
-- priority: 50
-- scope: setting
-- cost: 0
-- min_version: 13
-- run_on: primary
SELECT 'PG-REPL-009'::text            AS check_id,
       'setting'::text                AS scope,
       'max_slot_wal_keep_size'::text AS object,
       format('max_slot_wal_keep_size = -1 (unlimited) while %s replication slot(s) exist: %s. Any consumer that stops - a crashed logical decoder, a decommissioned standby whose slot was never dropped, a paused CDC connector - pins WAL indefinitely, and pg_wal grows until the volume fills and the primary PANICs. Setting a cap sized to the WAL volume converts that outage into a broken slot (wal_status = lost, PG-REPL-005), which is recoverable. pg_wal currently holds %s.',
              (SELECT count(*) FROM pg_replication_slots),
              (SELECT string_agg(format('%s (%s, active=%s)', slot_name, slot_type, active), '; ' ORDER BY slot_name)
               FROM pg_replication_slots),
              coalesce((SELECT pg_size_pretty(sum(size)) FROM pg_ls_waldir()), 'an unknown amount')) AS details,
       json_build_object('max_slot_wal_keep_size', '-1',
                         'slot_count', (SELECT count(*) FROM pg_replication_slots),
                         'inactive_slot_count', (SELECT count(*) FROM pg_replication_slots WHERE NOT active),
                         'max_wal_size', current_setting('max_wal_size'),
                         'wal_keep_size', current_setting('wal_keep_size'))::text AS evidence_json,
       'high'::text AS confidence
WHERE NOT pg_is_in_recovery()
  AND (SELECT setting::int FROM pg_settings WHERE name = 'max_slot_wal_keep_size') = -1
  AND (SELECT count(*) FROM pg_replication_slots) >= 1;
