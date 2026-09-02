-- check: PG-BAK-003
-- title: WAL archiving stalled
-- priority: 1
-- scope: cluster
-- cost: 1
-- min_version: 12
-- run_on: primary
-- thresholds: ready_files, stall_seconds, segments_behind
WITH ready AS (
  SELECT count(*) FILTER (WHERE name LIKE '%.ready') AS ready_files
  FROM pg_ls_archive_statusdir()
),
arch AS (SELECT * FROM pg_stat_archiver)
SELECT 'PG-BAK-003'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('%s WAL segments are queued for archiving in pg_wal/archive_status (threshold %s). Last archived %s at %s (%s ago); current WAL position is %s. archive_timeout = %s, archive_command = %s. The queue drains only as fast as the archive command succeeds; while it grows, pg_wal grows with it.',
              to_char(r.ready_files, 'FM999,999,999'),
              :'pg_bak_003_ready_files'::text,
              coalesce(a.last_archived_wal, 'nothing'),
              coalesce(a.last_archived_time::text, 'never'),
              coalesce(justify_interval(date_trunc('second', now() - a.last_archived_time))::text, 'n/a'),
              pg_walfile_name(pg_current_wal_lsn()),
              current_setting('archive_timeout'),
              coalesce(nullif(current_setting('archive_command'), ''), '(empty)')) AS details,
       json_build_object('ready_files', r.ready_files, 'threshold_ready_files', :'pg_bak_003_ready_files'::int,
                         'last_archived_wal', a.last_archived_wal, 'last_archived_time', a.last_archived_time,
                         'current_wal_file', pg_walfile_name(pg_current_wal_lsn()),
                         'failed_count', a.failed_count, 'archived_count', a.archived_count,
                         'archive_timeout', current_setting('archive_timeout'))::text AS evidence_json,
       'high'::text AS confidence
FROM ready r CROSS JOIN arch a
WHERE current_setting('archive_mode') <> 'off'
  AND NOT pg_is_in_recovery()
  AND (r.ready_files >= :'pg_bak_003_ready_files'::int
       OR (a.last_archived_time IS NOT NULL
           AND now() - a.last_archived_time > greatest(
                 (:'pg_bak_003_stall_seconds'::int || ' seconds')::interval,
                 3 * (SELECT setting::int FROM pg_settings WHERE name = 'archive_timeout') * interval '1 second')
           AND (SELECT setting::int FROM pg_settings WHERE name = 'archive_timeout') > 0));
