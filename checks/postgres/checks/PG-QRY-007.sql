-- check: PG-QRY-007
-- title: Top 10 statements by WAL generated
-- priority: 240
-- scope: query
-- cost: 1
-- thresholds: top_n
-- Requires pg_stat_statements in this database; PG-QRY-001 fires when it is absent.
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_007_pgss \gset
\if :pg_qry_007_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'total_exec_time' AND NOT attisdropped) AS pg_qry_007_v18 \gset
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'wal_bytes' AND NOT attisdropped) AS pg_qry_007_has_wal \gset
WITH q AS (
\if :pg_qry_007_v18
  SELECT queryid, query, calls, rows,
         total_exec_time::numeric AS total_ms, mean_exec_time::numeric AS mean_ms, stddev_exec_time::numeric AS stddev_ms,
         shared_blks_read, shared_blks_hit, temp_blks_read, temp_blks_written,
\if :pg_qry_007_has_wal
         wal_bytes, wal_records,
\else
         0::numeric AS wal_bytes, 0::bigint AS wal_records,
\endif
         userid, dbid
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
\else
  SELECT queryid, query, calls, rows,
         total_time::numeric AS total_ms, mean_time::numeric AS mean_ms, stddev_time::numeric AS stddev_ms,
         shared_blks_read, shared_blks_hit, temp_blks_read, temp_blks_written,
         0::numeric AS wal_bytes, 0::bigint AS wal_records,
         userid, dbid
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
\endif
),
tot AS (SELECT sum(total_ms) AS all_ms, sum(calls) AS all_calls FROM q)

SELECT 'PG-QRY-007'::text AS check_id,
       'query'::text   AS scope,
       ('queryid:' || q.queryid::text)::text AS object,
       format('#%s by WAL generated: %s of WAL. %s calls, mean %s ms, %s rows per call, %s%% of total execution time on this database. Shared blocks: %s read, %s hit. Temp blocks written: %s.%s Statement (normalised, first 300 characters): %s',
              row_number() OVER (ORDER BY q.wal_bytes DESC),
              pg_size_pretty(q.wal_bytes::bigint),
              to_char(q.calls, 'FM999,999,999,999'),
              round(q.mean_ms, 2)::text,
              round(q.rows::numeric / nullif(q.calls, 0), 1)::text,
              round(100.0 * q.total_ms / nullif(t.all_ms, 0), 1)::text,
              to_char(q.shared_blks_read, 'FM999,999,999,999'),
              to_char(q.shared_blks_hit, 'FM999,999,999,999'),
              to_char(q.temp_blks_written, 'FM999,999,999,999'),
              CASE WHEN q.wal_bytes > 0 THEN ' WAL generated: ' || pg_size_pretty(q.wal_bytes::bigint) || '.' ELSE '' END,
              left(regexp_replace(q.query, '\s+', ' ', 'g'), 300)) AS details,
       json_build_object('queryid', q.queryid, 'calls', q.calls, 'rows', q.rows,
                         'total_ms', round(q.total_ms, 2), 'mean_ms', round(q.mean_ms, 3),
                         'stddev_ms', round(q.stddev_ms, 3),
                         'pct_of_total_time', round(100.0 * q.total_ms / nullif(t.all_ms, 0), 2),
                         'shared_blks_read', q.shared_blks_read, 'shared_blks_hit', q.shared_blks_hit,
                         'temp_blks_read', q.temp_blks_read, 'temp_blks_written', q.temp_blks_written,
                         'wal_bytes', q.wal_bytes::bigint, 'wal_records', q.wal_records,
                         'usename', (SELECT rolname FROM pg_roles WHERE oid = q.userid),
                         'query', left(regexp_replace(q.query, '\s+', ' ', 'g'), 300))::text AS evidence_json,
       'medium'::text AS confidence
FROM q CROSS JOIN tot t
WHERE q.wal_bytes > 0
ORDER BY q.wal_bytes DESC
LIMIT :'pg_qry_007_top_n'::int;
\endif
