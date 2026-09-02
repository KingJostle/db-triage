-- check: PG-WAL-009
-- title: Slow checkpoint sync phase
-- priority: 100
-- scope: cluster
-- cost: 0
-- run_on: primary
-- thresholds: sync_ms, min_checkpoints
-- PostgreSQL 17 renamed checkpoint_write_time/checkpoint_sync_time to
-- write_time/sync_time and moved them to pg_stat_checkpointer.
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 170000) AS pg_wal_009_pg17 \gset
WITH c AS (
\if :pg_wal_009_pg17
  SELECT num_timed + num_requested AS checkpoints,
         write_time::numeric AS write_time, sync_time::numeric AS sync_time, stats_reset
  FROM pg_stat_checkpointer
\else
  SELECT checkpoints_timed + checkpoints_req AS checkpoints,
         checkpoint_write_time::numeric AS write_time, checkpoint_sync_time::numeric AS sync_time, stats_reset
  FROM pg_stat_bgwriter
\endif
)
SELECT 'PG-WAL-009'::text     AS check_id,
       'cluster'::text        AS scope,
       'checkpoint sync'::text AS object,
       format('Checkpoints spend an average of %s ms in the sync phase (threshold %s ms) across %s checkpoints since %s, against %s ms average in the write phase. The sync phase is the fsync of every file the checkpoint dirtied; a long one is storage fsync latency, and it blocks the checkpoint from completing while WAL keeps accumulating. Total sync time %s ms.',
              round(c.sync_time / nullif(c.checkpoints, 0), 1)::text,
              :'pg_wal_009_sync_ms'::text,
              to_char(c.checkpoints, 'FM999,999,999'),
              coalesce(c.stats_reset::text, 'the last statistics reset'),
              round(c.write_time / nullif(c.checkpoints, 0), 1)::text,
              to_char(c.sync_time, 'FM999,999,999,999')) AS details,
       json_build_object('checkpoints', c.checkpoints,
                         'avg_sync_ms', round(c.sync_time / nullif(c.checkpoints, 0), 2),
                         'avg_write_ms', round(c.write_time / nullif(c.checkpoints, 0), 2),
                         'total_sync_ms', c.sync_time, 'total_write_ms', c.write_time,
                         'threshold_ms', :'pg_wal_009_sync_ms'::numeric,
                         'stats_reset', c.stats_reset)::text AS evidence_json,
       'medium'::text AS confidence
FROM c
WHERE NOT pg_is_in_recovery()
  AND c.checkpoints >= :'pg_wal_009_min_checkpoints'::int
  AND c.sync_time / nullif(c.checkpoints, 0) >= :'pg_wal_009_sync_ms'::numeric;
