-- check: PG-WAL-004
-- title: Backends forced to write or fsync their own buffers
-- priority: 100
-- scope: cluster
-- cost: 0
-- run_on: primary
-- pg_stat_io (PostgreSQL 16+) reports backend writes and fsyncs directly.
-- Before 16 the same signal comes from pg_stat_bgwriter.buffers_backend and
-- buffers_backend_fsync, which PostgreSQL 17 removed.
\set ON_ERROR_STOP off
SELECT (current_setting('server_version_num')::int >= 160000) AS pg_wal_004_has_stat_io \gset
\if :pg_wal_004_has_stat_io
WITH io AS (
  SELECT sum(writes) FILTER (WHERE backend_type = 'client backend')          AS backend_writes,
         sum(fsyncs) FILTER (WHERE backend_type = 'client backend')          AS backend_fsyncs,
         sum(writes) FILTER (WHERE backend_type IN ('checkpointer', 'background writer')) AS helper_writes,
         max(stats_reset)                                                    AS stats_reset
  FROM pg_stat_io
  WHERE context = 'normal' AND object = 'relation'
)
SELECT 'PG-WAL-004'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('Client backends performed %s buffer writes and %s fsyncs of their own since %s, against %s writes by the checkpointer and background writer combined. A backend that has to evict and write its own dirty buffer stalls the query that owns it, and a backend fsync means the fsync request queue was full. Raise max_wal_size, raise bgwriter_lru_maxpages (currently %s), or fix storage latency. Read from pg_stat_io.',
              to_char(coalesce(io.backend_writes, 0), 'FM999,999,999,999'),
              to_char(coalesce(io.backend_fsyncs, 0), 'FM999,999,999,999'),
              coalesce(io.stats_reset::text, 'the last statistics reset'),
              to_char(coalesce(io.helper_writes, 0), 'FM999,999,999,999'),
              (SELECT setting FROM pg_settings WHERE name = 'bgwriter_lru_maxpages')) AS details,
       json_build_object('source', 'pg_stat_io',
                         'backend_writes', coalesce(io.backend_writes, 0),
                         'backend_fsyncs', coalesce(io.backend_fsyncs, 0),
                         'helper_writes', coalesce(io.helper_writes, 0),
                         'stats_reset', io.stats_reset,
                         'bgwriter_lru_maxpages', (SELECT setting::int FROM pg_settings WHERE name = 'bgwriter_lru_maxpages'),
                         'max_wal_size', current_setting('max_wal_size'))::text AS evidence_json,
       'medium'::text AS confidence
FROM io
WHERE NOT pg_is_in_recovery()
  AND (coalesce(io.backend_fsyncs, 0) > 0
    OR coalesce(io.backend_writes, 0) > coalesce(io.helper_writes, 0));
\else
SELECT 'PG-WAL-004'::text AS check_id,
       'cluster'::text    AS scope,
       NULL::text         AS object,
       format('Client backends performed %s buffer writes and %s fsyncs of their own since %s, against %s by the checkpointer and %s by the background writer. A backend that has to evict and write its own dirty buffer stalls the query that owns it, and a backend fsync means the fsync request queue was full. Raise max_wal_size, raise bgwriter_lru_maxpages (currently %s), or fix storage latency. Read from pg_stat_bgwriter.',
              to_char(b.buffers_backend, 'FM999,999,999,999'),
              to_char(b.buffers_backend_fsync, 'FM999,999,999,999'),
              coalesce(b.stats_reset::text, 'the last statistics reset'),
              to_char(b.buffers_checkpoint, 'FM999,999,999,999'),
              to_char(b.buffers_clean, 'FM999,999,999,999'),
              (SELECT setting FROM pg_settings WHERE name = 'bgwriter_lru_maxpages')) AS details,
       json_build_object('source', 'pg_stat_bgwriter',
                         'buffers_backend', b.buffers_backend,
                         'buffers_backend_fsync', b.buffers_backend_fsync,
                         'buffers_checkpoint', b.buffers_checkpoint,
                         'buffers_clean', b.buffers_clean,
                         'stats_reset', b.stats_reset,
                         'bgwriter_lru_maxpages', (SELECT setting::int FROM pg_settings WHERE name = 'bgwriter_lru_maxpages'))::text AS evidence_json,
       'medium'::text AS confidence
FROM pg_stat_bgwriter b
WHERE NOT pg_is_in_recovery()
  AND (b.buffers_backend_fsync > 0
    OR b.buffers_backend > b.buffers_checkpoint + b.buffers_clean);
\endif
