-- check: PG-WAL-001
-- title: Checkpoints mostly requested (max_wal_size too small)
-- priority: 50
-- scope: cluster
-- cost: 0
-- run_on: primary
-- thresholds: min_checkpoints, requested_ratio
-- PostgreSQL 17 moved the checkpoint counters from pg_stat_bgwriter to
-- pg_stat_checkpointer and renamed them; both shapes are handled below.
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 170000) AS pg_wal_001_pg17 \gset
WITH c AS (
\if :pg_wal_001_pg17
  SELECT num_timed AS timed, num_requested AS requested, stats_reset FROM pg_stat_checkpointer
\else
  SELECT checkpoints_timed AS timed, checkpoints_req AS requested, stats_reset FROM pg_stat_bgwriter
\endif
)
SELECT 'PG-WAL-001'::text AS check_id,
       'cluster'::text    AS scope,
       'max_wal_size'::text AS object,
       format('%s of %s checkpoints since %s were requested rather than timed (%s%%, threshold %s%%). A requested checkpoint means WAL hit max_wal_size (%s) before checkpoint_timeout (%s) elapsed, so checkpoints are driven by write volume instead of by the clock. Each one restarts full-page-image logging, so WAL volume and I/O both rise. Raising max_wal_size costs disk in pg_wal and nothing else.',
              to_char(c.requested, 'FM999,999,999'), to_char(c.timed + c.requested, 'FM999,999,999'),
              coalesce(c.stats_reset::text, 'the last statistics reset'),
              round(100.0 * c.requested / nullif(c.timed + c.requested, 0), 1)::text,
              round(100 * :'pg_wal_001_requested_ratio'::numeric)::text,
              current_setting('max_wal_size'),
              current_setting('checkpoint_timeout')) AS details,
       json_build_object('checkpoints_timed', c.timed, 'checkpoints_requested', c.requested,
                         'requested_ratio', round(c.requested::numeric / nullif(c.timed + c.requested, 0), 4),
                         'threshold_ratio', :'pg_wal_001_requested_ratio'::numeric,
                         'stats_reset', c.stats_reset,
                         'max_wal_size', current_setting('max_wal_size'),
                         'checkpoint_timeout', current_setting('checkpoint_timeout'))::text AS evidence_json,
       'medium'::text AS confidence
FROM c
WHERE NOT pg_is_in_recovery()
  AND c.timed + c.requested >= :'pg_wal_001_min_checkpoints'::int
  AND c.requested::numeric / nullif(c.timed + c.requested, 0) >= :'pg_wal_001_requested_ratio'::numeric;
