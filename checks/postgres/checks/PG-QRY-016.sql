-- check: PG-QRY-016
-- title: High-frequency statements returning almost no rows
-- priority: 150
-- scope: query
-- cost: 1
-- thresholds: min_calls, rows_per_call, top_n
\set ON_ERROR_STOP off
SELECT (to_regclass('pg_stat_statements') IS NOT NULL) AS pg_qry_016_pgss \gset
\if :pg_qry_016_pgss
SELECT EXISTS (SELECT 1 FROM pg_attribute
               WHERE attrelid = to_regclass('pg_stat_statements')
                 AND attname = 'total_exec_time' AND NOT attisdropped) AS pg_qry_016_v18 \gset
WITH q AS (
\if :pg_qry_016_v18
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

SELECT 'PG-QRY-016'::text AS check_id,
       'query'::text      AS scope,
       ('queryid:' || q.queryid::text)::text AS object,
       format('This statement has been executed %s times (threshold %s) and returned %s rows in total: %s rows per call (threshold %s). Total execution time %s ms, mean %s ms - individually trivial, collectively %s%% of all recorded execution time on this database, plus one round trip and one snapshot each. This shape is a polling loop, a health check, or an existence test in application code that could be cached, batched, or replaced by a notification. Statement: %s',
              to_char(q.calls, 'FM999,999,999,999'),
              to_char(:'pg_qry_016_min_calls'::bigint, 'FM999,999,999,999'),
              to_char(q.rows, 'FM999,999,999,999'),
              round(q.rows::numeric / nullif(q.calls, 0), 4)::text,
              :'pg_qry_016_rows_per_call'::text,
              to_char(round(q.total_ms), 'FM999,999,999,999'),
              round(q.mean_ms, 3)::text,
              round(100.0 * q.total_ms / nullif(t.all_ms, 0), 1)::text,
              left(regexp_replace(q.query, '\s+', ' ', 'g'), 300)) AS details,
       json_build_object('queryid', q.queryid, 'calls', q.calls, 'rows', q.rows,
                         'rows_per_call', round(q.rows::numeric / nullif(q.calls, 0), 5),
                         'threshold_calls', :'pg_qry_016_min_calls'::bigint,
                         'threshold_rows_per_call', :'pg_qry_016_rows_per_call'::numeric,
                         'total_ms', round(q.total_ms, 2), 'mean_ms', round(q.mean_ms, 4),
                         'pct_of_total_time', round(100.0 * q.total_ms / nullif(t.all_ms, 0), 2),
                         'query', left(regexp_replace(q.query, '\s+', ' ', 'g'), 300))::text AS evidence_json,
       'medium'::text AS confidence
FROM q CROSS JOIN tot t
WHERE q.calls >= :'pg_qry_016_min_calls'::bigint
  AND q.rows::numeric / nullif(q.calls, 0) < :'pg_qry_016_rows_per_call'::numeric
ORDER BY q.calls DESC
LIMIT :'pg_qry_016_top_n'::int;
\endif
