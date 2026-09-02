-- check: PG-BAK-002
-- title: archive_command is failing
-- priority: 1
-- scope: cluster
-- cost: 0
-- min_version: 9.4
-- run_on: primary
SELECT 'PG-BAK-002'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('pg_stat_archiver reports %s failures; the last failure was at %s (%s ago) on WAL file %s, and the last success was %s. Failing archiving means WAL segments cannot be recycled: pg_wal grows until the volume fills, at which point the server PANICs. Statistics reset %s.',
              to_char(a.failed_count, 'FM999,999,999,999'),
              a.last_failed_time,
              justify_interval(date_trunc('second', now() - a.last_failed_time)),
              coalesce(a.last_failed_wal, 'unknown'),
              coalesce(a.last_archived_time::text || ' (' || justify_interval(date_trunc('second', now() - a.last_archived_time))::text || ' ago, ' || coalesce(a.last_archived_wal, '?') || ')', 'never'),
              coalesce(a.stats_reset::text, 'unknown')) AS details,
       json_build_object('failed_count', a.failed_count, 'archived_count', a.archived_count,
                         'last_failed_time', a.last_failed_time, 'last_failed_wal', a.last_failed_wal,
                         'last_archived_time', a.last_archived_time, 'last_archived_wal', a.last_archived_wal,
                         'stats_reset', a.stats_reset,
                         'archive_command', current_setting('archive_command'),
                         'seconds_since_last_success',
                            CASE WHEN a.last_archived_time IS NULL THEN NULL
                                 ELSE round(extract(epoch FROM now() - a.last_archived_time))::bigint END)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_archiver a
WHERE a.failed_count > 0
  AND a.last_failed_time > coalesce(a.last_archived_time, '-infinity'::timestamptz);
