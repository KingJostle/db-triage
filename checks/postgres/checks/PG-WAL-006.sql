-- check: PG-WAL-006
-- title: pg_wal directory unusually large
-- priority: 50
-- scope: cluster
-- cost: 1
-- min_version: 10
-- thresholds: waldir_multiple, waldir_floor_bytes
WITH w AS (
  SELECT sum(size)::bigint AS wal_bytes, count(*) AS segments FROM pg_ls_waldir()
),
lim AS (
  SELECT greatest(:'pg_wal_006_waldir_multiple'::numeric
                    * (SELECT setting::bigint FROM pg_settings WHERE name = 'max_wal_size') * 1048576,
                  :'pg_wal_006_waldir_floor_bytes'::bigint) AS threshold
)
SELECT 'PG-WAL-006'::text AS check_id,
       'cluster'::text    AS scope,
       'pg_wal'::text     AS object,
       format('pg_wal holds %s across %s files, above the threshold of %s (the larger of %sx max_wal_size = %s and the floor %s). This is a symptom, not a cause. Look for: archiving failing or stalled (PG-BAK-002/003), a replication slot pinning WAL (PG-REPL-002/003/004 - %s slot(s) exist, %s inactive), or wal_keep_size = %s. If pg_wal shares a volume with the data directory, PG-CAP-001/002 matter more than this row does.',
              pg_size_pretty(w.wal_bytes), w.segments, pg_size_pretty(lim.threshold::bigint),
              :'pg_wal_006_waldir_multiple'::text,
              pg_size_pretty(((SELECT setting::bigint FROM pg_settings WHERE name = 'max_wal_size') * 1048576)::bigint),
              pg_size_pretty(:'pg_wal_006_waldir_floor_bytes'::bigint),
              (SELECT count(*) FROM pg_replication_slots),
              (SELECT count(*) FROM pg_replication_slots WHERE NOT active),
              current_setting('wal_keep_size')) AS details,
       json_build_object('wal_bytes', w.wal_bytes, 'wal_segments', w.segments,
                         'threshold_bytes', lim.threshold::bigint,
                         'max_wal_size', current_setting('max_wal_size'),
                         'wal_keep_size', current_setting('wal_keep_size'),
                         'slot_count', (SELECT count(*) FROM pg_replication_slots),
                         'inactive_slots', (SELECT count(*) FROM pg_replication_slots WHERE NOT active),
                         'archive_mode', current_setting('archive_mode'),
                         'archiver_failed_count', (SELECT failed_count FROM pg_stat_archiver))::text AS evidence_json,
       'high'::text AS confidence
FROM w CROSS JOIN lim
WHERE w.wal_bytes >= lim.threshold;
