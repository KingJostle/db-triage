-- check: PG-WAL-002
-- title: max_wal_size at the default on a write-active primary
-- priority: 100
-- scope: setting
-- cost: 0
-- run_on: primary
-- thresholds: wal_bytes_per_hour
-- pg_stat_wal arrived in PostgreSQL 14. Below that the WAL rate is estimated
-- from the position of the write-ahead log against server uptime, which is a
-- lower bound (it misses WAL written before the last restart).
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 140000) AS pg_wal_002_has_stat_wal \gset
WITH w AS (
\if :pg_wal_002_has_stat_wal
  SELECT wal_bytes::numeric AS wal_bytes,
         greatest(extract(epoch FROM now() - coalesce(stats_reset, pg_postmaster_start_time())), 60) AS window_seconds,
         'pg_stat_wal since stats_reset'::text AS source
  FROM pg_stat_wal
\else
  SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')::numeric AS wal_bytes,
         greatest(extract(epoch FROM now() - pg_postmaster_start_time()), 60) AS window_seconds,
         'WAL position against uptime (lower bound)'::text AS source
\endif
)
SELECT 'PG-WAL-002'::text   AS check_id,
       'setting'::text      AS scope,
       'max_wal_size'::text AS object,
       format('max_wal_size is at the shipped default of 1 GB while this primary generates about %s of WAL per hour (%s, over %s). At that rate max_wal_size is consumed every %s, so checkpoints are triggered by volume rather than by checkpoint_timeout (%s) - see PG-WAL-001. Raising max_wal_size trades pg_wal disk for fewer checkpoints and less full-page-image WAL.',
              pg_size_pretty((w.wal_bytes / w.window_seconds * 3600)::bigint),
              w.source,
              justify_interval(date_trunc('second', make_interval(secs => w.window_seconds))),
              justify_interval(date_trunc('second',
                make_interval(secs => (1073741824.0 / greatest(w.wal_bytes / w.window_seconds, 1))::double precision))),
              current_setting('checkpoint_timeout')) AS details,
       json_build_object('max_wal_size_bytes', 1073741824::bigint,
                         'wal_bytes_per_hour', round(w.wal_bytes / w.window_seconds * 3600)::bigint,
                         'threshold_bytes_per_hour', :'pg_wal_002_wal_bytes_per_hour'::bigint,
                         'window_seconds', round(w.window_seconds)::bigint,
                         'measurement_source', w.source,
                         'checkpoint_timeout', current_setting('checkpoint_timeout'))::text AS evidence_json,
       'medium'::text AS confidence
FROM w
WHERE NOT pg_is_in_recovery()
  AND (SELECT setting::bigint FROM pg_settings WHERE name = 'max_wal_size') = 1024
  AND w.wal_bytes / w.window_seconds * 3600 >= :'pg_wal_002_wal_bytes_per_hour'::bigint;
