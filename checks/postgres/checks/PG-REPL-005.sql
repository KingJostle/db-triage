-- check: PG-REPL-005
-- title: Replication slot invalidated or lost
-- priority: 10
-- scope: slot
-- cost: 0
-- min_version: 13
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 160000) AS pg_repl_005_has_conflicting \gset
SELECT (current_setting('server_version_num')::int >= 170000) AS pg_repl_005_has_reason \gset
WITH slots AS (
  SELECT s.slot_name, s.slot_type, s.plugin, s.database, s.active, s.wal_status, s.restart_lsn,
\if :pg_repl_005_has_conflicting
         s.conflicting,
\else
         NULL::boolean AS conflicting,
\endif
\if :pg_repl_005_has_reason
         s.invalidation_reason
\else
         NULL::text AS invalidation_reason
\endif
  FROM pg_replication_slots s
)
SELECT 'PG-REPL-005'::text AS check_id,
       'slot'::text        AS scope,
       s.slot_name::text   AS object,
       format('Replication slot %s (%s%s) is no longer usable: wal_status = %s%s%s. The WAL it needed has already been removed, so the consumer cannot resume from where it stopped and must be re-initialised from a fresh snapshot. The slot still exists, so topology diagrams and monitoring that only check "does the slot exist" will report it as healthy. active = %s.',
              s.slot_name, s.slot_type, coalesce(', plugin ' || s.plugin, ''),
              coalesce(s.wal_status, 'unknown'),
              coalesce(', invalidation_reason = ' || s.invalidation_reason, ''),
              CASE WHEN s.conflicting THEN ', conflicting with recovery' ELSE '' END,
              s.active) AS details,
       json_build_object('slot_name', s.slot_name, 'slot_type', s.slot_type, 'plugin', s.plugin,
                         'database', s.database, 'active', s.active, 'wal_status', s.wal_status,
                         'conflicting', s.conflicting, 'invalidation_reason', s.invalidation_reason,
                         'restart_lsn', s.restart_lsn::text)::text AS evidence_json,
       'high'::text AS confidence
FROM slots s
WHERE s.wal_status = 'lost' OR s.conflicting IS TRUE OR s.invalidation_reason IS NOT NULL;
