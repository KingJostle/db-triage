-- check: PG-QRY-013
-- title: Plan-instability candidates (high standard deviation)
-- priority: 150
-- scope: query
-- cost: 1
-- thresholds: stddev_multiple, min_calls, min_mean_ms, top_n
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_013_pgss \gset
\if :pg_qry_013_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'total_exec_time' AND NOT attisdropped) AS pg_qry_013_v18 \gset
WITH q AS (
\if :pg_qry_013_v18
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

SELECT 'PG-QRY-013'::text AS check_id,
       'query'::text      AS scope,
       ('queryid:' || q.queryid::text)::text AS object,
       format('Execution time for this statement has a standard deviation of %s ms against a mean of %s ms (%sx, threshold %sx) over %s calls. A spread that wide means the same normalised statement sometimes runs quickly and sometimes does not: parameter values that select very different row counts, a generic plan chosen after five executions of a prepared statement, or a working set that is sometimes cached and sometimes not. The mean and the "top by total time" ranking both hide this. Total %s ms, %s rows per call. Statement: %s',
              round(q.stddev_ms, 2)::text, round(q.mean_ms, 2)::text,
              round(q.stddev_ms / nullif(q.mean_ms, 0), 1)::text,
              :'pg_qry_013_stddev_multiple'::text,
              to_char(q.calls, 'FM999,999,999,999'),
              to_char(round(q.total_ms), 'FM999,999,999,999'),
              round(q.rows::numeric / nullif(q.calls, 0), 1)::text,
              left(regexp_replace(q.query, '\s+', ' ', 'g'), 300)) AS details,
       json_build_object('queryid', q.queryid, 'calls', q.calls,
                         'mean_ms', round(q.mean_ms, 3), 'stddev_ms', round(q.stddev_ms, 3),
                         'stddev_multiple', round(q.stddev_ms / nullif(q.mean_ms, 0), 2),
                         'threshold_multiple', :'pg_qry_013_stddev_multiple'::numeric,
                         'total_ms', round(q.total_ms, 2),
                         'rows_per_call', round(q.rows::numeric / nullif(q.calls, 0), 2),
                         'plan_cache_mode', current_setting('plan_cache_mode'),
                         'query', left(regexp_replace(q.query, '\s+', ' ', 'g'), 300))::text AS evidence_json,
       'low'::text AS confidence
FROM q CROSS JOIN tot t
WHERE q.calls >= :'pg_qry_013_min_calls'::bigint
  AND q.mean_ms >= :'pg_qry_013_min_mean_ms'::numeric
  AND q.stddev_ms >= :'pg_qry_013_stddev_multiple'::numeric * q.mean_ms
ORDER BY q.total_ms DESC
LIMIT :'pg_qry_013_top_n'::int;
\endif
