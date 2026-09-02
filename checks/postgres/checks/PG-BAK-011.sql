-- check: PG-BAK-011
-- title: Base backup running for more than 2 hours
-- priority: 100
-- scope: cluster
-- cost: 0
-- min_version: 13
-- run_on: primary
-- thresholds: duration_seconds
SELECT 'PG-BAK-011'::text AS check_id,
       'cluster'::text    AS scope,
       ('pid:' || b.pid)::text AS object,
       format('A base backup started by pid %s has been running for %s (threshold %s). Phase "%s", %s of %s streamed (%s%%), %s of %s tablespaces done. It holds a WAL retention obligation for its whole duration, so pg_wal will not shrink until it finishes.',
              b.pid,
              justify_interval(date_trunc('second', now() - a.backend_start)),
              (:'pg_bak_011_duration_seconds'::int || ' seconds')::interval,
              b.phase,
              pg_size_pretty(b.backup_streamed),
              CASE WHEN b.backup_total > 0 THEN pg_size_pretty(b.backup_total) ELSE 'unknown total' END,
              CASE WHEN b.backup_total > 0
                   THEN round(100.0 * b.backup_streamed / b.backup_total, 1)::text ELSE '?' END,
              b.tablespaces_streamed, b.tablespaces_total) AS details,
       json_build_object('pid', b.pid, 'phase', b.phase,
                         'backup_streamed', b.backup_streamed, 'backup_total', b.backup_total,
                         'tablespaces_streamed', b.tablespaces_streamed, 'tablespaces_total', b.tablespaces_total,
                         'duration_seconds', round(extract(epoch FROM now() - a.backend_start))::bigint,
                         'threshold_seconds', :'pg_bak_011_duration_seconds'::int)::text AS evidence_json,
       'high'::text AS confidence
FROM pg_stat_progress_basebackup b
JOIN pg_stat_activity a ON a.pid = b.pid
WHERE now() - a.backend_start >= (:'pg_bak_011_duration_seconds'::int || ' seconds')::interval;
