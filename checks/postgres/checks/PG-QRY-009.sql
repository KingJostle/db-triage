-- check: PG-QRY-009
-- title: Statements spilling to temp files
-- priority: 100
-- scope: query
-- cost: 1
-- thresholds: temp_bytes, top_n
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_009_pgss \gset
\if :pg_qry_009_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'total_exec_time' AND NOT attisdropped) AS pg_qry_009_v18 \gset
WITH q AS (
\if :pg_qry_009_v18
  SELECT queryid, query, calls, rows,
         total_exec_time::numeric AS total_ms, mean_exec_time::numeric AS mean_ms,
         stddev_exec_time::numeric AS stddev_ms,
         shared_blks_read, shared_blks_hit, temp_blks_read, temp_blks_written, userid
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
\else
  SELECT queryid, query, calls, rows,
         total_time::numeric AS total_ms, mean_time::numeric AS mean_ms,
         stddev_time::numeric AS stddev_ms,
         shared_blks_read, shared_blks_hit, temp_blks_read, temp_blks_written, userid
  FROM pg_stat_statements WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
\endif
),
tot AS (SELECT sum(total_ms) AS all_ms, sum(calls) AS all_calls FROM q)

SELECT 'PG-QRY-009'::text AS check_id,
       'query'::text      AS scope,
       ('queryid:' || q.queryid::text)::text AS object,
       format('This statement has written %s of temporary files since the statistics reset (threshold %s) across %s calls: about %s per call. That is a sort, hash or materialise step that did not fit in work_mem (currently %s) and went to disk instead - each spill is a write and a re-read of data that could have stayed in memory. Mean execution time %s ms, %s rows per call. Raise work_mem for the role that runs this (%s) rather than globally, because the global value multiplies by max_connections in PG-MEM-003. Statement: %s',
              pg_size_pretty((q.temp_blks_written * current_setting('block_size')::bigint)::bigint),
              pg_size_pretty(:'pg_qry_009_temp_bytes'::bigint),
              to_char(q.calls, 'FM999,999,999,999'),
              pg_size_pretty((q.temp_blks_written * current_setting('block_size')::bigint / greatest(q.calls, 1))::bigint),
              current_setting('work_mem'),
              round(q.mean_ms, 2)::text,
              round(q.rows::numeric / nullif(q.calls, 0), 1)::text,
              coalesce((SELECT rolname FROM pg_roles WHERE oid = q.userid), 'unknown'),
              left(regexp_replace(q.query, '\s+', ' ', 'g'), 300)) AS details,
       json_build_object('queryid', q.queryid, 'calls', q.calls,
                         'temp_blks_written', q.temp_blks_written,
                         'temp_bytes', (q.temp_blks_written * current_setting('block_size')::bigint)::bigint,
                         'temp_bytes_per_call', (q.temp_blks_written * current_setting('block_size')::bigint / greatest(q.calls, 1))::bigint,
                         'threshold_bytes', :'pg_qry_009_temp_bytes'::bigint,
                         'mean_ms', round(q.mean_ms, 3),
                         'work_mem', current_setting('work_mem'),
                         'usename', (SELECT rolname FROM pg_roles WHERE oid = q.userid),
                         'query', left(regexp_replace(q.query, '\s+', ' ', 'g'), 300))::text AS evidence_json,
       'medium'::text AS confidence
FROM q CROSS JOIN tot t
WHERE q.temp_blks_written * current_setting('block_size')::bigint >= :'pg_qry_009_temp_bytes'::bigint
ORDER BY q.temp_blks_written DESC
LIMIT :'pg_qry_009_top_n'::int;
\endif
