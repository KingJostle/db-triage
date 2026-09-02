-- check: PG-REPL-004
-- title: Inactive replication slot
-- priority: 50
-- scope: slot
-- cost: 0
-- min_version: 9.4
-- thresholds: retained_bytes_low
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 130000) AS pg_repl_004_has_wal_status \gset
SELECT (current_setting('server_version_num')::int >= 170000) AS pg_repl_004_has_inactive_since \gset
WITH cur AS (
  SELECT CASE WHEN pg_is_in_recovery() THEN pg_last_wal_receive_lsn() ELSE pg_current_wal_lsn() END AS lsn
),
slots AS (
  SELECT s.slot_name, s.slot_type, s.plugin, s.database, s.active, s.active_pid,
         s.restart_lsn, s.xmin, s.catalog_xmin,
         CASE WHEN s.restart_lsn IS NULL THEN NULL
              ELSE pg_wal_lsn_diff(cur.lsn, s.restart_lsn)::bigint END AS retained_bytes,
\if :pg_repl_004_has_wal_status
         s.wal_status,
\else
         NULL::text AS wal_status,
\endif
\if :pg_repl_004_has_inactive_since
         s.inactive_since,
\else
         NULL::timestamptz AS inactive_since,
\endif
         cur.lsn AS current_lsn
  FROM pg_replication_slots s CROSS JOIN cur
)
SELECT 'PG-REPL-004'::text AS check_id,
       'slot'::text   AS scope,
       s.slot_name::text AS object,
       format('Replication slot %s (%s%s) is inactive and is holding back %s of WAL (threshold %s). restart_lsn %s against current %s.%s%s Until the slot is consumed or dropped, the WAL it pins cannot be recycled or archived away, and pg_wal grows without limit unless max_slot_wal_keep_size is set (currently %s).',
              s.slot_name, s.slot_type,
              coalesce(', plugin ' || s.plugin, ''),
              coalesce(pg_size_pretty(s.retained_bytes), 'an unknown amount'),
              pg_size_pretty(:'pg_repl_004_retained_bytes_low'::bigint),
              coalesce(s.restart_lsn::text, 'none'), s.current_lsn::text,
              coalesce(' wal_status = ' || s.wal_status || '.', ''),
              coalesce(' Inactive since ' || s.inactive_since::text || ' (' || justify_interval(date_trunc('second', now() - s.inactive_since))::text || ').', ''),
              current_setting('max_slot_wal_keep_size')) AS details,
       json_build_object('slot_name', s.slot_name, 'slot_type', s.slot_type, 'plugin', s.plugin,
                         'database', s.database, 'active', s.active,
                         'retained_bytes', s.retained_bytes,
                         'threshold_bytes', :'pg_repl_004_retained_bytes_low'::bigint,
                         'restart_lsn', s.restart_lsn::text, 'current_lsn', s.current_lsn::text,
                         'wal_status', s.wal_status, 'inactive_since', s.inactive_since,
                         'xmin_age', CASE WHEN s.xmin IS NULL THEN NULL ELSE age(s.xmin) END,
                         'catalog_xmin_age', CASE WHEN s.catalog_xmin IS NULL THEN NULL ELSE age(s.catalog_xmin) END,
                         'max_slot_wal_keep_size', current_setting('max_slot_wal_keep_size'))::text AS evidence_json,
       'high'::text AS confidence
FROM slots s
WHERE NOT s.active
  AND coalesce(s.retained_bytes, 0) < :'pg_repl_004_retained_bytes_low'::bigint
ORDER BY s.retained_bytes DESC NULLS LAST;
