-- check: PG-INFO-008
-- title: Checkpoint, background writer, WAL and archiver rates
-- priority: 250
-- scope: cluster
-- cost: 0
-- PostgreSQL 17 split pg_stat_bgwriter into pg_stat_bgwriter and
-- pg_stat_checkpointer and renamed the checkpoint counters.
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 170000) AS pg_info_008_pg17 \gset
SELECT (current_setting('server_version_num')::int >= 140000) AS pg_info_008_has_stat_wal \gset
WITH ck AS (
\if :pg_info_008_pg17
  SELECT num_timed AS timed, num_requested AS requested,
         write_time::numeric AS write_time, sync_time::numeric AS sync_time,
         buffers_written AS buffers_checkpoint, stats_reset
  FROM pg_stat_checkpointer
\else
  SELECT checkpoints_timed AS timed, checkpoints_req AS requested,
         checkpoint_write_time::numeric AS write_time, checkpoint_sync_time::numeric AS sync_time,
         buffers_checkpoint, stats_reset
  FROM pg_stat_bgwriter
\endif
),
bg AS (SELECT buffers_clean, maxwritten_clean, buffers_alloc, stats_reset FROM pg_stat_bgwriter),
wl AS (
\if :pg_info_008_has_stat_wal
  SELECT wal_records, wal_fpi, wal_bytes::numeric AS wal_bytes, wal_buffers_full, stats_reset FROM pg_stat_wal
\else
  SELECT NULL::bigint AS wal_records, NULL::bigint AS wal_fpi, NULL::numeric AS wal_bytes,
         NULL::bigint AS wal_buffers_full, NULL::timestamptz AS stats_reset
\endif
),
ar AS (SELECT archived_count, failed_count, last_archived_time, last_failed_time, stats_reset FROM pg_stat_archiver),
w AS (SELECT greatest(extract(epoch FROM now() - coalesce((SELECT stats_reset FROM ck), pg_postmaster_start_time())) / 3600.0, 0.01) AS hours)
SELECT 'PG-INFO-008'::text AS check_id,
       'cluster'::text     AS scope,
       NULL::text          AS object,
       format('Counters cover %s hours since %s. Checkpoints: %s timed + %s requested = %s per hour; average write phase %s ms, sync phase %s ms; %s buffers written by the checkpointer. Background writer: %s buffers cleaned, %s rounds stopped at bgwriter_lru_maxpages, %s buffers allocated. WAL: %s. Archiver: %s archived, %s failed%s.',
              round(w.hours, 1)::text,
              coalesce(ck.stats_reset::text, 'the last statistics reset'),
              to_char(ck.timed, 'FM999,999,999'), to_char(ck.requested, 'FM999,999,999'),
              round((ck.timed + ck.requested) / w.hours, 2)::text,
              round(ck.write_time / nullif(ck.timed + ck.requested, 0), 1)::text,
              round(ck.sync_time / nullif(ck.timed + ck.requested, 0), 1)::text,
              to_char(ck.buffers_checkpoint, 'FM999,999,999,999'),
              to_char(bg.buffers_clean, 'FM999,999,999,999'),
              to_char(bg.maxwritten_clean, 'FM999,999,999,999'),
              to_char(bg.buffers_alloc, 'FM999,999,999,999'),
              CASE WHEN wl.wal_bytes IS NULL THEN 'pg_stat_wal is PostgreSQL 14 and newer; not available here'
                   ELSE format('%s total, %s per hour, %s records of which %s were full-page images (%s%%), %s buffer-full events',
                               pg_size_pretty(wl.wal_bytes::bigint),
                               pg_size_pretty((wl.wal_bytes / w.hours)::bigint),
                               to_char(wl.wal_records, 'FM999,999,999,999'),
                               to_char(wl.wal_fpi, 'FM999,999,999,999'),
                               round(100.0 * wl.wal_fpi / nullif(wl.wal_records, 0), 1)::text,
                               to_char(wl.wal_buffers_full, 'FM999,999,999,999')) END,
              to_char(ar.archived_count, 'FM999,999,999,999'), to_char(ar.failed_count, 'FM999,999,999,999'),
              coalesce(', last success ' || ar.last_archived_time::text, ' (archive_mode = ' || current_setting('archive_mode') || ')')) AS details,
       json_build_object('window_hours', round(w.hours, 2),
                         'checkpoints_timed', ck.timed, 'checkpoints_requested', ck.requested,
                         'checkpoints_per_hour', round((ck.timed + ck.requested) / w.hours, 3),
                         'avg_checkpoint_write_ms', round(ck.write_time / nullif(ck.timed + ck.requested, 0), 2),
                         'avg_checkpoint_sync_ms', round(ck.sync_time / nullif(ck.timed + ck.requested, 0), 2),
                         'buffers_checkpoint', ck.buffers_checkpoint,
                         'buffers_clean', bg.buffers_clean, 'maxwritten_clean', bg.maxwritten_clean,
                         'buffers_alloc', bg.buffers_alloc,
                         'wal_bytes', wl.wal_bytes::bigint, 'wal_records', wl.wal_records,
                         'wal_fpi', wl.wal_fpi, 'wal_buffers_full', wl.wal_buffers_full,
                         'wal_bytes_per_hour', (wl.wal_bytes / w.hours)::bigint,
                         'archived_count', ar.archived_count, 'failed_count', ar.failed_count,
                         'last_archived_time', ar.last_archived_time,
                         'checkpoint_stats_reset', ck.stats_reset,
                         'wal_stats_reset', wl.stats_reset, 'archiver_stats_reset', ar.stats_reset)::text AS evidence_json,
       'high'::text AS confidence
FROM ck, bg, wl, ar, w;
